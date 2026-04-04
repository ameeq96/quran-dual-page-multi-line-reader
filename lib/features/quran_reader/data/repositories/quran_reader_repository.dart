import '../../../../core/constants/quran_constants.dart';
import '../../../../core/storage/reader_preferences.dart';
import '../../domain/models/quran_chapter_summary.dart';
import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_navigation_marker.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/quran_page_insight.dart';
import '../../domain/models/quran_search_result.dart';
import '../../domain/models/quran_spread.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';
import '../../domain/models/reader_bookmark.dart';
import '../../domain/models/reader_daily_progress_state.dart';
import '../../domain/models/reader_history_entry.dart';
import '../../domain/models/reader_settings.dart';
import '../models/reader_launch_state.dart';
import '../services/quran_asset_resolver.dart';
import '../services/quran_navigation_data_source.dart';
import '../services/quran_page_insights_data_source.dart';
import '../services/quran_remote_content_service.dart';
import '../services/quran_text_data_source.dart';

class QuranReaderRepository {
  QuranReaderRepository({
    required QuranAssetResolver assetResolver,
    required QuranNavigationDataSource navigationDataSource,
    required QuranTextDataSource textDataSource,
    required QuranPageInsightsDataSource pageInsightsDataSource,
    required QuranRemoteContentService remoteContentService,
    required ReaderPreferences preferences,
  })  : _assetResolver = assetResolver,
        _navigationDataSource = navigationDataSource,
        _textDataSource = textDataSource,
        _pageInsightsDataSource = pageInsightsDataSource,
        _remoteContentService = remoteContentService,
        _preferences = preferences;

  static const int _standardTotalPages = 604;
  final QuranAssetResolver _assetResolver;
  final QuranNavigationDataSource _navigationDataSource;
  final QuranTextDataSource _textDataSource;
  final QuranPageInsightsDataSource _pageInsightsDataSource;
  final QuranRemoteContentService _remoteContentService;
  final ReaderPreferences _preferences;
  final Map<String, QuranPage> _pageCache = <String, QuranPage>{};
  final Map<String, QuranSpread> _spreadCache = <String, QuranSpread>{};
  final Map<String, Map<int, int>> _surahStartPageCache =
      <String, Map<int, int>>{};
  final Map<String, Map<int, int>> _juzStartPageCache =
      <String, Map<int, int>>{};
  final Map<String, Map<int, int>> _standardToNavigationPageCache =
      <String, Map<int, int>>{};
  final Map<String, Map<int, int>> _navigationToStandardPageCache =
      <String, Map<int, int>>{};
  final Map<String, List<QuranSearchResult>> _pageSearchCache =
      <String, List<QuranSearchResult>>{};
  final Map<String, List<QuranSearchResult>> _ayahSearchCache =
      <String, List<QuranSearchResult>>{};

  Future<ReaderLaunchState> loadLaunchState() async {
    await Future.wait([
      _assetResolver.initialize(),
      _navigationDataSource.initialize(),
      _textDataSource.initialize(),
      _pageInsightsDataSource.initialize(),
    ]);
    var settings = await _preferences.loadSettings();
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
    final initialPageNumber = await _preferences.loadLastPageNumber();
    return ReaderLaunchState(
      initialPageNumber: clampPage(
        initialPageNumber,
        preferImageMode: settings.preferImageMode,
      ),
      settings: settings,
    );
  }

  bool get hasAnyPageAssets => _assetResolver.hasAnyPageAssets;
  bool get hasBundledImageEdition => _assetResolver.hasBundledImageEdition;
  int get imagePageCount => _assetResolver.imagePageCount;
  int get imageLeadingPagesToSkip => _assetResolver.leadingPagesToSkip;
  MushafEdition get mushafEdition => _assetResolver.selectedEdition;
  int get textPageCount => _textDataSource.totalPages;
  List<QuranSurahNavigationEntry> get surahs => _navigationDataSource.surahs;
  List<QuranJuzNavigationEntry> get juzs => _navigationDataSource.juzs;
  List<QuranChapterSummary> get chapters =>
      _pageInsightsDataSource.chapters.toList(growable: false);
  List<MushafEdition> get availableImageEditions =>
      _assetResolver.availableImageEditions;
  List<MushafEdition> get compareEditions => const <MushafEdition>[
        MushafEdition.lines13,
        MushafEdition.lines15,
        MushafEdition.lines16,
        MushafEdition.lines17,
        MushafEdition.kanzulIman,
      ];

  void setMushafEdition(MushafEdition edition) {
    _assetResolver.setSelectedEdition(edition);
    _clearResolvedPageCaches();
  }

  MushafEdition resolveSupportedEdition(MushafEdition edition) {
    return _assetResolver.resolveSupportedEdition(edition);
  }

