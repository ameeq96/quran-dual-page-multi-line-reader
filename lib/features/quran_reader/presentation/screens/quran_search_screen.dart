import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_navigation_marker.dart';
import '../../domain/models/quran_search_result.dart';
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
    required this.rukuMarkers,
    required this.hizbMarkers,
    required this.manzilMarkers,
    required this.rubMarkers,
    required this.currentPage,
    required this.maxPage,
    required this.surahPageResolver,
    required this.juzPageResolver,
    required this.surahSearch,
    required this.juzSearch,
    required this.markerSearch,
    required this.ayahSearch,
    required this.textSearch,
  });

  final String title;
  final int initialTab;
  final bool nightMode;
  final bool showTabs;
  final List<QuranSurahNavigationEntry> surahs;
  final List<QuranJuzNavigationEntry> juzs;
  final List<QuranNavigationMarker> rukuMarkers;
  final List<QuranNavigationMarker> hizbMarkers;
  final List<QuranNavigationMarker> manzilMarkers;
  final List<QuranNavigationMarker> rubMarkers;
  final int currentPage;
  final int maxPage;
  final int Function(QuranSurahNavigationEntry entry) surahPageResolver;
  final int Function(QuranJuzNavigationEntry entry) juzPageResolver;
  final Future<List<QuranSurahNavigationEntry>> Function(String query)
      surahSearch;
  final Future<List<QuranJuzNavigationEntry>> Function(String query) juzSearch;
  final Future<List<QuranNavigationMarker>> Function(
    String query, {
    required String category,
  }) markerSearch;
  final Future<List<QuranSearchResult>> Function(String query) ayahSearch;
  final Future<List<QuranSearchResult>> Function(String query) textSearch;

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
                rukuMarkers: rukuMarkers,
                hizbMarkers: hizbMarkers,
                manzilMarkers: manzilMarkers,
                rubMarkers: rubMarkers,
                currentPage: currentPage,
                maxPage: maxPage,
                initialTab: initialTab,
                showHandle: false,
                showTabs: showTabs,
                applyKeyboardInset: false,
                surahPageResolver: surahPageResolver,
                juzPageResolver: juzPageResolver,
                surahSearch: surahSearch,
                juzSearch: juzSearch,
                markerSearch: markerSearch,
                ayahSearch: ayahSearch,
                textSearch: textSearch,
              ),
            ),
          );
        },
      ),
    );
  }
}
