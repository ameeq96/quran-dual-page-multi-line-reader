import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';
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
            body: SafeArea(
              child: ReaderSearchContent(
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
              ),
            ),
          );
        },
      ),
    );
  }
}
