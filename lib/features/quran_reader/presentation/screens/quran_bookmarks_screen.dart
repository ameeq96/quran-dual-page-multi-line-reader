import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/app_page_header.dart';
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
            // Zero-height bar: keeps the status bar styling and top inset
            // while the hero header in the body carries title and back.
            appBar: AppBar(toolbarHeight: 0, automaticallyImplyLeading: false),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: SafeArea(
                  child: controller.isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppPageHeader(
                                eyebrow: tr(context, 'Saved places'),
                                title: tr(context, 'Bookmarks'),
                                icon: Icons.bookmarks_rounded,
                                onBack: AppPageHeader.popAction(context),
                              ),
                              const SizedBox(height: 16),
                              const ReaderSkeletonBlock(height: 120),
                              const SizedBox(height: 12),
                              const ReaderSkeletonBlock(height: 120),
                              const SizedBox(height: 12),
                              const ReaderSkeletonBlock(height: 120),
                            ],
                          ),
                        )
                      : ReaderBookmarksContent(
                          controller: controller,
                          showHandle: false,
                          eyebrow: tr(context, 'Saved places'),
                          onBack: AppPageHeader.popAction(context),
                          onSelectPage: (pageNumber) async {
                            Navigator.of(context).pop(pageNumber);
                          },
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
