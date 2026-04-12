import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/reader_bookmarks_sheet.dart';
import '../widgets/reader_skeleton.dart';

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
              child: controller.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ReaderSkeletonBlock(height: 28, width: 180),
                          SizedBox(height: 16),
                          ReaderSkeletonBlock(height: 120),
                          SizedBox(height: 12),
                          ReaderSkeletonBlock(height: 120),
                          SizedBox(height: 12),
                          ReaderSkeletonBlock(height: 120),
                        ],
                      ),
                    )
                  : ReaderBookmarksContent(
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
