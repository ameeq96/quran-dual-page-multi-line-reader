import 'dart:collection';

import 'package:dio/dio.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../../../core/storage/reader_preferences.dart';
import '../../domain/models/quran_chapter_summary.dart';
import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_navigation_marker.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/quran_page_insight.dart';
import '../../domain/models/quran_search_result.dart';
import '../../domain/models/quran_spread.dart';
import '../../domain/models/quran_asset_pack_download.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_growth_models.dart';
import '../../domain/models/reader_bookmark.dart';
import '../../domain/models/reader_daily_progress_state.dart';
import '../../domain/models/reader_history_entry.dart';
import '../../domain/models/reader_settings.dart';
import '../models/reader_launch_state.dart';
import '../services/quran_asset_resolver.dart';
import '../services/quran_navigation_data_source.dart';
import '../services/quran_page_insights_data_source.dart';
import '../services/quran_admin_config_service.dart';
import '../services/quran_remote_content_service.dart';
import '../services/quran_text_data_source.dart';

class QuranReaderRepository {
  static const int _maxPageCacheEntries = 320;
  static const int _maxSpreadCacheEntries = 160;
  static const int _maxSearchCacheEntries = 48;

  QuranReaderRepository({
    required QuranAssetResolver assetResolver,
    required QuranNavigationDataSource navigationDataSource,
    required QuranTextDataSource textDataSource,
    required QuranPageInsightsDataSource pageInsightsDataSource,
    required QuranAdminConfigService adminConfigService,
    required QuranRemoteContentService remoteContentService,
    required ReaderPreferences preferences,
  })  : _assetResolver = assetResolver,
        _navigationDataSource = navigationDataSource,
        _textDataSource = textDataSource,
        _pageInsightsDataSource = pageInsightsDataSource,
        _adminConfigService = adminConfigService,
        _remoteContentService = remoteContentService,
        _preferences = preferences;

  static const int _standardTotalPages = 604;
  final QuranAssetResolver _assetResolver;
  final QuranNavigationDataSource _navigationDataSource;
  final QuranTextDataSource _textDataSource;
  final QuranPageInsightsDataSource _pageInsightsDataSource;
  final QuranAdminConfigService _adminConfigService;
  final QuranRemoteContentService _remoteContentService;
  final ReaderPreferences _preferences;
  final LinkedHashMap<String, QuranPage> _pageCache =
      LinkedHashMap<String, QuranPage>();
  final LinkedHashMap<String, QuranSpread> _spreadCache =
      LinkedHashMap<String, QuranSpread>();
  final Map<String, Map<int, int>> _surahStartPageCache =
      <String, Map<int, int>>{};
  final Map<String, Map<int, int>> _juzStartPageCache =
      <String, Map<int, int>>{};
  final Map<String, Map<int, int>> _standardToNavigationPageCache =
      <String, Map<int, int>>{};
  final Map<String, Map<int, int>> _navigationToStandardPageCache =
      <String, Map<int, int>>{};
  final LinkedHashMap<String, List<QuranSearchResult>> _pageSearchCache =
      LinkedHashMap<String, List<QuranSearchResult>>();
  final LinkedHashMap<String, List<QuranSearchResult>> _ayahSearchCache =
      LinkedHashMap<String, List<QuranSearchResult>>();
  Future<void>? _supplementalContentWarmFuture;

  Future<ReaderLaunchState> loadLaunchState() async {
    final settingsFuture = _preferences.loadSettings();
    final initialPageNumberFuture = _preferences.loadLastPageNumber();
    final adminConfig = await _adminConfigService.loadConfig();
    var settings = await settingsFuture;
    final effectiveAdminConfig = await _initializeNavigationConfig(
      adminConfig,
      edition: settings.mushafEdition,
    );
    settings = await applyAdminReaderDefaults(
      settings,
      config: effectiveAdminConfig,
    );
    _assetResolver.applyRemoteConfig(effectiveAdminConfig);
    await _assetResolver.initialize();
    if (effectiveAdminConfig.hasEditionControls &&
        !_assetResolver.hasAssetsForEdition(settings.mushafEdition)) {
      final enabledEditions = _assetResolver.availableImageEditions;
      if (enabledEditions.isNotEmpty) {
        settings = settings.copyWith(mushafEdition: enabledEditions.first);
      }
    }
    final hasSelectedEditionAssets =
        _assetResolver.hasAssetsForEdition(settings.mushafEdition);
    final normalizedPreferImageMode = hasSelectedEditionAssets;
    if (settings.preferImageMode != normalizedPreferImageMode) {
      settings = settings.copyWith(
        preferImageMode: normalizedPreferImageMode,
      );
      await _preferences.saveSettings(settings);
    }
    _assetResolver.setSelectedEdition(settings.mushafEdition);
    final initialPageNumber = await initialPageNumberFuture;
    return ReaderLaunchState(
      initialPageNumber: clampPage(
        initialPageNumber,
        preferImageMode: settings.preferImageMode,
      ),
      settings: settings,
    );
  }

  Future<void> warmSupplementalContent({bool forceRefresh = false}) {
    if (!forceRefresh && _supplementalContentWarmFuture != null) {
      return _supplementalContentWarmFuture!;
    }

    final config = _adminConfigService.currentConfig;
    final future = Future.wait([
      _textDataSource.initialize(
        adminConfig: config,
        forceRefresh: forceRefresh,
      ),
      _pageInsightsDataSource.initialize(
        adminConfig: config,
        forceRefresh: forceRefresh,
      ),
    ]).then((_) {
      _clearResolvedPageCaches();
    });

    _supplementalContentWarmFuture = future.whenComplete(() {
      if (identical(_supplementalContentWarmFuture, future)) {
        _supplementalContentWarmFuture = null;
      }
    });

    return _supplementalContentWarmFuture!;
  }

  bool get hasAnyPageAssets => _assetResolver.hasAnyPageAssets;
  bool get hasRemoteImageEdition => _assetResolver.hasRemoteImageEdition;
  int get imagePageCount => _assetResolver.imagePageCount;
  int get imageLeadingPagesToSkip => _assetResolver.leadingPagesToSkip;
  MushafEdition get mushafEdition => _assetResolver.selectedEdition;
  int get textPageCount => _textDataSource.totalPages;
  List<QuranSurahNavigationEntry> get surahs => _navigationDataSource.surahs;
  List<QuranJuzNavigationEntry> get juzs => _navigationDataSource.juzs;
  List<QuranSurahNavigationEntry> get standardSurahs =>
      _navigationDataSource.standardSurahs;
  List<QuranJuzNavigationEntry> get standardJuzs =>
      _navigationDataSource.standardJuzs;
  List<QuranChapterSummary> get chapters =>
      _pageInsightsDataSource.chapters.toList(growable: false);
  ReaderAdminConfig get adminConfig => _adminConfigService.currentConfig;
  String get adminConfigBaseUrl => _adminConfigService.currentBaseUrl;
  List<MushafEdition> get availableImageEditions =>
      _assetResolver.availableImageEditions;
  List<MushafEdition> get compareEditions {
    final editions = availableImageEditions;
    if (editions.isNotEmpty) {
      return editions;
    }
    return MushafEdition.values.toList(growable: false);
  }

  Future<void> setMushafEdition(MushafEdition edition) async {
    _assetResolver.setSelectedEdition(edition);
    await _navigationDataSource.initialize(
      adminConfig: _adminConfigService.currentConfig,
      edition: edition,
    );
    _clearResolvedPageCaches();
  }

