import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/system_ui_service.dart';
import '../../../../core/storage/reader_preferences.dart';
import '../../data/repositories/quran_reader_repository.dart';
import '../../data/services/quran_ai_feature_service.dart';
import '../../data/services/quran_audio_service.dart';
import '../../data/services/quran_ollama_service.dart';
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
import '../../domain/models/reader_bookmark.dart';
import '../../domain/models/reader_daily_progress_state.dart';
import '../../domain/models/reader_history_entry.dart';
import '../../domain/models/reader_settings.dart';
import '../models/reader_audio_state.dart';

class QuranReaderController extends ChangeNotifier {
  static const String _defaultBookmarkFolder = 'General';
  static const int _audioPositionNotifyStepMillis = 750;
  static const Duration _pagePersistenceDebounce = Duration(milliseconds: 420);
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
    required ReaderPreferences preferences,
    required QuranOllamaService ollamaService,
  })  : _repository = repository,
        _audioService = audioService,
        _preferences = preferences,
        _ollamaService = ollamaService,
        _aiFeatureService = QuranAiFeatureService(ollamaService: ollamaService);

  final QuranReaderRepository _repository;
  final QuranAudioService _audioService;
  final ReaderPreferences _preferences;
  final QuranOllamaService _ollamaService;
  final QuranAiFeatureService _aiFeatureService;
  final ValueNotifier<ReaderAudioState> _audioNotifier =
      ValueNotifier<ReaderAudioState>(const ReaderAudioState.idle());
  final ValueNotifier<int> _pageNotifier = ValueNotifier<int>(1);
  final ValueNotifier<bool> _controlsNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<ReaderSettings> _settingsNotifier =
      ValueNotifier<ReaderSettings>(const ReaderSettings.defaults());
  final ValueNotifier<ReaderAiSettings> _aiSettingsNotifier =
      ValueNotifier<ReaderAiSettings>(const ReaderAiSettings.defaults());
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<int> _viewportNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _contentNotifier = ValueNotifier<int>(0);

  ReaderSettings _settings = const ReaderSettings.defaults();
  ReaderAiSettings _aiSettings = const ReaderAiSettings.defaults();
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
  List<QuranReciter> _reciters = const [];
  Set<String> _downloadedAudioKeys = const <String>{};
  String? _audioDownloadKeyInProgress;
  int _readingStreakCount = 0;
  String? _readingStreakLastDate;
  int _savedAudioPositionMillis = 0;
  Timer? _controlsTimer;
  Timer? _pagePersistenceTimer;
  Timer? _notesPersistenceTimer;
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
  Map<int, ReaderBookmark> _bookmarkByPageCache =
      const <int, ReaderBookmark>{};
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

  bool get isLoading => _isLoading;
  bool get controlsVisible => _controlsVisible;
  ReaderSettings get settings => _settings;
  ReaderAiSettings get aiSettings => _aiSettings;
  ReaderAudioState get audioState => _audioState;
  ValueListenable<ReaderAudioState> get audioListenable => _audioNotifier;
  ValueListenable<int> get pageListenable => _pageNotifier;
  ValueListenable<bool> get controlsListenable => _controlsNotifier;
  ValueListenable<ReaderSettings> get settingsListenable => _settingsNotifier;
  ValueListenable<ReaderAiSettings> get aiSettingsListenable =>
      _aiSettingsNotifier;
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
  List<MushafEdition> get availableImageEditions =>
      _repository.availableImageEditions;
  List<MushafEdition> get compareEditions => _repository.compareEditions;
  List<ReaderHistoryEntry> get readingHistory => _readingHistory;
  Map<int, String> get pageNotes => _pageNotes;
  List<int> get favoritePages => _favoritePages;
  List<ReaderBookmark> get bookmarks => _bookmarks;
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
      _currentSpreadCache ??
      spreadAt(currentSpreadIndex);
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

  bool get isCurrentPageFavorite => _favoritePageSet.contains(_currentPageNumber);

  bool get isCurrentPageBookmarked =>
      _bookmarkByPageCache.containsKey(_currentPageNumber);

  bool isFavoritePage(int pageNumber) => _favoritePageSet.contains(pageNumber);

  bool isBookmarkedPage(int pageNumber) =>
      _bookmarkByPageCache.containsKey(pageNumber);

  ReaderBookmark? bookmarkForPage(int pageNumber) => _bookmarkByPageCache[pageNumber];

  bool get hasActiveAudioSelection => _audioState.currentChapterId != null;

  bool get hasAudioResumePoint => _savedAudioPositionMillis > 0;

  int get audioResumePositionMillis => _savedAudioPositionMillis;
  int get downloadedAudioCount => _downloadedAudioKeys.length;

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
    return standardPageForPageNumber(pageNumber) == _smartHifzStandardPageNumber;
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
      _settings = launchState.settings;
      _settingsNotifier.value = _settings;
      _aiSettings = await _preferences.loadAiSettings();
      _aiSettingsNotifier.value = _aiSettings;
      _repository.setMushafEdition(_settings.mushafEdition);
      _currentPageNumber = launchState.initialPageNumber;
      _pageNotifier.value = _currentPageNumber;
      _controlsVisible = !_settings.fullscreenReading;
      _controlsNotifier.value = _controlsVisible;
      _dailyTargetPages = await _repository.loadDailyTargetPages();
      _dailyProgressState = await _repository.loadDailyProgressState(
        todayKey: _todayKey(),
        fallbackStartPage: _currentPageNumber,
      );
      _readingHistory = await _repository.loadReadingHistory();
      _pageNotes = await _repository.loadPageNotes();
      _favoritePages = await _repository.loadFavoritePages();
      _bookmarks = await _repository.loadBookmarks();
      _rebuildContentCaches();
      preferredReciterId = await _repository.loadPreferredReciterId();
      final audioChapterId = await _repository.loadAudioChapterId();
      _savedAudioPositionMillis = await _repository.loadAudioPositionMillis();
      final repeatEnabled = await _repository.loadAudioRepeatEnabled();
      _readingStreakCount = await _repository.loadReadingStreakCount();
      _readingStreakLastDate = await _repository.loadReadingStreakLastDate();
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
      await _recordCurrentPage();
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

  int navigationPageForStandardPageInEdition(
    int standardPage, {
    required MushafEdition edition,
  }) {
    return _repository.navigationPageForStandardPageInEdition(
      standardPage,
      edition: edition,
    );
  }

  List<QuranSearchResult> searchPages(String query) {
    return _repository.searchPages(
      query,
      preferImageMode: _settings.preferImageMode,
    );
  }

  List<QuranSearchResult> searchAyahs(String query) {
    return _repository.searchAyahs(
      query,
      preferImageMode: _settings.preferImageMode,
    );
  }

  Future<void> setAiResponseLanguage(AiResponseLanguage language) async {
    _aiSettings = _aiSettings.copyWith(responseLanguage: language);
    _publishAiSettings();
    await _preferences.saveAiSettings(_aiSettings);
  }

  Future<void> setAiOllamaEnabled(bool enabled) async {
    _aiSettings = _aiSettings.copyWith(ollamaEnabled: enabled);
    _publishAiSettings();
    await _preferences.saveAiSettings(_aiSettings);
  }

  Future<void> setAiOllamaBaseUrl(String baseUrl) async {
    _aiSettings = _aiSettings.copyWith(ollamaBaseUrl: baseUrl.trim());
    _publishAiSettings();
    await _preferences.saveAiSettings(_aiSettings);
  }

  Future<void> setAiOllamaModel(String model) async {
    final normalized =
        model.trim().isEmpty ? 'qwen2.5:1.5b-instruct' : model.trim();
    _aiSettings = _aiSettings.copyWith(ollamaModel: normalized);
    _publishAiSettings();
    await _preferences.saveAiSettings(_aiSettings);
  }

  Future<String> testAiConnection() {
    return _ollamaService.testConnection(settings: _aiSettings);
  }

  Future<QuranAiToolResult> runAiTool(
    QuranAiTool tool, {
    String userInput = '',
  }) async {
    final context = await _buildCurrentAiPageContext();
    return _aiFeatureService.runTool(
      tool: tool,
      settings: _aiSettings,
      context: context,
      userInput: userInput,
      pageSearch: searchPages,
      ayahSearch: searchAyahs,
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
    notifyListeners();
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
    _settings = _settings.copyWith(fullscreenReading: enabled);
    _controlsVisible = !enabled || _controlsVisible;
    _publishSettings();
    _publishControlsVisibility();
    notifyListeners();
    await _persistSettings();
    await SystemUiService.setFullscreen(enabled);
    _scheduleControlsAutoHide();
  }

  Future<void> togglePageNumbers(bool enabled) async {
    _settings = _settings.copyWith(showPageNumbers: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> toggleCustomBrightness(bool enabled) async {
    _settings = _settings.copyWith(customBrightnessEnabled: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> setPageBrightness(double value) async {
    _settings = _settings.copyWith(pageBrightness: value);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> toggleNightMode(bool enabled) async {
    _settings = _settings.copyWith(nightMode: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> togglePagePreset(bool enabled) async {
    _settings = _settings.copyWith(pagePresetEnabled: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> setPagePreset(PagePreset preset) async {
    _settings = _settings.copyWith(pagePreset: preset, pagePresetEnabled: true);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> togglePageOverlay(bool enabled) async {
    _settings = _settings.copyWith(pageOverlayEnabled: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> togglePageReflection(bool enabled) async {
    _settings = _settings.copyWith(pageReflectionEnabled: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> toggleLowMemoryMode(bool enabled) async {
    _settings = _settings.copyWith(lowMemoryMode: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> toggleHifzFocusMode(bool enabled) async {
    _settings = _settings.copyWith(hifzFocusMode: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> setHifzMaskHeightFactor(double value) async {
    _settings = _settings.copyWith(hifzMaskHeightFactor: value);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
  }

  Future<void> toggleHifzRevealOnHold(bool enabled) async {
    _settings = _settings.copyWith(hifzRevealOnHold: enabled);
    _publishSettings();
    notifyListeners();
    await _persistSettings();
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

    final standardPage = currentStandardPageNumber;
    _settings = _settings.copyWith(
      mushafEdition: edition,
      preferImageMode: nextPreferImageMode,
    );
    _repository.setMushafEdition(edition);
    _currentPageNumber = _repository.navigationPageForStandardPage(
      standardPage,
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
    final buffer = StringBuffer()
      ..writeln('Quran Dual Page & Multi-Line Reader Summary')
      ..writeln('Current page: $_currentPageNumber / $totalPages')
      ..writeln('Khatam progress: ${(khatamProgress * 100).round()}%')
      ..writeln('Reading streak: $_readingStreakCount day(s)')
      ..writeln('Daily target: $_dailyTargetPages page(s)')
      ..writeln('Favorites: ${_favoritePages.length}')
      ..writeln('Bookmarks: ${_bookmarks.length}');

    if (selectedAudioChapter != null && _audioState.selectedReciter != null) {
      buffer
        ..writeln('Audio Surah: ${selectedAudioChapter!.nameSimple}')
        ..writeln('Audio Qari: ${_audioState.selectedReciter!.displayName}');
    }

    return buffer.toString().trimRight();
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

  void _publishControlsVisibility() {
    if (_isDisposed || _controlsNotifier.value == _controlsVisible) {
      return;
    }
    _controlsNotifier.value = _controlsVisible;
  }

  void _publishSettings() {
    if (_isDisposed || identical(_settingsNotifier.value, _settings)) {
      return;
    }
    _settingsNotifier.value = _settings;
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
  }

  Future<void> _persistSettings() {
    return _repository.saveSettings(_settings);
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
        now.difference(_lastRecordedHistoryAt!) <
            const Duration(seconds: 18);
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
    _loadingNotifier.dispose();
    _viewportNotifier.dispose();
    _contentNotifier.dispose();
    _audioNotifier.dispose();
    _ollamaService.dispose();
    _audioService.dispose();
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
    _readingActivityCountsCache =
        Map<String, int>.unmodifiable(activityCounts);
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

  void _publishAiSettings() {
    if (_isDisposed) {
      return;
    }
    _aiSettingsNotifier.value = _aiSettings;
  }
}
