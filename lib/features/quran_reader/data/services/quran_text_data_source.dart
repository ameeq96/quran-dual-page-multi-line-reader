import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quran_text_page_data.dart';

class QuranTextDataSource {
  static const _assetPath = 'assets/quran_pages/quran_text_by_page.json';

  final Map<int, QuranTextPageData> _pages = <int, QuranTextPageData>{};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final payload = json.decode(jsonString) as Map<String, dynamic>;
      final pagesJson = payload['pages'] as List<dynamic>? ?? const <dynamic>[];
      _pages
        ..clear()
        ..addEntries(
          pagesJson.map((entry) {
            final pageData =
                QuranTextPageData.fromJson(entry as Map<String, dynamic>);
            return MapEntry(pageData.pageNumber, pageData);
          }),
        );
    } catch (_) {
      _pages.clear();
    }

    _isInitialized = true;
  }

  bool get hasTextPages => _pages.isNotEmpty;
  int get totalPages => _pages.length;
  Iterable<QuranTextPageData> get pages => _pages.values;

  QuranTextPageData? pageForNumber(int pageNumber) {
    return _pages[pageNumber];
  }
}
