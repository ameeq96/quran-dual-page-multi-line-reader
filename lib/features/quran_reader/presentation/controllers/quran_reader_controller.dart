import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/system_ui_service.dart';
import '../../../../core/storage/reader_preferences.dart';
import '../../data/repositories/quran_reader_repository.dart';
import '../../data/services/quran_admin_ai_proxy_service.dart';
import '../../data/services/quran_ai_feature_service.dart';
import '../../data/services/quran_audio_service.dart';
import '../../data/services/quran_reader_sync_service.dart';
import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/quran_chapter_summary.dart';
import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_navigation_marker.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/quran_page_insight.dart';
import '../../domain/models/quran_reciter.dart';
import '../../domain/models/quran_search_result.dart';
import '../../domain/models/quran_spread.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_bookmark.dart';
import '../../domain/models/reader_daily_progress_state.dart';
import '../../domain/models/reader_growth_models.dart';
import '../../domain/models/reader_history_entry.dart';
import '../../domain/models/reader_settings.dart';
import '../../domain/models/reader_sync_snapshot.dart';
import '../models/reader_audio_state.dart';

class QuranReaderController extends ChangeNotifier {
  static const String _defaultBookmarkFolder = 'General';
  static const int _audioPositionNotifyStepMillis = 750;
  static const Duration _pagePersistenceDebounce = Duration(milliseconds: 420);
  static const Duration _pageUiRefreshDebounce = Duration(milliseconds: 80);
  static const Duration _notesPersistenceDebounce = Duration(milliseconds: 650);
  static const List<String> _bookmarkFolderPresets = <String>[
    _defaultBookmarkFolder,
    'Hifz',
    'Review',
    'Dua',
  ];

  QuranReaderController({
    required QuranReaderRepository repository,
    required QuranAudioService audioService,
    required QuranReaderSyncService readerSyncService,
    required ReaderPreferences preferences,
  })  : _repository = repository,
        _audioService = audioService,
        _readerSyncService = readerSyncService,
        _preferences = preferences,
        _aiFeatureService = QuranAiFeatureService();

  final QuranReaderRepository _repository;
  final QuranAudioService _audioService;
  final QuranReaderSyncService _readerSyncService;
  final ReaderPreferences _preferences;
  final QuranAiFeatureService _aiFeatureService;
  final QuranAdminAiProxyService _adminAiProxyService =
      QuranAdminAiProxyService();
  final ValueNotifier<ReaderAudioState> _audioNotifier =
      ValueNotifier<ReaderAudioState>(const ReaderAudioState.idle());
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(1);
  final ValueNotifier<bool> _controlsNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<ReaderSettings> _settingsNotifier =
      ValueNotifier<ReaderSettings>(const ReaderSettings.defaults());
  final ValueNotifier<ReaderAiSettings> _aiSettingsNotifier =
      ValueNotifier<ReaderAiSettings>(const ReaderAiSettings.defaults());
  final ValueNotifier<ReaderExperienceSettings> _experienceNotifier =
      ValueNotifier<ReaderExperienceSettings>(
    const ReaderExperienceSettings.defaults(),
  );
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<int> _viewportNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _contentNotifier = ValueNotifier<int>(0);

  ReaderSettings _settings = const ReaderSettings.defaults();
  ReaderAiSettings _aiSettings = const ReaderAiSettings.defaults();
  ReaderReadingPlan _readingPlan = const ReaderReadingPlan.defaults();
  ReaderExperienceSettings _experienceSettings =
      const ReaderExperienceSettings.defaults();
  ReaderAdminConfig _adminConfig = const ReaderAdminConfig.empty();
  ReaderAudioState _audioState = const ReaderAudioState.idle();
  bool _isLoading = true;
  bool _controlsVisible = true;
  int _currentPageNumber = 1;
  int _dailyTargetPages = 8;
  ReaderDailyProgressState _dailyProgressState = const ReaderDailyProgressState(
    dateKey: '',
    startPage: 1,
  );
  List<ReaderHistoryEntry> _readingHistory = const [];
  Map<int, String> _pageNotes = const {};
  List<int> _favoritePages = const [];
  List<ReaderBookmark> _bookmarks = const [];
  List<ReaderHifzReviewEntry> _hifzReviewEntries = const [];
  List<QuranReciter> _reciters = const [];
  Set<String> _downloadedAudioKeys = const <String>{};
  String? _audioDownloadKeyInProgress;
  int _readingStreakCount = 0;
  String? _readingStreakLastDate;
  int _savedAudioPositionMillis = 0;
  Timer? _controlsTimer;
  Timer? _pagePersistenceTimer;
  Timer? _pageUiRefreshTimer;
  Timer? _notesPersistenceTimer;
  Timer? _cloudSyncTimer;
  Future<void>? _supplementalContentWarmFuture;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  int _lastNotifiedAudioPositionMillis = -1;
  int _lastNotifiedAudioDurationMillis = -1;
  PlayerState? _lastPlayerState;
  int? _lastPersistedPageNumber;
  bool? _lastPersistedPreferImageMode;
  int? _lastRecordedHistoryPageNumber;
  String? _lastRecordedHistoryDateKey;
  DateTime? _lastRecordedHistoryAt;
  List<QuranNavigationMarker> _rukuMarkers = const [];
  List<QuranNavigationMarker> _hizbMarkers = const [];
  List<QuranNavigationMarker> _manzilMarkers = const [];
  List<QuranNavigationMarker> _rubMarkers = const [];
  QuranPage? _currentPageCache;
  QuranSpread? _currentSpreadCache;
  QuranPageInsight? _currentPageInsightCache;
  QuranChapterSummary? _currentChapterSummaryCache;
  List<String> _bookmarkFoldersCache = _bookmarkFolderPresets;
  Map<String, List<ReaderBookmark>> _bookmarksByFolderCache =
      const <String, List<ReaderBookmark>>{};
  Map<int, ReaderBookmark> _bookmarkByPageCache = const <int, ReaderBookmark>{};
  Set<int> _favoritePageSet = const <int>{};
  Map<String, int> _readingActivityCountsCache = const <String, int>{};
  Set<String> _recentActivityDateKeysCache = const <String>{};
  Set<int> _smartHifzHiddenLines = const <int>{};
  List<double> _smartHifzManualMaskAnchors = const <double>[];
  int? _smartHifzStandardPageNumber;
  MushafEdition? _smartHifzEdition;
  int? _smartHifzLineCount;
  bool _smartHifzRevealed = false;
  bool _isDisposed = false;
  String _syncClientId = '';
  Set<MushafEdition> _downloadedOfflineEditions = const <MushafEdition>{};
  Map<MushafEdition, double> _offlinePackProgress =
      const <MushafEdition, double>{};

