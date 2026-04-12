import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/reader_settings_sheet.dart';

class QuranSettingsScreen extends StatelessWidget {
  const QuranSettingsScreen({
    super.key,
    required this.controller,
  });

  final QuranReaderController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller.settingsListenable,
        controller.experienceListenable,
      ]),
      builder: (context, _) {
        final settings = controller.settings;
        final experience = controller.experienceSettings;
        return Theme(
          data: settings.nightMode
              ? AppTheme.dark(
                  highContrast: experience.highContrastMode,
                  largerText: experience.largerTextMode,
                )
              : AppTheme.light(
                  highContrast: experience.highContrastMode,
                  largerText: experience.largerTextMode,
                ),
          child: Scaffold(
            body: SafeArea(
              child: ReaderSettingsSheet(
                settings: settings,
                availableImageEditions: controller.availableImageEditions,
                showHandle: false,
                onSelectMushafEdition: controller.selectMushafEdition,
                onToggleFullscreen: controller.toggleFullscreen,
                onTogglePageNumbers: controller.togglePageNumbers,
                onToggleCustomBrightness: controller.toggleCustomBrightness,
                onBrightnessChanged: controller.setPageBrightness,
                onToggleNightMode: controller.toggleNightMode,
                onTogglePagePreset: controller.togglePagePreset,
                onSelectPagePreset: controller.setPagePreset,
                onTogglePageOverlay: controller.togglePageOverlay,
                onTogglePageReflection: controller.togglePageReflection,
                onToggleLowMemoryMode: controller.toggleLowMemoryMode,
                onToggleHifzFocusMode: controller.toggleHifzFocusMode,
                onHifzMaskHeightFactorChanged:
                    controller.setHifzMaskHeightFactor,
                onToggleHifzRevealOnHold: controller.toggleHifzRevealOnHold,
              ),
            ),
          ),
        );
      },
    );
  }
}
