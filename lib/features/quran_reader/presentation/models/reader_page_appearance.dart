import 'package:flutter/material.dart';

import '../../domain/models/reader_settings.dart';

class ReaderPageAppearance {
  const ReaderPageAppearance({
    required this.baseColor,
    required this.baseColorSecondary,
    required this.borderColor,
    required this.textColor,
    required this.accentColor,
    required this.placeholderLineColor,
    required this.pageNumberBackgroundColor,
    required this.pageNumberForegroundColor,
    required this.imageTintColor,
    required this.imageTintOpacity,
    required this.overlayColor,
    required this.overlayOpacity,
    required this.reflectionColor,
    required this.sideShadowColor,
    required this.outerShadowColor,
    required this.pageBrightness,
    required this.nightMode,
    required this.showOverlay,
    required this.showReflection,
  });

  final Color baseColor;
  final Color baseColorSecondary;
  final Color borderColor;
  final Color textColor;
  final Color accentColor;
  final Color placeholderLineColor;
  final Color pageNumberBackgroundColor;
  final Color pageNumberForegroundColor;
  final Color imageTintColor;
  final double imageTintOpacity;
  final Color overlayColor;
  final double overlayOpacity;
  final Color reflectionColor;
  final Color sideShadowColor;
  final Color outerShadowColor;
  final double pageBrightness;
  final bool nightMode;
  final bool showOverlay;
  final bool showReflection;

  bool get hasImageTint => imageTintOpacity > 0.001;
  bool get needsBrightnessFilter => (pageBrightness - 1.0).abs() > 0.001;

  static const invertImageMatrix = <double>[
    -1,
    0,
    0,
    0,
    255,
    0,
    -1,
    0,
    0,
    255,
    0,
    0,
    -1,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> brightnessMatrix() {
    final offset = (pageBrightness - 1.0) * 255;
    return <double>[
      1,
      0,
      0,
      0,
      offset,
      0,
      1,
      0,
      0,
      offset,
      0,
      0,
      1,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  factory ReaderPageAppearance.resolve({
    required ThemeData theme,
    required ReaderSettings settings,
  }) {
    final isNight = settings.nightMode;
    final preset =
        settings.pagePresetEnabled ? settings.pagePreset : PagePreset.classic;

    final baseColors = _resolveBaseColors(preset, isNight);
    final textColor = _resolveTextColor(isNight);
    final accentColor = _resolveAccentColor(preset, isNight, theme);
    final imageTintColor = accentColor;
    final imageTintOpacity =
        settings.pagePresetEnabled ? (isNight ? 0.08 : 0.04) : 0.0;

    return ReaderPageAppearance(
      baseColor: baseColors.$1,
      baseColorSecondary: baseColors.$2,
      borderColor: accentColor.withOpacity(isNight ? 0.38 : 0.24),
      textColor: textColor,
      accentColor: accentColor,
      placeholderLineColor: textColor.withOpacity(isNight ? 0.22 : 0.12),
      pageNumberBackgroundColor: isNight
          ? const Color(0xFF111613).withOpacity(0.92)
          : Colors.white.withOpacity(0.9),
      pageNumberForegroundColor: textColor,
      imageTintColor: imageTintColor,
      imageTintOpacity: imageTintOpacity,
      overlayColor: accentColor,
      overlayOpacity:
          settings.pageOverlayEnabled ? (isNight ? 0.12 : 0.08) : 0.0,
      reflectionColor: Colors.white.withOpacity(isNight ? 0.06 : 0.12),
      sideShadowColor: Colors.black.withOpacity(isNight ? 0.28 : 0.16),
      outerShadowColor: Colors.black.withOpacity(isNight ? 0.28 : 0.12),
      pageBrightness:
          settings.customBrightnessEnabled ? settings.pageBrightness : 1.0,
      nightMode: isNight,
      showOverlay: settings.pageOverlayEnabled,
      showReflection: settings.pageReflectionEnabled,
    );
  }

  static (Color, Color) _resolveBaseColors(PagePreset preset, bool isNight) {
    return switch ((preset, isNight)) {
      (PagePreset.classic, false) => (
          const Color(0xFFF9F3E8),
          const Color(0xFFF4EBDD)
        ),
      (PagePreset.warm, false) => (
          const Color(0xFFF6E7D0),
          const Color(0xFFECDABD)
        ),
      (PagePreset.emerald, false) => (
          const Color(0xFFEDF4EE),
          const Color(0xFFE3EEE5)
        ),
      (PagePreset.slate, false) => (
          const Color(0xFFF1F3F6),
          const Color(0xFFE6EAF0)
        ),
      (PagePreset.classic, true) => (
          const Color(0xFF1D170F),
          const Color(0xFF2A2218)
        ),
      (PagePreset.warm, true) => (
          const Color(0xFF24190F),
          const Color(0xFF322316)
        ),
      (PagePreset.emerald, true) => (
          const Color(0xFF111C17),
          const Color(0xFF172821)
        ),
      (PagePreset.slate, true) => (
          const Color(0xFF151A1F),
          const Color(0xFF1E252D)
        ),
    };
  }

  static Color _resolveAccentColor(
    PagePreset preset,
    bool isNight,
    ThemeData theme,
  ) {
    return switch ((preset, isNight)) {
      (PagePreset.classic, false) => const Color(0xFF1B6B5D),
      (PagePreset.warm, false) => const Color(0xFF9C6B2D),
      (PagePreset.emerald, false) => const Color(0xFF2B7A63),
      (PagePreset.slate, false) => const Color(0xFF51657F),
      (PagePreset.classic, true) => const Color(0xFFE6D3A3),
      (PagePreset.warm, true) => const Color(0xFFF0C686),
      (PagePreset.emerald, true) => const Color(0xFF9EE1C2),
      (PagePreset.slate, true) => const Color(0xFFC7D4E9),
    };
  }

  static Color _resolveTextColor(bool isNight) {
    return isNight ? const Color(0xFFF1E4BD) : const Color(0xFF21180F);
  }
}
