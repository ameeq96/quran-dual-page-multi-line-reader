enum PagePreset {
  classic,
  warm,
  emerald,
  slate,
}

enum MushafEdition {
  lines10,
  lines13,
  lines14,
  lines15,
  lines16,
  lines17,
  kanzulIman,
}

extension MushafEditionX on MushafEdition {
  String get storageValue => switch (this) {
        MushafEdition.lines10 => '10_lines',
        MushafEdition.lines13 => '13_lines',
        MushafEdition.lines14 => '14_lines',
        MushafEdition.lines15 => '15_lines',
        MushafEdition.lines16 => '16_lines',
        MushafEdition.lines17 => '17_lines',
        MushafEdition.kanzulIman => 'kanzul_iman',
      };

  String get label => switch (this) {
        MushafEdition.lines10 => '10 lines',
        MushafEdition.lines13 => '13 lines',
        MushafEdition.lines14 => '14 lines',
        MushafEdition.lines15 => '15 lines',
        MushafEdition.lines16 => '16 lines',
        MushafEdition.lines17 => '17 lines',
        MushafEdition.kanzulIman => 'Kanzul Iman',
      };

  String get shortLabel => switch (this) {
        MushafEdition.lines10 => '10',
        MushafEdition.lines13 => '13',
        MushafEdition.lines14 => '14',
        MushafEdition.lines15 => '15',
        MushafEdition.lines16 => '16',
        MushafEdition.lines17 => '17',
        MushafEdition.kanzulIman => 'KI',
      };

  int? get lineCount => switch (this) {
        MushafEdition.lines10 => 10,
        MushafEdition.lines13 => 13,
        MushafEdition.lines14 => 14,
        MushafEdition.lines15 => 15,
        MushafEdition.lines16 => 16,
        MushafEdition.lines17 => 17,
        MushafEdition.kanzulIman => null,
      };

  String get companyLabel => switch (this) {
        MushafEdition.lines10 => 'Pak Company',
        MushafEdition.lines13 => 'Qudrat Ullah Company',
        MushafEdition.lines14 => 'Pak Company',
        MushafEdition.lines15 => 'Qudrat Ullah Company',
        MushafEdition.lines16 => 'Taj Company',
        MushafEdition.lines17 => 'Taj Company',
        MushafEdition.kanzulIman => 'Kanzul Iman',
      };

  String get commonRegionLabel => switch (this) {
        MushafEdition.lines10 => 'South Asia large-print use',
        MushafEdition.lines13 => 'Pakistan and India',
        MushafEdition.lines14 => 'Pak print readers',
        MushafEdition.lines15 => 'Pakistan hifz and daily tilawat',
        MushafEdition.lines16 => 'Pakistan, India, Bangladesh',
        MushafEdition.lines17 => 'South Asia decorative print',
        MushafEdition.kanzulIman => 'Urdu study and tafsir readers',
      };

  String get bestUseLabel => switch (this) {
        MushafEdition.lines10 => 'Large script reading',
        MushafEdition.lines13 => 'Compact page memory',
        MushafEdition.lines14 => 'Balanced print density',
        MushafEdition.lines15 => 'Hifz and common Pakistani layout',
        MushafEdition.lines16 => 'Taj-style Mushaf experience',
        MushafEdition.lines17 => 'Dense scan comparison',
        MushafEdition.kanzulIman => 'Translation and tafsir study',
      };

  String get historySummary => switch (this) {
        MushafEdition.lines10 =>
          'Large-script Pakistani scan with fewer lines per page for easier single-page reading.',
        MushafEdition.lines13 =>
          'Compact 13-line Pakistani print often used where a lighter page count and tighter layout is preferred.',
        MushafEdition.lines14 =>
          'A balanced Pak-company layout sitting between compact and standard hifz-oriented prints.',
        MushafEdition.lines15 =>
          'A very common Pakistani Mushaf layout, especially familiar to many huffaz and madrasa readers.',
        MushafEdition.lines16 =>
          'The Taj-style 16-line experience, widely recognized across South Asia for physical Mushaf reading.',
        MushafEdition.lines17 =>
          'A denser decorative print style that is useful for edition comparison and visual research.',
        MushafEdition.kanzulIman =>
          'An Urdu translation and tafsir presentation built for reflective study, not just page memorization.',
      };

  static MushafEdition fromStorageValue(String? value) {
    return MushafEdition.values.firstWhere(
      (edition) => edition.storageValue == value,
      orElse: () => MushafEdition.lines16,
    );
  }
}

