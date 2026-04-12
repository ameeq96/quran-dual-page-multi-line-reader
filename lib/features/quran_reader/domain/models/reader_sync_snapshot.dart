import 'quran_ai_models.dart';
import 'reader_bookmark.dart';
import 'reader_daily_progress_state.dart';
import 'reader_growth_models.dart';
import 'reader_history_entry.dart';
import 'reader_settings.dart';

class ReaderSyncSnapshot {
  const ReaderSyncSnapshot({
    required this.deviceId,
    required this.lastPageNumber,
    required this.settings,
    required this.aiSettings,
    required this.readingPlan,
    required this.experienceSettings,
    required this.dailyTargetPages,
    required this.dailyProgressState,
    required this.readingHistory,
    required this.pageNotes,
    required this.favoritePages,
    required this.bookmarks,
    required this.hifzReviewEntries,
    required this.updatedAtIso,
  });

  final String deviceId;
  final int lastPageNumber;
  final ReaderSettings settings;
  final ReaderAiSettings aiSettings;
  final ReaderReadingPlan readingPlan;
  final ReaderExperienceSettings experienceSettings;
  final int dailyTargetPages;
  final ReaderDailyProgressState dailyProgressState;
  final List<ReaderHistoryEntry> readingHistory;
  final Map<int, String> pageNotes;
  final List<int> favoritePages;
  final List<ReaderBookmark> bookmarks;
  final List<ReaderHifzReviewEntry> hifzReviewEntries;
  final String updatedAtIso;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'lastPageNumber': lastPageNumber,
      'settings': <String, dynamic>{
        'mushafEdition': settings.mushafEdition.storageValue,
        'fullscreenReading': settings.fullscreenReading,
        'showPageNumbers': settings.showPageNumbers,
        'preferImageMode': settings.preferImageMode,
        'customBrightnessEnabled': settings.customBrightnessEnabled,
        'pageBrightness': settings.pageBrightness,
        'nightMode': settings.nightMode,
        'pagePresetEnabled': settings.pagePresetEnabled,
        'pagePreset': settings.pagePreset.storageValue,
        'pageOverlayEnabled': settings.pageOverlayEnabled,
        'pageReflectionEnabled': settings.pageReflectionEnabled,
        'lowMemoryMode': settings.lowMemoryMode,
        'hifzFocusMode': settings.hifzFocusMode,
        'hifzMaskHeightFactor': settings.hifzMaskHeightFactor,
        'hifzRevealOnHold': settings.hifzRevealOnHold,
      },
      'aiSettings': <String, dynamic>{
        'responseLanguage': aiSettings.responseLanguage.storageValue,
        'responseDepth': aiSettings.responseDepth.storageValue,
      },
      'readingPlan': readingPlan.toJson(),
      'experienceSettings': experienceSettings.toJson(),
      'dailyTargetPages': dailyTargetPages,
      'dailyProgressState': <String, dynamic>{
        'dateKey': dailyProgressState.dateKey,
        'startPage': dailyProgressState.startPage,
      },
      'readingHistory': readingHistory.map((entry) => entry.toJson()).toList(),
      'pageNotes': pageNotes.map((key, value) => MapEntry('$key', value)),
      'favoritePages': favoritePages,
      'bookmarks': bookmarks.map((entry) => entry.toJson()).toList(),
      'hifzReviewEntries': hifzReviewEntries.map((entry) => entry.toJson()).toList(),
      'updatedAtIso': updatedAtIso,
    };
  }

  static ReaderSyncSnapshot? fromJson(Map<String, dynamic> json) {
    final deviceId = (json['deviceId'] as String? ?? '').trim();
    if (deviceId.isEmpty) {
      return null;
    }

    final settingsJson = json['settings'] as Map<String, dynamic>? ?? const {};
    final aiJson = json['aiSettings'] as Map<String, dynamic>? ?? const {};
    final dailyProgressJson =
        json['dailyProgressState'] as Map<String, dynamic>? ?? const {};

    final rawNotes = json['pageNotes'] as Map<String, dynamic>? ?? const {};
    final pageNotes = <int, String>{};
    for (final entry in rawNotes.entries) {
      final pageNumber = int.tryParse(entry.key);
      final note = entry.value?.toString() ?? '';
      if (pageNumber != null && note.trim().isNotEmpty) {
        pageNotes[pageNumber] = note;
      }
    }

    return ReaderSyncSnapshot(
      deviceId: deviceId,
      lastPageNumber: (json['lastPageNumber'] as num? ?? 1).toInt(),
      settings: ReaderSettings(
        mushafEdition:
            MushafEditionX.fromStorageValue(settingsJson['mushafEdition'] as String?),
        fullscreenReading: settingsJson['fullscreenReading'] as bool? ?? false,
        showPageNumbers: settingsJson['showPageNumbers'] as bool? ?? true,
        preferImageMode: settingsJson['preferImageMode'] as bool? ?? true,
        customBrightnessEnabled:
            settingsJson['customBrightnessEnabled'] as bool? ?? false,
        pageBrightness:
            (settingsJson['pageBrightness'] as num? ?? 1.0).toDouble(),
        nightMode: settingsJson['nightMode'] as bool? ?? false,
        pagePresetEnabled: settingsJson['pagePresetEnabled'] as bool? ?? false,
        pagePreset: PagePresetX.fromStorageValue(settingsJson['pagePreset'] as String?),
        pageOverlayEnabled: settingsJson['pageOverlayEnabled'] as bool? ?? false,
        pageReflectionEnabled:
            settingsJson['pageReflectionEnabled'] as bool? ?? true,
        lowMemoryMode: settingsJson['lowMemoryMode'] as bool? ?? false,
        hifzFocusMode: settingsJson['hifzFocusMode'] as bool? ?? false,
        hifzMaskHeightFactor:
            (settingsJson['hifzMaskHeightFactor'] as num? ?? 0.42).toDouble(),
        hifzRevealOnHold: settingsJson['hifzRevealOnHold'] as bool? ?? true,
      ),
      aiSettings: ReaderAiSettings(
        responseLanguage:
            AiResponseLanguageX.fromStorageValue(aiJson['responseLanguage'] as String?),
        responseDepth:
            AiResponseDepthX.fromStorageValue(aiJson['responseDepth'] as String?),
      ),
      readingPlan: ReaderReadingPlan.fromJson(
        json['readingPlan'] as Map<String, dynamic>? ?? const {},
      ),
      experienceSettings: ReaderExperienceSettings.fromJson(
        json['experienceSettings'] as Map<String, dynamic>? ?? const {},
      ),
      dailyTargetPages: (json['dailyTargetPages'] as num? ?? 8).toInt(),
      dailyProgressState: ReaderDailyProgressState(
        dateKey: dailyProgressJson['dateKey'] as String? ?? '',
        startPage: (dailyProgressJson['startPage'] as num? ?? 1).toInt(),
      ),
      readingHistory: (json['readingHistory'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReaderHistoryEntry.fromJson)
          .toList(growable: false),
      pageNotes: pageNotes,
      favoritePages: (json['favoritePages'] as List<dynamic>? ?? const [])
          .map((entry) => (entry as num).toInt())
          .toList(growable: false),
      bookmarks: (json['bookmarks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReaderBookmark.fromJson)
          .toList(growable: false),
      hifzReviewEntries:
          (json['hifzReviewEntries'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ReaderHifzReviewEntry.fromJson)
              .toList(growable: false),
      updatedAtIso: json['updatedAtIso'] as String? ?? '',
    );
  }
}
