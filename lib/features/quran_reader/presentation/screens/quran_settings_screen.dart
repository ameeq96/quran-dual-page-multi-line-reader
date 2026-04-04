import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
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
    return ValueListenableBuilder<ReaderSettings>(
      valueListenable: controller.settingsListenable,
      builder: (context, settings, _) {
        return Theme(
          data: settings.nightMode ? AppTheme.dark() : AppTheme.light(),
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
