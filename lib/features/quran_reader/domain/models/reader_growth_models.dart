import 'reader_settings.dart';

enum ReadingGoalPreset {
  steady,
  ramadan,
  khatam30,
  hifzRevision,
  custom,
}

extension ReadingGoalPresetX on ReadingGoalPreset {
  String get storageValue => switch (this) {
        ReadingGoalPreset.steady => 'steady',
        ReadingGoalPreset.ramadan => 'ramadan',
        ReadingGoalPreset.khatam30 => 'khatam30',
        ReadingGoalPreset.hifzRevision => 'hifzRevision',
        ReadingGoalPreset.custom => 'custom',
      };

  String get label => switch (this) {
        ReadingGoalPreset.steady => 'Steady flow',
        ReadingGoalPreset.ramadan => 'Ramadan khatam',
        ReadingGoalPreset.khatam30 => '30-day khatam',
        ReadingGoalPreset.hifzRevision => 'Hifz revision',
        ReadingGoalPreset.custom => 'Custom goal',
      };

  String get subtitle => switch (this) {
        ReadingGoalPreset.steady =>
          'Balanced reading pace for daily consistency.',
        ReadingGoalPreset.ramadan =>
          'Daily schedule for a Ramadan khatam rhythm.',
        ReadingGoalPreset.khatam30 =>
          'Finish the Quran in 30 days with a clear target.',
        ReadingGoalPreset.hifzRevision =>
          'Focus on memorization review and weak pages.',
        ReadingGoalPreset.custom =>
          'Set your own timeline and pages-per-day target.',
      };

  int get defaultTargetDays => switch (this) {
        ReadingGoalPreset.steady => 60,
        ReadingGoalPreset.ramadan => 30,
        ReadingGoalPreset.khatam30 => 30,
        ReadingGoalPreset.hifzRevision => 45,
        ReadingGoalPreset.custom => 21,
      };

  static ReadingGoalPreset fromStorageValue(String? value) {
    return ReadingGoalPreset.values.firstWhere(
      (preset) => preset.storageValue == value,
      orElse: () => ReadingGoalPreset.steady,
    );
  }
}

class ReaderReadingPlan {
  const ReaderReadingPlan({
    required this.preset,
    required this.targetDays,
    required this.customPagesPerDay,
    required this.createdAtIso,
  });

  const ReaderReadingPlan.defaults()
      : preset = ReadingGoalPreset.steady,
        targetDays = 60,
        customPagesPerDay = 8,
        createdAtIso = '';

  final ReadingGoalPreset preset;
  final int targetDays;
  final int customPagesPerDay;
  final String createdAtIso;

  int effectiveTargetDays({required int fallbackDailyTarget}) {
    if (preset == ReadingGoalPreset.custom) {
      return targetDays.clamp(1, 365).toInt();
    }
    if (preset == ReadingGoalPreset.steady) {
      return targetDays <= 0
          ? fallbackDailyTarget * 7
          : targetDays.clamp(7, 365).toInt();
    }
    return preset.defaultTargetDays;
  }

  int pagesPerDay({
    required int remainingPages,
    required int fallbackDailyTarget,
  }) {
    if (preset == ReadingGoalPreset.custom) {
      return customPagesPerDay.clamp(1, 40);
    }
    final targetDays = effectiveTargetDays(
      fallbackDailyTarget: fallbackDailyTarget,
    );
    return ((remainingPages <= 0 ? 1 : remainingPages) / targetDays)
        .ceil()
        .clamp(1, 40)
        .toInt();
  }

  ReaderReadingPlan copyWith({
    ReadingGoalPreset? preset,
    int? targetDays,
    int? customPagesPerDay,
    String? createdAtIso,
  }) {
    return ReaderReadingPlan(
      preset: preset ?? this.preset,
      targetDays: (targetDays ?? this.targetDays).clamp(1, 365).toInt(),
      customPagesPerDay:
          (customPagesPerDay ?? this.customPagesPerDay).clamp(1, 40).toInt(),
      createdAtIso: createdAtIso ?? this.createdAtIso,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'preset': preset.storageValue,
      'targetDays': targetDays,
      'customPagesPerDay': customPagesPerDay,
      'createdAtIso': createdAtIso,
    };
  }

  static ReaderReadingPlan fromJson(Map<String, dynamic> json) {
    return ReaderReadingPlan(
      preset: ReadingGoalPresetX.fromStorageValue(json['preset'] as String?),
      targetDays: (json['targetDays'] as num? ?? 60).toInt(),
      customPagesPerDay: (json['customPagesPerDay'] as num? ?? 8).toInt(),
      createdAtIso: json['createdAtIso'] as String? ?? '',
    );
  }
}

enum HifzPageStrength {
  weak,
  steady,
  strong,
}

extension HifzPageStrengthX on HifzPageStrength {
  String get storageValue => switch (this) {
        HifzPageStrength.weak => 'weak',
        HifzPageStrength.steady => 'steady',
        HifzPageStrength.strong => 'strong',
      };

  String get label => switch (this) {
        HifzPageStrength.weak => 'Needs review',
        HifzPageStrength.steady => 'Steady',
        HifzPageStrength.strong => 'Strong',
      };

  int get priorityWeight => switch (this) {
        HifzPageStrength.weak => 3,
        HifzPageStrength.steady => 2,
        HifzPageStrength.strong => 1,
      };

  static HifzPageStrength fromStorageValue(String? value) {
    return HifzPageStrength.values.firstWhere(
      (strength) => strength.storageValue == value,
      orElse: () => HifzPageStrength.steady,
    );
  }
}

