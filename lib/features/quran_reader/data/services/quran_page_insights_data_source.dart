import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/quran_chapter_summary.dart';
import '../../domain/models/quran_page_insight.dart';
import '../../domain/models/reader_admin_config.dart';

class QuranPageInsightsDataSource {
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const String _bundledPageInsightsAssetPath =
      'assets/quran_pages/quran_page_insights.json';

  QuranPageInsightsDataSource({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Map<int, QuranPageInsight> _pages = <int, QuranPageInsight>{};
  final Map<int, QuranPageInsight> _surahInsights = {};
  final Map<int, QuranChapterSummary> _chapters = <int, QuranChapterSummary>{};
  final http.Client _client;
  bool _isInitialized = false;

  Future<void> initialize({
    ReaderAdminConfig? adminConfig,
    bool forceRefresh = false,
  }) async {
    if (_isInitialized) {
      if (!forceRefresh) {
        return;
      }
      _isInitialized = false;
    }

    try {
      _surahInsights.clear();
      final payload = await _loadPayload(adminConfig);

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
      rethrow;
    }

    _isInitialized = true;
  }

  QuranPageInsight? pageForNumber(int pageNumber) => _pages[pageNumber];

  QuranChapterSummary? chapterForId(int chapterId) => _chapters[chapterId];

  Iterable<QuranPageInsight> get pages => _pages.values;

  Iterable<QuranChapterSummary> get chapters => _chapters.values;

  QuranPageInsight? insightForChapter(int chapterId) {
    final cached = _surahInsights[chapterId];
    if (cached != null) return cached;
    final verses = _pages.values.expand((page) => page.verses)
        .where((verse) => verse.chapterId == chapterId).toList()
      ..sort((a, b) => a.verseNumber.compareTo(b.verseNumber));
    if (verses.isEmpty) return null;
    final insight = QuranPageInsight(
      pageNumber: _chapters[chapterId]?.pages.first ?? 1,
      chapterIds: [chapterId],
      juzNumbers: verses.map((v) => v.juzNumber).toSet().toList(),
      hizbNumbers: verses.map((v) => v.hizbNumber).toSet().toList(),
      rubElHizbNumbers: verses.map((v) => v.rubElHizbNumber).toSet().toList(),
      rukuNumbers: verses.map((v) => v.rukuNumber).toSet().toList(),
      manzilNumbers: verses.map((v) => v.manzilNumber).toSet().toList(),
      sajdahVerseKeys: verses.where((v) => v.sajdahNumber != null).map((v) => v.verseKey).toList(),
      translationEn: verses.map((v) => '${v.verseKey}  ${v.translationEn}').join('\n\n'),
      translationUr: verses.map((v) => '${v.verseKey}  ${v.translationUr}').join('\n\n'),
      verses: verses,
    );
    _surahInsights[chapterId] = insight;
    return insight;
  }

  int? canonicalPageForVerse(String verseKey) {
    for (final page in _pages.values) {
      if (page.verses.any((verse) => verse.verseKey == verseKey)) return page.pageNumber;
    }
    return null;
  }

  Future<Map<String, dynamic>> _loadPayload(
      ReaderAdminConfig? adminConfig) async {
    final remoteDataset = adminConfig?.contentDataset('page_insights');
    try {
      if (remoteDataset == null || remoteDataset.url.trim().isEmpty) {
        throw StateError('Admin dataset "page_insights" is not configured.');
      }
      final response = await _client.get(
        Uri.parse(remoteDataset.url),
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        return compute(_decodePageInsightsPayload, response.body);
      }
      throw StateError(
        'Admin dataset "page_insights" request failed with status ${response.statusCode}.',
      );
    } catch (_) {
      try {
        final payload =
            await rootBundle.loadString(_bundledPageInsightsAssetPath);
        return compute(_decodePageInsightsPayload, payload);
      } catch (_) {
        throw StateError(
          'Unable to load page insights from API or local assets.',
        );
      }
    }
  }
}

Map<String, dynamic> _decodePageInsightsPayload(String responseBody) {
  final payload = json.decode(responseBody);
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  throw StateError('Page insights payload returned invalid JSON.');
}
