import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/quran_reader/domain/models/reader_daily_progress_state.dart';
import '../../features/quran_reader/domain/models/reader_bookmark.dart';
import '../../features/quran_reader/domain/models/reader_history_entry.dart';
import '../../features/quran_reader/domain/models/quran_ai_models.dart';
import '../../features/quran_reader/domain/models/reader_growth_models.dart';
import '../../features/quran_reader/domain/models/reader_settings.dart';

class ReaderPreferences {
  static const _defaultAdminPublicBaseUrl =
      'https://quran.opplexify.com';
  static const _lastPageKey = 'reader.lastPageNumber';
  static const _legacyLastSpreadKey = 'reader.lastSpreadIndex';
  static const _mushafEditionKey = 'reader.mushafEdition';
  static const _fullscreenKey = 'reader.fullscreen';
  static const _showPageNumbersKey = 'reader.showPageNumbers';
  static const _preferImageModeKey = 'reader.preferImageMode';
  static const _customBrightnessEnabledKey = 'reader.customBrightnessEnabled';
  static const _pageBrightnessKey = 'reader.pageBrightness';
  static const _nightModeKey = 'reader.nightMode';
  static const _pageNightModeKey = 'reader.pageNightMode';
  static const _pagePresetEnabledKey = 'reader.pagePresetEnabled';
  static const _pagePresetKey = 'reader.pagePreset';
  static const _pageOverlayEnabledKey = 'reader.pageOverlayEnabled';
  static const _pageReflectionEnabledKey = 'reader.pageReflectionEnabled';
  static const _lowMemoryModeKey = 'reader.lowMemoryMode';
  static const _hifzFocusModeKey = 'reader.hifzFocusMode';
  static const _hifzMaskHeightFactorKey = 'reader.hifzMaskHeightFactor';
  static const _hifzRevealOnHoldKey = 'reader.hifzRevealOnHold';
  static const _dailyTargetPagesKey = 'reader.dailyTargetPages';
  static const _dailyProgressDateKey = 'reader.dailyProgressDate';
  static const _dailyProgressStartPageKey = 'reader.dailyProgressStartPage';
  static const _readingHistoryKey = 'reader.readingHistory';
  static const _pageNotesKey = 'reader.pageNotes';
  static const _preferredReciterIdKey = 'reader.preferredReciterId';
  static const _favoritePagesKey = 'reader.favoritePages';
  static const _bookmarksKey = 'reader.bookmarks';
  static const _audioChapterIdKey = 'reader.audioChapterId';
  static const _audioPositionMillisKey = 'reader.audioPositionMillis';
  static const _audioRepeatEnabledKey = 'reader.audioRepeatEnabled';
  static const _readingStreakCountKey = 'reader.streakCount';
  static const _readingStreakLastDateKey = 'reader.streakLastDate';
  static const _onboardingSeenKey = 'reader.onboardingSeen';
  static const _readingPlanKey = 'reader.readingPlan';
  static const _hifzRevisionEntriesKey = 'reader.hifzRevisionEntries';
  static const _experienceSettingsKey = 'reader.experienceSettings';
  static const _adminPublicBaseUrlKey = 'reader.admin.publicBaseUrl';
  static const _adminPublicConfigJsonKey = 'reader.admin.publicConfigJson';
  static const _syncClientIdKey = 'reader.sync.clientId';
  static const _aiOllamaEnabledKey = 'reader.ai.ollamaEnabled';
  static const _aiOllamaBaseUrlKey = 'reader.ai.ollamaBaseUrl';
  static const _aiOllamaModelKey = 'reader.ai.ollamaModel';
  static const _aiResponseDepthKey = 'reader.ai.responseDepth';
  static const _aiOnlineEnabledKey = 'reader.ai.onlineEnabled';
  static const _aiApiKeyKey = 'reader.ai.apiKey';
  static const _aiModelKey = 'reader.ai.model';
  static const _aiResponseLanguageKey = 'reader.ai.responseLanguage';
  static const _legacyBookmarkPageKey = 'reader.bookmarkPage';
  static const _legacyCustomFontColorEnabledKey =
      'reader.customFontColorEnabled';
  static const _legacyFontColorPresetKey = 'reader.fontColorPreset';

  Future<SharedPreferences> get _prefs async {
    return SharedPreferences.getInstance();
  }

