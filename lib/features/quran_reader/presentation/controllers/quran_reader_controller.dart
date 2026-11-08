import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/system_ui_service.dart';
import '../../../../core/services/reader_download_policy.dart';
import '../../../../core/services/reader_browser_reminder_service.dart';
import '../../../../core/storage/reader_preferences.dart';
import '../../../../core/storage/reader_backup_history.dart';
import '../../data/repositories/quran_reader_repository.dart';
import '../../data/services/quran_admin_ai_proxy_service.dart';
import '../../data/services/quran_ai_feature_service.dart';
import '../../data/services/quran_audio_service.dart';
import '../../data/services/quran_reader_sync_service.dart';
import '../../data/services/reader_account_service.dart';
import '../../data/services/reader_audio_verse_lookup.dart';
import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/quran_asset_pack_download.dart';
import '../../domain/models/quran_chapter_summary.dart';
import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_navigation_marker.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/quran_page_line.dart';
import '../../domain/models/quran_page_insight.dart';
import '../../domain/models/quran_page_verse.dart';
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

class ReaderPreparedAccount {
  const ReaderPreparedAccount._({required this.account, required this.baseUrl,
    required this.context, required this.generation, this.snapshot, this.syncRevision, this.alreadyConnected = false});
  final ReaderAccountIdentity account;
  final String baseUrl;
  final int context;
  final int generation;
  final ReaderSyncSnapshot? snapshot;
  final int? syncRevision;
  final bool alreadyConnected;
  bool get keepsCurrentData => snapshot == null;
}

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
    ReaderAccountService? accountService,
  })  : _repository = repository,
        _audioService = audioService,
        _readerSyncService = readerSyncService,
        _readerAccountService = accountService ?? ReaderAccountService(),
        _preferences = preferences,
        _aiFeatureService = QuranAiFeatureService();

  final QuranReaderRepository _repository;
  final QuranAudioService _audioService;
  QuranAudioService get audioPracticeService => _audioService;
  final QuranReaderSyncService _readerSyncService;
  final ReaderAccountService _readerAccountService;
  final ReaderPreferences _preferences;
  late final ReaderBackupHistory backupHistory = ReaderBackupHistory(profileId: _preferences.profileId);
  Timer? _backupHistoryTimer;
  String? _backupHistoryError;
  String? get backupHistoryError => _backupHistoryError;
  Future<void> saveRestorePoint(String reason, {bool force = false}) async {
    await backupHistory.save(buildStateBackupJson(), reason: reason, force: force);
    _backupHistoryError = null;
  }
  void _scheduleRestorePoint() {
    if (_isDisposed || _isLoading) return;
    _backupHistoryTimer?.cancel();
    _backupHistoryTimer = Timer(const Duration(seconds: 2), () async {
      try { await saveRestorePoint('Automatic backup'); }
      catch (_) {
        _backupHistoryError = 'Automatic backup could not be saved. Export a backup to keep a copy.';
        if (!_isDisposed) notifyListeners();
      }
    });
  }
  Future<void> restoreHistoryPoint(ReaderRestorePoint point) async {
    await restoreStateBackupJson(point.backup);
  }
  Future<void> prepareForLocalProfileSwitch() async {
    if (_readerAccountBusy) throw StateError('Finish the current account action first.');
    if (_syncBaseUrl.isNotEmpty && _syncToken.isNotEmpty) {
      await detachReaderBrowserReminders(baseUrl: _syncBaseUrl,
          identity: ReaderSyncIdentity(deviceId: _syncClientId, token: _syncToken));
    }
    _cloudSyncTimer?.cancel();
    _backupHistoryTimer?.cancel();
    _pagePersistenceTimer?.cancel();
    _notesPersistenceTimer?.cancel();
    _invalidateReaderSyncContext();
    await _audioService.pause();
    await _persistCurrentPageSnapshot();
    await _repository.savePageNotesByEdition(_editionPageNotes);
    await _persistAudioState();
    await _syncStateWrites;
    await saveRestorePoint('Before switching profile');
    _cloudSyncTimer?.cancel();
  }
  final ReaderDownloadPolicy _downloadPolicy = ReaderDownloadPolicy();
  StreamSubscription<bool>? _downloadNetworkSubscription;
  Map<MushafEdition, QuranPartialAssetPack> _partialOfflinePacks = {};
  final Map<MushafEdition, QuranPackTransferProgress> _packTransferProgress = {};
  QuranPackStorageInfo? _packStorageInfo;
  int? _availableStorageBytes;

  bool get wifiOnlyDownloads => _downloadPolicy.wifiOnly;
  bool get supportsWifiOnlyDownloads => _downloadPolicy.supportsWifiOnly;
  QuranPackStorageInfo? get packStorageInfo => _packStorageInfo;
  int? get availableStorageBytes => _availableStorageBytes;
  QuranPartialAssetPack? partialOfflinePackForEdition(MushafEdition edition) =>
      _partialOfflinePacks[edition];
  QuranPackTransferProgress? transferProgressForEdition(MushafEdition edition) =>
      _packTransferProgress[edition];
  bool isOfflinePackPaused(MushafEdition edition) =>
      !isOfflinePackDownloading(edition) && _partialOfflinePacks.containsKey(edition);

  Future<void> setWifiOnlyDownloads(bool enabled) async {
    await _downloadPolicy.setWifiOnly(enabled);
    await refreshDownloadPolicy();
    if (!_isDisposed) notifyListeners();
  }

  Future<void> refreshDownloadPolicy() async {
    if (!await _downloadPolicy.allowsDownload() && !_isDisposed) {
      for (final edition in _offlinePackCancelTokens.keys.toList()) {
        pauseOfflineEditionPackDownload(edition);
      }
    }
  }

  Future<void> refreshDownloadStorage() async {
    final info = await _repository.offlinePackStorageInfo();
    final available = await _downloadPolicy.availableStorageBytes();
    if (_isDisposed) return;
    _packStorageInfo = info;
    _availableStorageBytes = available;
    notifyListeners();
  }

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
  Map<String, Map<int, String>> _editionPageNotes = {};
  Map<String, List<int>> _editionFavoritePages = {};
  String get _annotationKey => _settings.preferImageMode
      ? _settings.mushafEdition.storageValue : '__canonical_text__';
  List<int> _favoritePages = const [];
  List<ReaderBookmark> _bookmarks = const [];
  List<ReaderHifzReviewEntry> _hifzReviewEntries = const [];
  List<QuranReciter> _reciters = const [];
  Set<String> _downloadedAudioKeys = const <String>{};
  String? _audioDownloadKeyInProgress;
  int _readingStreakCount = 0;
  String? _readingStreakLastDate;
  int _savedAudioPositionMillis = 0;
  int _audioLoadGeneration = 0;
  Timer? _controlsTimer;
  Timer? _pagePersistenceTimer;
  Timer? _pageUiRefreshTimer;
  Timer? _notesPersistenceTimer;
  Timer? _cloudSyncTimer;
  Future<void>? _supplementalContentWarmFuture;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<String>? _playbackErrorSubscription;
  String? _currentRecitationVerseKey;
  String? get currentRecitationVerseKey => _currentRecitationVerseKey;
  QuranPageVerse? get currentAudioVerse {
    final key = _currentRecitationVerseKey;
    if (!isAudioEnabled || !_experienceSettings.recitationSyncEnabled ||
        !_audioState.isPlaying || _audioState.isLoading ||
        _audioState.isBuffering || _audioState.errorMessage != null ||
        _audioService.isPlaybackCompleted || key == null ||
        _audioService.loadedChapterId != _audioState.currentChapterId ||
        _audioService.loadedReciterId != _audioState.selectedReciter?.id ||
        _audioService.verseKeyAtPosition(
          Duration(milliseconds: _audioState.positionMillis),
        ) != key) {
      return null;
    }
    final page = _repository.canonicalPageForVerse(key);
    if (page == null) return null;
    return resolveReaderAudioVerse(
      verseKey: key,
      chapterId: _audioState.currentChapterId,
      active: true,
      verses: _repository.pageInsightForPageNumber(
        page, preferImageMode: false,
      )?.verses ?? const <QuranPageVerse>[],
    );
  }
  String get recitationFollowStatus {
    if (!_experienceSettings.recitationSyncEnabled) return 'Recitation follow is off';
    if (_audioState.isLoading || _audioState.isBuffering) return 'Loading recitation…';
    if (_audioState.errorMessage != null) return 'Recitation is unavailable';
    if (!_audioState.isPlaying) {
      if (_lastPlayerState?.processingState == ProcessingState.completed) return 'Recitation complete';
      return _currentRecitationVerseKey == null
          ? 'Start recitation to follow verses'
          : 'Paused at verse $_currentRecitationVerseKey';
    }
    if (_currentRecitationVerseKey == null) return 'Verse timing is unavailable for this recording';
    return isStudySurahScoped
        ? 'Following verse $_currentRecitationVerseKey • reading your selected Mushaf scan'
        : 'Following verse $_currentRecitationVerseKey';
  }
  int _lastNotifiedAudioPositionMillis = -1;
  int _lastNotifiedAudioDurationMillis = -1;
  PlayerState? _lastPlayerState;
  int? _lastPersistedPageNumber;
  bool? _lastPersistedPreferImageMode;
  int? _lastRecordedHistoryPageNumber;
  String? _lastRecordedHistoryDateKey;
  DateTime? _lastRecordedHistoryAt;
  MushafEdition? _lastRecordedHistoryEdition;
  bool? _lastRecordedHistoryPreferImageMode;
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
  int? _smartHifzScanPageNumber;
  MushafEdition? _smartHifzEdition;
  int? _smartHifzLineCount;
  bool _smartHifzRevealed = false;
  bool _isDisposed = false;
  String _syncClientId = '';
  String _syncToken = '';
  String _syncBaseUrl = '';
  String _syncBindingBaseUrl = '';
  int _syncBindingContext = -1;
  int _syncContextGeneration = 0;
  int _localChangeGeneration = 0;
  int? _syncPushGeneration;
  int? _readerSyncRevision;
  bool _readerSyncConflict = false;
  bool _readerSyncDirty = true;
  bool _syncUsesFreshBackup = false;
  bool _suppressSyncDirty = false;
  bool _syncStateWriteFailed = false;
  String _readerSyncStatus = 'Reader data is stored on this device.';
  Future<bool>? _syncIdentityBinding;
  Future<void> _syncStateWrites = Future<void>.value();
  Future<void> _syncOperationQueue = Future<void>.value();
  bool _readerAccountBusy = false;
  bool _readerAccountAdopting = false;
  ReaderPreparedAccount? _preparedReaderAccount;
  String? _readerAccountEmail;
  bool get readerAccountBusy => _readerAccountBusy;
  String? get readerAccountEmail => _readerAccountEmail;
  String get readerSyncStatusLabel => _experienceSettings.syncMode == ReaderSyncMode.localOnly
      ? 'Local only. Reader data stays on this device.' : _readerSyncStatus;
  bool get hasUnsyncedReaderChanges => _readerSyncDirty;
  Set<MushafEdition> _downloadedOfflineEditions = const <MushafEdition>{};
  List<QuranZipAssetPack> _zipAssetPacks = const <QuranZipAssetPack>[];
  Map<MushafEdition, double> _offlinePackProgress =
      const <MushafEdition, double>{};
  final Map<MushafEdition, CancelToken> _offlinePackCancelTokens =
      <MushafEdition, CancelToken>{};

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

  List<MushafEdition> get compareEditions => _repository.compareEditions
      .where(isMushafEditionStoredOffline)
      .toList(growable: false);
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
  String get adminAiProviderLabel => 'Ollama';
  String get adminAiModelLabel => QuranAdminAiProxyService.modelName;
  String get adminAiEndpointLabel => '$adminSyncBaseUrl/public/ai/run';
  String get adminAiStatusLabel =>
      _adminAiProviderSetting.toLowerCase() == 'ollama' &&
              _adminAiModelSetting == QuranAdminAiProxyService.modelName &&
              _adminAiStatusSetting.isNotEmpty
          ? _adminAiStatusSetting
          : 'Ollama qwen3:0.6b only';
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
  bool get isCompareEnabled =>
      _featureFlag(
        'feature_compare',
        fallback: true,
      ) &&
      compareEditions.length >= 2;
  bool get isKanzulStudyEnabled =>
      _featureFlag(
        'feature_kanzul_study',
        fallback: true,
      ) &&
      isMushafEditionStoredOffline(MushafEdition.kanzulIman);
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

  List<ReaderHistoryEntry> get readingHistory => _readingHistory
      .where((entry) => entry.preferImageMode == _settings.preferImageMode &&
          (!entry.preferImageMode || entry.edition == _settings.mushafEdition))
      .toList(growable: false);
  Map<int, String> get pageNotes => _pageNotes;
  List<int> get favoritePages => _favoritePages;
  List<ReaderBookmark> get bookmarks => _bookmarks
      .where((entry) => entry.preferImageMode == _settings.preferImageMode &&
          (!entry.preferImageMode || entry.edition == _settings.mushafEdition))
      .toList(growable: false);
  List<ReaderHifzReviewEntry> get hifzReviewEntries => _hifzReviewEntries
      .where((entry) => entry.preferImageMode == _settings.preferImageMode &&
          (!entry.preferImageMode || entry.edition == _settings.mushafEdition))
      .toList(growable: false);
  List<ReaderHifzReviewEntry> get hifzRevisionQueue {
    final now = DateTime.now();
    final entries = _hifzReviewEntries
        .where((entry) => entry.preferImageMode)
        .toList(growable: false);
    entries.sort((a, b) {
      final due = a.reviewDueDate(now: now).compareTo(b.reviewDueDate(now: now));
      if (due != 0) return due;
      final strength = b.strength.priorityWeight - a.strength.priorityWeight;
      if (strength != 0) return strength;
      final edition = a.edition.storageValue.compareTo(b.edition.storageValue);
      return edition != 0 ? edition : a.pageNumber.compareTo(b.pageNumber);
    });
    return entries;
  }

  Future<void> openHifzReviewEntry(ReaderHifzReviewEntry entry) async {
    if (!entry.preferImageMode || !_repository.hasAssetsForEdition(entry.edition)) {
      throw StateError('Download this Mushaf edition before opening its review.');
    }
    await selectMushafEdition(entry.edition);
    await jumpToPage(entry.pageNumber);
  }

  List<String> get bookmarkFolders => _bookmarkFoldersCache;

  Map<String, List<ReaderBookmark>> get bookmarksByFolder =>
      _bookmarksByFolderCache;

  int get readingStreakCount => _readingStreakCount;
  int get dailyTargetPages => _dailyTargetPages;
  bool get isStudySurahScoped => _settings.preferImageMode;
  String get studyScopeLabel => isStudySurahScoped
      ? currentChapterSummary == null
          ? 'Surah reference unavailable for this scan'
          : 'Surah ${currentChapterSummary!.nameSimple} • full Surah study'
      : 'Canonical page $_currentPageNumber';
  String get scanMappingNotice =>
      'Scanned pages use Surah-level study. Exact verse-to-scan-page alignment is unavailable.';

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
    for (final entry in hifzReviewEntries) {
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
    final sorted = List<ReaderHifzReviewEntry>.from(hifzReviewEntries);
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
    final zipAvailable = _zipAssetPacks.map((pack) => pack.edition).toSet();
    return MushafEdition.values.map((edition) {
      final state = _offlinePackProgress.containsKey(edition)
          ? OfflinePackState.downloading
          : _downloadedOfflineEditions.contains(edition)
              ? OfflinePackState.downloaded
              : zipAvailable.contains(edition)
                  ? OfflinePackState.adminManaged
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

  bool isMushafEditionReady(MushafEdition edition) {
    return _repository.hasAssetsForEdition(edition);
  }

  bool isMushafEditionStoredOffline(MushafEdition edition) {
    return isBundledPackForEdition(edition) || isOfflinePackDownloaded(edition);
  }

  bool isOfflinePackDownloading(MushafEdition edition) {
    return _offlinePackProgress.containsKey(edition);
  }

  bool hasZipPackForEdition(MushafEdition edition) {
    return _zipAssetPacks.any((pack) => pack.edition == edition);
  }

  bool hasDownloadablePackForEdition(MushafEdition edition) {
    return hasZipPackForEdition(edition) ||
        remoteAssetPackForEdition(edition) != null;
  }

  QuranZipAssetPack? zipPackForEdition(MushafEdition edition) {
    for (final pack in _zipAssetPacks) {
      if (pack.edition == edition) {
        return pack;
      }
    }
    return null;
  }

  int get downloadableZipPackCount {
    return MushafEdition.values
        .where(
          (edition) =>
              hasDownloadablePackForEdition(edition) &&
              !_downloadedOfflineEditions.contains(edition) &&
              !_repository.hasBundledPackForEdition(edition),
        )
        .length;
  }

  int get downloadedZipPackCount {
    return _downloadedOfflineEditions
        .where((edition) => !_repository.hasBundledPackForEdition(edition))
        .length;
  }

  MushafEdition? get activeOfflineDownloadEdition {
    return _offlinePackProgress.isEmpty
        ? null
        : _offlinePackProgress.keys.first;
  }

  bool get hasActiveOfflinePackDownloads => _offlinePackProgress.isNotEmpty;

  double offlinePackProgressForEdition(MushafEdition edition) {
    return _offlinePackProgress[edition] ?? 0;
  }

  bool isBundledPackForEdition(MushafEdition edition) {
    return _repository.hasBundledPackForEdition(edition);
  }

  Map<String, int> get readingActivityCounts => _readingActivityCountsCache;

  Set<String> get recentActivityDateKeys => _recentActivityDateKeysCache;

  Set<String> _pageNumbersForDateKey(String dateKey) {
    final pages = <String>{};
    for (final entry in _readingHistory) {
      if (_dateKeyFromIso(entry.viewedAtIso) == dateKey) {
        pages.add('${entry.preferImageMode ? entry.edition.storageValue : '__canonical_text__'}:${entry.pageNumber}');
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
    if (pageNumber < 1 || !hasSmartHifzChallenge) {
      return false;
    }
    if (_settings.preferImageMode) {
      return _smartHifzEdition == _settings.mushafEdition &&
          _smartHifzScanPageNumber == pageNumber;
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
      await _downloadPolicy.initialize();
      _downloadNetworkSubscription ??= _downloadPolicy.allowedChanges.listen(
        (allowed) {
          if (!allowed && !_isDisposed) {
            for (final edition in _offlinePackCancelTokens.keys.toList()) {
              pauseOfflineEditionPackDownload(edition);
            }
          }
        },
        onError: (Object _) { unawaited(refreshDownloadPolicy()); },
      );
      final launchState = await _repository.loadLaunchState();
      final aiSettingsFuture = _preferences.loadAiSettings();
      final dailyTargetPagesFuture = _repository.loadDailyTargetPages();
      final dailyProgressStateFuture = _repository.loadDailyProgressState(
        todayKey: _todayKey(),
        fallbackStartPage: launchState.initialPageNumber,
      );
      final readingPlanFuture = _repository.loadReadingPlan();
      final experienceSettingsFuture = _repository.loadExperienceSettings();
      final readingHistoryFuture = _repository.loadReadingHistory();
      final pageNotesFuture = _repository.loadPageNotesByEdition();
      final favoritePagesFuture = _repository.loadFavoritePagesByEdition();
      final bookmarksFuture = _repository.loadBookmarks();
      final hifzRevisionEntriesFuture = _repository.loadHifzRevisionEntries();

      _settings = launchState.settings;
      _settingsNotifier.value = _settings;
      _adminConfig = _repository.adminConfig;
      _zipAssetPacks = _repository.availableZipPacks;
      _refreshZipPacksInBackground();
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
      _experienceNotifier.value = _experienceSettings;
      _readingHistory = await readingHistoryFuture;
      _editionPageNotes = await pageNotesFuture;
      _editionFavoritePages = await favoritePagesFuture;
      _activateEditionAnnotations();
      _bookmarks = await bookmarksFuture;
      _hifzReviewEntries = await hifzRevisionEntriesFuture;
      _rebuildContentCaches();
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
      await _bindReaderSyncIdentity();
      await _hydrateFromCloudIfNeeded();
      _publishAudioState();
      _rebuildNavigationCaches();
      _refreshCurrentCaches();
      _bindAudioStreams();
      try {
        await _audioService
            .setRepeatEnabled(_audioState.repeatEnabled)
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      await SystemUiService.setFullscreen(_settings.fullscreenReading);
      unawaited(_recordCurrentPage());
      _scheduleCloudSyncPush();
    } finally {
      _isLoading = false;
      _loadingNotifier.value = false;
      _scheduleRestorePoint();
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
    _markReaderSyncDirty();
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
    _markReaderSyncDirty();
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
        entries.indexWhere((entry) => entry.pageNumber == pageNumber &&
            entry.preferImageMode == _settings.preferImageMode &&
            (!entry.preferImageMode || entry.edition == _settings.mushafEdition));
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
          edition: _settings.mushafEdition,
          preferImageMode: _settings.preferImageMode,
          strength: strength,
          updatedAtIso: nowIso,
          reviewCount: 1,
        ),
      );
    }
    _hifzReviewEntries = entries;
    _markReaderSyncDirty();
    await _repository.saveHifzRevisionEntries(_hifzReviewEntries);
    _publishContentChange();
  }

  Future<void> clearHifzReviewEntry(int pageNumber) async {
    final edition = _settings.mushafEdition;
    final preferImages = _settings.preferImageMode;
    await saveRestorePoint('Before deleting reader data');
    if (_isDisposed) return;
    _hifzReviewEntries = _hifzReviewEntries
        .where((entry) => entry.pageNumber != pageNumber ||
            entry.preferImageMode != preferImages ||
            (entry.preferImageMode && entry.edition != edition))
        .toList(growable: false);
    _markReaderSyncDirty();
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
    if (_experienceSettings.syncMode == mode) return;
    _invalidateReaderSyncContext();
    final context = _syncContextGeneration;
    _experienceSettings = _experienceSettings.copyWith(syncMode: mode);
    _suppressSyncDirty = true;
    try {
      _publishExperienceSettings();
    } finally {
      _suppressSyncDirty = false;
    }
    if (!_isDisposed) notifyListeners();
    await _repository.saveExperienceSettings(_experienceSettings);
    if (_isDisposed || context != _syncContextGeneration ||
        mode != ReaderSyncMode.cloudReady) {
      return;
    }
    await _hydrateFromCloudIfNeeded();
    _scheduleCloudSyncPush(markDirty: false);
  }

  Future<QuranAiToolResult> runAiTool(
    QuranAiTool tool, {
    String userInput = '',
    String referenceSelection = '',
    List<String> historyReferences = const [],
    int quizCount = 5,
    int revisionDays = 7,
    int minutesPerDay = 10,
  }) async {
    if (tool != QuranAiTool.smartSearch) {
      return _runCanonicalStudyTool(tool,
        userInput: userInput,
        referenceSelection: referenceSelection,
        historyReferences: historyReferences,
        quizCount: quizCount,
        revisionDays: revisionDays,
        minutesPerDay: minutesPerDay,
      );
    }
    if (tool == QuranAiTool.smartSearch) {
      await _repository.warmSupplementalContent();
    }
    final context = await _buildCurrentAiPageContext(
      forSearch: tool == QuranAiTool.smartSearch,
    );
    QuranAiToolResult? groundedActions;
    var groundingContext = '';
    final searchPassageKeys = <String>{};
    if (tool == QuranAiTool.smartSearch ||
        tool == QuranAiTool.bookmarkAssistant ||
        tool == QuranAiTool.hifzCoach ||
        tool == QuranAiTool.recitationFollow) {
      Map<String, dynamic>? searchPlan;
      if (await _aiFeatureService.needsSearchPlanning(userInput)) {
        final planned = await _adminAiProxyService.runTool(
          baseUrl: adminSyncBaseUrl,
          tool: QuranAiTool.smartSearch,
          settings: _aiSettings,
          context: context,
          userInput: userInput,
          groundingContext: await _aiFeatureService.searchPlanningContext(userInput),
          searchPlanning: true,
        );
        if (planned == null) {
          throw const QuranAdminAiException('Ollama returned no search plan.');
        }
        try {
          var text = planned.output.trim();
          if (text.startsWith('```')) {
            final fenced = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$',
                caseSensitive: false).firstMatch(text);
            if (fenced == null) throw const FormatException('Invalid search plan.');
            text = fenced[1]!;
          }
          final decoded = json.decode(text);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Invalid search plan.');
          }
          searchPlan = decoded;
        } catch (_) {
          throw const QuranAdminAiException(
              'Ollama could not understand this search. Try a clearer question.');
        }
      }
      groundedActions = await _aiFeatureService.searchQuranData(
        settings: _aiSettings,
        context: context,
        userInput: userInput,
        plan: searchPlan,
        ayahSearch: searchAyahsLocal,
      );
      if (tool == QuranAiTool.smartSearch) {
        final hits = groundedActions.searchResults
            .where((hit) => hit.verseKey != null &&
                RegExp(r'^\d{1,3}:\d{1,3}$').hasMatch(hit.verseKey!))
            .take(12)
            .toList(growable: false);
        final passages = <String>[];
        var passageLength = 0;
        for (final hit in hits) {
          final passage = 'Verse key: ${hit.verseKey}\n'
              'Title: ${hit.title}\nVerified translation:\n${hit.snippet}';
          if (passageLength + passage.length > 7200) continue;
          passages.add(passage);
          searchPassageKeys.add(hit.verseKey!);
          passageLength += passage.length;
        }
        groundingContext = passages.isEmpty
            ? 'Verified query-specific Quran lookup: no verified Ayah hits '
                'were found in the local Quran data. Do not invent matching '
                'references or treat the current page as a query match.'
            : 'Verified query-specific Ayah translations from the bundled '
                'Quran.com resources (English 84, Urdu 97). These are the '
                'search results, not the currently open page. Rank only '
                'these references for the query; the app displays their '
                'original translations.\n\n${passages.join('\n\n')}';
      }
    }
    final remoteResult = await _adminAiProxyService.runTool(
      baseUrl: adminSyncBaseUrl,
      tool: tool,
      settings: _aiSettings,
      context: context,
      userInput: userInput,
      groundingContext: groundingContext,
    );
    if (remoteResult == null) {
      throw const QuranAdminAiException('Ollama returned no answer.');
    }
    if (groundedActions == null) {
      return remoteResult;
    }
    var output = remoteResult.output;
    var searchResults = groundedActions.searchResults;
    if (tool == QuranAiTool.smartSearch) {
      try {
        final decision = json.decode(remoteResult.output);
        if (decision is! Map<String, dynamic> || decision.length != 1 ||
            decision['matches'] is! List) {
          throw const FormatException('Invalid search ranking.');
        }
        final keys = List<String>.from(decision['matches'] as List);
        if (keys.length > searchPassageKeys.length ||
            keys.toSet().length != keys.length ||
            (searchPassageKeys.isNotEmpty && keys.isEmpty) ||
            keys.any((key) => !searchPassageKeys.contains(key))) {
          throw const FormatException('Unverified search references.');
        }
        final verifiedResults = {
          for (final result in groundedActions.searchResults)
            result.verseKey: result,
        };
        searchResults = keys.map((key) => verifiedResults[key]!).toList();
      } catch (_) {
        throw const QuranAdminAiException(
            'Ollama returned an invalid Quran search ranking. Try again.');
      }
      final count = searchResults.length;
      final english = count == 0
          ? 'No matching Ayah was found. Try a clearer topic, word, or Surah:Ayah reference.'
          : 'Found $count relevant Ayah${count == 1 ? '' : 's'}. The verified translations are shown below.';
      final urdu = count == 0
          ? 'کوئی متعلقہ آیت نہیں ملی۔ واضح موضوع، لفظ یا سورہ:آیت نمبر لکھ کر دوبارہ تلاش کریں۔'
          : '$count متعلقہ آیات ملیں۔ مستند تراجم نیچے دیے گئے ہیں۔';
      output = switch (_aiSettings.responseLanguage) {
        AiResponseLanguage.english => english,
        AiResponseLanguage.urdu => urdu,
        AiResponseLanguage.bilingual => '$english\n\n$urdu',
      };
    }
    return QuranAiToolResult(
      tool: tool,
      output: output,
      sourceLabel: remoteResult.sourceLabel,
      usedOnlineModel: remoteResult.usedOnlineModel,
      searchResults: searchResults,
      selectionLabel: groundedActions.selectionLabel,
      sourceNotes: groundedActions.sourceNotes,
      bookmarkSuggestion: groundedActions.bookmarkSuggestion,
      matchedLineNumber: groundedActions.matchedLineNumber,
      matchedLineText: groundedActions.matchedLineText,
    );
  }

  Future<QuranAiToolResult> _runCanonicalStudyTool(
    QuranAiTool tool, {
    required String userInput,
    required String referenceSelection,
    required List<String> historyReferences,
    required int quizCount,
    required int revisionDays,
    required int minutesPerDay,
  }) async {
    await _repository.warmSupplementalContent();
    final page = _currentPageNumber;
    final scope = '${_preferences.profileId}|$_annotationKey';
    final material = await _aiFeatureService.prepareStudy(
      tool: tool,
      settings: _aiSettings,
      userInput: userInput,
      referenceSelection: referenceSelection,
      historyReferences: historyReferences.take(12).toList(growable: false),
      defaultReferences: currentPageInsight?.verses.take(7)
          .map((verse) => verse.verseKey).toList(growable: false) ?? const [],
      ayahSearch: searchAyahsLocal,
    );
    final allowedKeys = material.candidates.map((verse) => verse.verseKey).toSet();
    if (material.candidates.length > 12 ||
        allowedKeys.length != material.candidates.length) {
      throw const QuranAdminAiException('Select at most 12 distinct Ayahs.');
    }
    final passages = material.candidates.map((verse) =>
        'Verse key: ${verse.verseKey}\n'
        'Surah: ${verse.chapterName}\n'
        'Verified translation:\n${verse.translationFor(_aiSettings.responseLanguage)}')
        .join('\n\n');
    if (passages.length > 7200) {
      throw const QuranAdminAiException(
          'This selection is too long. Choose a smaller Ayah range.');
    }
    final context = await _buildCurrentAiPageContext(forSearch: true);
    final remote = await _adminAiProxyService.runTool(
      baseUrl: adminSyncBaseUrl,
      tool: tool,
      settings: _aiSettings,
      context: context,
      userInput: userInput,
      groundingContext: passages.isEmpty
          ? 'No verified Ayah candidates were found.'
          : 'Verified canonical study references. ${material.selectionLabel}\n\n$passages',
    );
    if (remote == null) {
      throw const QuranAdminAiException('Ollama returned no study selection.');
    }
    late List<String> keys;
    try {
      final decision = json.decode(remote.output);
      if (decision is! Map<String, dynamic> || decision.length != 1 ||
          decision['matches'] is! List) {
        throw const FormatException('Invalid study ranking.');
      }
      keys = List<String>.from(decision['matches'] as List);
      if (keys.length > allowedKeys.length || keys.toSet().length != keys.length ||
          (allowedKeys.isNotEmpty && keys.isEmpty) ||
          keys.any((key) => !allowedKeys.contains(key))) {
        throw const FormatException('Unverified study references.');
      }
    } catch (_) {
      throw const QuranAdminAiException(
          'Ollama returned an invalid study selection. Try again.');
    }
    final result = await _aiFeatureService.finishStudy(
      material: material,
      selectedKeys: keys,
      tool: tool,
      settings: _aiSettings,
      quizCount: quizCount,
      revisionDays: revisionDays,
      minutesPerDay: minutesPerDay,
    );
    return QuranAiToolResult(
      tool: result.tool,
      output: remote.sourceNotes.isEmpty
          ? result.output
          : '${remote.sourceNotes.join('\n\n')}\n\n${result.output}',
      sourceLabel: remote.sourceLabel,
      usedOnlineModel: true,
      searchResults: result.searchResults,
      bookmarkSuggestion: result.bookmarkSuggestion,
      matchedLineNumber: result.matchedLineNumber,
      matchedLineText: result.matchedLineText,
      canonicalVerses: result.canonicalVerses,
      quizQuestions: result.quizQuestions,
      revisionDays: result.revisionDays,
      textComparison: result.textComparison,
      selectionLabel: result.selectionLabel,
      sourceNotes: [...result.sourceNotes, ...remote.sourceNotes],
      contextPageNumber: page,
      contextScopeKey: scope,
    );
  }

  Future<void> saveAiStudyResultAsNote(QuranAiToolResult result) async {
    final page = result.contextPageNumber;
    final scope = '${_preferences.profileId}|$_annotationKey';
    if (page == null || page != _currentPageNumber ||
        result.contextScopeKey != scope || _isDisposed) {
      throw StateError('Return to the original reading page and edition before saving this study.');
    }
    final block = StringBuffer()
      ..writeln('[AI study: ${result.tool.title}]')
      ..writeln(result.selectionLabel)
      ..writeln(result.output);
    for (final verse in result.canonicalVerses) {
      block..writeln('\n${verse.verseKey} - ${verse.chapterName}')
        ..writeln(verse.arabic)
        ..writeln(verse.translationFor(_aiSettings.responseLanguage));
    }
    for (final day in result.revisionDays) {
      block.writeln('Day ${day.day} (${day.minutes} min): '
          'Study ${day.learnReferences.join(', ')}; review ${day.reviewReferences.join(', ')}');
    }
    if (result.textComparison case final comparison?) {
      block..writeln('\nTyped recall: ${comparison.recalled}')
        ..writeln('Missing words: ${comparison.missingWords.join(' ')}')
        ..writeln('Extra words: ${comparison.extraWords.join(' ')}');
    }
    block.writeln(result.sourceNotes.join('\n'));
    final text = block.toString().trim();
    await saveRestorePoint('Before adding AI study note');
    if (_isDisposed || page != _currentPageNumber ||
        scope != '${_preferences.profileId}|$_annotationKey') {
      throw StateError('The reading context changed. Run the study again before saving.');
    }
    final next = Map<int, String>.from(_editionPageNotes[_annotationKey] ?? {});
    final previous = next[page] ?? '';
    if (previous.contains(text)) return;
    next[page] = previous.trim().isEmpty ? text : '${previous.trimRight()}\n\n$text';
    _pageNotes = next;
    _editionPageNotes[_annotationKey] = next;
    _publishContentChange();
    _scheduleNotesPersistence();
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
    if (spread.leftPage.number == 0) return 'Page ${spread.rightPage.number}';
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

  Future<void> togglePageNightMode(bool enabled) async {
    if (_settings.pageNightMode == enabled) {
      return;
    }
    await _commitSettingsUpdate(
      _settings.copyWith(pageNightMode: enabled),
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
    _smartHifzScanPageNumber = _settings.preferImageMode && edition == _settings.mushafEdition
        ? _currentPageNumber : null;
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
    _smartHifzScanPageNumber = _settings.preferImageMode && edition == _settings.mushafEdition
        ? _currentPageNumber : null;
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
    _smartHifzScanPageNumber = null;
    _smartHifzEdition = null;
    _smartHifzLineCount = null;
    _smartHifzRevealed = false;
    _publishViewportChange();
    notifyListeners();
  }

  Future<void> _mushafEditionChanges = Future<void>.value();

  Future<void> selectMushafEdition(MushafEdition edition) {
    final context = _syncContextGeneration;
    final operation = _mushafEditionChanges.then<void>((_) async {
      if (_isDisposed || context != _syncContextGeneration) return;
      await _selectMushafEdition(edition);
    });
    _mushafEditionChanges = operation.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return operation;
  }

  Future<void> _selectMushafEdition(MushafEdition edition) async {
    final context = _syncContextGeneration;
    if (!_repository.hasAssetsForEdition(edition)) {
      return;
    }

    const nextPreferImageMode = true;

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
    await _repository.setMushafEdition(edition);
    if (_isDisposed) return;
    if (context != _syncContextGeneration) {
      await _repository.setMushafEdition(_settings.mushafEdition);
      return;
    }
    _settings = _settings.copyWith(
      mushafEdition: edition,
      preferImageMode: nextPreferImageMode,
    );
    _markReaderSyncDirty();
    _activateEditionAnnotations();
    _rebuildContentCaches();
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
    if (!enabled || _settings.preferImageMode) {
      return;
    }
    final standardPage = currentStandardPageNumber;
    _settings = _settings.copyWith(preferImageMode: enabled);
    _activateEditionAnnotations();
    _rebuildContentCaches();
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
    final page = _currentPageNumber;
    final annotationKey = _annotationKey;
    if ((_pageNotes[page] ?? '') != trimmed) {
      await saveRestorePoint('Before changing note');
    }
    if (_isDisposed) return;
    final nextNotes = Map<int, String>.from(_editionPageNotes[annotationKey] ?? {});
    if (trimmed.isEmpty) {
      nextNotes.remove(page);
    } else {
      nextNotes[page] = trimmed;
    }
    if (_annotationKey == annotationKey) _pageNotes = nextNotes;
    _editionPageNotes[annotationKey] = nextNotes;
    _publishContentChange();
    _scheduleNotesPersistence();
  }

  Future<void> toggleFavoritePage([int? pageNumber]) async {
    final targetPage = pageNumber ?? _currentPageNumber;
    final annotationKey = _annotationKey;
    final wasFavorite = _favoritePages.contains(targetPage);
    if (wasFavorite) {
      await saveRestorePoint('Before deleting reader data');
    }
    if (_isDisposed) return;
    final next = List<int>.from(_editionFavoritePages[annotationKey] ?? []);
    if (wasFavorite) {
      next.remove(targetPage);
    } else if (!next.contains(targetPage)) {
      next.add(targetPage);
      next.sort();
    }
    if (_annotationKey == annotationKey) _favoritePages = next;
    _editionFavoritePages[annotationKey] = next;
    _rebuildContentCaches();
    _publishContentChange();
    await _repository.saveFavoritePagesByEdition(_editionFavoritePages);
  }

  Future<void> addBookmark([
    String? label,
    String folder = _defaultBookmarkFolder,
  ]) async {
    final defaultLabel = currentChapterSummary == null
        ? 'Page $_currentPageNumber'
        : '${currentChapterSummary!.nameSimple} • Page $_currentPageNumber';
    final next = List<ReaderBookmark>.from(_bookmarks)
      ..removeWhere((entry) => entry.pageNumber == _currentPageNumber &&
          entry.preferImageMode == _settings.preferImageMode &&
          (!entry.preferImageMode || entry.edition == _settings.mushafEdition))
      ..insert(
        0,
        ReaderBookmark(
          pageNumber: _currentPageNumber,
          edition: _settings.mushafEdition,
          preferImageMode: _settings.preferImageMode,
          label: (label == null || label.trim().isEmpty)
              ? defaultLabel
              : label.trim(),
          folder: folder,
          createdAtIso: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    var currentEditionCount = 0;
    _bookmarks = next.where((entry) => entry.preferImageMode != _settings.preferImageMode ||
        (entry.preferImageMode && entry.edition != _settings.mushafEdition) ||
        currentEditionCount++ < 24).toList(growable: false);
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
    final edition = _settings.mushafEdition;
    final preferImages = _settings.preferImageMode;
    await saveRestorePoint('Before deleting reader data');
    if (_isDisposed) return;
    _bookmarks = _bookmarks
        .where((entry) => entry.pageNumber != pageNumber ||
            entry.preferImageMode != preferImages ||
            (entry.preferImageMode && entry.edition != edition))
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
    return const JsonEncoder.withIndent('  ').convert({
      ..._buildSyncSnapshot().toJson(),
      'formatVersion': 2,
      'exportedAtIso': DateTime.now().toUtc().toIso8601String(),
      'currentPageNumber': _currentPageNumber,
    });
  }

  ReaderSyncSnapshot _validatedReaderBackup(String source, {String? deviceId}) {
    if (source.length > 10000000) throw const FormatException('Backup is too large.');
    final decoded = json.decode(source);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Backup must be a JSON object.');
    final data = decoded;
    Never invalid(String field) => throw FormatException('Invalid backup field: $field');
    Map<String, dynamic> object(Object? value, String field) {
      if (value is! Map<String, dynamic>) invalid(field);
      return value;
    }
    List<dynamic> array(Object? value, String field) {
      if (value is! List<dynamic>) invalid(field);
      return value;
    }
    void number(Object? value, String field, num min, num max, {bool integer = true}) {
      if (value is! num || !value.isFinite || value < min || value > max ||
          (integer && value % 1 != 0)) {
        invalid(field);
      }
    }
    void date(Object? value, String field, {bool allowEmpty = false}) {
      if (value is! String || (!allowEmpty || value.isNotEmpty) && DateTime.tryParse(value) == null) invalid(field);
    }
    void edition(Object? value, String field) {
      if (value is! String || !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(value)) invalid(field);
    }
    void notes(Object? value, String field) {
      for (final entry in object(value, field).entries) {
        final page = int.tryParse(entry.key);
        if (page == null) invalid(field);
        number(page, field, 1, 10000);
        if (entry.value is! String) invalid(field);
      }
    }
    void favorites(Object? value, String field) {
      for (final page in array(value, field)) {
        number(page, field, 1, 10000);
      }
    }
    if (!data.containsKey('settings') ||
        (!data.containsKey('currentPageNumber') && !data.containsKey('lastPageNumber'))) {
      throw const FormatException('This is not a Quran Reader backup.');
    }
    if (data.containsKey('formatVersion')) number(data['formatVersion'], 'formatVersion', 1, 2);
    final settings = object(data['settings'], 'settings');
    edition(settings['mushafEdition'], 'settings.mushafEdition');
    for (final key in ['fullscreenReading', 'showPageNumbers', 'preferImageMode',
      'customBrightnessEnabled', 'nightMode', 'pageNightMode', 'pagePresetEnabled',
      'pageOverlayEnabled', 'pageReflectionEnabled', 'lowMemoryMode',
      'hifzFocusMode', 'hifzRevealOnHold']) {
      if (settings.containsKey(key) && settings[key] is! bool) invalid('settings.$key');
    }
    if (settings.containsKey('pageBrightness')) number(settings['pageBrightness'], 'settings.pageBrightness', .7, 1.25, integer: false);
    if (settings.containsKey('hifzMaskHeightFactor')) number(settings['hifzMaskHeightFactor'], 'settings.hifzMaskHeightFactor', .18, .7, integer: false);
    if (settings.containsKey('pagePreset') && !PagePreset.values.any((preset) => preset.storageValue == settings['pagePreset'])) invalid('settings.pagePreset');
    if (data.containsKey('currentPageNumber')) number(data['currentPageNumber'], 'currentPageNumber', 1, 10000);
    if (data.containsKey('aiSettings')) {
      final ai = object(data['aiSettings'], 'aiSettings');
      if (ai.containsKey('responseLanguage') && !AiResponseLanguage.values.any((value) => value.storageValue == ai['responseLanguage'])) invalid('aiSettings.responseLanguage');
      if (ai.containsKey('responseDepth') && !AiResponseDepth.values.any((value) => value.storageValue == ai['responseDepth'])) invalid('aiSettings.responseDepth');
    }
    final page = data['lastPageNumber'] ?? data['currentPageNumber'];
    number(page, 'lastPageNumber', 1, 10000);
    if (data.containsKey('pageNotes')) notes(data['pageNotes'], 'pageNotes');
    if (data.containsKey('favoritePages')) favorites(data['favoritePages'], 'favoritePages');
    for (final key in ['editionPageNotes', 'editionFavoritePages']) {
      if (!data.containsKey(key)) continue;
      for (final entry in object(data[key], key).entries) {
        if (entry.key != '__canonical_text__') edition(entry.key, key);
        if (key == 'editionPageNotes') {
          notes(entry.value, key);
        } else {
          favorites(entry.value, key);
        }
      }
    }
    for (final key in ['bookmarks', 'readingHistory', 'hifzReviewEntries', 'hifzRevisionEntries']) {
      if (!data.containsKey(key)) continue;
      for (final item in array(data[key], key)) {
        final record = object(item, key);
        number(record['pageNumber'], '$key.pageNumber', 1, 10000);
        if (record.containsKey('edition')) edition(record['edition'], '$key.edition');
        if (record.containsKey('preferImageMode') && record['preferImageMode'] is! bool) invalid(key);
        if (key == 'bookmarks') {
          if (record['label'] is! String || record.containsKey('folder') && record['folder'] is! String) invalid(key);
          date(record['createdAtIso'], '$key.createdAtIso');
        } else if (key == 'readingHistory') {
          date(record['viewedAtIso'], '$key.viewedAtIso');
        } else {
          if (!HifzPageStrength.values.any((strength) => strength.storageValue == record['strength'])) invalid(key);
          date(record['updatedAtIso'], '$key.updatedAtIso', allowEmpty: true);
          number(record['reviewCount'], '$key.reviewCount', 0, 1000000);
        }
      }
    }
    if (data.containsKey('dailyTargetPages')) number(data['dailyTargetPages'], 'dailyTargetPages', 1, 40);
    if (data.containsKey('readingPlan')) {
      final plan = object(data['readingPlan'], 'readingPlan');
      if (!ReadingGoalPreset.values.any((preset) => preset.storageValue == plan['preset'])) invalid('readingPlan.preset');
      number(plan['targetDays'], 'readingPlan.targetDays', 1, 365);
      number(plan['customPagesPerDay'], 'readingPlan.customPagesPerDay', 1, 40);
      date(plan['createdAtIso'], 'readingPlan.createdAtIso', allowEmpty: true);
    }
    if (data.containsKey('dailyProgressState')) {
      final progress = object(data['dailyProgressState'], 'dailyProgressState');
      date(progress['dateKey'], 'dailyProgressState.dateKey', allowEmpty: true);
      number(progress['startPage'], 'dailyProgressState.startPage', 1, 10000);
    }
    if (data.containsKey('readingStreak')) {
      final streak = object(data['readingStreak'], 'readingStreak');
      number(streak['count'], 'readingStreak.count', 0, 1000000);
      if (streak['lastDateKey'] != null) date(streak['lastDateKey'], 'readingStreak.lastDateKey');
    }
    if (data.containsKey('audio')) {
      final audio = object(data['audio'], 'audio');
      for (final key in ['chapterId', 'reciterId']) {
        if (audio[key] != null) number(audio[key], 'audio.$key', 1, key == 'chapterId' ? 114 : 100000);
      }
      number(audio['positionMillis'], 'audio.positionMillis', 0, 0x80000000);
      if (audio['repeatEnabled'] is! bool) invalid('audio.repeatEnabled');
    }
    if (data.containsKey('experienceSettings')) {
      final experience = object(data['experienceSettings'], 'experienceSettings');
      for (final key in ['largerTextMode', 'highContrastMode', 'reducedMotion',
        'tajweedMode', 'recitationSyncEnabled']) {
        if (experience.containsKey(key) && experience[key] is! bool) invalid('experienceSettings.$key');
      }
      if (experience.containsKey('syncMode') && !ReaderSyncMode.values.any((mode) => mode.storageValue == experience['syncMode'])) invalid('experienceSettings.syncMode');
    }
    final current = _buildSyncSnapshot().toJson();
    final editionKey = settings['preferImageMode'] == false
        ? '__canonical_text__' : settings['mushafEdition'] as String;
    final merged = <String, dynamic>{
      ...current,
      ...data,
      'deviceId': deviceId ?? _syncClientId,
      'lastPageNumber': page,
      'settings': {...current['settings'] as Map<String, dynamic>, ...settings},
      'editionPageNotes': data['editionPageNotes'] ?? {
        ...current['editionPageNotes'] as Map<String, dynamic>,
        if (data.containsKey('pageNotes')) editionKey: data['pageNotes'],
      },
      'editionFavoritePages': data['editionFavoritePages'] ?? {
        ...current['editionFavoritePages'] as Map<String, dynamic>,
        if (data.containsKey('favoritePages')) editionKey: data['favoritePages'],
      },
    };
    final ReaderSyncSnapshot snapshot;
    try {
      final parsed = ReaderSyncSnapshot.fromJson(merged);
      if (parsed == null) invalid('snapshot');
      snapshot = parsed;
    } catch (_) {
      throw const FormatException('Backup contains invalid reader data.');
    }
    final maximum = _repository.hasAssetsForEdition(snapshot.settings.mushafEdition)
        ? _repository.totalPagesForEdition(snapshot.settings.mushafEdition) : 10000;
    number(snapshot.lastPageNumber, 'lastPageNumber', 1, snapshot.settings.preferImageMode ? maximum : 604);
    return snapshot;
  }

  Future<void> restoreStateBackupJson(String source) async {
    final snapshot = _validatedReaderBackup(source);
    final previous = _buildSyncSnapshot();
    final initialContext = _syncContextGeneration;
    final generation = _localChangeGeneration;
    await saveRestorePoint('Before restoring backup', force: true);
    if (_isDisposed || initialContext != _syncContextGeneration || generation != _localChangeGeneration) {
      throw StateError('Reader state changed while the backup was being restored. Try again.');
    }
    _backupHistoryTimer?.cancel();
    _pagePersistenceTimer?.cancel();
    _notesPersistenceTimer?.cancel();
    _cloudSyncTimer?.cancel();
    _invalidateReaderSyncContext();
    final context = _syncContextGeneration;
    try {
      final applied = await _applyRemoteSyncSnapshot(snapshot,
          syncContext: context, expectedGeneration: generation, requireCloud: false);
      if (!applied) throw StateError('Reader state changed while the backup was being restored. Try again.');
    } catch (_) {
      if (!_isDisposed && context == _syncContextGeneration && generation == _localChangeGeneration) {
        try {
          await _applyRemoteSyncSnapshot(previous,
              syncContext: context, expectedGeneration: generation, requireCloud: false,
              createRestorePoint: false);
        } catch (_) { /* The previous in-memory state remains usable if storage is unavailable. */ }
      }
      rethrow;
    }
    _scheduleCloudSyncPush();
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
    if (_audioState.selectedReciter?.id == reciter.id) return;
    final wasPlaying = _audioState.isPlaying;
    final generation = ++_audioLoadGeneration;
    _audioService.cancelPendingLoad();
    await _audioService.practice.cancel();
    if (_isDisposed || generation != _audioLoadGeneration) return;
    _currentRecitationVerseKey = null;
    _setAudioState(_audioState.copyWith(selectedReciter: reciter, isLoading: false, isBuffering: false));
    _markReaderSyncDirty();
    await _repository.savePreferredReciterId(reciter.id);
    _scheduleCloudSyncPush();
    if (!_isDisposed && generation == _audioLoadGeneration && wasPlaying && selectedAudioChapter != null) {
      await playSelectedSurah(forceReload: true);
    }
  }

  Future<void> selectAudioChapter(QuranChapterSummary chapter) async {
    final selectedId = _audioState.currentChapterId;
    if (selectedId == chapter.id &&
        _audioState.currentSurahName == chapter.nameSimple) {
      return;
    }

    ++_audioLoadGeneration;
    await _audioService.practice.cancel();
    _currentRecitationVerseKey = null;
    _savedAudioPositionMillis = 0;
    _markReaderSyncDirty();
    await _audioService.resetPlayback();

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

    final isSameChapter = _audioService.loadedChapterId == chapter.id &&
        _audioService.loadedReciterId == reciter.id;
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

    final request = ++_audioLoadGeneration;
    _currentRecitationVerseKey = null;
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
      if (_isDisposed || request != _audioLoadGeneration ||
          _audioState.currentChapterId != chapter.id || _audioState.selectedReciter?.id != reciter.id) return;
      final loaded = _audioService.loadedChapterId == chapter.id && _audioService.loadedReciterId == reciter.id;
      _setAudioState(
        _audioState.copyWith(
          isLoading: false,
          isBuffering: false,
          isDownloading: false,
          isPlaying: loaded && _audioService.isPlaying,
          clearError: true,
        ),
      );
      if (loaded) await _repository.saveAudioChapterId(chapter.id);
      _scheduleCloudSyncPush();
    } catch (error) {
      if (_isDisposed || request != _audioLoadGeneration) return;
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
    ++_audioLoadGeneration;
    await _audioService.pause();
    await _persistAudioState();
    _setAudioState(
      _audioState.copyWith(
        isPlaying: false,
        isLoading: false,
        isBuffering: false,
        clearError: true,
      ),
    );
  }

  Future<void> resumeAudio() async {
    if (_audioService.isPlaybackCompleted) {
      _savedAudioPositionMillis = 0;
      _currentRecitationVerseKey = null;
      _setAudioState(_audioState.copyWith(positionMillis: 0));
      _markReaderSyncDirty();
      await _repository.saveAudioPositionMillis(0);
    }
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
    ++_audioLoadGeneration;
    _currentRecitationVerseKey = null;
    _savedAudioPositionMillis = 0;
    _markReaderSyncDirty();
    await _audioService.resetPlayback();
    await _repository.saveAudioPositionMillis(0);
    _scheduleCloudSyncPush();
    _setAudioState(
      _audioState.copyWith(
        isPlaying: false,
        isLoading: false,
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
    _markReaderSyncDirty();
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
    _scheduleCloudSyncPush();
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

  void _publishContentChange({bool localChange = true}) {
    if (_isDisposed) {
      return;
    }
    _contentNotifier.value = _contentNotifier.value + 1;
    _scheduleCloudSyncPush(markDirty: localChange);
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
      unawaited(_repository.savePageNotesByEdition(_editionPageNotes));
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
    _playbackErrorSubscription?.cancel();

    _playerStateSubscription = _audioService.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.idle ||
          state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.completed) {
        _currentRecitationVerseKey = null;
      }
      final nextState = _audioState.copyWith(
        isPlaying: state.playing && state.processingState != ProcessingState.completed,
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

    _playbackErrorSubscription = _audioService.playbackErrors.listen((error) {
      if (_isDisposed) return;
      _currentRecitationVerseKey = null;
      _setAudioState(_audioState.copyWith(
        isPlaying: false, isLoading: false, isBuffering: false, errorMessage: error,
      ));
    });

    _positionSubscription = _audioService.positionStream.listen((position) {
      final millis = position.inMilliseconds;
      if (millis != _savedAudioPositionMillis &&
          (!_readerSyncDirty || _syncPushGeneration == _localChangeGeneration)) {
        _markReaderSyncDirty();
      }
      _savedAudioPositionMillis = millis;
      _audioState = _audioState.copyWith(positionMillis: millis);
      if (_experienceSettings.recitationSyncEnabled && _audioState.isPlaying) {
        final verseKey = _audioService.verseKeyAtPosition(position);
        if (verseKey != _currentRecitationVerseKey) {
          _currentRecitationVerseKey = verseKey;
          if (verseKey != null && !isStudySurahScoped) {
            final page = _repository.canonicalPageForVerse(verseKey);
            if (page != null && page != _currentPageNumber) unawaited(jumpToPage(page));
          }
          _publishAudioState();
        }
      }

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
      _markReaderSyncDirty();
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
        _lastRecordedHistoryEdition == _settings.mushafEdition &&
        _lastRecordedHistoryPreferImageMode == _settings.preferImageMode &&
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
        edition: _settings.mushafEdition,
        preferImageMode: _settings.preferImageMode,
        viewedAtIso: now.toUtc().toIso8601String(),
      ),
      ..._readingHistory
          .where((entry) => entry.pageNumber != _currentPageNumber ||
              entry.preferImageMode != _settings.preferImageMode ||
              (entry.preferImageMode && entry.edition != _settings.mushafEdition) ||
              _dateKeyFromIso(entry.viewedAtIso) != todayKey),
    ];
    _readingHistory = nextHistory;
    _markReaderSyncDirty();
    _rebuildContentCaches();
    _lastRecordedHistoryPageNumber = _currentPageNumber;
    _lastRecordedHistoryDateKey = todayKey;
    _lastRecordedHistoryEdition = _settings.mushafEdition;
    _lastRecordedHistoryPreferImageMode = _settings.preferImageMode;
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
      final difference = last == null ? 999 : DateTime.utc(today.year, today.month, today.day)
          .difference(DateTime.utc(last.year, last.month, last.day)).inDays;
      if (difference == 1) {
        _readingStreakCount += 1;
      } else if (difference == 0) {
        return;
      } else {
        _readingStreakCount = 1;
      }
    }

    _readingStreakLastDate = todayKey;
    _markReaderSyncDirty();
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
      _publishContentChange(localChange: false);
      _setAudioState(
        _audioState.copyWith(
          selectedReciter: _resolveSelectedReciter(selectedReciterId),
        ),
      );
    } catch (_) {
      // Reader should stay usable even if audio metadata cannot be warmed.
    }
  }

  Future<QuranAiPageContext> _buildCurrentAiPageContext({
    bool forSearch = false,
  }) async {
    final standardPage = currentStandardPageNumber;
    if (forSearch) {
      return QuranAiPageContext(
        pageNumber: _currentPageNumber,
        standardPageNumber: standardPage,
        pageReference: buildCurrentPageReference(),
        mushafEditionLabel: _settings.mushafEdition.label,
        chapterName: null,
        chapterSummary: '',
        chapterInfo: '',
        tafsirExcerpt: '',
        translationUr: '',
        translationEn: '',
        arabicLines: const [],
        verseKeys: const [],
        notes: '',
        dailyProgressSummary: '',
      );
    }
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
      arabicLines: (isStudySurahScoped ? const <QuranPageLine>[] : textPage.lines)
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
    _backupHistoryTimer?.cancel();
    for (final token in _offlinePackCancelTokens.values) {
      if (!token.isCancelled) token.cancel(QuranPackDownloadStop.pause);
    }
    _downloadNetworkSubscription?.cancel();
    _invalidateReaderSyncContext();
    _controlsTimer?.cancel();
    _pagePersistenceTimer?.cancel();
    _pageUiRefreshTimer?.cancel();
    _cloudSyncTimer?.cancel();
    final shouldFlushNotes = _notesPersistenceTimer?.isActive ?? false;
    _notesPersistenceTimer?.cancel();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playbackErrorSubscription?.cancel();
    unawaited(_persistAudioState());
    if (shouldFlushNotes) {
      unawaited(_repository.savePageNotesByEdition(_editionPageNotes));
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
    _readerAccountService.dispose();
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

  void _activateEditionAnnotations() {
    final key = _annotationKey;
    _pageNotes = _editionPageNotes[key] ?? const {};
    _favoritePages = _editionFavoritePages[key] ?? const [];
  }

  void _rebuildContentCaches() {
    _favoritePageSet = _favoritePages.toSet();

    final bookmarkFolders = <String>{
      ..._bookmarkFolderPresets,
      ...bookmarks.map((bookmark) => bookmark.folder),
    }.toList(growable: false);
    _bookmarkFoldersCache = bookmarkFolders;

    final bookmarkByPage = <int, ReaderBookmark>{};
    final groupedBookmarks = <String, List<ReaderBookmark>>{};
    for (final folder in bookmarkFolders) {
      groupedBookmarks[folder] = <ReaderBookmark>[];
    }
    for (final bookmark in bookmarks) {
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
    final adminDefaultSettings =
        await _repository.applyAdminReaderDefaults(_settings);
    if (adminDefaultSettings != _settings) {
      _settings = adminDefaultSettings;
      _publishSettings();
    }
    _zipAssetPacks =
        await _repository.fetchAvailableZipPacks(forceRefresh: true);
    _syncCurrentAiSettingsWithAdminConfig();
    await _refreshOfflinePackAvailability();
    await _applyAdminEditionVisibilityRules();
    _rebuildNavigationCaches();
    _refreshCurrentCaches();
    _publishContentChange();
    _warmSupplementalContentInBackground(forceRefresh: true);
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  bool _readerSyncContextIsCurrent(int context, {bool requireCloud = true}) {
    if (_isDisposed || _readerAccountBusy || context != _syncContextGeneration || _syncBaseUrl.isEmpty ||
        _syncClientId.isEmpty || _syncToken.isEmpty ||
        (requireCloud && _experienceSettings.syncMode != ReaderSyncMode.cloudReady)) {
      return false;
    }
    try {
      return ReaderPreferences.normalizeSyncBaseUrl(adminSyncBaseUrl) == _syncBaseUrl;
    } catch (_) {
      return false;
    }
  }

  void _invalidateReaderSyncContext() {
    _syncContextGeneration++;
    _cloudSyncTimer?.cancel();
    _readerSyncService.cancelPending();
    _readerAccountService.cancelPending();
  }

  Future<void> _persistReaderSyncLocalState() {
    final baseUrl = _syncBaseUrl;
    if (baseUrl.isEmpty) return Future<void>.value();
    final context = _syncContextGeneration;
    final generation = _localChangeGeneration;
    final dirty = _readerSyncDirty;
    _syncStateWrites = _syncStateWrites.then((_) async {
      try {
        await _preferences.saveReaderSyncLocalState(baseUrl, generation: generation, dirty: dirty);
        if (context == _syncContextGeneration) _syncStateWriteFailed = false;
      } catch (_) {
        if (context == _syncContextGeneration) {
          _syncStateWriteFailed = true;
          _readerSyncStatus = 'Local sync state could not be saved. Cloud sync is paused.';
        }
      }
    });
    return _syncStateWrites;
  }

  void _markReaderSyncDirty() {
    if (_isDisposed || _isLoading || _suppressSyncDirty) return;
    _scheduleRestorePoint();
    _localChangeGeneration++;
    _readerSyncDirty = true;
    unawaited(_persistReaderSyncLocalState());
  }

  Future<bool> _bindReaderSyncIdentity() async {
    if (_readerAccountBusy) return false;
    final rawBase = adminSyncBaseUrl.trim();
    if (rawBase.isEmpty) {
      _invalidateReaderSyncContext();
      _syncBaseUrl = '';
      _syncClientId = '';
      _syncToken = '';
      return false;
    }
    final String normalized;
    try {
      normalized = ReaderPreferences.normalizeSyncBaseUrl(rawBase);
    } catch (_) {
      _invalidateReaderSyncContext();
      _syncBaseUrl = '';
      _syncClientId = '';
      _syncToken = '';
      _readerSyncStatus = 'The reader sync URL is invalid.';
      return false;
    }
    if (_syncBaseUrl == normalized && _syncToken.isNotEmpty) return true;
    final pending = _syncIdentityBinding;
    if (pending != null && _syncBindingBaseUrl == normalized &&
        _syncBindingContext == _syncContextGeneration) {
      return pending;
    }
    final previousBase = _syncBaseUrl;
    final generationBeforeBinding = _localChangeGeneration;
    _invalidateReaderSyncContext();
    final context = _syncContextGeneration;
    _syncBindingBaseUrl = normalized;
    _syncBindingContext = context;
    final operation = () async {
      await _syncStateWrites;
      if (_isDisposed || context != _syncContextGeneration) return false;
      final identity = await _preferences.loadOrCreateSyncIdentity(normalized);
      if (_isDisposed || context != _syncContextGeneration) return false;
      final state = await _preferences.loadReaderSyncLocalState(normalized);
      if (_isDisposed || context != _syncContextGeneration) return false;
      final revision = await _preferences.loadReaderSyncRevision(normalized, identity);
      if (_isDisposed || context != _syncContextGeneration) return false;
      _syncBaseUrl = normalized;
      _syncClientId = identity.deviceId;
      _syncToken = identity.token;
      _readerSyncRevision = revision;
      _readerSyncConflict = false;
      _syncUsesFreshBackup = state == null;
      final changedWhileBinding = generationBeforeBinding != _localChangeGeneration;
      final changedBackend = previousBase.isNotEmpty && previousBase != normalized;
      _localChangeGeneration = (state?.generation ?? 0) +
          (changedWhileBinding || changedBackend ? 1 : 0);
      _readerSyncDirty = changedWhileBinding || changedBackend || (state?.dirty ?? true);
      _syncStateWriteFailed = false;
      await _persistReaderSyncLocalState();
      return !_isDisposed && context == _syncContextGeneration && !_syncStateWriteFailed;
    }();
    _syncIdentityBinding = operation;
    try {
      return await operation;
    } catch (_) {
      if (!_isDisposed && context == _syncContextGeneration) {
        _readerSyncStatus = 'Cloud sync could not load its private identity. Local data is unchanged.';
      }
      return false;
    } finally {
      if (identical(_syncIdentityBinding, operation)) _syncIdentityBinding = null;
    }
  }

  Future<bool> _queueReaderSync(int context, Future<bool> Function() operation) {
    final result = Completer<bool>();
    _syncOperationQueue = _syncOperationQueue.then((_) async {
      if (!_readerSyncContextIsCurrent(context)) {
        result.complete(false);
        return;
      }
      try {
        result.complete(await operation());
      } catch (_) {
        if (_readerSyncContextIsCurrent(context)) {
          _readerSyncStatus = 'Cloud sync failed. Unsynced changes remain on this device.';
        }
        result.complete(false);
      }
    });
    return result.future;
  }

  void _reportReaderSyncFailure(ReaderSyncStatus status) {
    if (status == ReaderSyncStatus.conflict) _readerSyncConflict = true;
    _readerSyncStatus = switch (status) {
      ReaderSyncStatus.conflict =>
        'Cloud data changed on another device. Your local changes are safe. Export a backup, then sign in or pair again to review the cloud copy.',
      ReaderSyncStatus.unauthorized || ReaderSyncStatus.forbidden =>
        'Cloud sync was not authorized. Local data is unchanged.',
      ReaderSyncStatus.cancelled => 'Cloud sync was cancelled.',
      ReaderSyncStatus.networkError => 'Cloud sync is unavailable. Changes remain on this device.',
      _ => 'The cloud sync response was invalid. Local data is unchanged.',
    };
    if (!_isDisposed) notifyListeners();
  }

  Future<bool> _pushReaderSnapshot(int context) async {
    if (!_readerSyncContextIsCurrent(context)) return false;
    if (_readerSyncConflict) {
      _reportReaderSyncFailure(ReaderSyncStatus.conflict);
      return false;
    }
    await _persistReaderSyncLocalState();
    if (!_readerSyncContextIsCurrent(context) || _syncStateWriteFailed) return false;
    final generation = _localChangeGeneration;
    final snapshot = _buildSyncSnapshot();
    _syncPushGeneration = generation;
    final ReaderSyncPushResult result;
    try {
      result = await _readerSyncService.pushSnapshot(
        baseUrl: _syncBaseUrl,
        deviceId: _syncClientId,
        token: _syncToken,
        snapshot: snapshot,
        baseRevision: _readerSyncRevision,
      );
    } finally {
      _syncPushGeneration = null;
    }
    if (!_readerSyncContextIsCurrent(context)) return false;
    if (!result.success) {
      _reportReaderSyncFailure(result.status);
      return false;
    }
    if (!await _acknowledgeReaderSyncRevision(result.syncRevision, context)) return false;
    if (generation == _localChangeGeneration) {
      _readerSyncDirty = false;
      await _persistReaderSyncLocalState();
      if (!_readerSyncContextIsCurrent(context) || _syncStateWriteFailed) return false;
    }
    _readerSyncStatus = _readerSyncDirty ? 'Newer changes are waiting to sync.'
        : _syncUsesFreshBackup
            ? 'Synced to a new private backup. Older backups remain in admin restore.'
            : 'Reader data is synced.';
    if (!_isDisposed) notifyListeners();
    return true;
  }

  Future<bool> pushReaderSyncToCloud() async {
    if (_experienceSettings.syncMode != ReaderSyncMode.cloudReady) return false;
    final ready = await _bindReaderSyncIdentity();
    if (!ready || _experienceSettings.syncMode != ReaderSyncMode.cloudReady) return false;
    final context = _syncContextGeneration;
    return _queueReaderSync(context, () => _pushReaderSnapshot(context));
  }

  Future<bool> _pullReaderSnapshot(int context, {required bool seedWhenMissing}) async {
    await _syncStateWrites;
    if (!_readerSyncContextIsCurrent(context) || _syncStateWriteFailed) return false;
    if (_readerSyncDirty) {
      if (seedWhenMissing) return _pushReaderSnapshot(context);
      _readerSyncStatus = 'Unsynced local changes were kept. Sync them before pulling a backup.';
      return false;
    }
    final generation = _localChangeGeneration;
    final result = await _readerSyncService.pullSnapshot(
      baseUrl: _syncBaseUrl,
      deviceId: _syncClientId,
      token: _syncToken,
    );
    if (!_readerSyncContextIsCurrent(context) || generation != _localChangeGeneration) return false;
    if (result.found) {
      final applied = await _applyRemoteSyncSnapshot(
        result.snapshot!, syncContext: context, expectedGeneration: generation,
      );
      if (!applied || !_readerSyncContextIsCurrent(context) ||
          generation != _localChangeGeneration) {
        return false;
      }
      if (!await _acknowledgeReaderSyncRevision(result.syncRevision, context)) return false;
      _readerSyncDirty = false;
      await _persistReaderSyncLocalState();
      if (!_readerSyncContextIsCurrent(context)) return false;
      _readerSyncStatus = 'Reader data is synced.';
      return true;
    }
    if (result.status == ReaderSyncStatus.notFound && seedWhenMissing) {
      if (!await _acknowledgeReaderSyncRevision(result.syncRevision, context)) return false;
      return _pushReaderSnapshot(context);
    }
    _reportReaderSyncFailure(result.status);
    return false;
  }

  Future<bool> pullReaderSyncFromCloud() async {
    if (_experienceSettings.syncMode != ReaderSyncMode.cloudReady) return false;
    final ready = await _bindReaderSyncIdentity();
    if (!ready || _experienceSettings.syncMode != ReaderSyncMode.cloudReady) return false;
    final context = _syncContextGeneration;
    return _queueReaderSync(context, () => _pullReaderSnapshot(context, seedWhenMissing: false));
  }

  Future<bool> _acknowledgeReaderSyncRevision(int? revision, int context, {bool forAccount = false}) async {
    bool current() => forAccount
        ? !_isDisposed && _readerAccountBusy && context == _syncContextGeneration &&
            _syncBaseUrl == ReaderPreferences.normalizeSyncBaseUrl(adminSyncBaseUrl)
        : _readerSyncContextIsCurrent(context);
    if (!current()) return false;
    if (revision == null) return true;
    final identity = ReaderSyncIdentity(deviceId: _syncClientId, token: _syncToken);
    try {
      await _preferences.saveReaderSyncRevision(_syncBaseUrl, identity, revision);
    } catch (_) {
      if (current()) {
        _syncStateWriteFailed = true;
        _readerSyncDirty = true;
        _readerSyncStatus = 'Local sync state could not be saved. Cloud sync is paused.';
        notifyListeners();
      }
      return false;
    }
    if (!current()) return false;
    _readerSyncRevision = revision;
    _readerSyncConflict = false;
    return true;
  }

  Future<void> saveAdminSyncBaseUrl(String baseUrl) async {
    _invalidateReaderSyncContext();
    final context = _syncContextGeneration;
    await _syncStateWrites;
    if (_isDisposed || context != _syncContextGeneration) return;
    await _preferences.saveAdminPublicBaseUrl(baseUrl);
    if (_isDisposed || context != _syncContextGeneration) return;
    await refreshAdminSync();
    if (_isDisposed) return;
    final ready = await _bindReaderSyncIdentity();
    if (!ready) return;
    _markReaderSyncDirty();
    _scheduleCloudSyncPush(markDirty: false);
  }

  Future<ReaderSyncIdentity> readerIdentityForFeature() async {
    if (_readerAccountBusy || !await _bindReaderSyncIdentity()) {
      throw const ReaderAccountFailure('Reader identity is unavailable. Try again.');
    }
    return ReaderSyncIdentity(deviceId: _syncClientId, token: _syncToken);
  }

  Future<void> refreshReaderAccountStatus() async {
    final identity = await readerIdentityForFeature();
    final base = _syncBaseUrl;
    final context = _syncContextGeneration;
    final status = await _readerAccountService.status(base, identity);
    if (!_isDisposed && context == _syncContextGeneration && base == _syncBaseUrl) {
      _readerAccountEmail = status.email;
      notifyListeners();
    }
  }

  Future<({int context, int generation, String baseUrl, ReaderSyncIdentity identity})>
      _beginReaderAccountTransition() async {
    if (_readerAccountBusy) throw const ReaderAccountFailure('An account request is already in progress.');
    final identity = await readerIdentityForFeature();
    if (_readerAccountBusy || _isDisposed) throw const ReaderAccountFailure('Account request was cancelled.');
    ensureReaderBrowserRemindersIdle(_syncBaseUrl);
    _readerAccountBusy = true;
    _invalidateReaderSyncContext();
    final context = _syncContextGeneration;
    await _syncOperationQueue;
    await _syncStateWrites;
    if (_isDisposed || context != _syncContextGeneration) {
      cancelReaderAccountOperation();
      throw const ReaderAccountFailure('Account request was cancelled.');
    }
    notifyListeners();
    return (context: context, generation: _localChangeGeneration, baseUrl: _syncBaseUrl, identity: identity);
  }

  void _finishReaderAccountTransition() {
    _readerAccountBusy = false;
    _preparedReaderAccount = null;
    if (!_isDisposed) {
      notifyListeners();
      _scheduleCloudSyncPush(markDirty: false);
    }
  }

  void cancelReaderAccountOperation() {
    if (!_readerAccountBusy) return;
    _invalidateReaderSyncContext();
    if (!_readerAccountAdopting) _finishReaderAccountTransition();
  }

  Future<ReaderPreparedAccount> prepareReaderAccount({required String email,
      required String password, bool register = false, String? recoveryKey, String? pairingCode,
      Future<void> Function(String key)? onRecoveryKey}) async {
    final source = await _beginReaderAccountTransition();
    var sourceRevision = _readerSyncRevision;
    bool current() => !_isDisposed && source.context == _syncContextGeneration &&
        source.generation == _localChangeGeneration &&
        ReaderPreferences.normalizeSyncBaseUrl(adminSyncBaseUrl) == source.baseUrl;
    try {
      if (register) {
        final uploaded = await _readerSyncService.pushSnapshot(baseUrl: source.baseUrl,
            deviceId: source.identity.deviceId, token: source.identity.token, snapshot: _buildSyncSnapshot(),
            baseRevision: _readerSyncRevision);
        if (!uploaded.success || !current()) {
          if (current() && uploaded.status == ReaderSyncStatus.conflict) _reportReaderSyncFailure(uploaded.status);
          throw const ReaderAccountFailure('Your reader backup could not be saved. Account creation was stopped.');
        }
        if (!await _acknowledgeReaderSyncRevision(uploaded.syncRevision, source.context, forAccount: true) || !current()) {
          throw const ReaderAccountFailure('Your reader backup could not be saved. Account creation was stopped.');
        }
        sourceRevision = uploaded.syncRevision ?? sourceRevision;
      }
      final ReaderAccountIdentity account;
      if (pairingCode != null) {
        account = await _readerAccountService.redeemPairing(source.baseUrl, pairingCode);
      } else if (register) {
        account = await _readerAccountService.register(source.baseUrl, source.identity, email: email, password: password);
      } else if (recoveryKey != null) {
        account = await _readerAccountService.recover(source.baseUrl, email: email, password: password, recoveryKey: recoveryKey);
      } else {
        account = await _readerAccountService.login(source.baseUrl, email: email, password: password);
      }
      if (register && account.identity.deviceId != source.identity.deviceId) {
        throw const ReaderAccountFailure('The account server returned invalid data. Your local reader is unchanged.');
      }
      final rotatesCurrentIdentity = register ||
          (recoveryKey != null && account.identity.deviceId == source.identity.deviceId);
      if (rotatesCurrentIdentity) {
        if (sourceRevision != null) {
          try {
            await _preferences.saveReaderSyncRevision(source.baseUrl, account.identity, sourceRevision);
          } catch (_) { sourceRevision = null; }
        }
        try {
          await detachReaderBrowserReminders(baseUrl: source.baseUrl, identity: source.identity);
        } catch (_) { /* A rotated credential must survive a reminder cleanup failure. */ }
        var saved = false;
        try {
          await _preferences.saveSyncIdentity(source.baseUrl, account.identity);
          saved = true;
        } catch (_) { /* Keep the response available for a retry after the key is saved. */ }
        final ownsTransition = !_isDisposed && source.context == _syncContextGeneration &&
            _readerAccountBusy && _syncBaseUrl == source.baseUrl &&
            ReaderPreferences.normalizeSyncBaseUrl(adminSyncBaseUrl) == source.baseUrl;
        if (ownsTransition) {
          _syncClientId = account.identity.deviceId;
          _syncToken = account.identity.token;
          _readerSyncRevision = sourceRevision;
          _readerAccountEmail = account.email;
          _readerSyncDirty = register ? source.generation != _localChangeGeneration : _readerSyncDirty;
          await _persistReaderSyncLocalState();
        } else if (!_isDisposed && _syncBaseUrl == source.baseUrl &&
            _syncClientId == source.identity.deviceId && _syncToken == source.identity.token) {
          // Rebind the saved rotated identity on demand; never retain its revoked token.
          _syncToken = '';
        }
        if (account.recoveryKey != null && onRecoveryKey != null) await onRecoveryKey(account.recoveryKey!);
        final prepared = ReaderPreparedAccount._(account: account, baseUrl: source.baseUrl,
            context: _syncContextGeneration, generation: _localChangeGeneration, alreadyConnected: saved);
        if (saved && ownsTransition && source.context == _syncContextGeneration) {
          _readerSyncStatus = 'Reader account connected. The selected backup is ready.';
          _finishReaderAccountTransition();
        } else if (!saved && ownsTransition && source.context == _syncContextGeneration) {
          _preparedReaderAccount = prepared;
        }
        return prepared;
      }
      if (account.recoveryKey != null && onRecoveryKey != null) await onRecoveryKey(account.recoveryKey!);
      if (!current()) throw const ReaderAccountFailure('Reader data changed during the request. Try again.');
      ReaderSyncSnapshot? snapshot;
      int? syncRevision;
      if (!register) {
        final payload = await _readerAccountService.fetchBackup(source.baseUrl, account.identity);
        syncRevision = payload is ReaderAccountBackup ? payload.syncRevision : null;
        if (!current()) throw const ReaderAccountFailure('Reader data changed during the request. Try again.');
        final required = _buildSyncSnapshot().toJson();
        if (required.keys.any((key) => !payload.containsKey(key)) ||
            payload['settings'] is! Map<String, dynamic> ||
            (required['settings'] as Map<String, dynamic>).keys.any((key) => !(payload['settings'] as Map).containsKey(key)) ||
            payload['hifzReviewEntries'] is! List ||
            payload['updatedAtIso'] is! String || DateTime.tryParse(payload['updatedAtIso'] as String) == null) {
          throw const ReaderAccountFailure('The account backup is incomplete. Your local reader is unchanged.');
        }
        snapshot = _validatedReaderBackup(json.encode({
          ...payload, 'hifzRevisionEntries': payload['hifzReviewEntries'],
        }), deviceId: account.identity.deviceId);
      }
      final prepared = ReaderPreparedAccount._(account: account, baseUrl: source.baseUrl,
          context: source.context, generation: source.generation, snapshot: snapshot, syncRevision: syncRevision);
      _preparedReaderAccount = prepared;
      return prepared;
    } catch (error) {
      if (source.context == _syncContextGeneration) _finishReaderAccountTransition();
      if (error is ReaderAccountFailure) rethrow;
      throw const ReaderAccountFailure('The account backup could not be validated. Your local reader is unchanged.');
    }
  }

  Future<void> adoptReaderAccount(ReaderPreparedAccount prepared) async {
    bool owns() => identical(prepared, _preparedReaderAccount) && _readerAccountBusy;
    bool sameContext() => !_isDisposed && prepared.context == _syncContextGeneration &&
        _syncBaseUrl == prepared.baseUrl &&
        ReaderPreferences.normalizeSyncBaseUrl(adminSyncBaseUrl) == prepared.baseUrl;
    var expectedGeneration = prepared.generation;
    bool current() => owns() && sameContext() && expectedGeneration == _localChangeGeneration;
    if (!current()) {
      if (owns()) _finishReaderAccountTransition();
      throw const ReaderAccountFailure('Reader data changed during the request. Try again.');
    }
    final previous = _buildSyncSnapshot();
    final previousIdentity = ReaderSyncIdentity(deviceId: _syncClientId, token: _syncToken);
    final previousEmail = _readerAccountEmail;
    final previousDirty = _readerSyncDirty;
    final previousRevision = _readerSyncRevision;
    final previousConflict = _readerSyncConflict;
    var dataApplied = false;
    var identitySaved = false;
    _readerAccountAdopting = true;
    try {
      await detachReaderBrowserReminders(baseUrl: prepared.baseUrl, identity: previousIdentity);
      if (!current()) throw const ReaderAccountFailure('Reader data changed during the request. Try again.');
      if (prepared.snapshot != null) {
        dataApplied = true;
        final applied = await _applyRemoteSyncSnapshot(prepared.snapshot!, syncContext: prepared.context,
            expectedGeneration: expectedGeneration, requireCloud: false);
        if (!applied || !current()) throw const ReaderAccountFailure('Reader data changed during the request. Try again.');
      }
      await _preferences.saveSyncIdentity(prepared.baseUrl, prepared.account.identity);
      identitySaved = true;
      if (!current()) throw const ReaderAccountFailure('Reader data changed during the request. Try again.');
      _syncClientId = prepared.account.identity.deviceId;
      _syncToken = prepared.account.identity.token;
      _readerAccountEmail = prepared.account.email;
      if (prepared.syncRevision != null) {
        await _preferences.saveReaderSyncRevision(prepared.baseUrl, prepared.account.identity, prepared.syncRevision!);
        if (!current()) throw const ReaderAccountFailure('Reader data changed during the request. Try again.');
      }
      _readerSyncRevision = prepared.syncRevision;
      _readerSyncConflict = false;
      _syncUsesFreshBackup = false;
      _localChangeGeneration++;
      expectedGeneration = _localChangeGeneration;
      _readerSyncDirty = false;
      await _persistReaderSyncLocalState();
      if (!current()) throw const ReaderAccountFailure('Reader data changed during the request. Try again.');
      if (_syncStateWriteFailed) throw const ReaderAccountFailure('Account settings could not be saved. Try again.');
      _readerSyncStatus = 'Reader account connected. The selected backup is ready.';
    } catch (_) {
      // Keep this transition exclusive until its pending identity write is settled.
      // A cancelled transition cannot overwrite another backend or a newer edit.
      if (owns()) {
        if (identitySaved) {
          try {
            final stored = await _preferences.loadOrCreateSyncIdentity(prepared.baseUrl);
            if (stored.deviceId == prepared.account.identity.deviceId && stored.token == prepared.account.identity.token) {
              await _preferences.saveSyncIdentity(prepared.baseUrl, previousIdentity);
            }
          } catch (_) { /* Preserve local data even if credential rollback storage fails. */ }
        }
        if (sameContext()) {
          _syncClientId = previousIdentity.deviceId;
          _syncToken = previousIdentity.token;
          _readerAccountEmail = previousEmail;
          _readerSyncRevision = previousRevision;
          _readerSyncConflict = previousConflict;
          if (dataApplied && expectedGeneration == _localChangeGeneration) {
            try {
              await _applyRemoteSyncSnapshot(previous, syncContext: prepared.context,
                  expectedGeneration: expectedGeneration, requireCloud: false,
                  createRestorePoint: false);
            } catch (_) { /* In-memory rollback remains usable if persistence fails. */ }
          }
          if (sameContext()) {
            _readerSyncDirty = expectedGeneration != _localChangeGeneration || dataApplied || previousDirty;
            await _persistReaderSyncLocalState();
          }
        }
      }
      rethrow;
    } finally {
      _readerAccountAdopting = false;
      if (owns()) _finishReaderAccountTransition();
    }
  }

  Future<ReaderPairingCode> createReaderPairingCode() async {
    final source = await _beginReaderAccountTransition();
    try {
      final uploaded = await _readerSyncService.pushSnapshot(baseUrl: source.baseUrl,
          deviceId: source.identity.deviceId, token: source.identity.token, snapshot: _buildSyncSnapshot(),
          baseRevision: _readerSyncRevision);
      if (!uploaded.success || source.context != _syncContextGeneration || source.generation != _localChangeGeneration) {
        if (source.context == _syncContextGeneration && uploaded.status == ReaderSyncStatus.conflict) _reportReaderSyncFailure(uploaded.status);
        throw const ReaderAccountFailure('Your reader backup could not be saved. Pairing was stopped.');
      }
      if (!await _acknowledgeReaderSyncRevision(uploaded.syncRevision, source.context, forAccount: true) ||
          source.generation != _localChangeGeneration) {
        throw const ReaderAccountFailure('Your reader backup could not be saved. Pairing was stopped.');
      }
      return await _readerAccountService.createPairing(source.baseUrl, source.identity);
    } finally {
      if (source.context == _syncContextGeneration) _finishReaderAccountTransition();
    }
  }

  Future<void> cancelReaderPairingCode() async {
    final identity = await readerIdentityForFeature();
    await _readerAccountService.cancelPairing(_syncBaseUrl, identity);
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
    if (isOfflinePackPaused(edition)) return 'Paused';
    if (isOfflinePackDownloaded(edition)) {
      return 'Available offline';
    }
    final remotePack = remoteAssetPackForEdition(edition);
    if (remotePack != null) {
      return 'Admin v${remotePack.version}';
    }
    if (hasZipPackForEdition(edition)) {
      return 'Not downloaded';
    }
    return 'Not available';
  }

  String adminPackSubtitleForEdition(MushafEdition edition) {
    final remotePack = remoteAssetPackForEdition(edition);
    if (isBundledPackForEdition(edition)) {
      return '${edition.bestUseLabel}. This edition is bundled with the app and always available offline.';
    }
    if (isOfflinePackDownloading(edition)) {
      final progress = (offlinePackProgressForEdition(edition) * 100).round();
      final versionLabel =
          remotePack == null ? 'ZIP pack' : 'admin pack ${remotePack.version}';
      return '${edition.bestUseLabel}. Downloading $versionLabel for offline use ($progress%).';
    }
    if (isOfflinePackPaused(edition)) {
      final partial = _partialOfflinePacks[edition]!;
      return partial.canResume
          ? 'Download paused. Resume to continue from the saved data.'
          : 'Download paused. This server requires a fresh transfer when resumed.';
    }
    if (isOfflinePackDownloaded(edition)) {
      final versionLabel =
          remotePack == null ? 'ZIP pack' : 'admin pack ${remotePack.version}';
      return '${edition.bestUseLabel}. $versionLabel is stored on this device and will keep working offline.';
    }
    if (remotePack != null) {
      return '${edition.bestUseLabel}. Admin pack ${remotePack.version} with ${remotePack.pageCount} imported pages can be downloaded for offline use.';
    }
    final zipPack = zipPackForEdition(edition);
    if (zipPack != null) {
      return '${edition.bestUseLabel}. ZIP pack is available from the server and will work offline after download.';
    }
    return '${edition.bestUseLabel}. No admin-managed pack is active yet.';
  }

  Future<void> downloadOfflineEditionPack(MushafEdition edition) async {
    if (_offlinePackProgress.containsKey(edition)) {
      return;
    }

    if (!await _downloadPolicy.allowsDownload()) {
      throw StateError('Wi-Fi-only downloads are enabled. Connect to Wi-Fi to continue.');
    }
    if (_isDisposed || _offlinePackProgress.containsKey(edition)) return;
    final cancelToken = CancelToken();
    _offlinePackCancelTokens[edition] = cancelToken;
    _packTransferProgress.remove(edition);
    _offlinePackProgress = Map<MushafEdition, double>.from(_offlinePackProgress)
      ..[edition] = 0;
    notifyListeners();

    try {
      var lastProgress = 0.0;
      var lastProgressNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
      await _repository.downloadOfflinePack(
        edition,
        cancelToken: cancelToken,
        onTransferProgress: (progress) {
          if (!_isDisposed) _packTransferProgress[edition] = progress;
        },
        onProgress: (progress) {
          if (_isDisposed) {
            return;
          }
          final clampedProgress = progress.clamp(0, 1).toDouble();
          final now = DateTime.now();
          final progressDelta = (clampedProgress - lastProgress).abs();
          final elapsed = now.difference(lastProgressNotifyAt);
          if (clampedProgress < 1 &&
              progressDelta < 0.01 &&
              elapsed < const Duration(milliseconds: 250)) {
            return;
          }
          lastProgress = clampedProgress;
          lastProgressNotifyAt = now;
          _offlinePackProgress =
              Map<MushafEdition, double>.from(_offlinePackProgress)
                ..[edition] = clampedProgress;
          notifyListeners();
        },
      );
    } catch (error) {
      if (cancelToken.cancelError?.error == QuranPackDownloadStop.pause) {
        throw StateError('Download paused. Saved data is kept for resume.');
      }
      rethrow;
    } finally {
      _offlinePackCancelTokens.remove(edition);
      _offlinePackProgress =
          Map<MushafEdition, double>.from(_offlinePackProgress)
            ..remove(edition);
      if (!_isDisposed) {
        await _refreshOfflinePackAvailability();
        _refreshCurrentCaches();
        _publishContentChange();
        notifyListeners();
        unawaited(refreshDownloadStorage().catchError((Object _) {}));
      }
    }
  }

  void pauseOfflineEditionPackDownload(MushafEdition edition) {
    final token = _offlinePackCancelTokens[edition];
    if (token != null && !token.isCancelled) token.cancel(QuranPackDownloadStop.pause);
  }

  Future<void> discardPausedOfflineEditionPack(MushafEdition edition) async {
    if (isOfflinePackDownloading(edition)) return;
    await _repository.discardPartialOfflinePack(edition);
    _partialOfflinePacks.remove(edition);
    _packTransferProgress.remove(edition);
    if (!_isDisposed) notifyListeners();
    await refreshDownloadStorage();
  }

  void cancelOfflineEditionPackDownload(MushafEdition edition) {
    final token = _offlinePackCancelTokens[edition];
    if (token == null || token.isCancelled) {
      return;
    }
    token.cancel(QuranPackDownloadStop.cancel);
  }

  void cancelAllOfflinePackDownloads() {
    final tokens = List<CancelToken>.from(_offlinePackCancelTokens.values);
    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel(QuranPackDownloadStop.cancel);
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

  Future<void> _hydrateFromCloudIfNeeded() async {
    if (_experienceSettings.syncMode != ReaderSyncMode.cloudReady) return;
    final ready = await _bindReaderSyncIdentity();
    if (!ready || _experienceSettings.syncMode != ReaderSyncMode.cloudReady) return;
    final context = _syncContextGeneration;
    await _queueReaderSync(context,
        () => _pullReaderSnapshot(context, seedWhenMissing: true));
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
      editionPageNotes: _editionPageNotes,
      editionFavoritePages: _editionFavoritePages,
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

  Future<bool> _applyRemoteSyncSnapshot(
    ReaderSyncSnapshot snapshot, {
    int? syncContext,
    int? expectedGeneration,
    bool requireCloud = true,
    bool createRestorePoint = true,
  }) async {
    bool isCurrent() => !_isDisposed &&
        (syncContext == null || (requireCloud
            ? _readerSyncContextIsCurrent(syncContext)
            : syncContext == _syncContextGeneration)) &&
        (expectedGeneration == null || expectedGeneration == _localChangeGeneration);
    if (!isCurrent()) return false;
    if (createRestorePoint) await saveRestorePoint('Before replacing reader data');
    if (!isCurrent()) return false;
    ++_audioLoadGeneration;
    await _audioService.resetPlayback();
    if (!isCurrent()) return false;
    await _audioService.setRepeatEnabled(snapshot.audioState.repeatEnabled);
    if (!isCurrent()) return false;
    await _repository.setMushafEdition(snapshot.settings.mushafEdition);
    if (!isCurrent()) {
      await _repository.setMushafEdition(_settings.mushafEdition);
      return false;
    }

    _pagePersistenceTimer?.cancel();
    _notesPersistenceTimer?.cancel();
    _currentRecitationVerseKey = null;
    _lastPlayerState = null;
    _lastNotifiedAudioPositionMillis = -1;
    _lastNotifiedAudioDurationMillis = -1;
    _settings = snapshot.settings.copyWith(preferImageMode: true);
    _aiSettings = snapshot.aiSettings;
    _syncCurrentAiSettingsWithAdminConfig();
    _readingPlan = snapshot.readingPlan;
    _experienceSettings = snapshot.experienceSettings.copyWith(
      syncMode: _experienceSettings.syncMode,
    );
    _dailyTargetPages = snapshot.dailyTargetPages;
    _dailyProgressState = snapshot.dailyProgressState;
    _readingHistory = snapshot.readingHistory;
    _editionPageNotes = Map<String, Map<int, String>>.from(snapshot.editionPageNotes);
    _editionFavoritePages = Map<String, List<int>>.from(snapshot.editionFavoritePages);
    final sourceAnnotationKey = snapshot.settings.preferImageMode
        ? snapshot.settings.mushafEdition.storageValue
        : '__canonical_text__';
    _editionPageNotes.putIfAbsent(sourceAnnotationKey, () => snapshot.pageNotes);
    _editionFavoritePages.putIfAbsent(sourceAnnotationKey, () => snapshot.favoritePages);
    _activateEditionAnnotations();
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
      durationMillis: 0,
      isPlaying: false,
      isLoading: false,
      isBuffering: false,
      isDownloading: false,
      clearError: true,
      repeatEnabled: snapshot.audioState.repeatEnabled,
    );
    _currentPageNumber = snapshot.settings.preferImageMode
        ? _repository.clampPage(snapshot.lastPageNumber, preferImageMode: true)
        : _repository.navigationPageForStandardPage(
            snapshot.lastPageNumber,
            preferImageMode: true,
          );
    _lastPersistedPageNumber = null;
    _lastRecordedHistoryPageNumber = null;
    _rebuildContentCaches();
    _rebuildNavigationCaches();
    _refreshCurrentCaches();
    _suppressSyncDirty = true;
    try {
      _publishSettings();
      _publishAiSettings();
      _publishExperienceSettings();
      _publishAudioState();
      _publishCurrentPage();
      _publishContentChange(localChange: false);
    } finally {
      _suppressSyncDirty = false;
    }
    if (!_isDisposed) notifyListeners();

    final persistenceTasks = <Future<void>>[
      _repository.saveSettings(_settings),
      _preferences.saveAiSettings(_aiSettings),
      _repository.saveReadingPlan(_readingPlan),
      _repository.saveExperienceSettings(_experienceSettings),
      _repository.saveDailyTargetPages(_dailyTargetPages),
      _repository.saveDailyProgressState(_dailyProgressState),
      _repository.saveReadingHistory(_readingHistory),
      _repository.savePageNotesByEdition(_editionPageNotes),
      _repository.saveFavoritePagesByEdition(_editionFavoritePages),
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
    return isCurrent();
  }

  void _scheduleCloudSyncPush({bool markDirty = true}) {
    if (_isDisposed || _isLoading || _suppressSyncDirty) return;
    if (markDirty) _markReaderSyncDirty();
    if (_readerAccountBusy || _readerSyncConflict || _experienceSettings.syncMode != ReaderSyncMode.cloudReady ||
        !_readerSyncDirty || _syncClientId.isEmpty || _syncBaseUrl.isEmpty) {
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
      _publishContentChange(localChange: false);
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
    const nextPreferImageMode = true;
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
    _markReaderSyncDirty();
    await _repository.setMushafEdition(fallbackEdition);
    _activateEditionAnnotations();
    _rebuildContentCaches();
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
    final editions = MushafEdition.values;
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
    _partialOfflinePacks = await _repository.loadPartialOfflinePacks();
  }

  void _refreshZipPacksInBackground() {
    unawaited(
      _repository.fetchAvailableZipPacks(forceRefresh: true).then((packs) {
        if (_isDisposed) {
          return;
        }
        _zipAssetPacks = packs;
        notifyListeners();
      }).catchError((_) {}),
    );
  }
}
