import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/quran_chapter_summary.dart';
import '../../domain/models/quran_page_insight.dart';

class QuranPageInsightsDataSource {
  static const _assetPath = 'assets/quran_pages/quran_page_insights.json';

  final Map<int, QuranPageInsight> _pages = <int, QuranPageInsight>{};
  final Map<int, QuranChapterSummary> _chapters = <int, QuranChapterSummary>{};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final payload = json.decode(jsonString) as Map<String, dynamic>;

      final pagesJson = payload['pages'] as List<dynamic>? ?? const [];
      final chaptersJson = payload['chapters'] as List<dynamic>? ?? const [];

      _pages
        ..clear()
        ..addEntries(
          pagesJson.map((entry) {
            final pageData =
                QuranPageInsight.fromJson(entry as Map<String, dynamic>);
            return MapEntry(pageData.pageNumber, pageData);
          }),
        );

      _chapters
        ..clear()
        ..addEntries(
          chaptersJson.map((entry) {
            final chapter =
                QuranChapterSummary.fromJson(entry as Map<String, dynamic>);
            return MapEntry(chapter.id, chapter);
          }),
        );
    } catch (_) {
      _pages.clear();
      _chapters.clear();
    }

    _isInitialized = true;
  }

  QuranPageInsight? pageForNumber(int pageNumber) => _pages[pageNumber];

  QuranChapterSummary? chapterForId(int chapterId) => _chapters[chapterId];

  Iterable<QuranPageInsight> get pages => _pages.values;

  Iterable<QuranChapterSummary> get chapters => _chapters.values;
}