  bool hasAssetsForEdition(MushafEdition edition) {
    return _assetResolver.hasAssetsForEdition(edition);
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
    final cached = _spreadCache[cacheKey];
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
    _spreadCache[cacheKey] = spread;
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
    final cached = _pageSearchCache[cacheKey];
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
    _pageSearchCache[cacheKey] = frozenResults;
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
    final cached = _ayahSearchCache[cacheKey];
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
    _ayahSearchCache[cacheKey] = frozenResults;
    return frozenResults;
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

  void dispose() {
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
    final cached = _pageCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final assetPath = preferImageMode
        ? explicitEdition == null
            ? _assetResolver.assetPathForPage(pageNumber)
            : _assetResolver.assetPathForEditionPage(explicitEdition, pageNumber)
        : null;
    final pageText = _textDataSource.pageForNumber(resolvedStandardPage);
    final page = QuranPage(
      number: pageNumber,
      isLeftPage: isLeftPage,
      assetPath: assetPath,
      lines: pageText?.lines ?? const [],
      contentType: assetPath != null
          ? QuranPageContentType.image
          : pageText != null
              ? QuranPageContentType.text
              : QuranPageContentType.placeholder,
    );
    _pageCache[cacheKey] = page;
    return page;
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

    if (edition == MushafEdition.lines16) {
      return _buildTajStandardToNavigationPageCache();
    }

    final lineCount = edition.lineCount;
    if (lineCount != null) {
      return _buildLineCountStandardToNavigationPageCache(
        edition: edition,
        lineCount: lineCount,
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

    for (var navigationPage = 1; navigationPage <= totalPages; navigationPage++) {
      while (currentStandardPage < _standardTotalPages &&
          (forwardMap[currentStandardPage + 1] ?? _standardTotalPages) <=
              navigationPage) {
        currentStandardPage += 1;
      }
      inverseMap[navigationPage] = currentStandardPage;
    }

    return inverseMap;
  }

  Map<int, int> _buildLineCountStandardToNavigationPageCache({
    required MushafEdition edition,
    required int lineCount,
  }) {
    final totalPages = totalPagesForEdition(edition);
    final pageMap = <int, int>{};

    for (var standardPage = 1; standardPage <= _standardTotalPages; standardPage++) {
      final pageData = _textDataSource.pageForNumber(standardPage);
      final startLine = pageData == null || pageData.lines.isEmpty
          ? 1
          : pageData.lines.first.lineNumber;
      final contentOffset =
          ((standardPage - 1) * QuranConstants.mushafTextLineSlots) +
              (startLine - 1);
      final estimatedPage = 1 + (contentOffset ~/ lineCount);
      pageMap[standardPage] = QuranConstants.clampPage(
        estimatedPage,
        totalPages: totalPages,
      );
    }

    return pageMap;
  }

  Map<int, int> _buildRatioStandardToNavigationPageCache(
    MushafEdition edition,
  ) {
    final totalPages = totalPagesForEdition(edition);
    final pageMap = <int, int>{};

    for (var standardPage = 1; standardPage <= _standardTotalPages; standardPage++) {
      final ratio = (standardPage - 1) / (_standardTotalPages - 1);
      final estimatedPage = 1 + (ratio * (totalPages - 1)).round();
      pageMap[standardPage] = QuranConstants.clampPage(
        estimatedPage,
        totalPages: totalPages,
      );
    }

    return pageMap;
  }

  Map<int, int> _buildTajStandardToNavigationPageCache() {
    final totalPages = totalPagesForEdition(MushafEdition.lines16);
    final pageMap = <int, int>{};
    final anchors = surahs
        .map(
          (entry) => (
            standardPage: entry.standardStartPage,
            logicalPage:
                _assetResolver.logicalPageForImportedPage(entry.tajScanStartPage),
          ),
        )
        .toList(growable: false);

    if (anchors.isEmpty) {
      return _buildRatioStandardToNavigationPageCache(MushafEdition.lines16);
    }

    for (var index = 0; index < anchors.length; index++) {
      final current = anchors[index];
      final nextStandardPage = index + 1 < anchors.length
          ? anchors[index + 1].standardPage
          : _standardTotalPages + 1;
      final nextLogicalPage = index + 1 < anchors.length
          ? anchors[index + 1].logicalPage
          : totalPages + 1;
      final segmentLength = nextStandardPage - current.standardPage;

      for (var standardPage = current.standardPage;
          standardPage < nextStandardPage;
          standardPage++) {
        final progress = segmentLength <= 0
            ? 0.0
            : (standardPage - current.standardPage) / segmentLength;
        final estimatedPage = current.logicalPage +
            ((nextLogicalPage - current.logicalPage) * progress).round();
        pageMap[standardPage] = QuranConstants.clampPage(
          estimatedPage,
          totalPages: totalPages,
        );
      }
    }

    pageMap.putIfAbsent(1, () => 1);
    return pageMap;
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
    final cache = <int, int>{};
    final totalPages = totalPagesForMode(preferImageMode: preferImageMode);

    for (var pageNumber = 1; pageNumber <= totalPages; pageNumber++) {
      final standardPage = standardPageForNavigationPage(
        pageNumber,
        preferImageMode: preferImageMode,
      );
      final insight = _pageInsightsDataSource.pageForNumber(standardPage);
      if (insight == null) {
        continue;
      }

      final startingChapterIds = insight.verses
          .where((verse) => verse.verseNumber == 1)
          .map((verse) => verse.chapterId)
          .toSet();
      final candidateChapterIds = startingChapterIds.isEmpty
          ? insight.chapterIds.toSet()
          : startingChapterIds;

      for (final chapterId in candidateChapterIds) {
        cache.putIfAbsent(chapterId, () => pageNumber);
      }
    }

    return cache;
  }

  Map<int, int> _buildJuzStartPageCache({
    required bool preferImageMode,
  }) {
    final cache = <int, int>{};
    final totalPages = totalPagesForMode(preferImageMode: preferImageMode);

    for (var pageNumber = 1; pageNumber <= totalPages; pageNumber++) {
      final standardPage = standardPageForNavigationPage(
        pageNumber,
        preferImageMode: preferImageMode,
      );
      final insight = _pageInsightsDataSource.pageForNumber(standardPage);
      if (insight == null) {
        continue;
      }

      for (final juzNumber in insight.juzNumbers) {
        cache.putIfAbsent(juzNumber, () => pageNumber);
      }
    }

    return cache;
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
}