class ReaderHifzReviewEntry {
  const ReaderHifzReviewEntry({
    required this.pageNumber,
    required this.strength,
    required this.updatedAtIso,
    required this.reviewCount,
  });

  final int pageNumber;
  final HifzPageStrength strength;
  final String updatedAtIso;
  final int reviewCount;

  ReaderHifzReviewEntry copyWith({
    int? pageNumber,
    HifzPageStrength? strength,
    String? updatedAtIso,
    int? reviewCount,
  }) {
    return ReaderHifzReviewEntry(
      pageNumber: pageNumber ?? this.pageNumber,
      strength: strength ?? this.strength,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pageNumber': pageNumber,
      'strength': strength.storageValue,
      'updatedAtIso': updatedAtIso,
      'reviewCount': reviewCount,
    };
  }

  static ReaderHifzReviewEntry fromJson(Map<String, dynamic> json) {
    return ReaderHifzReviewEntry(
      pageNumber: (json['pageNumber'] as num? ?? 1).toInt(),
      strength: HifzPageStrengthX.fromStorageValue(json['strength'] as String?),
      updatedAtIso: json['updatedAtIso'] as String? ?? '',
      reviewCount: (json['reviewCount'] as num? ?? 0).toInt(),
    );
  }
}

enum ReaderSyncMode {
  localOnly,
  backupExport,
  cloudReady,
}

extension ReaderSyncModeX on ReaderSyncMode {
  String get storageValue => switch (this) {
        ReaderSyncMode.localOnly => 'localOnly',
        ReaderSyncMode.backupExport => 'backupExport',
        ReaderSyncMode.cloudReady => 'cloudReady',
      };

  String get label => switch (this) {
        ReaderSyncMode.localOnly => 'Local only',
        ReaderSyncMode.backupExport => 'Backup export',
        ReaderSyncMode.cloudReady => 'Cloud-ready',
      };

  String get subtitle => switch (this) {
        ReaderSyncMode.localOnly =>
          'Keep bookmarks, notes, and progress only on this device.',
        ReaderSyncMode.backupExport =>
          'Use export files as a manual backup between devices.',
        ReaderSyncMode.cloudReady =>
          'Push and pull bookmarks, notes, progress, and hifz data through the admin backend.',
      };

  static ReaderSyncMode fromStorageValue(String? value) {
    return ReaderSyncMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => ReaderSyncMode.localOnly,
    );
  }
}

class ReaderExperienceSettings {
  const ReaderExperienceSettings({
    required this.largerTextMode,
    required this.highContrastMode,
    required this.reducedMotion,
    required this.tajweedMode,
    required this.recitationSyncEnabled,
    required this.syncMode,
  });

  const ReaderExperienceSettings.defaults()
      : largerTextMode = false,
        highContrastMode = false,
        reducedMotion = false,
        tajweedMode = false,
        recitationSyncEnabled = true,
        syncMode = ReaderSyncMode.localOnly;

  final bool largerTextMode;
  final bool highContrastMode;
  final bool reducedMotion;
  final bool tajweedMode;
  final bool recitationSyncEnabled;
  final ReaderSyncMode syncMode;

  ReaderExperienceSettings copyWith({
    bool? largerTextMode,
    bool? highContrastMode,
    bool? reducedMotion,
    bool? tajweedMode,
    bool? recitationSyncEnabled,
    ReaderSyncMode? syncMode,
  }) {
    return ReaderExperienceSettings(
      largerTextMode: largerTextMode ?? this.largerTextMode,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      tajweedMode: tajweedMode ?? this.tajweedMode,
      recitationSyncEnabled:
          recitationSyncEnabled ?? this.recitationSyncEnabled,
      syncMode: syncMode ?? this.syncMode,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'largerTextMode': largerTextMode,
      'highContrastMode': highContrastMode,
      'reducedMotion': reducedMotion,
      'tajweedMode': tajweedMode,
      'recitationSyncEnabled': recitationSyncEnabled,
      'syncMode': syncMode.storageValue,
    };
  }

  static ReaderExperienceSettings fromJson(Map<String, dynamic> json) {
    return ReaderExperienceSettings(
      largerTextMode: json['largerTextMode'] as bool? ?? false,
      highContrastMode: json['highContrastMode'] as bool? ?? false,
      reducedMotion: json['reducedMotion'] as bool? ?? false,
      tajweedMode: json['tajweedMode'] as bool? ?? false,
      recitationSyncEnabled: json['recitationSyncEnabled'] as bool? ?? true,
      syncMode: ReaderSyncModeX.fromStorageValue(
        json['syncMode'] as String?,
      ),
    );
  }
}

enum OfflinePackState {
  adminManaged,
  localOnly,
  planned,
}

extension OfflinePackStateX on OfflinePackState {
  String get label => switch (this) {
        OfflinePackState.adminManaged => 'Admin-managed',
        OfflinePackState.localOnly => 'Local only',
        OfflinePackState.planned => 'Pack-ready',
      };
}

class OfflineEditionPack {
  const OfflineEditionPack({
    required this.edition,
    required this.state,
  });

  final MushafEdition edition;
  final OfflinePackState state;

  String get title => edition.label;

  String get subtitle => switch (state) {
        OfflinePackState.adminManaged =>
          '${edition.bestUseLabel}. This edition is currently controlled by the admin dashboard.',
        OfflinePackState.localOnly =>
          '${edition.bestUseLabel}. Keep this as a local-only pack on your device.',
        OfflinePackState.planned =>
          '${edition.bestUseLabel}. Best candidate for a future downloadable edition pack.',
      };
}