  MushafEdition resolveSupportedEdition(MushafEdition edition) {
    return _assetResolver.resolveSupportedEdition(edition);
  }

  bool hasAssetsForEdition(MushafEdition edition) {
    return _assetResolver.hasAssetsForEdition(edition);
  }

  bool hasBundledPackForEdition(MushafEdition edition) {
    return _assetResolver.hasBundledPackForEdition(edition);
  }

  Future<bool> hasOfflinePackForEdition(MushafEdition edition) {
    return _assetResolver.hasOfflinePackForEdition(edition);
  }

  List<QuranZipAssetPack> get availableZipPacks {
    return _assetResolver.availableZipPacksSnapshot;
  }

  Future<List<QuranZipAssetPack>> fetchAvailableZipPacks({
    bool forceRefresh = false,
  }) {
    return _assetResolver.fetchAvailableZipPacks(forceRefresh: forceRefresh);
  }

  Future<void> downloadOfflinePack(
    MushafEdition edition, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _assetResolver.downloadOfflinePack(
      edition,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    _clearResolvedPageCaches();
  }

  Future<void> removeOfflinePack(MushafEdition edition) async {
    await _assetResolver.removeOfflinePack(edition);
    _clearResolvedPageCaches();
  }

  int totalPagesForEdition(MushafEdition edition) {
    final imagePageCount = _assetResolver.imagePageCountForEdition(edition);
    if (imagePageCount > 0) {
      return imagePageCount;
    }
    return QuranConstants.defaultTotalPages;
  }

  int navigationPageForStandardPageInEdition(
    int standardPage, {
    required MushafEdition edition,
  }) {
    final normalizedStandard = QuranConstants.clampPage(
      standardPage,
      totalPages: _standardTotalPages,
    );
    final pageMap = _standardToNavigationPageCache.putIfAbsent(
      _editionNavigationCacheKey(edition),
      () => _buildStandardToNavigationPageCache(edition),
    );
    return pageMap[normalizedStandard] ?? normalizedStandard;
  }

  QuranPage pageForStandardPageInEdition(
    int standardPage, {
    required MushafEdition edition,
    required bool isLeftPage,
  }) {
    final pageNumber = navigationPageForStandardPageInEdition(
      standardPage,
      edition: edition,
    );
    return _pageForNumber(
      pageNumber,
      isLeftPage: isLeftPage,
      preferImageMode: true,
      explicitEdition: edition,
      explicitStandardPage: QuranConstants.clampPage(
        standardPage,
        totalPages: _standardTotalPages,
      ),
    );
  }

  int navigationPageForCurrentReferenceInEdition(
    int currentPageNumber, {
    required MushafEdition sourceEdition,
    required MushafEdition targetEdition,
    required bool preferImageMode,
  }) {
    if (!preferImageMode ||
        _assetResolver.imagePageCountForEdition(sourceEdition) == 0 ||
        _assetResolver.imagePageCountForEdition(targetEdition) == 0) {
      final standardPage = standardPageForNavigationPage(
        currentPageNumber,
        preferImageMode: preferImageMode,
      );
      return navigationPageForStandardPageInEdition(
        standardPage,
        edition: targetEdition,
      );
    }

    final sourceEntries = _navigationDataSource.surahsForEdition(sourceEdition);
    final targetEntries = _navigationDataSource.surahsForEdition(targetEdition);
    if (sourceEntries.isEmpty || targetEntries.isEmpty) {
      final standardPage = standardPageForNavigationPage(
        currentPageNumber,
        preferImageMode: true,
      );
      return navigationPageForStandardPageInEdition(
        standardPage,
        edition: targetEdition,
      );
    }

    final sourceSurah = _surahEntryForImagePage(
      currentPageNumber,
      edition: sourceEdition,
    );
    if (sourceSurah == null) {
      final standardPage = standardPageForNavigationPage(
        currentPageNumber,
        preferImageMode: true,
      );
      return navigationPageForStandardPageInEdition(
        standardPage,
        edition: targetEdition,
      );
    }

    final sourceIndex =
        sourceEntries.indexWhere((entry) => entry.id == sourceSurah.id);
    final targetIndex =
        targetEntries.indexWhere((entry) => entry.id == sourceSurah.id);
    if (sourceIndex < 0 || targetIndex < 0) {
      final standardPage = standardPageForNavigationPage(
        currentPageNumber,
        preferImageMode: true,
      );
      return navigationPageForStandardPageInEdition(
        standardPage,
        edition: targetEdition,
      );
    }

    final sourceStartPage = _navigationAnchorPageForImportedPage(
      sourceEdition,
      sourceEntries[sourceIndex].tajScanStartPage,
    );
    final sourceEndPage = sourceIndex + 1 < sourceEntries.length
        ? _navigationAnchorPageForImportedPage(
              sourceEdition,
              sourceEntries[sourceIndex + 1].tajScanStartPage,
            ) -
            1
        : totalPagesForEdition(sourceEdition);
    final normalizedSourcePage = QuranConstants.clampPage(
      currentPageNumber,
      totalPages: totalPagesForEdition(sourceEdition),
    );
    final sourceOffset =
        normalizedSourcePage.clamp(sourceStartPage, sourceEndPage).toInt() -
            sourceStartPage;

    final targetStartPage = _navigationAnchorPageForImportedPage(
      targetEdition,
      targetEntries[targetIndex].tajScanStartPage,
    );
    final targetEndPage = targetIndex + 1 < targetEntries.length
        ? _navigationAnchorPageForImportedPage(
              targetEdition,
              targetEntries[targetIndex + 1].tajScanStartPage,
            ) -
            1
        : totalPagesForEdition(targetEdition);

    final targetPage = targetStartPage + sourceOffset;
    final clampedTargetPage = targetPage > targetEndPage
        ? targetEndPage
        : targetPage < targetStartPage
            ? targetStartPage
            : targetPage;
    return QuranConstants.clampPage(
      clampedTargetPage,
      totalPages: totalPagesForEdition(targetEdition),
    );
  }

  QuranPage pageForCurrentReferenceInEdition(
    int currentPageNumber, {
    required MushafEdition sourceEdition,
    required MushafEdition targetEdition,
    required bool preferImageMode,
    required bool isLeftPage,
  }) {
    final pageNumber = navigationPageForCurrentReferenceInEdition(
      currentPageNumber,
      sourceEdition: sourceEdition,
      targetEdition: targetEdition,
      preferImageMode: preferImageMode,
    );
    return _pageForNumber(
      pageNumber,
      isLeftPage: isLeftPage,
      preferImageMode: true,
      explicitEdition: targetEdition,
    );
  }

  List<QuranNavigationMarker> markersForCategory(
    String category, {
    required bool preferImageMode,
  }) {
    final markersById = <int, QuranNavigationMarker>{};

    for (final page in _pageInsightsDataSource.pages) {
      final targetPage = navigationPageForStandardPage(
        page.pageNumber,
        preferImageMode: preferImageMode,
      );
      final values = _markerValuesForPage(page, category);
      final titlePrefix = _markerTitlePrefix(category);

      final chapter = page.primaryChapterId == null
          ? null
          : chapterSummaryForId(page.primaryChapterId!);
      for (final value in values) {
        markersById.putIfAbsent(
          value,
          () => QuranNavigationMarker(
            id: value,
            title: '$titlePrefix $value',
            subtitle: chapter == null
                ? 'Page $targetPage'
                : '${chapter.nameSimple} • Page $targetPage',
            pageNumber: targetPage,
            category: category,
          ),
        );
      }
    }

    final markers = markersById.values.toList(growable: false);
    markers.sort((a, b) => a.id.compareTo(b.id));
    return markers;
  }

  int totalPagesForMode({
    required bool preferImageMode,
  }) {
    if (preferImageMode && _assetResolver.imagePageCount > 0) {
      return _assetResolver.imagePageCount;
    }
    if (_textDataSource.totalPages > 0) {
      return _textDataSource.totalPages;
    }
    return QuranConstants.defaultTotalPages;
  }

  int totalSpreadsForMode({
    required bool preferImageMode,
  }) {
    return QuranConstants.totalSpreadsFor(
      totalPagesForMode(preferImageMode: preferImageMode),
    );
  }

  int clampSpread(
    int spreadIndex, {
    required bool preferImageMode,
  }) {
    return QuranConstants.clampSpread(
      spreadIndex,
      totalPages: totalPagesForMode(preferImageMode: preferImageMode),
    );
  }

  int clampPage(
    int pageNumber, {
    required bool preferImageMode,
  }) {
    return QuranConstants.clampPage(
      pageNumber,
      totalPages: totalPagesForMode(preferImageMode: preferImageMode),
    );
  }

  int spreadIndexFromPage(
    int pageNumber, {
    required bool preferImageMode,
  }) {
    return QuranConstants.spreadIndexFromPage(
      pageNumber,
      totalPages: totalPagesForMode(preferImageMode: preferImageMode),
    );
  }

  int navigationPageForSurah(
    QuranSurahNavigationEntry entry, {
    required bool preferImageMode,
  }) {
    if (preferImageMode && _assetResolver.imagePageCount > 0) {
      return clampPage(
        _navigationAnchorPageForImportedPage(
          _assetResolver.selectedEdition,
          entry.tajScanStartPage,
        ),
        preferImageMode: true,
      );
    }

    final resolvedPage = _resolvedSurahStartPage(
      entry.id,
      preferImageMode: preferImageMode,
    );
    if (resolvedPage != null) {
      return clampPage(
        resolvedPage,
        preferImageMode: preferImageMode,
      );
    }

    return navigationPageForStandardPage(
      entry.standardStartPage,
      preferImageMode: preferImageMode,
    );
  }

  int navigationPageForJuz(
    QuranJuzNavigationEntry entry, {
    required bool preferImageMode,
  }) {
    if (preferImageMode && _assetResolver.imagePageCount > 0) {
      return clampPage(
        _navigationAnchorPageForImportedPage(
          _assetResolver.selectedEdition,
          entry.tajScanStartPage,
        ),
        preferImageMode: true,
      );
    }

    final resolvedPage = _resolvedJuzStartPage(
      entry.number,
      preferImageMode: preferImageMode,
    );
    if (resolvedPage != null) {
      return clampPage(
        resolvedPage,
        preferImageMode: preferImageMode,
      );
    }

    return navigationPageForStandardPage(
      entry.standardStartPage,
      preferImageMode: preferImageMode,
    );
  }

  int navigationPageForStandardPage(
    int standardPage, {
    required bool preferImageMode,
  }) {
    final normalizedStandard = QuranConstants.clampPage(
      standardPage,
      totalPages: _standardTotalPages,
    );
    if (!preferImageMode || _assetResolver.imagePageCount == 0) {
      return normalizedStandard;
    }
    final pageMap = _standardToNavigationPageCache.putIfAbsent(
      _navigationCacheKey(preferImageMode),
      () => _buildStandardToNavigationPageCache(_assetResolver.selectedEdition),
    );
    return pageMap[normalizedStandard] ??
        clampPage(
          normalizedStandard,
          preferImageMode: true,
        );
  }

  int standardPageForNavigationPage(
    int pageNumber, {
    required bool preferImageMode,
  }) {
    if (!preferImageMode || _assetResolver.imagePageCount == 0) {
      return QuranConstants.clampPage(
        pageNumber,
        totalPages: _standardTotalPages,
      );
    }
    final normalizedPage = clampPage(pageNumber, preferImageMode: true);
    final inverseMap = _navigationToStandardPageCache.putIfAbsent(
      _navigationCacheKey(preferImageMode),
      () => _buildNavigationToStandardPageCache(_assetResolver.selectedEdition),
    );
    return inverseMap[normalizedPage] ??
        QuranConstants.clampPage(
          normalizedPage,
          totalPages: _standardTotalPages,
        );
  }

  QuranSpread spreadForIndex(
    int spreadIndex, {
    required bool preferImageMode,
  }) {
    final totalPages = totalPagesForMode(preferImageMode: preferImageMode);
    final normalizedIndex = QuranConstants.clampSpread(
      spreadIndex,
      totalPages: totalPages,
    );
    final edition = _assetResolver.selectedEdition;
    final cacheKey =
        '${edition.storageValue}|${preferImageMode ? 1 : 0}|spread|$normalizedIndex';
    final cached = _readBoundedCache(_spreadCache, cacheKey);
    if (cached != null) {
      return cached;
    }

    final rightPageNumber = QuranConstants.rightPageForSpread(
      normalizedIndex,
      totalPages: totalPages,
    );
    final leftPageNumber = QuranConstants.leftPageForSpread(
      normalizedIndex,
      totalPages: totalPages,
    );

    final spread = QuranSpread(
      index: normalizedIndex,
      rightPage: _pageForNumber(
        rightPageNumber,
        isLeftPage: false,
        preferImageMode: preferImageMode,
      ),
      leftPage: _pageForNumber(
        leftPageNumber,
        isLeftPage: true,
        preferImageMode: preferImageMode,
      ),
    );
    _storeInBoundedCache(
      _spreadCache,
      cacheKey,
      spread,
      maxEntries: _maxSpreadCacheEntries,
    );
    return spread;
  }

  QuranPage pageForNumber(
    int pageNumber, {
    required bool isLeftPage,
    required bool preferImageMode,
  }) {
    final normalizedPageNumber = clampPage(
      pageNumber,
      preferImageMode: preferImageMode,
    );
    return _pageForNumber(
      normalizedPageNumber,
      isLeftPage: isLeftPage,
      preferImageMode: preferImageMode,
    );
  }

  QuranPageInsight? pageInsightForPageNumber(
    int pageNumber, {
    required bool preferImageMode,
  }) {
    final standardPage = standardPageForNavigationPage(
      pageNumber,
      preferImageMode: preferImageMode,
    );
    return _pageInsightsDataSource.pageForNumber(standardPage);
  }

  QuranChapterSummary? chapterSummaryForId(int chapterId) {
    return _pageInsightsDataSource.chapterForId(chapterId);
  }

  QuranChapterSummary? chapterSummaryForPage(
    int pageNumber, {
    required bool preferImageMode,
  }) {
    if (preferImageMode) {
      final entry = surahEntryForPage(
        pageNumber,
        preferImageMode: true,
      );
      if (entry != null) {
        final chapter = chapterSummaryForId(entry.id);
        if (chapter != null) {
          return chapter;
        }
      }
    }

    final insight = pageInsightForPageNumber(
      pageNumber,
      preferImageMode: preferImageMode,
    );
    final chapterId = insight?.primaryChapterId;
    if (chapterId == null) {
      return null;
    }
    return chapterSummaryForId(chapterId);
  }

  QuranSurahNavigationEntry? surahEntryForPage(
    int pageNumber, {
    required bool preferImageMode,
    MushafEdition? edition,
  }) {
    if (preferImageMode) {
      return _surahEntryForImagePage(
        pageNumber,
        edition: edition ?? _assetResolver.selectedEdition,
      );
    }

    final insight = pageInsightForPageNumber(
      pageNumber,
      preferImageMode: false,
    );
    final chapterId = insight?.primaryChapterId;
    if (chapterId == null) {
      return null;
    }

    for (final entry in standardSurahs) {
      if (entry.id == chapterId) {
        return entry;
      }
    }
    return null;
  }

  QuranJuzNavigationEntry? juzEntryForPage(
    int pageNumber, {
    required bool preferImageMode,
    MushafEdition? edition,
  }) {
    if (preferImageMode) {
      return _juzEntryForImagePage(
        pageNumber,
        edition: edition ?? _assetResolver.selectedEdition,
      );
    }

    final insight = pageInsightForPageNumber(
      pageNumber,
      preferImageMode: false,
    );
    final juzNumbers = insight?.juzNumbers;
    if (juzNumbers == null || juzNumbers.isEmpty) {
      return null;
    }
    final juzNumber = juzNumbers.first;
    for (final entry in standardJuzs) {
      if (entry.number == juzNumber) {
        return entry;
      }
    }
    return null;
  }

  List<QuranSearchResult> searchPages(
    String query, {
    required bool preferImageMode,
    int limit = 40,
  }) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final cacheKey = [
      _navigationCacheKey(preferImageMode),
      limit,
      normalizedQuery.toLowerCase(),
    ].join('|');
    final cached = _readBoundedCache(_pageSearchCache, cacheKey);
    if (cached != null) {
      return cached;
    }

    final lowerQuery = normalizedQuery.toLowerCase();
    final results = <QuranSearchResult>[];

    for (final pageData in _textDataSource.pages) {
      if (results.length >= limit) {
        break;
      }

      final standardPage = pageData.pageNumber;
      final targetPage = navigationPageForStandardPage(
        standardPage,
        preferImageMode: preferImageMode,
      );
      final insight = _pageInsightsDataSource.pageForNumber(standardPage);
      final chapter = insight?.primaryChapterId != null
          ? chapterSummaryForId(insight!.primaryChapterId!)
          : null;
      final title = chapter == null
          ? 'Page $targetPage'
          : '${chapter.nameSimple} • Page $targetPage';

      final verseMatch = _findVerseKeyMatch(insight, lowerQuery);
      if (verseMatch != null) {
        results.add(
          QuranSearchResult(
            pageNumber: targetPage,
            referencePageNumber: standardPage,
            title: title,
            snippet: 'Verse ${verseMatch.verseKey}',
            category: 'Ayah',
            verseKey: verseMatch.verseKey,
          ),
        );
        continue;
      }

      final verseTranslationMatches = _findVerseTranslationMatches(
        insight,
        lowerQuery,
        targetPage: targetPage,
        standardPage: standardPage,
        title: title,
        limit: limit - results.length,
      );
      if (verseTranslationMatches.isNotEmpty) {
        results.addAll(verseTranslationMatches);
        continue;
      }

      final arabicSnippet =
          _firstMatchingArabicSnippet(pageData, normalizedQuery);
      if (arabicSnippet != null) {
        results.add(
          QuranSearchResult(
            pageNumber: targetPage,
            referencePageNumber: standardPage,
            title: title,
            snippet: arabicSnippet,
            category: 'Arabic text',
          ),
        );
        continue;
      }

      final englishSnippet =
          _matchingTranslationSnippet(insight?.translationEn ?? '', lowerQuery);
      if (englishSnippet != null) {
        results.add(
          QuranSearchResult(
            pageNumber: targetPage,
            referencePageNumber: standardPage,
            title: title,
            snippet: englishSnippet,
            category: 'English translation',
          ),
        );
        continue;
      }

      final urduSnippet =
          _matchingTranslationSnippet(insight?.translationUr ?? '', lowerQuery);
      if (urduSnippet != null) {
        results.add(
          QuranSearchResult(
            pageNumber: targetPage,
            referencePageNumber: standardPage,
            title: title,
            snippet: urduSnippet,
            category: 'Urdu translation',
          ),
        );
      }
    }

    final frozenResults = List<QuranSearchResult>.unmodifiable(results);
    _storeInBoundedCache(
      _pageSearchCache,
      cacheKey,
      frozenResults,
      maxEntries: _maxSearchCacheEntries,
    );
    return frozenResults;
  }

