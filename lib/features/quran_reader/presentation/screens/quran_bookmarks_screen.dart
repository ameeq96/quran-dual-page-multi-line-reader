import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/reader_bookmarks_sheet.dart';

class QuranBookmarksScreen extends StatelessWidget {
  const QuranBookmarksScreen({
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
              child: ReaderBookmarksContent(
                controller: controller,
                showHandle: false,
                onSelectPage: (pageNumber) async {
                  Navigator.of(context).pop(pageNumber);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
