import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';
import '../widgets/app_page_header.dart';
import '../widgets/reader_search_sheet.dart';

class QuranSearchScreen extends StatelessWidget {
  const QuranSearchScreen({
    super.key,
    required this.title,
    required this.initialTab,
    required this.nightMode,
    this.showTabs = true,
    required this.surahs,
    required this.juzs,
    required this.surahPageResolver,
    required this.juzPageResolver,
    required this.surahSearch,
    required this.juzSearch,
  });

  final String title;
  final int initialTab;
  final bool nightMode;
  final bool showTabs;
  final List<QuranSurahNavigationEntry> surahs;
  final List<QuranJuzNavigationEntry> juzs;
  final int Function(QuranSurahNavigationEntry entry) surahPageResolver;
  final int Function(QuranJuzNavigationEntry entry) juzPageResolver;
  final Future<List<QuranSurahNavigationEntry>> Function(String query)
      surahSearch;
  final Future<List<QuranJuzNavigationEntry>> Function(String query) juzSearch;

  @override
  Widget build(BuildContext context) {
    final themeData = nightMode ? AppTheme.dark() : AppTheme.light();

    return Theme(
      data: themeData,
      child: Builder(
        builder: (context) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            // Zero-height bar: keeps the status bar styling and top inset
            // while the hero header in the body carries title and back.
            appBar: AppBar(toolbarHeight: 0, automaticallyImplyLeading: false),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final content = ReaderSearchContent(
                        surahs: surahs,
                        juzs: juzs,
                        initialTab: initialTab,
                        showHandle: false,
                        showTabs: showTabs,
                        applyKeyboardInset: false,
                        surahPageResolver: surahPageResolver,
                        juzPageResolver: juzPageResolver,
                        surahSearch: surahSearch,
                        juzSearch: juzSearch,
                      );
                      // Very short viewports keep the list usable by
                      // dropping to the slimmest header.
                      final roomy = constraints.maxHeight >= 420;
                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                              20,
                              roomy ? 12 : 6,
                              20,
                              0,
                            ),
                            child: AppPageHeader(
                              title: tr(context, title),
                              icon: roomy ? Icons.search_rounded : null,
                              compact: true,
                              onBack: AppPageHeader.popAction(context),
                            ),
                          ),
                          Expanded(child: content),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