  List<QuranSearchResult> searchAyahs(
    String query, {
    required bool preferImageMode,
    int limit = 40,
  }) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final cacheKey = [
      _navigationCacheKey(preferImageMode),
      limit,
      normalizedQuery.toLowerCase(),
    ].join('|');
    final cached = _readBoundedCache(_ayahSearchCache, cacheKey);
    if (cached != null) {
      return cached;
    }

    final lowerQuery = normalizedQuery.toLowerCase();
    final results = <QuranSearchResult>[];

    for (final insight in _pageInsightsDataSource.pages) {
      if (results.length >= limit) {
        break;
      }

      final targetPage = navigationPageForStandardPage(
        insight.pageNumber,
        preferImageMode: preferImageMode,
      );

      for (final verse in insight.verses) {
        if (results.length >= limit) {
          break;
        }

        final title = _ayahTitleForVerse(
          verse.chapterId,
          verse.verseNumber,
          targetPage,
        );
        final lowerVerseKey = verse.verseKey.toLowerCase();

        if (lowerVerseKey == lowerQuery || lowerVerseKey.contains(lowerQuery)) {
          results.add(
            QuranSearchResult(
              pageNumber: targetPage,
              referencePageNumber: insight.pageNumber,
              title: title,
              snippet: 'Verse ${verse.verseKey} - Page $targetPage',
              category: 'Ayah',
              verseKey: verse.verseKey,
            ),
          );
          continue;
        }

        final englishSnippet =
            _matchingTranslationSnippet(verse.translationEn, lowerQuery);
        if (englishSnippet != null) {
          results.add(
            QuranSearchResult(
              pageNumber: targetPage,
              referencePageNumber: insight.pageNumber,
              title: title,
              snippet: englishSnippet,
              category: 'Ayah translation',
              verseKey: verse.verseKey,
            ),
          );
          continue;
        }

        final urduSnippet =
            _matchingTranslationSnippet(verse.translationUr, lowerQuery);
        if (urduSnippet != null) {
          results.add(
            QuranSearchResult(
              pageNumber: targetPage,
              referencePageNumber: insight.pageNumber,
              title: title,
              snippet: urduSnippet,
              category: 'Ayah translation',
              verseKey: verse.verseKey,
            ),
          );
        }
      }
    }

