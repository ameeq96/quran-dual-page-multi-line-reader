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
  static const _defaultAdminPublicBaseUrl = 'https://quranadminapi.opplexify.com';
  static const _lastPageKey = 'reader.lastPageNumber';
  static const _legacyLastSpreadKey = 'reader.lastSpreadIndex';
  static const _mushafEditionKey = 'reader.mushafEdition';
  static const _fullscreenKey = 'reader.fullscreen';
  static const _showPageNumbersKey = 'reader.showPageNumbers';
  static const _preferImageModeKey = 'reader.preferImageMode';
  static const _customBrightnessEnabledKey = 'reader.customBrightnessEnabled';
  static const _pageBrightnessKey = 'reader.pageBrightness';
  static const _nightModeKey = 'reader.nightMode';
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

  Future<void> saveSettings(ReaderSettings settings) async {
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
        return ReaderHistoryEntry.fromJson(entry as Map<String, dynamic>);
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
    final payload = prefs.getString(_pageNotesKey);
    if (payload == null || payload.trim().isEmpty) {
      return const {};
    }

    try {
      final jsonMap = json.decode(payload) as Map<String, dynamic>;
      return jsonMap.map((key, value) {
        return MapEntry(int.parse(key), value as String);
      });
    } catch (_) {
      return const {};
    }
  }

  Future<void> savePageNotes(Map<int, String> notes) async {
    final prefs = await _prefs;
    final payload = <String, String>{};
    for (final entry in notes.entries) {
      final value = entry.value.trim();
      if (value.isNotEmpty) {
        payload['${entry.key}'] = value;
      }
    }
    await prefs.setString(_pageNotesKey, json.encode(payload));
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
    return prefs.getStringList(_favoritePagesKey)?.map(int.parse).toList() ??
        const [];
  }

  Future<void> saveFavoritePages(List<int> pages) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _favoritePagesKey,
      pages.map((value) => '$value').toList(growable: false),
    );
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
              (entry) => ReaderBookmark.fromJson(entry as Map<String, dynamic>))
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
          .map(ReaderHifzReviewEntry.fromJson)
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
    await prefs.setString(_experienceSettingsKey, json.encode(settings.toJson()));
  }

  Future<String> loadAdminPublicBaseUrl() async {
    final prefs = await _prefs;
    final savedUrl = prefs.getString(_adminPublicBaseUrlKey);
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      final normalizedSavedUrl = savedUrl.trim();
      if (_isLegacyLocalAdminPublicBaseUrl(normalizedSavedUrl)) {
        await prefs.setString(_adminPublicBaseUrlKey, _defaultAdminPublicBaseUrl);
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

  bool _isLegacyLocalAdminPublicBaseUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'http://localhost:5052' ||
        normalized == 'http://10.0.2.2:5052' ||
        normalized == 'http://127.0.0.1:5052';
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
      random.nextInt(1 << 32).toRadixString(16),
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
}