  bool get isLoading => _isLoading;
  bool get controlsVisible => _controlsVisible;
  ReaderSettings get settings => _settings;
  ReaderAiSettings get aiSettings => _aiSettings;
  ReaderReadingPlan get readingPlan => _readingPlan;
  ReaderExperienceSettings get experienceSettings => _experienceSettings;
  ReaderAdminConfig get adminConfig => _adminConfig;
  ReaderAudioState get audioState => _audioState;
  ValueListenable<ReaderAudioState> get audioListenable => _audioNotifier;
  ValueListenable<int> get pageListenable => _pageNotifier;
  ValueListenable<bool> get controlsListenable => _controlsNotifier;
  ValueListenable<ReaderSettings> get settingsListenable => _settingsNotifier;
  ValueListenable<ReaderAiSettings> get aiSettingsListenable =>
      _aiSettingsNotifier;
  ValueListenable<ReaderExperienceSettings> get experienceListenable =>
      _experienceNotifier;
  ValueListenable<bool> get loadingListenable => _loadingNotifier;
  ValueListenable<int> get viewportListenable => _viewportNotifier;
  ValueListenable<int> get contentListenable => _contentNotifier;
  int get currentPageNumber => _currentPageNumber;
  int get currentPageViewIndex => _currentPageNumber - 1;
  int get currentSpreadIndex => _repository.spreadIndexFromPage(
        _currentPageNumber,
        preferImageMode: _settings.preferImageMode,
      );
  bool get hasImageAssets => _repository.hasAnyPageAssets;
  int get imageLeadingPagesToSkip => _repository.imageLeadingPagesToSkip;
  int get totalPages =>
      _repository.totalPagesForMode(preferImageMode: _settings.preferImageMode);
  int get totalSpreads => _repository.totalSpreadsForMode(
        preferImageMode: _settings.preferImageMode,
      );
  List<QuranSurahNavigationEntry> get surahEntries => _repository.surahs;
  List<QuranJuzNavigationEntry> get juzEntries => _repository.juzs;
  List<QuranChapterSummary> get chapters => _repository.chapters;
  List<QuranReciter> get reciters => _reciters;
  List<MushafEdition> get availableImageEditions {
    final editions = _repository.availableImageEditions;
    if (!_adminConfig.hasEditionControls) {
      return editions;
    }
    final filtered = editions
        .where(
            (edition) => _adminConfig.editionConfig(edition)?.enabled ?? true)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return editions;
    }
    return filtered;
  }

  List<MushafEdition> get compareEditions => _repository.compareEditions;
  List<ReaderAdminAnnouncement> get adminAnnouncements =>
      _adminConfig.announcements;
  bool get hasAdminManagedAssets => _adminConfig.hasRemoteAssetPacks;
  bool get hasAdminSync => _adminConfig.source != ReaderAdminConfigSource.none;
  String get adminSyncBaseUrl => _repository.adminConfigBaseUrl;
  String get syncClientId => _syncClientId;
  bool get hasAdminAiConfiguration =>
      _adminAiProviderSetting.isNotEmpty ||
      _adminAiModelSetting.isNotEmpty ||
      _adminAiEndpointSetting.isNotEmpty ||
      _adminAiStatusSetting.isNotEmpty ||
      _adminAiLanguageOverride != null ||
      _adminAiDepthOverride != null;
  bool get isAiLanguageManagedByAdmin => _adminAiLanguageOverride != null;
  bool get isAiDepthManagedByAdmin => _adminAiDepthOverride != null;
  String get adminAiProviderLabel => switch (_normalizedAdminAiProvider) {
        'ollama' => 'Ollama',
        'openai' => 'ChatGPT',
        'custom' => 'Custom AI',
        _ => 'Local assistant',
      };
  String get adminAiModelLabel => _normalizedAdminAiProvider == 'local'
      ? 'Built-in local mode'
      : (_adminAiModelSetting.isEmpty
          ? 'Provider default model'
          : _adminAiModelSetting);
  String get adminAiEndpointLabel => _adminAiEndpointSetting;
  String get adminAiStatusLabel => _adminAiStatusSetting.isEmpty
      ? switch (_normalizedAdminAiProvider) {
          'ollama' => 'Ollama is active from the admin dashboard.',
          'openai' => 'ChatGPT is active from the admin dashboard.',
          'custom' => 'Custom AI is active from the admin dashboard.',
          _ => 'Local assistant is active in the app.',
        }
      : _adminAiStatusSetting;
  bool get isPlansPacksEnabled => _featureFlag(
        'feature_plans_packs',
        fallback: true,
      );
  bool get isInsightsEnabled => _featureFlag(
        'feature_insights',
        fallback: true,
      );
  bool get isAudioEnabled => _featureFlag(
        'feature_audio',
        fallback: true,
      );
  bool get isAiStudioEnabled => _featureFlag(
        'feature_ai_studio',
        fallback: true,
      );
  bool get isPageStripEnabled => _featureFlag(
        'feature_page_thumbnails',
        fallback: true,
      );
  bool get isCompareEnabled => _featureFlag(
        'feature_compare',
        fallback: true,
      );
  bool get isKanzulStudyEnabled => _featureFlag(
        'feature_kanzul_study',
        fallback: true,
      );
  String get appDisplayTitle =>
      _adminConfig.setting('app_title')?.trim().isNotEmpty == true
          ? _adminConfig.setting('app_title')!.trim()
          : 'Quran Pak Dual Page Reader';
  String get homeHeroTitle =>
      _adminConfig.setting('home_hero_title')?.trim().isNotEmpty == true
          ? _adminConfig.setting('home_hero_title')!.trim()
          : appDisplayTitle;
  String homeHeroSubtitle({
    required String chapterLabel,
    required String pageLabel,
    required String editionLabel,
  }) {
    final configured = _adminConfig.setting('home_hero_subtitle')?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return '$chapterLabel • $pageLabel • $editionLabel';
  }

  String get quickAccessSubtitle {
    final configured =
        _adminConfig.setting('home_quick_access_subtitle')?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    return 'Choose what you want to open. All reader options are available here.';
  }

  String get adminSyncStatusLabel => switch (_adminConfig.source) {
        ReaderAdminConfigSource.live => 'Live admin dashboard connected',
        ReaderAdminConfigSource.cached => 'Stored admin config loaded',
        ReaderAdminConfigSource.none => 'Admin API not connected',
      };
  String get adminAssetsStatusLabel {
    if (_adminConfig.assetPacks.isEmpty) {
      return 'No admin-managed page pack is active.';
    }
    return '${_adminConfig.assetPacks.length} admin-managed page pack(s) active.';
  }

  String get _adminAiProviderSetting =>
      _adminConfig.setting('ai_provider')?.trim() ?? '';

  String get _normalizedAdminAiProvider {
    final normalized = _adminAiProviderSetting.trim().toLowerCase();
    switch (normalized) {
      case 'ollama':
        return 'ollama';
      case 'openai':
      case 'chatgpt':
        return 'openai';
      case 'custom':
        return 'custom';
      default:
        return 'local';
    }
  }

  String get _adminAiModelSetting =>
      _adminConfig.setting('ai_model')?.trim() ?? '';

  String get _adminAiEndpointSetting =>
      _adminConfig.setting('ai_endpoint')?.trim() ?? '';

  String get _adminAiStatusSetting =>
      _adminConfig.setting('ai_status_label')?.trim() ?? '';

  AiResponseLanguage? get _adminAiLanguageOverride {
    final value =
        _adminConfig.setting('ai_default_language')?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }
    switch (value) {
      case 'urdu':
        return AiResponseLanguage.urdu;
      case 'english':
        return AiResponseLanguage.english;
      case 'bilingual':
      case 'english+urdu':
      case 'english_urdu':
      case 'english-urdu':
        return AiResponseLanguage.bilingual;
    }
    return null;
  }

  AiResponseDepth? get _adminAiDepthOverride {
    final value =
        _adminConfig.setting('ai_default_depth')?.trim().toLowerCase();
    if (value == null || value.isEmpty) {
      return null;
    }
    switch (value) {
      case 'fast':
        return AiResponseDepth.fast;
      case 'balanced':
        return AiResponseDepth.balanced;
      case 'deep':
        return AiResponseDepth.deep;
    }
    return null;
  }

  List<ReaderHistoryEntry> get readingHistory => _readingHistory;
  Map<int, String> get pageNotes => _pageNotes;
  List<int> get favoritePages => _favoritePages;
  List<ReaderBookmark> get bookmarks => _bookmarks;
  List<ReaderHifzReviewEntry> get hifzReviewEntries => _hifzReviewEntries;
  List<String> get bookmarkFolders => _bookmarkFoldersCache;

  Map<String, List<ReaderBookmark>> get bookmarksByFolder =>
      _bookmarksByFolderCache;

  int get readingStreakCount => _readingStreakCount;
  int get dailyTargetPages => _dailyTargetPages;
  int get currentStandardPageNumber =>
      _repository.standardPageForNavigationPage(
        _currentPageNumber,
        preferImageMode: _settings.preferImageMode,
      );
  double get khatamProgress => totalPages <= 1
      ? 0
      : ((_currentPageNumber - 1) / (totalPages - 1)).clamp(0, 1);
  int get remainingPages => totalPages - _currentPageNumber;
  List<QuranNavigationMarker> get rukuMarkers => _rukuMarkers;
  List<QuranNavigationMarker> get hizbMarkers => _hizbMarkers;
  List<QuranNavigationMarker> get manzilMarkers => _manzilMarkers;
  List<QuranNavigationMarker> get rubMarkers => _rubMarkers;

  QuranSpread get currentSpread =>
      _currentSpreadCache ?? spreadAt(currentSpreadIndex);
  QuranPage get currentPage =>
      _currentPageCache ?? pageForNumber(_currentPageNumber);
  MushafEdition get primaryStudyEdition =>
      _settings.mushafEdition == MushafEdition.kanzulIman
          ? MushafEdition.lines16
          : _settings.mushafEdition;
  bool get hasSmartHifzChallenge =>
      _smartHifzStandardPageNumber != null &&
      (_smartHifzHiddenLines.isNotEmpty ||
          _smartHifzManualMaskAnchors.isNotEmpty);
  QuranPageInsight? get currentPageInsight =>
      _currentPageInsightCache ??
      _repository.pageInsightForPageNumber(
        _currentPageNumber,
        preferImageMode: _settings.preferImageMode,
      );
  QuranChapterSummary? get currentChapterSummary =>
      _currentChapterSummaryCache ??
      _repository.chapterSummaryForPage(
        _currentPageNumber,
        preferImageMode: _settings.preferImageMode,
      );
  QuranChapterSummary? get selectedAudioChapter {
    final selectedChapterId = _audioState.currentChapterId;
    if (selectedChapterId == null) {
      return currentChapterSummary;
    }
    return chapterForId(selectedChapterId) ?? currentChapterSummary;
  }

  int get dailyProgressPages {
    return _pageNumbersForDateKey(_todayKey()).length;
  }

  int get dailyProgressRemainingPages {
    final remaining = _dailyTargetPages - dailyProgressPages;
    return remaining < 0 ? 0 : remaining;
  }

  int get dailyProgressExtraPages {
    final extra = dailyProgressPages - _dailyTargetPages;
    return extra < 0 ? 0 : extra;
  }

  bool get isDailyTargetComplete => dailyProgressPages >= _dailyTargetPages;

  String get dailyProgressSummaryLabel {
    return '$dailyProgressPages of $_dailyTargetPages pages';
  }

  String get dailyProgressStatusLabel {
    if (dailyProgressPages <= 0) {
      return 'Not started yet';
    }
    if (dailyProgressExtraPages > 0) {
      return 'Target complete +$dailyProgressExtraPages extra pages';
    }
    if (isDailyTargetComplete) {
      return 'Target complete';
    }
    return '$dailyProgressRemainingPages pages left';
  }

  double get dailyProgress {
    return (dailyProgressPages / _dailyTargetPages).clamp(0, 1);
  }

  bool get isCurrentPageFavorite =>
      _favoritePageSet.contains(_currentPageNumber);

  bool get isCurrentPageBookmarked =>
      _bookmarkByPageCache.containsKey(_currentPageNumber);

  bool isFavoritePage(int pageNumber) => _favoritePageSet.contains(pageNumber);

  bool isBookmarkedPage(int pageNumber) =>
      _bookmarkByPageCache.containsKey(pageNumber);

  ReaderBookmark? bookmarkForPage(int pageNumber) =>
      _bookmarkByPageCache[pageNumber];

  ReaderHifzReviewEntry? hifzReviewEntryForPage(int pageNumber) {
    for (final entry in _hifzReviewEntries) {
      if (entry.pageNumber == pageNumber) {
        return entry;
      }
    }
    return null;
  }

  bool get hasActiveAudioSelection => _audioState.currentChapterId != null;

  bool get hasAudioResumePoint => _savedAudioPositionMillis > 0;

  int get audioResumePositionMillis => _savedAudioPositionMillis;
  int get downloadedAudioCount => _downloadedAudioKeys.length;
  List<ReaderHifzReviewEntry> get prioritizedHifzReviewEntries {
    final sorted = List<ReaderHifzReviewEntry>.from(_hifzReviewEntries);
    sorted.sort((a, b) {
      final priorityDiff =
          b.strength.priorityWeight - a.strength.priorityWeight;
      if (priorityDiff != 0) {
        return priorityDiff;
      }
      return b.reviewCount.compareTo(a.reviewCount);
    });
    return sorted;
  }

  List<OfflineEditionPack> get offlineEditionPacks {
    final available = availableImageEditions.toSet();
    return MushafEdition.values.map((edition) {
      final state = _offlinePackProgress.containsKey(edition)
          ? OfflinePackState.downloading
          : _downloadedOfflineEditions.contains(edition)
              ? OfflinePackState.downloaded
              : remoteAssetPackForEdition(edition) != null
                  ? OfflinePackState.adminManaged
                  : available.contains(edition)
                      ? OfflinePackState.adminManaged
                      : edition == _settings.mushafEdition
                          ? OfflinePackState.localOnly
                          : OfflinePackState.planned;
      return OfflineEditionPack(
        edition: edition,
        state: state,
      );
    }).toList(growable: false);
  }

  bool isOfflinePackDownloaded(MushafEdition edition) {
    return _downloadedOfflineEditions.contains(edition);
  }

  bool isOfflinePackDownloading(MushafEdition edition) {
    return _offlinePackProgress.containsKey(edition);
  }

  double offlinePackProgressForEdition(MushafEdition edition) {
    return _offlinePackProgress[edition] ?? 0;
  }

  bool isBundledPackForEdition(MushafEdition edition) {
    return _repository.hasBundledPackForEdition(edition);
  }

  Map<String, int> get readingActivityCounts => _readingActivityCountsCache;

  Set<String> get recentActivityDateKeys => _recentActivityDateKeysCache;

  Set<int> _pageNumbersForDateKey(String dateKey) {
    final pages = <int>{};
    for (final entry in _readingHistory) {
      if (_dateKeyFromIso(entry.viewedAtIso) == dateKey) {
        pages.add(entry.pageNumber);
      }
    }
    return pages;
  }

  int plannedPagesPerDay(int days) {
    if (days <= 0) {
      return remainingPages;
    }
    return ((remainingPages + 1) / days).ceil().clamp(1, totalPages);
  }

  bool get isAudioDownloadInProgress =>
      _audioDownloadKeyInProgress != null &&
      _audioDownloadKeyInProgress == _selectedAudioDownloadKey;

  bool get isSelectedAudioDownloaded =>
      _selectedAudioDownloadKey != null &&
      _downloadedAudioKeys.contains(_selectedAudioDownloadKey);

  int standardPageForPageNumber(int pageNumber) {
    return _repository.standardPageForNavigationPage(
      pageNumber,
      preferImageMode: _settings.preferImageMode,
    );
  }

  bool smartHifzAppliesToPage(int pageNumber) {
    if (!hasSmartHifzChallenge) {
      return false;
    }
    return standardPageForPageNumber(pageNumber) ==
        _smartHifzStandardPageNumber;
  }

  Set<int> smartHifzHiddenLinesForPage(int pageNumber) {
    if (!smartHifzAppliesToPage(pageNumber)) {
      return const <int>{};
    }
    return _smartHifzHiddenLines;
  }

  List<double> smartHifzManualMaskAnchorsForPage(int pageNumber) {
    if (!smartHifzAppliesToPage(pageNumber)) {
      return const <double>[];
    }
    return _smartHifzManualMaskAnchors;
  }

  MushafEdition? smartHifzEditionForPage(int pageNumber) {
    if (!smartHifzAppliesToPage(pageNumber)) {
      return null;
    }
    return _smartHifzEdition ?? primaryStudyEdition;
  }

  int? smartHifzLineCountForPage(int pageNumber) {
    if (!smartHifzAppliesToPage(pageNumber)) {
      return null;
    }
    return _smartHifzLineCount;
  }

  bool smartHifzRevealedForPage(int pageNumber) {
    if (!smartHifzAppliesToPage(pageNumber)) {
      return false;
    }
    return _smartHifzRevealed;
  }

  Future<void> initialize() async {
    _isLoading = true;
    _loadingNotifier.value = true;
    notifyListeners();

    int? preferredReciterId;

    try {
      final launchState = await _repository.loadLaunchState();
      final syncClientIdFuture = _preferences.loadOrCreateSyncClientId();
      final aiSettingsFuture = _preferences.loadAiSettings();
      final dailyTargetPagesFuture = _repository.loadDailyTargetPages();
      final dailyProgressStateFuture = _repository.loadDailyProgressState(
        todayKey: _todayKey(),
        fallbackStartPage: launchState.initialPageNumber,
      );
      final readingPlanFuture = _repository.loadReadingPlan();
      final experienceSettingsFuture = _repository.loadExperienceSettings();
      final readingHistoryFuture = _repository.loadReadingHistory();
      final pageNotesFuture = _repository.loadPageNotes();
      final favoritePagesFuture = _repository.loadFavoritePages();
      final bookmarksFuture = _repository.loadBookmarks();
      final hifzRevisionEntriesFuture = _repository.loadHifzRevisionEntries();

      _syncClientId = await syncClientIdFuture;
      _settings = launchState.settings;
      _settingsNotifier.value = _settings;
      _adminConfig = _repository.adminConfig;
      _aiSettings = await aiSettingsFuture;
      _syncCurrentAiSettingsWithAdminConfig();
      _aiSettingsNotifier.value = _aiSettings;
      await _repository.setMushafEdition(_settings.mushafEdition);
      await _refreshOfflinePackAvailability();
      _currentPageNumber = launchState.initialPageNumber;
      _pageNotifier.value = _currentPageNumber;
      _controlsVisible = !_settings.fullscreenReading;
      _controlsNotifier.value = _controlsVisible;
      _warmSupplementalContentInBackground();
      _dailyTargetPages = await dailyTargetPagesFuture;
      _dailyProgressState = await dailyProgressStateFuture;
      _readingPlan = await readingPlanFuture;
      _experienceSettings = await experienceSettingsFuture;
      if (_experienceSettings.syncMode == ReaderSyncMode.localOnly &&
          adminSyncBaseUrl.trim().isNotEmpty) {
        _experienceSettings = _experienceSettings.copyWith(
          syncMode: ReaderSyncMode.cloudReady,
        );
        await _repository.saveExperienceSettings(_experienceSettings);
      }
      _experienceNotifier.value = _experienceSettings;
      _readingHistory = await readingHistoryFuture;
      _pageNotes = await pageNotesFuture;
      _favoritePages = await favoritePagesFuture;
      _bookmarks = await bookmarksFuture;
      _hifzReviewEntries = await hifzRevisionEntriesFuture;
      _rebuildContentCaches();
      await _hydrateFromCloudIfNeeded();
      preferredReciterId = await _repository.loadPreferredReciterId();
      final audioChapterId = await _repository.loadAudioChapterId();
      _savedAudioPositionMillis = await _repository.loadAudioPositionMillis();
      final repeatEnabled = await _repository.loadAudioRepeatEnabled();
      _readingStreakCount = await _repository.loadReadingStreakCount();
      _readingStreakLastDate = await _repository.loadReadingStreakLastDate();
      await _applyAdminEditionVisibilityRules();
      _reciters = _audioService.fallbackReciters;
      final selectedReciter = _resolveSelectedReciter(preferredReciterId);
      _audioState = _audioState.copyWith(
        selectedReciter: selectedReciter,
        currentChapterId: audioChapterId,
        currentSurahName: _chapterNameForId(audioChapterId),
        positionMillis: _savedAudioPositionMillis,
        repeatEnabled: repeatEnabled,
      );
      _publishAudioState();
      _rebuildNavigationCaches();
      _refreshCurrentCaches();
      _bindAudioStreams();
      try {
        await _audioService
            .setRepeatEnabled(repeatEnabled)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      await SystemUiService.setFullscreen(_settings.fullscreenReading);
      unawaited(_recordCurrentPage());
      _scheduleCloudSyncPush();
    } finally {
      _isLoading = false;
      _loadingNotifier.value = false;
      if (!_isDisposed) {
        notifyListeners();
      }
      _scheduleControlsAutoHide();
    }

    unawaited(_warmAudioBootstrap(preferredReciterId));
  }

  QuranSpread spreadAt(int spreadIndex) {
    return _repository.spreadForIndex(
      spreadIndex,
      preferImageMode: _settings.preferImageMode,
    );
  }

  QuranPage pageForNumber(
    int pageNumber, {
    bool isLeftPage = false,
  }) {
    return _repository.pageForNumber(
      pageNumber,
      isLeftPage: isLeftPage,
      preferImageMode: _settings.preferImageMode,
    );
  }

  QuranPage pageForStandardPageInEdition(
    int standardPage, {
    required MushafEdition edition,
    bool isLeftPage = false,
  }) {
    return _repository.pageForStandardPageInEdition(
      standardPage,
      edition: edition,
      isLeftPage: isLeftPage,
    );
  }

  QuranPage pageForCurrentReferenceInEdition(
    MushafEdition edition, {
    bool isLeftPage = false,
  }) {
    return _repository.pageForCurrentReferenceInEdition(
      _currentPageNumber,
      sourceEdition: _settings.mushafEdition,
      targetEdition: edition,
      preferImageMode: _settings.preferImageMode,
      isLeftPage: isLeftPage,
    );
  }

  int navigationPageForStandardPageInEdition(
    int standardPage, {
    required MushafEdition edition,
  }) {
    return _repository.navigationPageForStandardPageInEdition(
      standardPage,
      edition: edition,
    );
  }

  int navigationPageForCurrentReferenceInEdition(MushafEdition edition) {
    return _repository.navigationPageForCurrentReferenceInEdition(
      _currentPageNumber,
      sourceEdition: _settings.mushafEdition,
      targetEdition: edition,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<List<QuranSurahNavigationEntry>> searchSurahs(String query) {
    return _repository.searchSurahsRemote(query);
  }

  Future<List<QuranJuzNavigationEntry>> searchJuzs(String query) {
    return _repository.searchJuzsRemote(query);
  }

  Future<List<QuranNavigationMarker>> searchMarkers(
    String query, {
    required String category,
  }) {
    return _repository.searchMarkersRemote(
      query,
      category: category,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<List<QuranSearchResult>> searchPages(String query) {
    return _repository.searchPagesRemote(
      query,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<List<QuranSearchResult>> searchAyahs(String query) {
    return _repository.searchAyahsRemote(
      query,
      preferImageMode: _settings.preferImageMode,
    );
  }

  List<QuranSearchResult> searchPagesLocal(String query) {
    return _repository.searchPages(
      query,
      preferImageMode: _settings.preferImageMode,
    );
  }

  List<QuranSearchResult> searchAyahsLocal(String query) {
    return _repository.searchAyahs(
      query,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<void> setAiResponseLanguage(AiResponseLanguage language) async {
    if (isAiLanguageManagedByAdmin) {
      return;
    }
    if (_aiSettings.responseLanguage == language) {
      return;
    }
    await _commitAiSettingsUpdate(
      _aiSettings.copyWith(responseLanguage: language),
    );
  }

  Future<void> setAiResponseDepth(AiResponseDepth depth) async {
    if (isAiDepthManagedByAdmin) {
      return;
    }
    if (_aiSettings.responseDepth == depth) {
      return;
    }
    await _commitAiSettingsUpdate(
      _aiSettings.copyWith(responseDepth: depth),
    );
  }

  Future<void> setReadingPlanPreset(ReadingGoalPreset preset) async {
    _readingPlan = _readingPlan.copyWith(
      preset: preset,
      targetDays: preset.defaultTargetDays,
      customPagesPerDay: preset == ReadingGoalPreset.custom
          ? _readingPlan.customPagesPerDay
          : pagesForCurrentPlanPreset(preset),
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await _repository.saveReadingPlan(_readingPlan);
    _publishContentChange();
  }

  Future<void> setCustomReadingPlan({
    int? targetDays,
    int? pagesPerDay,
  }) async {
    _readingPlan = _readingPlan.copyWith(
      preset: ReadingGoalPreset.custom,
      targetDays: targetDays ?? _readingPlan.targetDays,
      customPagesPerDay: pagesPerDay ?? _readingPlan.customPagesPerDay,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await _repository.saveReadingPlan(_readingPlan);
    _publishContentChange();
  }

  int pagesForCurrentPlanPreset(ReadingGoalPreset preset) {
    final tempPlan = _readingPlan.copyWith(
      preset: preset,
      targetDays: preset.defaultTargetDays,
    );
    return tempPlan.pagesPerDay(
      remainingPages: remainingPages,
      fallbackDailyTarget: _dailyTargetPages,
    );
  }

  Future<void> markCurrentPageForHifz(HifzPageStrength strength) {
    return markPageForHifz(_currentPageNumber, strength: strength);
  }

  Future<void> markPageForHifz(
    int pageNumber, {
    required HifzPageStrength strength,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final entries = List<ReaderHifzReviewEntry>.from(_hifzReviewEntries);
    final existingIndex =
        entries.indexWhere((entry) => entry.pageNumber == pageNumber);
    if (existingIndex >= 0) {
      final existing = entries[existingIndex];
      entries[existingIndex] = existing.copyWith(
        strength: strength,
        updatedAtIso: nowIso,
        reviewCount: existing.reviewCount + 1,
      );
    } else {
      entries.add(
        ReaderHifzReviewEntry(
          pageNumber: pageNumber,
          strength: strength,
          updatedAtIso: nowIso,
          reviewCount: 1,
        ),
      );
    }
    _hifzReviewEntries = entries;
    await _repository.saveHifzRevisionEntries(_hifzReviewEntries);
    _publishContentChange();
  }

  Future<void> clearHifzReviewEntry(int pageNumber) async {
    _hifzReviewEntries = _hifzReviewEntries
        .where((entry) => entry.pageNumber != pageNumber)
        .toList(growable: false);
    await _repository.saveHifzRevisionEntries(_hifzReviewEntries);
    _publishContentChange();
  }

  Future<void> setLargerTextMode(bool enabled) async {
    if (_experienceSettings.largerTextMode == enabled) {
      return;
    }
    await _commitExperienceSettingsUpdate(
      _experienceSettings.copyWith(largerTextMode: enabled),
    );
  }

  Future<void> setHighContrastMode(bool enabled) async {
    if (_experienceSettings.highContrastMode == enabled) {
      return;
    }
    await _commitExperienceSettingsUpdate(
      _experienceSettings.copyWith(highContrastMode: enabled),
    );
  }

  Future<void> setReducedMotion(bool enabled) async {
    if (_experienceSettings.reducedMotion == enabled) {
      return;
    }
    await _commitExperienceSettingsUpdate(
      _experienceSettings.copyWith(reducedMotion: enabled),
    );
  }

  Future<void> setTajweedMode(bool enabled) async {
    if (_experienceSettings.tajweedMode == enabled) {
      return;
    }
    await _commitExperienceSettingsUpdate(
      _experienceSettings.copyWith(tajweedMode: enabled),
    );
  }

  Future<void> setRecitationSyncEnabled(bool enabled) async {
    if (_experienceSettings.recitationSyncEnabled == enabled) {
      return;
    }
    await _commitExperienceSettingsUpdate(
      _experienceSettings.copyWith(recitationSyncEnabled: enabled),
    );
  }

  Future<void> setSyncMode(ReaderSyncMode mode) async {
    if (_experienceSettings.syncMode == mode) {
      return;
    }
    await _commitExperienceSettingsUpdate(
      _experienceSettings.copyWith(syncMode: mode),
    );
    if (mode == ReaderSyncMode.cloudReady) {
      await _hydrateFromCloudIfNeeded();
      _scheduleCloudSyncPush();
    } else {
      _cloudSyncTimer?.cancel();
    }
  }

  Future<QuranAiToolResult> runAiTool(
    QuranAiTool tool, {
    String userInput = '',
  }) async {
    final context = await _buildCurrentAiPageContext();
    if (_shouldUseAdminAiProxy(tool)) {
      final remoteResult = await _adminAiProxyService.runTool(
        baseUrl: adminSyncBaseUrl,
        tool: tool,
        settings: _aiSettings,
        context: context,
        userInput: userInput,
      );
      if (remoteResult != null) {
        return remoteResult;
      }
    }
    return _aiFeatureService.runTool(
      tool: tool,
      settings: _aiSettings,
      context: context,
      userInput: userInput,
      pageSearch: searchPagesLocal,
      ayahSearch: searchAyahsLocal,
    );
  }

  Future<void> applyAiBookmarkSuggestion(
    QuranAiBookmarkSuggestion suggestion,
  ) async {
    await addBookmark(suggestion.label, suggestion.folder);
  }

  String? noteForPage(int pageNumber) => _pageNotes[pageNumber];

  bool get canGoNextPage => _currentPageNumber < totalPages;
  bool get canGoPreviousPage => _currentPageNumber > 1;
  bool get canGoNextSpread => currentSpreadIndex < totalSpreads - 1;
  bool get canGoPreviousSpread => currentSpreadIndex > 0;

  String get pageLabel => 'Page $_currentPageNumber';

  String get spreadLabel {
    final spread = currentSpread;
    return 'Pages ${spread.rightPage.number}-${spread.leftPage.number}';
  }

  String get pageProgressLabel => 'Page $_currentPageNumber / $totalPages';

  String get spreadProgressLabel {
    return 'Spread ${currentSpreadIndex + 1} / $totalSpreads';
  }

  Future<void> setCurrentPageNumber(int pageNumber) async {
    final normalizedPage = _repository.clampPage(
      pageNumber,
      preferImageMode: _settings.preferImageMode,
    );
    if (normalizedPage == _currentPageNumber) {
      _scheduleControlsAutoHide();
      return;
    }

    _currentPageNumber = normalizedPage;
    _refreshCurrentCaches();
    _publishCurrentPage();
    _schedulePageUiRefresh();
    _scheduleControlsAutoHide();
    _schedulePagePersistence();
  }

  Future<void> setCurrentSpreadIndex(int spreadIndex) {
    final normalizedIndex = _repository.clampSpread(
      spreadIndex,
      preferImageMode: _settings.preferImageMode,
    );
    final spread = spreadAt(normalizedIndex);
    final targetPage = _currentPageNumber == spread.leftPage.number
        ? spread.leftPage.number
        : spread.rightPage.number;
    return setCurrentPageNumber(targetPage);
  }

  Future<void> nextPage() {
    if (!canGoNextPage) {
      return Future<void>.value();
    }
    return setCurrentPageNumber(_currentPageNumber + 1);
  }

  Future<void> previousPage() {
    if (!canGoPreviousPage) {
      return Future<void>.value();
    }
    return setCurrentPageNumber(_currentPageNumber - 1);
  }

  Future<void> nextSpread() {
    if (!canGoNextSpread) {
      return Future<void>.value();
    }
    final nextSpread = spreadAt(currentSpreadIndex + 1);
    return setCurrentPageNumber(nextSpread.rightPage.number);
  }

  Future<void> previousSpread() {
    if (!canGoPreviousSpread) {
      return Future<void>.value();
    }
    final previousSpread = spreadAt(currentSpreadIndex - 1);
    return setCurrentPageNumber(previousSpread.rightPage.number);
  }

  Future<void> jumpToPage(int pageNumber) {
    return setCurrentPageNumber(pageNumber);
  }

  Future<void> toggleFullscreen(bool enabled) async {
    if (_settings.fullscreenReading == enabled) {
      _scheduleControlsAutoHide();
      return;
    }
    _controlsVisible = !enabled || _controlsVisible;
    await _commitSettingsUpdate(
      _settings.copyWith(fullscreenReading: enabled),
      publishControlsVisibility: true,
    );
    await SystemUiService.setFullscreen(enabled);
    _scheduleControlsAutoHide();
  }

  Future<void> togglePageNumbers(bool enabled) async {
    if (_settings.showPageNumbers == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(showPageNumbers: enabled),
    );
  }

  Future<void> toggleCustomBrightness(bool enabled) async {
    if (_settings.customBrightnessEnabled == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(customBrightnessEnabled: enabled),
    );
  }

  Future<void> setPageBrightness(double value) async {
    if ((_settings.pageBrightness - value).abs() < 0.0005) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(pageBrightness: value),
    );
  }

  Future<void> toggleNightMode(bool enabled) async {
    if (_settings.nightMode == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(nightMode: enabled),
    );
  }

  Future<void> togglePagePreset(bool enabled) async {
    if (_settings.pagePresetEnabled == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(pagePresetEnabled: enabled),
    );
  }

  Future<void> setPagePreset(PagePreset preset) async {
    if (_settings.pagePreset == preset && _settings.pagePresetEnabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(pagePreset: preset, pagePresetEnabled: true),
    );
  }

  Future<void> togglePageOverlay(bool enabled) async {
    if (_settings.pageOverlayEnabled == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(pageOverlayEnabled: enabled),
    );
  }

  Future<void> togglePageReflection(bool enabled) async {
    if (_settings.pageReflectionEnabled == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(pageReflectionEnabled: enabled),
    );
  }

  Future<void> toggleLowMemoryMode(bool enabled) async {
    if (_settings.lowMemoryMode == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(lowMemoryMode: enabled),
    );
  }

  Future<void> toggleHifzFocusMode(bool enabled) async {
    if (_settings.hifzFocusMode == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(hifzFocusMode: enabled),
    );
  }

  Future<void> setHifzMaskHeightFactor(double value) async {
    if ((_settings.hifzMaskHeightFactor - value).abs() < 0.0005) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(hifzMaskHeightFactor: value),
    );
  }

  Future<void> toggleHifzRevealOnHold(bool enabled) async {
    if (_settings.hifzRevealOnHold == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(hifzRevealOnHold: enabled),
    );
  }

  void applySmartHifzChallenge({
    required Set<int> hiddenLines,
    required MushafEdition edition,
    required int lineCount,
    int? standardPageNumber,
    bool revealed = false,
  }) {
    _smartHifzHiddenLines = Set<int>.from(hiddenLines);
    _smartHifzManualMaskAnchors = const <double>[];
    _smartHifzEdition = edition;
    _smartHifzLineCount = lineCount;
    _smartHifzStandardPageNumber =
        standardPageNumber ?? currentStandardPageNumber;
    _smartHifzRevealed = revealed;
    _publishViewportChange();
    notifyListeners();
  }

  void applySmartHifzManualChallenge({
    required List<double> maskAnchors,
    required MushafEdition edition,
    required int lineCount,
    int? standardPageNumber,
    bool revealed = false,
  }) {
    _smartHifzHiddenLines = const <int>{};
    _smartHifzManualMaskAnchors = List<double>.from(maskAnchors);
    _smartHifzEdition = edition;
    _smartHifzLineCount = lineCount;
    _smartHifzStandardPageNumber =
        standardPageNumber ?? currentStandardPageNumber;
    _smartHifzRevealed = revealed;
    _publishViewportChange();
    notifyListeners();
  }

  void updateSmartHifzManualMaskAnchor(int index, double nextAnchor) {
    if (index < 0 || index >= _smartHifzManualMaskAnchors.length) {
      return;
    }
    final clampedAnchor = nextAnchor.clamp(0.0, 1.0).toDouble();
    if ((_smartHifzManualMaskAnchors[index] - clampedAnchor).abs() < 0.0005) {
      return;
    }
    final nextAnchors = List<double>.from(_smartHifzManualMaskAnchors);
    nextAnchors[index] = clampedAnchor;
    _smartHifzManualMaskAnchors = nextAnchors;
    _publishViewportChange();
    notifyListeners();
  }

  void setSmartHifzChallengeRevealed(bool revealed) {
    if (!hasSmartHifzChallenge || _smartHifzRevealed == revealed) {
      return;
    }
    _smartHifzRevealed = revealed;
    _publishViewportChange();
    notifyListeners();
  }

  void clearSmartHifzChallenge() {
    if (!hasSmartHifzChallenge && !_smartHifzRevealed) {
      return;
    }
    _smartHifzHiddenLines = const <int>{};
    _smartHifzManualMaskAnchors = const <double>[];
    _smartHifzStandardPageNumber = null;
    _smartHifzEdition = null;
    _smartHifzLineCount = null;
    _smartHifzRevealed = false;
    _publishViewportChange();
    notifyListeners();
  }

  Future<void> selectMushafEdition(MushafEdition edition) async {
    final nextPreferImageMode = _repository.hasAssetsForEdition(edition);

    if (_settings.mushafEdition == edition &&
        _settings.preferImageMode == nextPreferImageMode) {
      return;
    }

    final targetPage = _repository.navigationPageForCurrentReferenceInEdition(
      _currentPageNumber,
      sourceEdition: _settings.mushafEdition,
      targetEdition: edition,
      preferImageMode: _settings.preferImageMode,
    );
    _settings = _settings.copyWith(
      mushafEdition: edition,
      preferImageMode: nextPreferImageMode,
    );
    await _repository.setMushafEdition(edition);
    _currentPageNumber = _repository.clampPage(
      targetPage,
      preferImageMode: _settings.preferImageMode,
    );
    _rebuildNavigationCaches();
    _refreshCurrentCaches();
    _publishSettings();
    _publishCurrentPage();
    notifyListeners();
    await _persistSettings();
    await _repository.saveLastPageNumber(
      _currentPageNumber,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<void> togglePreferImageMode(bool enabled) async {
    if (!enabled) {
      enabled = true;
    }
    if (_settings.preferImageMode == enabled) {
      return;
    }
    final standardPage = currentStandardPageNumber;
    _settings = _settings.copyWith(preferImageMode: enabled);
    _currentPageNumber = _repository.navigationPageForStandardPage(
      standardPage,
      preferImageMode: enabled,
    );
    _rebuildNavigationCaches();
    _refreshCurrentCaches();
    _publishSettings();
    _publishCurrentPage();
    notifyListeners();
    await _persistSettings();
    await _repository.saveLastPageNumber(
      _currentPageNumber,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<void> jumpToSurah(QuranSurahNavigationEntry entry) {
    return jumpToPage(
      _repository.navigationPageForSurah(
        entry,
        preferImageMode: _settings.preferImageMode,
      ),
    );
  }

  Future<void> jumpToJuz(QuranJuzNavigationEntry entry) {
    return jumpToPage(
      _repository.navigationPageForJuz(
        entry,
        preferImageMode: _settings.preferImageMode,
      ),
    );
  }

  int navigationPageForSurahEntry(QuranSurahNavigationEntry entry) {
    return _repository.navigationPageForSurah(
      entry,
      preferImageMode: _settings.preferImageMode,
    );
  }

  int navigationPageForJuzEntry(QuranJuzNavigationEntry entry) {
    return _repository.navigationPageForJuz(
      entry,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<void> persistReadingPosition() async {
    _pagePersistenceTimer?.cancel();
    await _persistCurrentPageSnapshot();
  }

  void toggleControlsVisibility() {
    _controlsVisible = !_controlsVisible;
    _publishControlsVisibility();
    _scheduleControlsAutoHide();
  }

  Future<void> setDailyTargetPages(int pageCount) async {
    _dailyTargetPages = pageCount.clamp(1, 40);
    _publishContentChange();
    await _repository.saveDailyTargetPages(_dailyTargetPages);
  }

  Future<void> saveNoteForCurrentPage(String note) async {
    final trimmed = note.trim();
    final nextNotes = Map<int, String>.from(_pageNotes);
    if (trimmed.isEmpty) {
      nextNotes.remove(_currentPageNumber);
    } else {
      nextNotes[_currentPageNumber] = trimmed;
    }
    _pageNotes = nextNotes;
    _publishContentChange();
    _scheduleNotesPersistence();
  }

  Future<void> toggleFavoritePage([int? pageNumber]) async {
    final targetPage = pageNumber ?? _currentPageNumber;
    final next = List<int>.from(_favoritePages);
    if (next.contains(targetPage)) {
      next.remove(targetPage);
    } else {
      next.add(targetPage);
      next.sort();
    }
    _favoritePages = next;
    _rebuildContentCaches();
    _publishContentChange();
    await _repository.saveFavoritePages(_favoritePages);
  }

  Future<void> addBookmark([
    String? label,
    String folder = _defaultBookmarkFolder,
  ]) async {
    final defaultLabel = currentChapterSummary == null
        ? 'Page $_currentPageNumber'
        : '${currentChapterSummary!.nameSimple} • Page $_currentPageNumber';
    final next = List<ReaderBookmark>.from(_bookmarks)
      ..removeWhere((entry) => entry.pageNumber == _currentPageNumber)
      ..insert(
        0,
        ReaderBookmark(
          pageNumber: _currentPageNumber,
          label: (label == null || label.trim().isEmpty)
              ? defaultLabel
              : label.trim(),
          folder: folder,
          createdAtIso: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    _bookmarks = next.take(24).toList(growable: false);
    _rebuildContentCaches();
    _publishContentChange();
    await _repository.saveBookmarks(_bookmarks);
  }

  Future<void> toggleBookmarkCurrentPage([
    String folder = _defaultBookmarkFolder,
  ]) async {
    if (isCurrentPageBookmarked) {
      await removeBookmark(_currentPageNumber);
      return;
    }
    await addBookmark(null, folder);
  }

  Future<void> removeBookmark(int pageNumber) async {
    _bookmarks = _bookmarks
        .where((entry) => entry.pageNumber != pageNumber)
        .toList(growable: false);
    _rebuildContentCaches();
    _publishContentChange();
    await _repository.saveBookmarks(_bookmarks);
  }

  Future<void> jumpToMarker(QuranNavigationMarker marker) {
    return jumpToPage(marker.pageNumber);
  }

  String buildCurrentPageReference() {
    final chapter = currentChapterSummary;
    if (chapter == null) {
      return 'Quran page $_currentPageNumber';
    }
    return '${chapter.nameSimple} - Page $_currentPageNumber';
  }

  String buildReadingSummary() {
    final planPagesPerDay = _readingPlan.pagesPerDay(
      remainingPages: remainingPages,
      fallbackDailyTarget: _dailyTargetPages,
    );
    final buffer = StringBuffer()
      ..writeln('Quran Pak Dual Page Reader Summary')
      ..writeln('Current page: $_currentPageNumber / $totalPages')
      ..writeln('Khatam progress: ${(khatamProgress * 100).round()}%')
      ..writeln('Reading streak: $_readingStreakCount day(s)')
      ..writeln('Daily target: $_dailyTargetPages page(s)')
      ..writeln(
          'Reading plan: ${_readingPlan.preset.label} ($planPagesPerDay pages/day)')
      ..writeln('Hifz tracked pages: ${_hifzReviewEntries.length}')
      ..writeln('Sync mode: ${_experienceSettings.syncMode.label}')
      ..writeln('Favorites: ${_favoritePages.length}')
      ..writeln('Bookmarks: ${_bookmarks.length}');

    if (selectedAudioChapter != null && _audioState.selectedReciter != null) {
      buffer
        ..writeln('Audio Surah: ${selectedAudioChapter!.nameSimple}')
        ..writeln('Audio Qari: ${_audioState.selectedReciter!.displayName}');
    }

    return buffer.toString().trimRight();
  }

  String buildStateBackupJson() {
    final payload = <String, dynamic>{
      'exportedAtIso': DateTime.now().toUtc().toIso8601String(),
      'currentPageNumber': _currentPageNumber,
      'settings': <String, dynamic>{
        'mushafEdition': _settings.mushafEdition.storageValue,
        'nightMode': _settings.nightMode,
        'preferImageMode': _settings.preferImageMode,
      },
      'readingPlan': _readingPlan.toJson(),
      'experienceSettings': _experienceSettings.toJson(),
      'hifzRevisionEntries': _hifzReviewEntries
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'favoritePages': _favoritePages,
      'bookmarks': _bookmarks.map((entry) => entry.toJson()).toList(),
      'pageNotes': _pageNotes.map(
        (key, value) => MapEntry('$key', value),
      ),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String?> loadCurrentChapterInfo() {
    return _repository.loadChapterInfoForPage(
      _currentPageNumber,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<String?> loadCurrentTafsirExcerpt() {
    return _repository.loadTafsirExcerptForPage(
      _currentPageNumber,
      preferImageMode: _settings.preferImageMode,
    );
  }

  QuranChapterSummary? chapterForId(int? chapterId) {
    if (chapterId == null) {
      return null;
    }
    for (final chapter in chapters) {
      if (chapter.id == chapterId) {
        return chapter;
      }
    }
    return null;
  }

  Future<void> selectReciter(QuranReciter reciter) async {
    _setAudioState(_audioState.copyWith(selectedReciter: reciter));
    await _repository.savePreferredReciterId(reciter.id);
    _scheduleCloudSyncPush();
    if (_audioState.isPlaying && selectedAudioChapter != null) {
      await playSelectedSurah(forceReload: true);
    }
  }

  Future<void> selectAudioChapter(QuranChapterSummary chapter) async {
    final selectedId = _audioState.currentChapterId;
    if (selectedId == chapter.id &&
        _audioState.currentSurahName == chapter.nameSimple) {
      return;
    }

    if (_audioState.isPlaying || _audioState.durationMillis > 0) {
      await _audioService.stop();
    }

    _setAudioState(
      _audioState.copyWith(
        currentChapterId: chapter.id,
        currentSurahName: chapter.nameSimple,
        isPlaying: false,
        isBuffering: false,
        isLoading: false,
        positionMillis: 0,
        durationMillis: 0,
        clearError: true,
      ),
    );
    await _repository.saveAudioChapterId(chapter.id);
    await _repository.saveAudioPositionMillis(0);
    _scheduleCloudSyncPush();
  }

  Future<void> playSelectedSurah({bool forceReload = false}) async {
    final chapter = selectedAudioChapter;
    final reciter =
        _audioState.selectedReciter ?? _resolveSelectedReciter(null);
    if (chapter == null || reciter == null) {
      return;
    }

    final isSameChapter = _audioState.currentChapterId == chapter.id;
    if (isSameChapter && !forceReload && _audioState.isPlaying) {
      await pauseAudio();
      return;
    }
    if (isSameChapter &&
        !forceReload &&
        !_audioState.isPlaying &&
        _audioState.durationMillis > 0) {
      await resumeAudio();
      return;
    }

    _setAudioState(
      _audioState.copyWith(
        isLoading: true,
        isBuffering: true,
        isDownloading: false,
        selectedReciter: reciter,
        currentChapterId: chapter.id,
        currentSurahName: chapter.nameSimple,
        positionMillis: 0,
        durationMillis: 0,
        clearError: true,
      ),
    );

    try {
      await _audioService.playChapter(
        reciterId: reciter.id,
        chapterId: chapter.id,
        chapterName: chapter.nameSimple,
        reciterName: reciter.displayName,
        initialPosition: _savedAudioPositionMillis > 0
            ? Duration(milliseconds: _savedAudioPositionMillis)
            : null,
      );
      _setAudioState(
        _audioState.copyWith(
          isLoading: false,
          isBuffering: false,
          isDownloading: false,
          isPlaying: true,
          clearError: true,
        ),
      );
      await _repository.saveAudioChapterId(chapter.id);
      _scheduleCloudSyncPush();
    } catch (error) {
      _setAudioState(
        _audioState.copyWith(
          isLoading: false,
          isBuffering: false,
          isDownloading: false,
          isPlaying: false,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<void> playCurrentSurah({bool forceReload = false}) {
    final chapter = currentChapterSummary;
    if (chapter == null) {
      return Future<void>.value();
    }

    final selectedId = _audioState.currentChapterId;
    if (selectedId == chapter.id &&
        _audioState.currentSurahName == chapter.nameSimple) {
      return playSelectedSurah(forceReload: forceReload);
    }

    return () async {
      await selectAudioChapter(chapter);
      await playSelectedSurah(forceReload: forceReload);
    }();
  }

  Future<void> pauseAudio() async {
    await _audioService.pause();
    await _persistAudioState();
    _setAudioState(
      _audioState.copyWith(
        isPlaying: false,
        isBuffering: false,
        clearError: true,
      ),
    );
  }

  Future<void> resumeAudio() async {
    await _audioService.resume();
    _setAudioState(
      _audioState.copyWith(
        isPlaying: true,
        isBuffering: false,
        clearError: true,
      ),
    );
  }

  Future<void> stopAudio() async {
    await _audioService.stop();
    _savedAudioPositionMillis = 0;
    await _repository.saveAudioPositionMillis(0);
    _scheduleCloudSyncPush();
    _setAudioState(
      _audioState.copyWith(
        isPlaying: false,
        isBuffering: false,
        positionMillis: 0,
        durationMillis: 0,
        clearError: true,
      ),
    );
  }

  Future<void> seekAudio(double progress) async {
    final duration = _audioState.durationMillis;
    if (duration <= 0) {
      return;
    }
    final target = (duration * progress.clamp(0, 1)).round();
    await _audioService.seek(Duration(milliseconds: target));
  }

  Future<void> toggleAudioRepeat(bool enabled) async {
    await _audioService.setRepeatEnabled(enabled);
    _setAudioState(_audioState.copyWith(repeatEnabled: enabled));
    await _repository.saveAudioRepeatEnabled(enabled);
    _scheduleCloudSyncPush();
  }

  Future<void> downloadSelectedAudio() async {
    final chapter = selectedAudioChapter;
    final reciter = _audioState.selectedReciter;
    if (chapter == null || reciter == null) {
      return;
    }

    final key = _audioKey(reciter.id, chapter.id);
    _audioDownloadKeyInProgress = key;
    _setAudioState(
      _audioState.copyWith(
        isDownloading: true,
        clearError: true,
      ),
    );

    try {
      await _audioService.downloadChapter(
        reciterId: reciter.id,
        chapterId: chapter.id,
      );
      _downloadedAudioKeys = <String>{
        ..._downloadedAudioKeys,
        key,
      };
      _setAudioState(
        _audioState.copyWith(
          isDownloading: false,
          clearError: true,
        ),
      );
      _publishContentChange();
    } catch (error) {
      _setAudioState(
        _audioState.copyWith(
          isDownloading: false,
          errorMessage: '$error',
        ),
      );
    } finally {
      _audioDownloadKeyInProgress = null;
      _publishAudioState();
    }
  }

  Future<void> deleteSelectedAudioDownload() async {
    final chapter = selectedAudioChapter;
    final reciter = _audioState.selectedReciter;
    if (chapter == null || reciter == null) {
      return;
    }

    final key = _audioKey(reciter.id, chapter.id);
    await _audioService.deleteChapterDownload(
      reciterId: reciter.id,
      chapterId: chapter.id,
    );
    _downloadedAudioKeys =
        _downloadedAudioKeys.where((value) => value != key).toSet();
    _publishContentChange();
    _publishAudioState();
  }

  void _publishCurrentPage() {
    if (_isDisposed || _pageNotifier.value == _currentPageNumber) {
      return;
    }
    _pageNotifier.value = _currentPageNumber;
  }

  void _schedulePageUiRefresh({bool immediate = false}) {
    if (_isDisposed) {
      return;
    }
    _pageUiRefreshTimer?.cancel();
    if (immediate) {
      notifyListeners();
      return;
    }
    _pageUiRefreshTimer = Timer(_pageUiRefreshDebounce, () {
      if (_isDisposed) {
        return;
      }
      notifyListeners();
    });
  }

  void _publishControlsVisibility() {
    if (_isDisposed || _controlsNotifier.value == _controlsVisible) {
      return;
    }
    _controlsNotifier.value = _controlsVisible;
  }

  void _publishSettings() {
    if (_isDisposed || _settingsNotifier.value == _settings) {
      return;
    }
    _settingsNotifier.value = _settings;
    _scheduleCloudSyncPush();
  }

  void _publishViewportChange() {
    if (_isDisposed) {
      return;
    }
    _viewportNotifier.value = _viewportNotifier.value + 1;
  }

  void _publishContentChange() {
    if (_isDisposed) {
      return;
    }
    _contentNotifier.value = _contentNotifier.value + 1;
    _scheduleCloudSyncPush();
  }

  Future<void> _persistSettings() {
    return _repository.saveSettings(_settings);
  }

  Future<void> _commitSettingsUpdate(
    ReaderSettings nextSettings, {
    bool publishControlsVisibility = false,
  }) async {
    _settings = nextSettings;
    _publishSettings();
    if (publishControlsVisibility) {
      _publishControlsVisibility();
    }
    notifyListeners();
    await _persistSettings();
  }

  Future<void> _commitAiSettingsUpdate(ReaderAiSettings nextSettings) async {
    _aiSettings = nextSettings;
    _publishAiSettings();
    await _preferences.saveAiSettings(_aiSettings);
  }

  Future<void> _commitExperienceSettingsUpdate(
    ReaderExperienceSettings nextSettings,
  ) async {
    _experienceSettings = nextSettings;
    _publishExperienceSettings();
    await _repository.saveExperienceSettings(_experienceSettings);
  }

  void _schedulePagePersistence() {
    _pagePersistenceTimer?.cancel();
    _pagePersistenceTimer = Timer(_pagePersistenceDebounce, () {
      unawaited(_persistCurrentPageSnapshot());
    });
  }

  void _scheduleNotesPersistence() {
    _notesPersistenceTimer?.cancel();
    _notesPersistenceTimer = Timer(_notesPersistenceDebounce, () {
      unawaited(_repository.savePageNotes(_pageNotes));
    });
  }

  Future<void> _persistCurrentPageSnapshot() async {
    if (_lastPersistedPageNumber == _currentPageNumber &&
        _lastPersistedPreferImageMode == _settings.preferImageMode) {
      return;
    }
    _lastPersistedPageNumber = _currentPageNumber;
    _lastPersistedPreferImageMode = _settings.preferImageMode;
    await _repository.saveLastPageNumber(
      _currentPageNumber,
      preferImageMode: _settings.preferImageMode,
    );
    await _recordCurrentPage();
    _scheduleCloudSyncPush();
  }

  void _scheduleControlsAutoHide() {
    _controlsTimer?.cancel();
    if (!_settings.fullscreenReading || !_controlsVisible) {
      return;
    }

    _controlsTimer = Timer(const Duration(seconds: 3), () {
      _controlsVisible = false;
      _publishControlsVisibility();
    });
  }

  void _bindAudioStreams() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();

    _playerStateSubscription = _audioService.playerStateStream.listen((state) {
      final nextState = _audioState.copyWith(
        isPlaying: state.playing,
        isBuffering: state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading,
        isLoading: state.processingState == ProcessingState.loading,
      );
      final shouldNotify = _lastPlayerState == null ||
          _lastPlayerState!.playing != state.playing ||
          _lastPlayerState!.processingState != state.processingState;
      _lastPlayerState = state;
      _audioState = nextState;
      if (shouldNotify) {
        _publishAudioState();
      }
    });

    _positionSubscription = _audioService.positionStream.listen((position) {
      final millis = position.inMilliseconds;
      _savedAudioPositionMillis = millis;
      _audioState = _audioState.copyWith(positionMillis: millis);

      final shouldNotify = _lastNotifiedAudioPositionMillis < 0 ||
          (millis - _lastNotifiedAudioPositionMillis).abs() >=
              _audioPositionNotifyStepMillis ||
          millis == 0 ||
          (_audioState.durationMillis > 0 &&
              millis >= _audioState.durationMillis);
      if (shouldNotify) {
        _lastNotifiedAudioPositionMillis = millis;
        _publishAudioState();
      }
    });

    _durationSubscription = _audioService.durationStream.listen((duration) {
      final durationMillis = duration?.inMilliseconds ?? 0;
      _audioState = _audioState.copyWith(
        durationMillis: durationMillis,
      );
      if (_lastNotifiedAudioDurationMillis != durationMillis) {
        _lastNotifiedAudioDurationMillis = durationMillis;
        _publishAudioState();
      }
    });
  }

  QuranReciter? _resolveSelectedReciter(int? preferredReciterId) {
    if (_reciters.isEmpty) {
      return null;
    }
    for (final reciter in _reciters) {
      if (reciter.id == preferredReciterId) {
        return reciter;
      }
    }
    return _reciters.first;
  }

  Future<void> _recordCurrentPage() async {
    final now = DateTime.now();
    final todayKey = _todayKey();
    var contentChanged = false;
    if (_dailyProgressState.dateKey != todayKey) {
      _dailyProgressState = ReaderDailyProgressState(
        dateKey: todayKey,
        startPage: _currentPageNumber,
      );
      await _repository.saveDailyProgressState(_dailyProgressState);
      contentChanged = true;
    }

    final previousStreakCount = _readingStreakCount;
    final previousStreakLastDate = _readingStreakLastDate;
    await _updateReadingStreak(todayKey);
    if (previousStreakCount != _readingStreakCount ||
        previousStreakLastDate != _readingStreakLastDate) {
      contentChanged = true;
    }

    final shouldSkipHistoryInsert = _lastRecordedHistoryPageNumber ==
            _currentPageNumber &&
        _lastRecordedHistoryDateKey == todayKey &&
        _lastRecordedHistoryAt != null &&
        now.difference(_lastRecordedHistoryAt!) < const Duration(seconds: 18);
    if (shouldSkipHistoryInsert) {
      if (contentChanged) {
        _rebuildContentCaches();
        _publishContentChange();
      }
      return;
    }

    final nextHistory = <ReaderHistoryEntry>[
      ReaderHistoryEntry(
        pageNumber: _currentPageNumber,
        viewedAtIso: now.toUtc().toIso8601String(),
      ),
      ..._readingHistory
          .where((entry) => entry.pageNumber != _currentPageNumber),
    ];
    _readingHistory = nextHistory.take(180).toList(growable: false);
    _rebuildContentCaches();
    _lastRecordedHistoryPageNumber = _currentPageNumber;
    _lastRecordedHistoryDateKey = todayKey;
    _lastRecordedHistoryAt = now;
    await _repository.saveReadingHistory(_readingHistory);
    _publishContentChange();
  }

  Future<void> _updateReadingStreak(String todayKey) async {
    if (_readingStreakLastDate == todayKey) {
      return;
    }

    if (_readingStreakLastDate == null) {
      _readingStreakCount = 1;
    } else {
      final today = DateTime.parse(todayKey);
      final last = DateTime.tryParse(_readingStreakLastDate!);
      final difference = last == null ? 999 : today.difference(last).inDays;
      if (difference == 1) {
        _readingStreakCount += 1;
      } else if (difference == 0) {
        return;
      } else {
        _readingStreakCount = 1;
      }
    }

    _readingStreakLastDate = todayKey;
    await _repository.saveReadingStreakCount(_readingStreakCount);
    await _repository.saveReadingStreakLastDate(_readingStreakLastDate);
  }

  Future<void> _persistAudioState() async {
    await _repository.saveAudioChapterId(_audioState.currentChapterId);
    await _repository.saveAudioPositionMillis(_savedAudioPositionMillis);
    await _repository.saveAudioRepeatEnabled(_audioState.repeatEnabled);
    _scheduleCloudSyncPush();
  }

  String? _chapterNameForId(int? chapterId) {
    if (chapterId == null) {
      return null;
    }
    for (final chapter in chapters) {
      if (chapter.id == chapterId) {
        return chapter.nameSimple;
      }
    }
    return null;
  }

  String _audioKey(int reciterId, int chapterId) => '$reciterId-$chapterId';

  String? get _selectedAudioDownloadKey {
    final chapter = selectedAudioChapter;
    final reciter = _audioState.selectedReciter;
    if (chapter == null || reciter == null) {
      return null;
    }
    return _audioKey(reciter.id, chapter.id);
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  String? _dateKeyFromIso(String isoValue) {
    final parsed = DateTime.tryParse(isoValue);
    if (parsed == null) {
      return null;
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Future<void> _warmAudioBootstrap(int? preferredReciterId) async {
    try {
      final reciters = await _audioService.loadReciters();
      final downloadedAudioKeys = await _audioService
          .downloadedChapterKeys()
          .timeout(const Duration(seconds: 4), onTimeout: () {
        return _downloadedAudioKeys;
      });

      if (_isDisposed) {
        return;
      }

      final selectedReciterId =
          _audioState.selectedReciter?.id ?? preferredReciterId;
      _reciters = reciters;
      _downloadedAudioKeys = downloadedAudioKeys;
      _publishContentChange();
      _setAudioState(
        _audioState.copyWith(
          selectedReciter: _resolveSelectedReciter(selectedReciterId),
        ),
      );
    } catch (_) {
      // Reader should stay usable even if audio metadata cannot be warmed.
    }
  }

  Future<QuranAiPageContext> _buildCurrentAiPageContext() async {
    final standardPage = currentStandardPageNumber;
    final textPage = _repository.pageForNumber(
      standardPage,
      isLeftPage: false,
      preferImageMode: false,
    );
    final insight = currentPageInsight;
    final chapter = currentChapterSummary;
    final chapterInfo = await loadCurrentChapterInfo() ?? '';
    final tafsirExcerpt = await loadCurrentTafsirExcerpt() ?? '';
    final chapterSummaryText = chapter == null
        ? ''
        : '${chapter.nameSimple} (${chapter.translatedName}) is a '
            '${chapter.revelationPlace.toLowerCase()} surah with '
            '${chapter.versesCount} ayat.';

    return QuranAiPageContext(
      pageNumber: _currentPageNumber,
      standardPageNumber: standardPage,
      pageReference: buildCurrentPageReference(),
      mushafEditionLabel: _settings.mushafEdition.label,
      chapterName: chapter?.nameSimple,
      chapterSummary: chapterSummaryText,
      chapterInfo: chapterInfo,
      tafsirExcerpt: tafsirExcerpt,
      translationUr: insight?.translationUr ?? '',
      translationEn: insight?.translationEn ?? '',
      arabicLines: textPage.lines
          .where((line) => line.text.trim().isNotEmpty)
          .map(
            (line) => QuranAiArabicLine(
              lineNumber: line.lineNumber,
              text: line.text.trim(),
            ),
          )
          .toList(growable: false),
      verseKeys: insight?.verses
              .map((verse) => verse.verseKey)
              .take(8)
              .toList(growable: false) ??
          const <String>[],
      notes: noteForPage(_currentPageNumber) ?? '',
      dailyProgressSummary:
          '$dailyProgressSummaryLabel • $dailyProgressStatusLabel',
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controlsTimer?.cancel();
    _pagePersistenceTimer?.cancel();
    _pageUiRefreshTimer?.cancel();
    _cloudSyncTimer?.cancel();
    final shouldFlushNotes = _notesPersistenceTimer?.isActive ?? false;
    _notesPersistenceTimer?.cancel();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    unawaited(_persistAudioState());
    if (shouldFlushNotes) {
      unawaited(_repository.savePageNotes(_pageNotes));
    }
    _pageNotifier.dispose();
    _controlsNotifier.dispose();
    _settingsNotifier.dispose();
    _aiSettingsNotifier.dispose();
    _experienceNotifier.dispose();
    _loadingNotifier.dispose();
    _viewportNotifier.dispose();
    _contentNotifier.dispose();
    _audioNotifier.dispose();
    _adminAiProxyService.dispose();
    _audioService.dispose();
    _readerSyncService.dispose();
    _repository.dispose();
    super.dispose();
  }

  void _rebuildNavigationCaches() {
    _rukuMarkers = _repository.markersForCategory(
      'ruku',
      preferImageMode: _settings.preferImageMode,
    );
    _hizbMarkers = _repository.markersForCategory(
      'hizb',
      preferImageMode: _settings.preferImageMode,
    );
    _manzilMarkers = _repository.markersForCategory(
      'manzil',
      preferImageMode: _settings.preferImageMode,
    );
    _rubMarkers = _repository.markersForCategory(
      'rub',
      preferImageMode: _settings.preferImageMode,
    );
  }

  void _rebuildContentCaches() {
    _favoritePageSet = _favoritePages.toSet();

    final bookmarkFolders = <String>{
      ..._bookmarkFolderPresets,
      ..._bookmarks.map((bookmark) => bookmark.folder),
    }.toList(growable: false);
    _bookmarkFoldersCache = bookmarkFolders;

    final bookmarkByPage = <int, ReaderBookmark>{};
    final groupedBookmarks = <String, List<ReaderBookmark>>{};
    for (final folder in bookmarkFolders) {
      groupedBookmarks[folder] = <ReaderBookmark>[];
    }
    for (final bookmark in _bookmarks) {
      bookmarkByPage[bookmark.pageNumber] = bookmark;
      groupedBookmarks.putIfAbsent(bookmark.folder, () => []);
      groupedBookmarks[bookmark.folder]!.add(bookmark);
    }
    _bookmarkByPageCache = bookmarkByPage;
    _bookmarksByFolderCache = Map<String, List<ReaderBookmark>>.unmodifiable(
      groupedBookmarks.map(
        (key, value) => MapEntry(
          key,
          List<ReaderBookmark>.unmodifiable(value),
        ),
      ),
    );

    final activityCounts = <String, int>{};
    final activityDateKeys = <String>{};
    for (final entry in _readingHistory) {
      final key = _dateKeyFromIso(entry.viewedAtIso);
      if (key == null) {
        continue;
      }
      activityDateKeys.add(key);
      activityCounts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    _readingActivityCountsCache = Map<String, int>.unmodifiable(activityCounts);
    _recentActivityDateKeysCache = Set<String>.unmodifiable(activityDateKeys);
  }

  void _refreshCurrentCaches() {
    _currentPageCache = _repository.pageForNumber(
      _currentPageNumber,
      isLeftPage: false,
      preferImageMode: _settings.preferImageMode,
    );
    _currentSpreadCache = _repository.spreadForIndex(
      currentSpreadIndex,
      preferImageMode: _settings.preferImageMode,
    );
    _currentPageInsightCache = _repository.pageInsightForPageNumber(
      _currentPageNumber,
      preferImageMode: _settings.preferImageMode,
    );
    _currentChapterSummaryCache = _repository.chapterSummaryForPage(
      _currentPageNumber,
      preferImageMode: _settings.preferImageMode,
    );
  }

  void _setAudioState(ReaderAudioState nextState) {
    _audioState = nextState;
    _publishAudioState();
  }

  void _publishAudioState() {
    if (_isDisposed) {
      return;
    }
    _audioNotifier.value = _audioState;
  }

  void _syncCurrentAiSettingsWithAdminConfig() {
    _aiSettings = _aiSettings.copyWith(
      responseLanguage:
          _adminAiLanguageOverride ?? _aiSettings.responseLanguage,
      responseDepth: _adminAiDepthOverride ?? _aiSettings.responseDepth,
    );
  }

  void _publishAiSettings() {
    if (_isDisposed || _aiSettingsNotifier.value == _aiSettings) {
      return;
    }
    _aiSettingsNotifier.value = _aiSettings;
    _scheduleCloudSyncPush();
  }

  Future<void> refreshAdminSync() async {
    final nextConfig = await _repository.refreshAdminConfig();
    _adminConfig = nextConfig;
    _syncCurrentAiSettingsWithAdminConfig();
    await _refreshOfflinePackAvailability();
    await _applyAdminEditionVisibilityRules();
    if (!_settings.preferImageMode &&
        _repository.hasAssetsForEdition(_settings.mushafEdition)) {
      _settings = _settings.copyWith(preferImageMode: true);
      _publishSettings();
      unawaited(_persistSettings());
    }
    _rebuildNavigationCaches();
    _refreshCurrentCaches();
    _publishContentChange();
    _warmSupplementalContentInBackground(forceRefresh: true);
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<bool> pushReaderSyncToCloud() async {
    if (_syncClientId.trim().isEmpty || adminSyncBaseUrl.trim().isEmpty) {
      return false;
    }
    return _readerSyncService.pushSnapshot(
      baseUrl: adminSyncBaseUrl,
      deviceId: _syncClientId,
      snapshot: _buildSyncSnapshot(),
    );
  }

  Future<bool> pullReaderSyncFromCloud() async {
    if (_syncClientId.trim().isEmpty || adminSyncBaseUrl.trim().isEmpty) {
      return false;
    }
    final snapshot = await _readerSyncService.pullSnapshot(
      baseUrl: adminSyncBaseUrl,
      deviceId: _syncClientId,
    );
    if (snapshot == null) {
      return false;
    }
    await _applyRemoteSyncSnapshot(snapshot);
    _publishSettings();
    _publishAiSettings();
    _publishExperienceSettings();
    _publishAudioState();
    _publishCurrentPage();
    _publishContentChange();
    notifyListeners();
    return true;
  }

  Future<void> saveAdminSyncBaseUrl(String baseUrl) async {
    await _preferences.saveAdminPublicBaseUrl(baseUrl);
    await refreshAdminSync();
    if (baseUrl.trim().isNotEmpty &&
        _experienceSettings.syncMode == ReaderSyncMode.localOnly) {
      _experienceSettings = _experienceSettings.copyWith(
        syncMode: ReaderSyncMode.cloudReady,
      );
      _publishExperienceSettings();
      await _repository.saveExperienceSettings(_experienceSettings);
    }
    _scheduleCloudSyncPush();
  }

  ReaderRemoteAssetPack? remoteAssetPackForEdition(MushafEdition edition) {
    return _adminConfig.assetPacks[edition];
  }

  String adminPackStatusForEdition(MushafEdition edition) {
    if (isBundledPackForEdition(edition)) {
      return 'Built-in';
    }
    if (isOfflinePackDownloading(edition)) {
      final progress = (offlinePackProgressForEdition(edition) * 100).round();
      return 'Downloading $progress%';
    }
    if (isOfflinePackDownloaded(edition)) {
      return 'Available offline';
    }
    final remotePack = remoteAssetPackForEdition(edition);
    if (remotePack != null) {
      return 'Admin v${remotePack.version}';
    }
    return 'Not available';
  }

  String adminPackSubtitleForEdition(MushafEdition edition) {
    final remotePack = remoteAssetPackForEdition(edition);
    if (isBundledPackForEdition(edition)) {
      return '${edition.bestUseLabel}. This edition is bundled with the app and always available offline.';
    }
    if (isOfflinePackDownloaded(edition) && remotePack != null) {
      return '${edition.bestUseLabel}. Admin pack ${remotePack.version} is stored on this device and will keep working offline.';
    }
    if (isOfflinePackDownloading(edition) && remotePack != null) {
      final progress = (offlinePackProgressForEdition(edition) * 100).round();
      return '${edition.bestUseLabel}. Downloading admin pack ${remotePack.version} for offline use ($progress%).';
    }
    if (remotePack != null) {
      return '${edition.bestUseLabel}. Admin pack ${remotePack.version} with ${remotePack.pageCount} imported pages is active.';
    }
    return '${edition.bestUseLabel}. No admin-managed pack is active yet.';
  }

  Future<void> downloadOfflineEditionPack(MushafEdition edition) async {
    if (_offlinePackProgress.containsKey(edition)) {
      return;
    }

    _offlinePackProgress = Map<MushafEdition, double>.from(_offlinePackProgress)
      ..[edition] = 0;
    notifyListeners();

    try {
      await _repository.downloadOfflinePack(
        edition,
        onProgress: (progress) {
          if (_isDisposed) {
            return;
          }
          _offlinePackProgress =
              Map<MushafEdition, double>.from(_offlinePackProgress)
                ..[edition] = progress.clamp(0, 1);
          notifyListeners();
        },
      );
    } finally {
      _offlinePackProgress =
          Map<MushafEdition, double>.from(_offlinePackProgress)
            ..remove(edition);
      await _refreshOfflinePackAvailability();
      _refreshCurrentCaches();
      _publishContentChange();
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> removeOfflineEditionPack(MushafEdition edition) async {
    await _repository.removeOfflinePack(edition);
    await _refreshOfflinePackAvailability();
    _refreshCurrentCaches();
    _publishContentChange();
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  bool _featureFlag(String key, {required bool fallback}) {
    return _adminConfig.isFeatureEnabled(key, fallback: fallback);
  }

  bool _shouldUseAdminAiProxy(QuranAiTool tool) {
    if (adminSyncBaseUrl.trim().isEmpty) {
      return false;
    }
    if (!QuranAdminAiProxyService.supportsRemoteTool(tool)) {
      return false;
    }
    return _normalizedAdminAiProvider != 'local';
  }

  Future<void> _hydrateFromCloudIfNeeded() async {
    if (_experienceSettings.syncMode != ReaderSyncMode.cloudReady ||
        _syncClientId.trim().isEmpty ||
        adminSyncBaseUrl.trim().isEmpty) {
      return;
    }
    final snapshot = await _readerSyncService.pullSnapshot(
      baseUrl: adminSyncBaseUrl,
      deviceId: _syncClientId,
    );
    if (snapshot != null) {
      await _applyRemoteSyncSnapshot(snapshot);
      return;
    }

    await _readerSyncService.pushSnapshot(
      baseUrl: adminSyncBaseUrl,
      deviceId: _syncClientId,
      snapshot: _buildSyncSnapshot(),
    );
  }

  ReaderSyncSnapshot _buildSyncSnapshot() {
    return ReaderSyncSnapshot(
      deviceId: _syncClientId,
      lastPageNumber: _currentPageNumber,
      settings: _settings,
      aiSettings: _aiSettings,
      readingPlan: _readingPlan,
      experienceSettings: _experienceSettings,
      dailyTargetPages: _dailyTargetPages,
      dailyProgressState: _dailyProgressState,
      readingHistory: _readingHistory,
      pageNotes: _pageNotes,
      favoritePages: _favoritePages,
      bookmarks: _bookmarks,
      hifzReviewEntries: _hifzReviewEntries,
      streakState: ReaderSyncStreakState(
        count: _readingStreakCount,
        lastDateKey: _readingStreakLastDate,
      ),
      audioState: ReaderSyncAudioState(
        chapterId: _audioState.currentChapterId,
        chapterName: _audioState.currentSurahName,
        reciterId: _audioState.selectedReciter?.id,
        reciterName: _audioState.selectedReciter?.displayName,
        positionMillis: _savedAudioPositionMillis,
        repeatEnabled: _audioState.repeatEnabled,
      ),
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _applyRemoteSyncSnapshot(ReaderSyncSnapshot snapshot) async {
    _settings = snapshot.settings;
    _aiSettings = snapshot.aiSettings;
    _syncCurrentAiSettingsWithAdminConfig();
    _readingPlan = snapshot.readingPlan;
    _experienceSettings = snapshot.experienceSettings;
    _dailyTargetPages = snapshot.dailyTargetPages;
    _dailyProgressState = snapshot.dailyProgressState;
    _readingHistory = snapshot.readingHistory;
    _pageNotes = snapshot.pageNotes;
    _favoritePages = snapshot.favoritePages;
    _bookmarks = snapshot.bookmarks;
    _hifzReviewEntries = snapshot.hifzReviewEntries;
    _readingStreakCount = snapshot.streakState.count;
    _readingStreakLastDate = snapshot.streakState.lastDateKey;
    _savedAudioPositionMillis = snapshot.audioState.positionMillis;
    QuranReciter? syncedReciter = _audioState.selectedReciter;
    if (snapshot.audioState.reciterId != null) {
      syncedReciter = _resolveSelectedReciter(snapshot.audioState.reciterId);
    }
    _audioState = _audioState.copyWith(
      selectedReciter: syncedReciter,
      currentChapterId: snapshot.audioState.chapterId,
      currentSurahName: snapshot.audioState.chapterName,
      positionMillis: snapshot.audioState.positionMillis,
      repeatEnabled: snapshot.audioState.repeatEnabled,
    );

    await _repository.setMushafEdition(_settings.mushafEdition);
    _currentPageNumber = _repository.clampPage(
      snapshot.lastPageNumber,
      preferImageMode: _settings.preferImageMode,
    );
    _rebuildContentCaches();
    _rebuildNavigationCaches();
    _refreshCurrentCaches();

    final persistenceTasks = <Future<void>>[
      _repository.saveSettings(_settings),
      _preferences.saveAiSettings(_aiSettings),
      _repository.saveReadingPlan(_readingPlan),
      _repository.saveExperienceSettings(_experienceSettings),
      _repository.saveDailyTargetPages(_dailyTargetPages),
      _repository.saveDailyProgressState(_dailyProgressState),
      _repository.saveReadingHistory(_readingHistory),
      _repository.savePageNotes(_pageNotes),
      _repository.saveFavoritePages(_favoritePages),
      _repository.saveBookmarks(_bookmarks),
      _repository.saveHifzRevisionEntries(_hifzReviewEntries),
      _repository.saveAudioChapterId(snapshot.audioState.chapterId),
      _repository.saveAudioPositionMillis(snapshot.audioState.positionMillis),
      _repository.saveAudioRepeatEnabled(snapshot.audioState.repeatEnabled),
      _repository.saveReadingStreakCount(_readingStreakCount),
      _repository.saveReadingStreakLastDate(_readingStreakLastDate),
      _repository.saveLastPageNumber(
        _currentPageNumber,
        preferImageMode: _settings.preferImageMode,
      ),
    ];
    if (snapshot.audioState.reciterId != null) {
      persistenceTasks.add(
        _repository.savePreferredReciterId(snapshot.audioState.reciterId!),
      );
    }
    await Future.wait(persistenceTasks);
  }

  void _scheduleCloudSyncPush() {
    if (_experienceSettings.syncMode != ReaderSyncMode.cloudReady ||
        _syncClientId.trim().isEmpty ||
        adminSyncBaseUrl.trim().isEmpty) {
      return;
    }
    _cloudSyncTimer?.cancel();
    _cloudSyncTimer = Timer(const Duration(seconds: 2), () {
      unawaited(pushReaderSyncToCloud());
    });
  }

  void _warmSupplementalContentInBackground({bool forceRefresh = false}) {
    if (_supplementalContentWarmFuture != null && !forceRefresh) {
      return;
    }

    final future = _repository
        .warmSupplementalContent(forceRefresh: forceRefresh)
        .then((_) {
      _rebuildNavigationCaches();
      _refreshCurrentCaches();
      _publishContentChange();
      if (!_isDisposed) {
        notifyListeners();
      }
    }).catchError((_) {
      // Keep launch fast even if large remote datasets are temporarily missing.
    });

    _supplementalContentWarmFuture = future.whenComplete(() {
      if (identical(_supplementalContentWarmFuture, future)) {
        _supplementalContentWarmFuture = null;
      }
    });
  }

  Future<void> _applyAdminEditionVisibilityRules() async {
    if (!_adminConfig.hasEditionControls) {
      return;
    }

    final enabledEditions = availableImageEditions;
    if (enabledEditions.contains(_settings.mushafEdition)) {
      return;
    }

    final fallbackEdition = enabledEditions.isNotEmpty
        ? enabledEditions.first
        : _repository.resolveSupportedEdition(_settings.mushafEdition);
    final nextPreferImageMode =
        _repository.hasAssetsForEdition(fallbackEdition);
    final targetPage = _repository.navigationPageForCurrentReferenceInEdition(
      _currentPageNumber,
      sourceEdition: _settings.mushafEdition,
      targetEdition: fallbackEdition,
      preferImageMode: _settings.preferImageMode,
    );

    _settings = _settings.copyWith(
      mushafEdition: fallbackEdition,
      preferImageMode: nextPreferImageMode,
    );
    await _repository.setMushafEdition(fallbackEdition);
    _currentPageNumber = _repository.clampPage(
      targetPage,
      preferImageMode: _settings.preferImageMode,
    );
    _publishSettings();
    _publishCurrentPage();
    unawaited(_persistSettings());
  }

  void _publishExperienceSettings() {
    if (_isDisposed || _experienceNotifier.value == _experienceSettings) {
      return;
    }
    _experienceNotifier.value = _experienceSettings;
    _scheduleCloudSyncPush();
  }

  Future<void> _refreshOfflinePackAvailability() async {
    const editions = MushafEdition.values;
    final checks = await Future.wait(
      editions.map((edition) async {
        final hasOfflinePack =
            await _repository.hasOfflinePackForEdition(edition);
        return MapEntry(edition, hasOfflinePack);
      }),
    );

    final bundledEditions =
        editions.where(_repository.hasBundledPackForEdition).toSet();
    _downloadedOfflineEditions = {
      ...bundledEditions,
      ...checks.where((entry) => entry.value).map((entry) => entry.key),
    };
  }
}