  Future<int> loadLastPageNumber() async {
    final prefs = await _prefs;
    final savedPage = prefs.getInt(_lastPageKey);
    if (savedPage != null) {
      return savedPage;
    }

    final legacySpreadIndex = prefs.getInt(_legacyLastSpreadKey);
    if (legacySpreadIndex != null) {
      return (legacySpreadIndex * 2) + 1;
    }

    return 1;
  }

  Future<ReaderSettings> loadSettings() async {
    final prefs = await _prefs;
    return ReaderSettings(
      mushafEdition:
          MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey)),
      fullscreenReading: prefs.getBool(_fullscreenKey) ?? false,
      showPageNumbers: prefs.getBool(_showPageNumbersKey) ?? true,
      preferImageMode: prefs.getBool(_preferImageModeKey) ?? true,
      customBrightnessEnabled:
          prefs.getBool(_customBrightnessEnabledKey) ?? false,
      pageBrightness:
          (prefs.getDouble(_pageBrightnessKey) ?? 1.0).clamp(0.7, 1.25),
      nightMode: prefs.getBool(_nightModeKey) ?? false,
      pageNightMode: prefs.getBool(_pageNightModeKey) ?? false,
      pagePresetEnabled: prefs.getBool(_pagePresetEnabledKey) ?? false,
      pagePreset: PagePresetX.fromStorageValue(prefs.getString(_pagePresetKey)),
      pageOverlayEnabled: prefs.getBool(_pageOverlayEnabledKey) ?? false,
      pageReflectionEnabled: prefs.getBool(_pageReflectionEnabledKey) ?? true,
      lowMemoryMode: prefs.getBool(_lowMemoryModeKey) ?? false,
      hifzFocusMode: prefs.getBool(_hifzFocusModeKey) ?? false,
      hifzMaskHeightFactor:
          (prefs.getDouble(_hifzMaskHeightFactorKey) ?? 0.42).clamp(0.18, 0.7),
      hifzRevealOnHold: prefs.getBool(_hifzRevealOnHoldKey) ?? true,
    );
  }

  Future<void> saveLastPageNumber(int pageNumber) async {
    final prefs = await _prefs;
    await prefs.setInt(_lastPageKey, pageNumber);
    await prefs.setInt(_legacyLastSpreadKey, (pageNumber - 1) ~/ 2);
  }

  static Future<void> _settingsWrites = Future<void>.value();

  Future<void> saveSettings(ReaderSettings settings) {
    final operation = _settingsWrites.then((_) => _saveSettings(settings));
    _settingsWrites = operation.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return operation;
  }

  Future<void> _saveSettings(ReaderSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString(
        _mushafEditionKey, settings.mushafEdition.storageValue);
    await prefs.setBool(_fullscreenKey, settings.fullscreenReading);
    await prefs.setBool(_showPageNumbersKey, settings.showPageNumbers);
    await prefs.setBool(_preferImageModeKey, settings.preferImageMode);
    await prefs.setBool(
      _customBrightnessEnabledKey,
      settings.customBrightnessEnabled,
    );
    await prefs.setDouble(_pageBrightnessKey, settings.pageBrightness);
    await prefs.setBool(_nightModeKey, settings.nightMode);
    await prefs.setBool(_pageNightModeKey, settings.pageNightMode);
    await prefs.setBool(_pagePresetEnabledKey, settings.pagePresetEnabled);
    await prefs.setString(_pagePresetKey, settings.pagePreset.storageValue);
    await prefs.setBool(_pageOverlayEnabledKey, settings.pageOverlayEnabled);
    await prefs.setBool(
      _pageReflectionEnabledKey,
      settings.pageReflectionEnabled,
    );
    await prefs.setBool(_lowMemoryModeKey, settings.lowMemoryMode);
    await prefs.setBool(_hifzFocusModeKey, settings.hifzFocusMode);
    await prefs.setDouble(
      _hifzMaskHeightFactorKey,
      settings.hifzMaskHeightFactor,
    );
    await prefs.setBool(_hifzRevealOnHoldKey, settings.hifzRevealOnHold);
    await prefs.remove(_legacyBookmarkPageKey);
    await prefs.remove(_legacyCustomFontColorEnabledKey);
    await prefs.remove(_legacyFontColorPresetKey);
  }

  Future<int> loadDailyTargetPages() async {
    final prefs = await _prefs;
    return (prefs.getInt(_dailyTargetPagesKey) ?? 8).clamp(1, 40);
  }

  Future<void> saveDailyTargetPages(int pageCount) async {
    final prefs = await _prefs;
    await prefs.setInt(_dailyTargetPagesKey, pageCount.clamp(1, 40));
  }

  Future<ReaderDailyProgressState> loadDailyProgressState({
    required String todayKey,
    required int fallbackStartPage,
  }) async {
    final prefs = await _prefs;
    final savedDate = prefs.getString(_dailyProgressDateKey);
    final savedStartPage = prefs.getInt(_dailyProgressStartPageKey);
    if (savedDate == todayKey && savedStartPage != null) {
      return ReaderDailyProgressState(
        dateKey: savedDate!,
        startPage: savedStartPage,
      );
    }

    final state = ReaderDailyProgressState(
      dateKey: todayKey,
      startPage: fallbackStartPage,
    );
    await saveDailyProgressState(state);
    return state;
  }

  Future<void> saveDailyProgressState(ReaderDailyProgressState state) async {
    final prefs = await _prefs;
    await prefs.setString(_dailyProgressDateKey, state.dateKey);
    await prefs.setInt(_dailyProgressStartPageKey, state.startPage);
  }

  Future<List<ReaderHistoryEntry>> loadReadingHistory() async {
    final prefs = await _prefs;
    final payload = prefs.getString(_readingHistoryKey);
    if (payload == null || payload.trim().isEmpty) {
      return const [];
    }

    try {
      final jsonList = json.decode(payload) as List<dynamic>;
      return jsonList.map((entry) {
        return ReaderHistoryEntry.fromJson(entry as Map<String, dynamic>,
          fallbackEdition: MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey)),
          fallbackPreferImageMode: prefs.getBool(_preferImageModeKey) ?? true);
      }).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveReadingHistory(List<ReaderHistoryEntry> entries) async {
    final prefs = await _prefs;
    final payload =
        json.encode(entries.map((entry) => entry.toJson()).toList());
    await prefs.setString(_readingHistoryKey, payload);
  }

  Future<Map<int, String>> loadPageNotes() async {
    final prefs = await _prefs;
    final edition = MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey));
    final annotationKey = (prefs.getBool(_preferImageModeKey) ?? true) ? edition.storageValue : '__canonical_text__';
    return (await loadPageNotesByEdition())[annotationKey] ?? const {};
  }

  Future<Map<String, Map<int, String>>> loadPageNotesByEdition() async {
    final prefs = await _prefs;
    final all = prefs.getString('$_pageNotesKey.byEdition');
    try {
      if (all != null) {
        return (json.decode(all) as Map<String, dynamic>).map((edition, notes) => MapEntry(edition,
          (notes as Map<String, dynamic>).map((page, note) => MapEntry(int.parse(page), note as String))));
      }
      final payload = prefs.getString(_pageNotesKey);
      if (payload == null || payload.trim().isEmpty) return {};
      final edition = MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey));
    final annotationKey = (prefs.getBool(_preferImageModeKey) ?? true) ? edition.storageValue : '__canonical_text__';
      return {annotationKey: (json.decode(payload) as Map<String, dynamic>).map(
        (page, note) => MapEntry(int.parse(page), note as String))};
    } catch (_) {
      return {};
    }
  }

  Future<void> savePageNotes(Map<int, String> notes) async {
    final prefs = await _prefs;
    final edition = MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey));
    final annotationKey = (prefs.getBool(_preferImageModeKey) ?? true) ? edition.storageValue : '__canonical_text__';
    final all = await loadPageNotesByEdition();
    all[annotationKey] = notes;
    await savePageNotesByEdition(all);
  }

  Future<void> savePageNotesByEdition(Map<String, Map<int, String>> notes) async {
    final prefs = await _prefs;
    await prefs.setString('$_pageNotesKey.byEdition', json.encode(notes.map(
      (edition, pages) => MapEntry(edition, pages.map((page, note) => MapEntry('$page', note))),
    )));
  }

  Future<int?> loadPreferredReciterId() async {
    final prefs = await _prefs;
    return prefs.getInt(_preferredReciterIdKey);
  }

  Future<void> savePreferredReciterId(int reciterId) async {
    final prefs = await _prefs;
    await prefs.setInt(_preferredReciterIdKey, reciterId);
  }

  Future<List<int>> loadFavoritePages() async {
    final prefs = await _prefs;
    final edition = MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey));
    final annotationKey = (prefs.getBool(_preferImageModeKey) ?? true) ? edition.storageValue : '__canonical_text__';
    return (await loadFavoritePagesByEdition())[annotationKey] ?? const [];
  }

  Future<Map<String, List<int>>> loadFavoritePagesByEdition() async {
    final prefs = await _prefs;
    final all = prefs.getString('$_favoritePagesKey.byEdition');
    if (all != null) {
      return (json.decode(all) as Map<String, dynamic>).map((edition, pages) =>
        MapEntry(edition, (pages as List<dynamic>).cast<int>()));
    }
    final edition = MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey));
    final annotationKey = (prefs.getBool(_preferImageModeKey) ?? true) ? edition.storageValue : '__canonical_text__';
    return {annotationKey: prefs.getStringList(_favoritePagesKey)?.map(int.parse).toList() ?? <int>[]};
  }

  Future<void> saveFavoritePages(List<int> pages) async {
    final prefs = await _prefs;
    final edition = MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey));
    final annotationKey = (prefs.getBool(_preferImageModeKey) ?? true) ? edition.storageValue : '__canonical_text__';
    final all = await loadFavoritePagesByEdition();
    all[annotationKey] = pages;
    await saveFavoritePagesByEdition(all);
  }

  Future<void> saveFavoritePagesByEdition(Map<String, List<int>> pages) async {
    final prefs = await _prefs;
    await prefs.setString('$_favoritePagesKey.byEdition', json.encode(pages));
  }

  Future<List<ReaderBookmark>> loadBookmarks() async {
    final prefs = await _prefs;
    final payload = prefs.getString(_bookmarksKey);
    if (payload == null || payload.trim().isEmpty) {
      return const [];
    }

    try {
      final jsonList = json.decode(payload) as List<dynamic>;
      return jsonList
          .map(
              (entry) => ReaderBookmark.fromJson(entry as Map<String, dynamic>,
                fallbackEdition: MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey)),
          fallbackPreferImageMode: prefs.getBool(_preferImageModeKey) ?? true))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveBookmarks(List<ReaderBookmark> bookmarks) async {
    final prefs = await _prefs;
    final payload =
        json.encode(bookmarks.map((entry) => entry.toJson()).toList());
    await prefs.setString(_bookmarksKey, payload);
  }

  Future<int?> loadAudioChapterId() async {
    final prefs = await _prefs;
    return prefs.getInt(_audioChapterIdKey);
  }

  Future<void> saveAudioChapterId(int? chapterId) async {
    final prefs = await _prefs;
    if (chapterId == null) {
      await prefs.remove(_audioChapterIdKey);
      return;
    }
    await prefs.setInt(_audioChapterIdKey, chapterId);
  }

  Future<int> loadAudioPositionMillis() async {
    final prefs = await _prefs;
    return prefs.getInt(_audioPositionMillisKey) ?? 0;
  }

  Future<void> saveAudioPositionMillis(int positionMillis) async {
    final prefs = await _prefs;
    await prefs.setInt(
        _audioPositionMillisKey, positionMillis.clamp(0, 1 << 31));
  }

  Future<bool> loadAudioRepeatEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_audioRepeatEnabledKey) ?? false;
  }

  Future<void> saveAudioRepeatEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_audioRepeatEnabledKey, enabled);
  }

  Future<int> loadReadingStreakCount() async {
    final prefs = await _prefs;
    return prefs.getInt(_readingStreakCountKey) ?? 0;
  }

  Future<void> saveReadingStreakCount(int count) async {
    final prefs = await _prefs;
    await prefs.setInt(_readingStreakCountKey, count);
  }

  Future<String?> loadReadingStreakLastDate() async {
    final prefs = await _prefs;
    return prefs.getString(_readingStreakLastDateKey);
  }

  Future<void> saveReadingStreakLastDate(String? dateKey) async {
    final prefs = await _prefs;
    if (dateKey == null) {
      await prefs.remove(_readingStreakLastDateKey);
      return;
    }
    await prefs.setString(_readingStreakLastDateKey, dateKey);
  }

  Future<bool> loadOnboardingSeen() async {
    final prefs = await _prefs;
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  Future<void> saveOnboardingSeen(bool seen) async {
    final prefs = await _prefs;
    await prefs.setBool(_onboardingSeenKey, seen);
  }

  Future<ReaderReadingPlan> loadReadingPlan() async {
    final prefs = await _prefs;
    final payload = prefs.getString(_readingPlanKey);
    if (payload == null || payload.trim().isEmpty) {
      return const ReaderReadingPlan.defaults();
    }

    try {
      final jsonMap = json.decode(payload) as Map<String, dynamic>;
      return ReaderReadingPlan.fromJson(jsonMap);
    } catch (_) {
      return const ReaderReadingPlan.defaults();
    }
  }

  Future<void> saveReadingPlan(ReaderReadingPlan plan) async {
    final prefs = await _prefs;
    await prefs.setString(_readingPlanKey, json.encode(plan.toJson()));
  }

  Future<List<ReaderHifzReviewEntry>> loadHifzRevisionEntries() async {
    final prefs = await _prefs;
    final payload = prefs.getString(_hifzRevisionEntriesKey);
    if (payload == null || payload.trim().isEmpty) {
      return const [];
    }

    try {
      final jsonList = json.decode(payload) as List<dynamic>;
      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((entry) => ReaderHifzReviewEntry.fromJson(entry,
            fallbackEdition: MushafEditionX.fromStorageValue(prefs.getString(_mushafEditionKey)),
            fallbackPreferImageMode: prefs.getBool(_preferImageModeKey) ?? true))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveHifzRevisionEntries(
    List<ReaderHifzReviewEntry> entries,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      _hifzRevisionEntriesKey,
      json.encode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<ReaderExperienceSettings> loadExperienceSettings() async {
    final prefs = await _prefs;
    final payload = prefs.getString(_experienceSettingsKey);
    if (payload == null || payload.trim().isEmpty) {
      return const ReaderExperienceSettings.defaults();
    }

    try {
      final jsonMap = json.decode(payload) as Map<String, dynamic>;
      return ReaderExperienceSettings.fromJson(jsonMap);
    } catch (_) {
      return const ReaderExperienceSettings.defaults();
    }
  }

  Future<void> saveExperienceSettings(ReaderExperienceSettings settings) async {
    final prefs = await _prefs;
    await prefs.setString(
        _experienceSettingsKey, json.encode(settings.toJson()));
  }

  Future<String> loadAdminPublicBaseUrl() async {
    final prefs = await _prefs;
    final savedUrl = prefs.getString(_adminPublicBaseUrlKey);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      final normalizedSavedUrl = savedUrl.trim();
      if (_isLegacyAdminPublicBaseUrl(normalizedSavedUrl)) {
        await prefs.setString(
            _adminPublicBaseUrlKey, _defaultAdminPublicBaseUrl);
        return _defaultAdminPublicBaseUrl;
      }
      return normalizedSavedUrl;
    }
    if (kIsWeb) {
      return _defaultAdminPublicBaseUrl;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _defaultAdminPublicBaseUrl,
      _ => _defaultAdminPublicBaseUrl,
    };
  }

  bool _isLegacyAdminPublicBaseUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'http://localhost:5052' ||
        normalized == 'http://10.0.2.2:5052' ||
        normalized == 'http://127.0.0.1:5052' ||
        normalized == 'https://quranadminapi.opplexify.com' ||
        normalized == 'https://adminapi.opplexify.com';
  }

  Future<void> saveAdminPublicBaseUrl(String baseUrl) async {
    final prefs = await _prefs;
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) {
      await prefs.remove(_adminPublicBaseUrlKey);
      return;
    }
    await prefs.setString(_adminPublicBaseUrlKey, normalized);
  }

  Future<String?> loadAdminPublicConfigJson() async {
    final prefs = await _prefs;
    final payload = prefs.getString(_adminPublicConfigJsonKey);
    if (payload == null || payload.trim().isEmpty) {
      return null;
    }
    return payload;
  }

  Future<void> saveAdminPublicConfigJson(String payload) async {
    final prefs = await _prefs;
    final normalized = payload.trim();
    if (normalized.isEmpty) {
      await prefs.remove(_adminPublicConfigJsonKey);
      return;
    }
    await prefs.setString(_adminPublicConfigJsonKey, normalized);
  }

  Future<({int generation, bool dirty})?> loadReaderSyncLocalState(String baseUrl) async {
    final prefs = await _prefs;
    final key = 'reader.sync.localState.${Uri.encodeComponent(normalizeSyncBaseUrl(baseUrl))}';
    final payload = prefs.getString(key);
    if (payload == null) return null;
    try {
      final state = json.decode(payload) as Map<String, dynamic>;
      final generation = state['generation'];
      final dirty = state['dirty'];
      if (generation is! int || generation < 0 || dirty is! bool) return null;
      return (generation: generation, dirty: dirty);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveReaderSyncLocalState(String baseUrl, {required int generation, required bool dirty}) async {
    final prefs = await _prefs;
    final key = 'reader.sync.localState.${Uri.encodeComponent(normalizeSyncBaseUrl(baseUrl))}';
    if (!await prefs.setString(key, json.encode({'generation': generation, 'dirty': dirty}))) {
      throw StateError('Unable to save the local reader sync state.');
    }
  }

  Future<String> loadOrCreateSyncClientId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_syncClientIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final random = Random();
    final generated = [
      'reader',
      DateTime.now().microsecondsSinceEpoch.toString(),
      random.nextInt(0x100000000).toRadixString(16),
    ].join('-');
    await prefs.setString(_syncClientIdKey, generated);
    return generated;
  }

  Future<ReaderAiSettings> loadAiSettings() async {
    final prefs = await _prefs;
    return ReaderAiSettings(
      responseLanguage: AiResponseLanguageX.fromStorageValue(
        prefs.getString(_aiResponseLanguageKey),
      ),
      responseDepth: AiResponseDepthX.fromStorageValue(
        prefs.getString(_aiResponseDepthKey),
      ),
    );
  }

  Future<void> saveAiSettings(ReaderAiSettings settings) async {
    final prefs = await _prefs;
    await prefs.remove(_aiOnlineEnabledKey);
    await prefs.remove(_aiApiKeyKey);
    await prefs.remove(_aiModelKey);
    await prefs.remove(_aiOllamaEnabledKey);
    await prefs.remove(_aiOllamaBaseUrlKey);
    await prefs.remove(_aiOllamaModelKey);
    await prefs.setString(
      _aiResponseLanguageKey,
      settings.responseLanguage.storageValue,
    );
    await prefs.setString(
      _aiResponseDepthKey,
      settings.responseDepth.storageValue,
    );
  }
  static String normalizeSyncBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const FormatException('A valid sync server URL is required.');
    }
    final normalized = uri.normalizePath().replace(host: uri.host.toLowerCase()).toString();
    return normalized.replaceFirst(RegExp(r'/+$'), '');
  }

  static final Map<String, Future<ReaderSyncIdentity>> _syncIdentityLoads = {};

  Future<ReaderSyncIdentity> loadOrCreateSyncIdentity(String baseUrl) {
    final normalized = normalizeSyncBaseUrl(baseUrl);
    final pending = _syncIdentityLoads[normalized];
    if (pending != null) return pending;
    final request = _loadOrCreateSyncIdentity(normalized);
    _syncIdentityLoads[normalized] = request;
    return request.whenComplete(() { if (identical(_syncIdentityLoads[normalized], request)) _syncIdentityLoads.remove(normalized); });
  }

  Future<ReaderSyncIdentity> _loadOrCreateSyncIdentity(String normalized) async {
    final prefs = await _prefs;
    final key = 'reader.sync.identity.${Uri.encodeComponent(normalized)}';
    final stored = prefs.getString(key);
    if (stored != null) {
      try {
        final record = json.decode(stored) as Map<String, dynamic>;
        final id = record['deviceId'];
        final token = record['token'];
        if (id is String && RegExp(r'^reader_[A-Za-z0-9_-]{32}$').hasMatch(id) &&
            token is String && token.length == 43 && RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
          return ReaderSyncIdentity(deviceId: id.toLowerCase(), token: token);
        }
      } catch (_) { /* A missing credential cannot claim an existing backup. */ }
    }
    final random = Random.secure();
    String secret(int count) => base64UrlEncode(List<int>.generate(count, (_) => random.nextInt(256))).replaceAll('=', '');
    final identity = ReaderSyncIdentity(deviceId: 'reader_${secret(24).toLowerCase()}', token: secret(32));
    if (!await prefs.setString(key, json.encode({'deviceId': identity.deviceId, 'token': identity.token}))) {
      throw StateError('Unable to save the private sync identity.');
    }
    return identity;
  }

}


class ReaderSyncIdentity {
  const ReaderSyncIdentity({required this.deviceId, required this.token});
  final String deviceId;
  final String token;
}