    final frozenResults = List<QuranSearchResult>.unmodifiable(results);
    _storeInBoundedCache(
      _ayahSearchCache,
      cacheKey,
      frozenResults,
      maxEntries: _maxSearchCacheEntries,
    );
    return frozenResults;
  }

  Future<List<QuranSurahNavigationEntry>> searchSurahsRemote(
    String query,
  ) async {
    return _searchSurahsLocal(query);
  }

  Future<List<QuranJuzNavigationEntry>> searchJuzsRemote(
    String query,
  ) async {
    return _searchJuzsLocal(query);
  }

  Future<List<QuranNavigationMarker>> searchMarkersRemote(
    String query, {
    required String category,
    required bool preferImageMode,
  }) async {
    return _searchMarkersLocal(
      query,
      category: category,
      preferImageMode: preferImageMode,
    );
  }

  Future<List<QuranSearchResult>> searchPagesRemote(
    String query, {
    required bool preferImageMode,
    int limit = 40,
  }) async {
    return searchPages(
      query,
      preferImageMode: preferImageMode,
      limit: limit,
    );
  }

  Future<List<QuranSearchResult>> searchAyahsRemote(
    String query, {
    required bool preferImageMode,
    int limit = 40,
  }) async {
    return searchAyahs(
      query,
      preferImageMode: preferImageMode,
      limit: limit,
    );
  }

  Future<String?> loadChapterInfoForPage(
    int pageNumber, {
    required bool preferImageMode,
  }) async {
    final chapter = chapterSummaryForPage(
      pageNumber,
      preferImageMode: preferImageMode,
    );
    if (chapter == null) {
      return null;
    }
    return _remoteContentService.chapterInfo(chapter.id);
  }

  Future<String?> loadTafsirExcerptForPage(
    int pageNumber, {
    required bool preferImageMode,
  }) {
    final standardPage = standardPageForNavigationPage(
      pageNumber,
      preferImageMode: preferImageMode,
    );
    return _remoteContentService.tafsirExcerptForPage(standardPage);
  }

  Future<void> saveLastPageNumber(
    int pageNumber, {
    required bool preferImageMode,
  }) {
    return _preferences.saveLastPageNumber(
      clampPage(
        pageNumber,
        preferImageMode: preferImageMode,
      ),
    );
  }

  Future<void> saveSettings(ReaderSettings settings) {
    return _preferences.saveSettings(settings);
  }

  Future<int> loadDailyTargetPages() => _preferences.loadDailyTargetPages();

  Future<void> saveDailyTargetPages(int pageCount) {
    return _preferences.saveDailyTargetPages(pageCount);
  }

  Future<ReaderDailyProgressState> loadDailyProgressState({
    required String todayKey,
    required int fallbackStartPage,
  }) {
    return _preferences.loadDailyProgressState(
      todayKey: todayKey,
      fallbackStartPage: fallbackStartPage,
    );
  }

  Future<void> saveDailyProgressState(ReaderDailyProgressState state) {
    return _preferences.saveDailyProgressState(state);
  }

  Future<List<ReaderHistoryEntry>> loadReadingHistory() {
    return _preferences.loadReadingHistory();
  }

  Future<void> saveReadingHistory(List<ReaderHistoryEntry> entries) {
    return _preferences.saveReadingHistory(entries);
  }

  Future<Map<int, String>> loadPageNotes() => _preferences.loadPageNotes();

  Future<void> savePageNotes(Map<int, String> notes) {
    return _preferences.savePageNotes(notes);
  }

  Future<int?> loadPreferredReciterId() =>
      _preferences.loadPreferredReciterId();

  Future<void> savePreferredReciterId(int reciterId) {
    return _preferences.savePreferredReciterId(reciterId);
  }

  Future<List<int>> loadFavoritePages() => _preferences.loadFavoritePages();

  Future<void> saveFavoritePages(List<int> pages) {
    return _preferences.saveFavoritePages(pages);
  }

  Future<List<ReaderBookmark>> loadBookmarks() => _preferences.loadBookmarks();

  Future<void> saveBookmarks(List<ReaderBookmark> bookmarks) {
    return _preferences.saveBookmarks(bookmarks);
  }

  Future<int?> loadAudioChapterId() => _preferences.loadAudioChapterId();

  Future<void> saveAudioChapterId(int? chapterId) {
    return _preferences.saveAudioChapterId(chapterId);
  }

  Future<int> loadAudioPositionMillis() =>
      _preferences.loadAudioPositionMillis();

  Future<void> saveAudioPositionMillis(int positionMillis) {
    return _preferences.saveAudioPositionMillis(positionMillis);
  }

  Future<bool> loadAudioRepeatEnabled() =>
      _preferences.loadAudioRepeatEnabled();

  Future<void> saveAudioRepeatEnabled(bool enabled) {
    return _preferences.saveAudioRepeatEnabled(enabled);
  }

  Future<int> loadReadingStreakCount() => _preferences.loadReadingStreakCount();

  Future<void> saveReadingStreakCount(int count) {
    return _preferences.saveReadingStreakCount(count);
  }

  Future<String?> loadReadingStreakLastDate() {
    return _preferences.loadReadingStreakLastDate();
  }

  Future<void> saveReadingStreakLastDate(String? dateKey) {
    return _preferences.saveReadingStreakLastDate(dateKey);
  }

  Future<ReaderReadingPlan> loadReadingPlan() => _preferences.loadReadingPlan();

  Future<void> saveReadingPlan(ReaderReadingPlan plan) {
    return _preferences.saveReadingPlan(plan);
  }

  Future<List<ReaderHifzReviewEntry>> loadHifzRevisionEntries() {
    return _preferences.loadHifzRevisionEntries();
  }

  Future<void> saveHifzRevisionEntries(List<ReaderHifzReviewEntry> entries) {
    return _preferences.saveHifzRevisionEntries(entries);
  }

  Future<ReaderExperienceSettings> loadExperienceSettings() {
    return _preferences.loadExperienceSettings();
  }

  Future<void> saveExperienceSettings(ReaderExperienceSettings settings) {
    return _preferences.saveExperienceSettings(settings);
  }

  Future<ReaderAdminConfig> refreshAdminConfig() async {
    final config = await _adminConfigService.loadConfig(forceRefresh: true);
    final effectiveConfig = await _initializeNavigationConfig(
      config,
      edition: _assetResolver.selectedEdition,
      forceRefresh: true,
    );
    _assetResolver.applyRemoteConfig(effectiveConfig);
    _clearResolvedPageCaches();
    return effectiveConfig;
  }

  Future<ReaderSettings> applyAdminReaderDefaults(
    ReaderSettings settings, {
    ReaderAdminConfig? config,
  }) async {
    final effectiveConfig = config ?? _adminConfigService.currentConfig;
    var nextSettings = settings;

    final defaultEdition = _editionSetting(
      effectiveConfig.setting('default_mushaf_edition'),
    );
    if (defaultEdition != null) {
      nextSettings = nextSettings.copyWith(mushafEdition: defaultEdition);
    }

    nextSettings = nextSettings.copyWith(
      fullscreenReading: _boolSetting(
        effectiveConfig.setting('default_fullscreen_reading'),
        fallback: nextSettings.fullscreenReading,
      ),
      showPageNumbers: _boolSetting(
        effectiveConfig.setting('default_show_page_numbers'),
        fallback: nextSettings.showPageNumbers,
      ),
      nightMode: _boolSetting(
        effectiveConfig.setting('default_app_dark_mode'),
        fallback: nextSettings.nightMode,
      ),
      pageNightMode: _boolSetting(
        effectiveConfig.setting('default_quran_page_dark_mode'),
        fallback: nextSettings.pageNightMode,
      ),
      lowMemoryMode: _boolSetting(
        effectiveConfig.setting('default_low_memory_mode'),
        fallback: nextSettings.lowMemoryMode,
      ),
      hifzFocusMode: _boolSetting(
        effectiveConfig.setting('default_hifz_focus_mode'),
        fallback: nextSettings.hifzFocusMode,
      ),
      pageOverlayEnabled: _boolSetting(
        effectiveConfig.setting('default_page_overlay_enabled'),
        fallback: nextSettings.pageOverlayEnabled,
      ),
      pageReflectionEnabled: _boolSetting(
        effectiveConfig.setting('default_page_reflection_enabled'),
        fallback: nextSettings.pageReflectionEnabled,
      ),
      pagePreset: _pagePresetSetting(
        effectiveConfig.setting('default_page_preset'),
      ),
      pagePresetEnabled: _boolSetting(
        effectiveConfig.setting('default_page_preset_enabled'),
        fallback: nextSettings.pagePresetEnabled,
      ),
    );

    if (nextSettings != settings) {
      await _preferences.saveSettings(nextSettings);
    }
    return nextSettings;
  }

  MushafEdition? _editionSetting(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      '10_line' || '10_lines' || 'lines10' => MushafEdition.lines10,
      '13_line' || '13_lines' || 'lines13' => MushafEdition.lines13,
      '14_line' || '14_lines' || 'lines14' => MushafEdition.lines14,
      '15_line' || '15_lines' || 'lines15' => MushafEdition.lines15,
      '16_line' || '16_lines' || 'lines16' => MushafEdition.lines16,
      '17_line' || '17_lines' || 'lines17' => MushafEdition.lines17,
      'kanzul_iman' || 'kanzuliman' => MushafEdition.kanzulIman,
      _ => null,
    };
  }

  PagePreset? _pagePresetSetting(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return PagePreset.values.firstWhere(
      (preset) => preset.storageValue == normalized,
      orElse: () => PagePreset.classic,
    );
  }

  bool _boolSetting(String? value, {required bool fallback}) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on' ||
        normalized == 'enabled') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'off' ||
        normalized == 'disabled') {
      return false;
    }
    return fallback;
  }

  Future<ReaderAdminConfig> _initializeNavigationConfig(
    ReaderAdminConfig config, {
    MushafEdition? edition,
    bool forceRefresh = false,
  }) async {
    try {
      await _navigationDataSource.initialize(
        adminConfig: config,
        edition: edition,
        forceRefresh: forceRefresh,
      );
      return config;
    } catch (error) {
      final message = error.toString();
      if (!message.contains('taj_navigation_overrides')) {
        rethrow;
      }

      final sanitizedConfig = config.withoutContentDataset(
        'taj_navigation_overrides',
      );
      await _navigationDataSource.initialize(
        adminConfig: sanitizedConfig,
        edition: edition,
        forceRefresh: true,
      );
      return sanitizedConfig;
    }
  }

  void dispose() {
    _assetResolver.dispose();
    _adminConfigService.dispose();
    _remoteContentService.dispose();
  }

  QuranPage _pageForNumber(
    int pageNumber, {
    required bool isLeftPage,
    required bool preferImageMode,
    MushafEdition? explicitEdition,
    int? explicitStandardPage,
  }) {
    final resolvedEdition = explicitEdition ?? _assetResolver.selectedEdition;
    final resolvedStandardPage = explicitStandardPage ??
        standardPageForNavigationPage(
          pageNumber,
          preferImageMode: preferImageMode,
        );
    final cacheKey = [
      resolvedEdition.storageValue,
      preferImageMode ? '1' : '0',
      pageNumber,
      isLeftPage ? 'L' : 'R',
      resolvedStandardPage,
    ].join('|');
    final cached = _readBoundedCache(_pageCache, cacheKey);
    if (cached != null) {
      return cached;
    }

    final assetPath = preferImageMode
        ? explicitEdition == null
            ? _assetResolver.assetPathForPage(pageNumber)
            : _assetResolver.assetPathForEditionPage(
                explicitEdition, pageNumber)
        : null;
    final pageText = _textDataSource.pageForNumber(resolvedStandardPage);
    final page = QuranPage(
      number: pageNumber,
      isLeftPage: isLeftPage,
      assetPath: assetPath,
      lines: pageText?.lines ?? const [],
      contentType: assetPath != null
          ? QuranPageContentType.image
          : QuranPageContentType.placeholder,
    );
    _storeInBoundedCache(
      _pageCache,
      cacheKey,
      page,
      maxEntries: _maxPageCacheEntries,
    );
    return page;
  }

  T? _readBoundedCache<T>(LinkedHashMap<String, T> cache, String key) {
    final cached = cache.remove(key);
    if (cached != null) {
      cache[key] = cached;
    }
    return cached;
  }

  void _storeInBoundedCache<T>(
    LinkedHashMap<String, T> cache,
    String key,
    T value, {
    required int maxEntries,
  }) {
    cache.remove(key);
    cache[key] = value;
    while (cache.length > maxEntries) {
      cache.remove(cache.keys.first);
    }
  }

  void _clearResolvedPageCaches() {
    _pageCache.clear();
    _spreadCache.clear();
    _surahStartPageCache.clear();
    _juzStartPageCache.clear();
    _standardToNavigationPageCache.clear();
    _navigationToStandardPageCache.clear();
    _pageSearchCache.clear();
    _ayahSearchCache.clear();
  }

  Map<int, int> _buildStandardToNavigationPageCache(MushafEdition edition) {
    final imagePageCount = _assetResolver.imagePageCountForEdition(edition);
    if (imagePageCount == 0) {
      return <int, int>{
        for (var page = 1; page <= _standardTotalPages; page++) page: page,
      };
    }

    final anchors = _buildNavigationAnchorsForEdition(edition);
    if (anchors.length >= 2) {
      return _buildAnchorStandardToNavigationPageCache(
        edition: edition,
        anchors: anchors,
      );
    }

    return _buildRatioStandardToNavigationPageCache(edition);
  }

  Map<int, int> _buildNavigationToStandardPageCache(MushafEdition edition) {
    final forwardMap = _standardToNavigationPageCache.putIfAbsent(
      _editionNavigationCacheKey(edition),
      () => _buildStandardToNavigationPageCache(edition),
    );
    final totalPages = totalPagesForEdition(edition);
    final inverseMap = <int, int>{};
    var currentStandardPage = 1;

    for (var navigationPage = 1;
        navigationPage <= totalPages;
        navigationPage++) {
      while (currentStandardPage < _standardTotalPages &&
          (forwardMap[currentStandardPage + 1] ?? _standardTotalPages) <=
              navigationPage) {
        currentStandardPage += 1;
      }
      inverseMap[navigationPage] = currentStandardPage;
    }

    return inverseMap;
  }

  Map<int, int> _buildRatioStandardToNavigationPageCache(
    MushafEdition edition,
  ) {
    final totalPages = totalPagesForEdition(edition);
    final pageMap = <int, int>{};

    for (var standardPage = 1;
        standardPage <= _standardTotalPages;
        standardPage++) {
      final ratio = (standardPage - 1) / (_standardTotalPages - 1);
      final estimatedPage = 1 + (ratio * (totalPages - 1)).round();
      pageMap[standardPage] = QuranConstants.clampPage(
        estimatedPage,
        totalPages: totalPages,
      );
    }

    return pageMap;
  }

  Map<int, int> _buildAnchorStandardToNavigationPageCache({
    required MushafEdition edition,
    required List<({int standardPage, int navigationPage})> anchors,
  }) {
    final totalPages = totalPagesForEdition(edition);
    final pageMap = <int, int>{};

    for (var index = 0; index < anchors.length; index++) {
      final current = anchors[index];
      final next = index + 1 < anchors.length ? anchors[index + 1] : null;
      final nextStandardPage = next?.standardPage ?? (_standardTotalPages + 1);
      final nextNavigationPage = next?.navigationPage ?? totalPages;
      final segmentLength = nextStandardPage - current.standardPage;

      for (var standardPage = current.standardPage;
          standardPage < nextStandardPage;
          standardPage++) {
        final progress = segmentLength <= 0
            ? 0.0
            : (standardPage - current.standardPage) / segmentLength;
        final estimatedPage = current.navigationPage +
            ((nextNavigationPage - current.navigationPage) * progress).round();
        pageMap[standardPage] = QuranConstants.clampPage(
          estimatedPage,
          totalPages: totalPages,
        );
      }
    }

    pageMap.putIfAbsent(1, () => 1);
    pageMap[_standardTotalPages] ??= totalPages;
    return pageMap;
  }

  List<({int standardPage, int navigationPage})>
      _buildNavigationAnchorsForEdition(
    MushafEdition edition,
  ) {
    final totalPages = totalPagesForEdition(edition);
    if (totalPages == 0) {
      return const [];
    }

    final anchorsByStandardPage = <int, int>{
      1: 1,
      _standardTotalPages: totalPages,
    };

    final surahById = <int, QuranSurahNavigationEntry>{
      for (final surah in _navigationDataSource.surahsForEdition(edition))
        surah.id: surah,
    };
    for (final surah in standardSurahs) {
      final editionSurah = surahById[surah.id];
      if (editionSurah == null) {
        continue;
      }
      final anchorPage = _navigationAnchorPageForImportedPage(
        edition,
        editionSurah.tajScanStartPage,
      );
      _storeEarliestAnchorPage(
        anchorsByStandardPage,
        surah.standardStartPage,
        anchorPage,
      );
    }

    final juzByNumber = <int, QuranJuzNavigationEntry>{
      for (final juz in _navigationDataSource.juzsForEdition(edition))
        juz.number: juz,
    };
    for (final juz in standardJuzs) {
      final editionJuz = juzByNumber[juz.number];
      if (editionJuz == null) {
        continue;
      }
      final anchorPage = _navigationAnchorPageForImportedPage(
        edition,
        editionJuz.tajScanStartPage,
      );
      _storeEarliestAnchorPage(
        anchorsByStandardPage,
        juz.standardStartPage,
        anchorPage,
      );
    }

    final sortedAnchors = anchorsByStandardPage.entries
        .map(
          (entry) => (
            standardPage: entry.key,
            navigationPage: QuranConstants.clampPage(
              entry.value,
              totalPages: totalPages,
            ),
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.standardPage.compareTo(right.standardPage));

    final normalizedAnchors = <({int standardPage, int navigationPage})>[];
    var previousPage = 1;
    for (final anchor in sortedAnchors) {
      final navigationPage = anchor.navigationPage < previousPage
          ? previousPage
          : anchor.navigationPage;
      normalizedAnchors.add(
        (
          standardPage: anchor.standardPage,
          navigationPage: navigationPage,
        ),
      );
      previousPage = navigationPage;
    }

    return normalizedAnchors;
  }

  void _storeEarliestAnchorPage(
    Map<int, int> cache,
    int standardPage,
    int navigationPage,
  ) {
    final existingPage = cache[standardPage];
    if (existingPage == null || navigationPage < existingPage) {
      cache[standardPage] = navigationPage;
    }
  }

  int _navigationAnchorPageForImportedPage(
    MushafEdition edition,
    int importedPageNumber,
  ) {
    final totalPages = totalPagesForEdition(edition);
    if (totalPages <= 1) {
      return 1;
    }

    final logicalPage = _assetResolver.logicalPageForImportedPageInEdition(
      edition,
      importedPageNumber,
    );
    return QuranConstants.clampPage(
      logicalPage,
      totalPages: totalPages,
    );
  }

  String _editionNavigationCacheKey(MushafEdition edition) {
    return 'image|${edition.storageValue}';
  }

  int? _resolvedSurahStartPage(
    int surahId, {
    required bool preferImageMode,
  }) {
    final cache = _surahStartPageCache.putIfAbsent(
      _navigationCacheKey(preferImageMode),
      () => _buildSurahStartPageCache(preferImageMode: preferImageMode),
    );
    return cache[surahId];
  }

  int? _resolvedJuzStartPage(
    int juzNumber, {
    required bool preferImageMode,
  }) {
    final cache = _juzStartPageCache.putIfAbsent(
      _navigationCacheKey(preferImageMode),
      () => _buildJuzStartPageCache(preferImageMode: preferImageMode),
    );
    return cache[juzNumber];
  }

  Map<int, int> _buildSurahStartPageCache({
    required bool preferImageMode,
  }) {
    if (!preferImageMode || _assetResolver.imagePageCount == 0) {
      return <int, int>{
        for (final surah in standardSurahs) surah.id: surah.standardStartPage,
      };
    }

    final edition = _assetResolver.selectedEdition;
    return <int, int>{
      for (final surah in _navigationDataSource.surahsForEdition(edition))
        surah.id: _navigationAnchorPageForImportedPage(
          edition,
          surah.tajScanStartPage,
        ),
    };
  }

  Map<int, int> _buildJuzStartPageCache({
    required bool preferImageMode,
  }) {
    if (!preferImageMode || _assetResolver.imagePageCount == 0) {
      return <int, int>{
        for (final juz in standardJuzs) juz.number: juz.standardStartPage,
      };
    }

    final edition = _assetResolver.selectedEdition;
    return <int, int>{
      for (final juz in _navigationDataSource.juzsForEdition(edition))
        juz.number: _navigationAnchorPageForImportedPage(
          edition,
          juz.tajScanStartPage,
        ),
    };
  }

  QuranSurahNavigationEntry? _surahEntryForImagePage(
    int pageNumber, {
    required MushafEdition edition,
  }) {
    final entries = _navigationDataSource.surahsForEdition(edition);
    if (entries.isEmpty) {
      return null;
    }

    final normalizedPage = QuranConstants.clampPage(
      pageNumber,
      totalPages: totalPagesForEdition(edition),
    );
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      final startPage = _navigationAnchorPageForImportedPage(
        edition,
        entry.tajScanStartPage,
      );
      final nextStartPage = index + 1 < entries.length
          ? _navigationAnchorPageForImportedPage(
              edition,
              entries[index + 1].tajScanStartPage,
            )
          : totalPagesForEdition(edition) + 1;
      final endPage = QuranConstants.clampPage(
        nextStartPage - 1,
        totalPages: totalPagesForEdition(edition),
      );
      if (normalizedPage >= startPage && normalizedPage <= endPage) {
        return entry;
      }
    }
    return null;
  }

  QuranJuzNavigationEntry? _juzEntryForImagePage(
    int pageNumber, {
    required MushafEdition edition,
  }) {
    final entries = _navigationDataSource.juzsForEdition(edition);
    if (entries.isEmpty) {
      return null;
    }

    final normalizedPage = QuranConstants.clampPage(
      pageNumber,
      totalPages: totalPagesForEdition(edition),
    );
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      final startPage = _navigationAnchorPageForImportedPage(
        edition,
        entry.tajScanStartPage,
      );
      final nextStartPage = index + 1 < entries.length
          ? _navigationAnchorPageForImportedPage(
              edition,
              entries[index + 1].tajScanStartPage,
            )
          : totalPagesForEdition(edition) + 1;
      final endPage = QuranConstants.clampPage(
        nextStartPage - 1,
        totalPages: totalPagesForEdition(edition),
      );
      if (normalizedPage >= startPage && normalizedPage <= endPage) {
        return entry;
      }
    }
    return null;
  }

  String _navigationCacheKey(bool preferImageMode) {
    return preferImageMode
        ? 'image|${_assetResolver.selectedEdition.storageValue}'
        : 'text';
  }

  String? _firstMatchingArabicSnippet(dynamic pageData, String query) {
    for (final line in pageData.lines) {
      final text = line.text.trim();
      if (text.contains(query)) {
        return text;
      }
    }
    return null;
  }

  String? _matchingTranslationSnippet(String text, String lowerQuery) {
    if (text.isEmpty || !text.toLowerCase().contains(lowerQuery)) {
      return null;
    }
    final lowerText = text.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);
    final start = (index - 48).clamp(0, text.length);
    final end = (index + lowerQuery.length + 72).clamp(0, text.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < text.length ? '...' : '';
    return '$prefix${text.substring(start, end).trim()}$suffix';
  }

  String _ayahTitleForVerse(
    int chapterId,
    int verseNumber,
    int targetPage,
  ) {
    final chapter = chapterSummaryForId(chapterId);
    if (chapter == null) {
      return '$chapterId:$verseNumber - Page $targetPage';
    }
    return '${chapter.id}:$verseNumber - ${chapter.nameSimple}';
  }

  dynamic _findVerseKeyMatch(QuranPageInsight? insight, String lowerQuery) {
    if (insight == null) {
      return null;
    }

    for (final verse in insight.verses) {
      if (verse.verseKey.toLowerCase() == lowerQuery) {
        return verse;
      }
    }
    return null;
  }

  List<QuranSearchResult> _findVerseTranslationMatches(
    QuranPageInsight? insight,
    String lowerQuery, {
    required int targetPage,
    required int standardPage,
    required String title,
    required int limit,
  }) {
    if (insight == null || limit <= 0) {
      return const [];
    }

    final matches = <QuranSearchResult>[];
    for (final verse in insight.verses) {
      if (matches.length >= limit) {
        break;
      }

      final englishSnippet =
          _matchingTranslationSnippet(verse.translationEn, lowerQuery);
      if (englishSnippet != null) {
        matches.add(
          QuranSearchResult(
            pageNumber: targetPage,
            referencePageNumber: standardPage,
            title: title,
            snippet: '${verse.verseKey} - $englishSnippet',
            category: 'Ayah translation',
            verseKey: verse.verseKey,
          ),
        );
        continue;
      }

      final urduSnippet =
          _matchingTranslationSnippet(verse.translationUr, lowerQuery);
      if (urduSnippet != null) {
        matches.add(
          QuranSearchResult(
            pageNumber: targetPage,
            referencePageNumber: standardPage,
            title: title,
            snippet: '${verse.verseKey} - $urduSnippet',
            category: 'Ayah translation',
            verseKey: verse.verseKey,
          ),
        );
      }
    }
    return matches;
  }

  Iterable<int> _markerValuesForPage(
    QuranPageInsight page,
    String category,
  ) {
    switch (category) {
      case 'ruku':
        return page.rukuNumbers;
      case 'hizb':
        return page.hizbNumbers;
      case 'manzil':
        return page.manzilNumbers;
      case 'rub':
        return page.rubElHizbNumbers;
      default:
        return const [];
    }
  }

  String _markerTitlePrefix(String category) {
    switch (category) {
      case 'ruku':
        return 'Ruku';
      case 'hizb':
        return 'Hizb';
      case 'manzil':
        return 'Manzil';
      case 'rub':
        return 'Rub';
      default:
        return 'Marker';
    }
  }

  List<QuranSurahNavigationEntry> _searchSurahsLocal(String query) {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty) {
      return surahs;
    }

    final results = surahs
        .where(
          (surah) => _matchesSearchQuery(<String>[
            surah.id.toString(),
            surah.nameSimple,
            surah.nameComplex,
            surah.nameArabic,
            surah.translatedName,
          ], normalizedQuery),
        )
        .toList(growable: false);

    results.sort(
      (left, right) => _surahSearchScore(
        right,
        normalizedQuery,
      ).compareTo(_surahSearchScore(left, normalizedQuery)),
    );
    return results;
  }

  List<QuranJuzNavigationEntry> _searchJuzsLocal(String query) {
    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty) {
      return juzs;
    }

    final results = juzs
        .where(
          (juz) => _matchesSearchQuery(<String>[
            juz.number.toString(),
            juz.name,
            juz.nameArabic,
          ], normalizedQuery),
        )
        .toList(growable: false);

    results.sort(
      (left, right) => _juzSearchScore(
        right,
        normalizedQuery,
      ).compareTo(_juzSearchScore(left, normalizedQuery)),
    );
    return results;
  }

  List<QuranNavigationMarker> _searchMarkersLocal(
    String query, {
    required String category,
    required bool preferImageMode,
  }) {
    final markers = markersForCategory(
      category,
      preferImageMode: preferImageMode,
    );
    final normalizedQuery = _normalizeSearchQuery(query);
    if (normalizedQuery.isEmpty) {
      return markers;
    }

    return markers
        .where(
          (marker) => _matchesSearchQuery(<String>[
            marker.id.toString(),
            marker.title,
            marker.subtitle,
            marker.pageNumber.toString(),
          ], normalizedQuery),
        )
        .toList(growable: false);
  }

  int _surahSearchScore(
    QuranSurahNavigationEntry surah,
    String normalizedQuery,
  ) {
    return _searchScore(<String>[
      surah.id.toString(),
      surah.nameSimple,
      surah.nameComplex,
      surah.nameArabic,
      surah.translatedName,
    ], normalizedQuery);
  }

  int _juzSearchScore(
    QuranJuzNavigationEntry juz,
    String normalizedQuery,
  ) {
    return _searchScore(<String>[
      juz.number.toString(),
      juz.name,
      juz.nameArabic,
    ], normalizedQuery);
  }

  bool _matchesSearchQuery(
    List<String> candidates,
    String normalizedQuery,
  ) {
    for (final candidate in candidates) {
      if (_normalizeSearchQuery(candidate).contains(normalizedQuery)) {
        return true;
      }
    }
    return false;
  }

  int _searchScore(
    List<String> candidates,
    String normalizedQuery,
  ) {
    var bestScore = 0;
    for (final candidate in candidates) {
      final normalizedCandidate = _normalizeSearchQuery(candidate);
      if (normalizedCandidate.isEmpty) {
        continue;
      }
      if (normalizedCandidate == normalizedQuery) {
        bestScore = bestScore < 400 ? 400 : bestScore;
        continue;
      }
      if (normalizedCandidate.startsWith(normalizedQuery)) {
        bestScore = bestScore < 300 ? 300 : bestScore;
        continue;
      }
      if (normalizedCandidate.contains(normalizedQuery)) {
        bestScore = bestScore < 200 ? 200 : bestScore;
      }
    }
    return bestScore;
  }

  String _normalizeSearchQuery(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