extension PagePresetX on PagePreset {
  String get storageValue => switch (this) {
        PagePreset.classic => 'classic',
        PagePreset.warm => 'warm',
        PagePreset.emerald => 'emerald',
        PagePreset.slate => 'slate',
      };

  String get label => switch (this) {
        PagePreset.classic => 'Classic',
        PagePreset.warm => 'Warm',
        PagePreset.emerald => 'Emerald',
        PagePreset.slate => 'Slate',
      };

  static PagePreset fromStorageValue(String? value) {
    return PagePreset.values.firstWhere(
      (preset) => preset.storageValue == value,
      orElse: () => PagePreset.classic,
    );
  }
}

class ReaderSettings {
  const ReaderSettings({
    required this.mushafEdition,
    required this.fullscreenReading,
    required this.showPageNumbers,
    required this.preferImageMode,
    required this.customBrightnessEnabled,
    required this.pageBrightness,
    required this.nightMode,
    required this.pagePresetEnabled,
    required this.pagePreset,
    required this.pageOverlayEnabled,
    required this.pageReflectionEnabled,
    required this.lowMemoryMode,
    required this.hifzFocusMode,
    required this.hifzMaskHeightFactor,
    required this.hifzRevealOnHold,
  });

  const ReaderSettings.defaults()
      : mushafEdition = MushafEdition.lines16,
        fullscreenReading = false,
        showPageNumbers = true,
        preferImageMode = true,
        customBrightnessEnabled = false,
        pageBrightness = 1.0,
        nightMode = false,
        pagePresetEnabled = false,
        pagePreset = PagePreset.classic,
        pageOverlayEnabled = false,
        pageReflectionEnabled = true,
        lowMemoryMode = false,
        hifzFocusMode = false,
        hifzMaskHeightFactor = 0.42,
        hifzRevealOnHold = true;

  final MushafEdition mushafEdition;
  final bool fullscreenReading;
  final bool showPageNumbers;
  final bool preferImageMode;
  final bool customBrightnessEnabled;
  final double pageBrightness;
  final bool nightMode;
  final bool pagePresetEnabled;
  final PagePreset pagePreset;
  final bool pageOverlayEnabled;
  final bool pageReflectionEnabled;
  final bool lowMemoryMode;
  final bool hifzFocusMode;
  final double hifzMaskHeightFactor;
  final bool hifzRevealOnHold;

  ReaderSettings copyWith({
    MushafEdition? mushafEdition,
    bool? fullscreenReading,
    bool? showPageNumbers,
    bool? preferImageMode,
    bool? customBrightnessEnabled,
    double? pageBrightness,
    bool? nightMode,
    bool? pagePresetEnabled,
    PagePreset? pagePreset,
    bool? pageOverlayEnabled,
    bool? pageReflectionEnabled,
    bool? lowMemoryMode,
    bool? hifzFocusMode,
    double? hifzMaskHeightFactor,
    bool? hifzRevealOnHold,
  }) {
    return ReaderSettings(
      mushafEdition: mushafEdition ?? this.mushafEdition,
      fullscreenReading: fullscreenReading ?? this.fullscreenReading,
      showPageNumbers: showPageNumbers ?? this.showPageNumbers,
      preferImageMode: preferImageMode ?? this.preferImageMode,
      customBrightnessEnabled:
          customBrightnessEnabled ?? this.customBrightnessEnabled,
      pageBrightness: (pageBrightness ?? this.pageBrightness).clamp(0.7, 1.25),
      nightMode: nightMode ?? this.nightMode,
      pagePresetEnabled: pagePresetEnabled ?? this.pagePresetEnabled,
      pagePreset: pagePreset ?? this.pagePreset,
      pageOverlayEnabled: pageOverlayEnabled ?? this.pageOverlayEnabled,
      pageReflectionEnabled:
          pageReflectionEnabled ?? this.pageReflectionEnabled,
      lowMemoryMode: lowMemoryMode ?? this.lowMemoryMode,
      hifzFocusMode: hifzFocusMode ?? this.hifzFocusMode,
      hifzMaskHeightFactor:
          (hifzMaskHeightFactor ?? this.hifzMaskHeightFactor).clamp(0.18, 0.7),
      hifzRevealOnHold: hifzRevealOnHold ?? this.hifzRevealOnHold,
    );
  }
}
