import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';

class QuranNavigationDataSource {
  static const _assetPath = 'assets/quran_pages/quran_navigation_index.json';
  static const _overrideAssetPath =
      'assets/quran_pages/taj_navigation_overrides.json';

  final List<QuranSurahNavigationEntry> _surahs = <QuranSurahNavigationEntry>[];
  final List<QuranJuzNavigationEntry> _juzs = <QuranJuzNavigationEntry>[];
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      final jsonString = await rootBundle.loadString(_assetPath);
      final payload = json.decode(jsonString) as Map<String, dynamic>;
      final overridePayload = await _loadOverridePayload();
      final surahOverrides = _parseOverrideMap(
        overridePayload?['surahStartPages'],
      );
      final juzOverrides = _parseOverrideMap(
        overridePayload?['siparaStartPages'],
      );

      final surahJson = payload['surahs'] as List<dynamic>? ?? const [];
      final juzJson = payload['siparas'] as List<dynamic>? ?? const [];

      _surahs
        ..clear()
        ..addAll(
          surahJson.map((entry) {
            final item = entry as Map<String, dynamic>;
            return QuranSurahNavigationEntry(
              id: item['id'] as int,
              nameSimple: item['nameSimple'] as String,
              nameComplex: item['nameComplex'] as String,
              nameArabic: item['nameArabic'] as String,
              translatedName: item['translatedName'] as String,
              standardStartPage: item['standardStartPage'] as int,
              tajScanStartPage: surahOverrides[item['id'] as int] ??
                  item['tajScanStartPage'] as int,
            );
          }),
        );

      _juzs
        ..clear()
        ..addAll(
          juzJson.map((entry) {
            final item = entry as Map<String, dynamic>;
            return QuranJuzNavigationEntry(
              number: item['number'] as int,
              name: item['name'] as String,
              nameArabic: item['nameArabic'] as String,
              standardStartPage: item['standardStartPage'] as int,
              tajScanStartPage: juzOverrides[item['number'] as int] ??
                  item['tajScanStartPage'] as int,
            );
          }),
        );
    } catch (_) {
      _surahs.clear();
      _juzs.clear();
    }

    _isInitialized = true;
  }

  List<QuranSurahNavigationEntry> get surahs =>
      List<QuranSurahNavigationEntry>.unmodifiable(_surahs);

  List<QuranJuzNavigationEntry> get juzs =>
      List<QuranJuzNavigationEntry>.unmodifiable(_juzs);

  Future<Map<String, dynamic>?> _loadOverridePayload() async {
    try {
      final jsonString = await rootBundle.loadString(_overrideAssetPath);
      final payload = json.decode(jsonString);
      if (payload is Map<String, dynamic>) {
        return payload;
      }
    } catch (_) {
      // Override asset is optional.
    }
    return null;
  }

  Map<int, int> _parseOverrideMap(dynamic rawValue) {
    if (rawValue is! Map) {
      return const {};
    }

    final parsed = <int, int>{};
    for (final entry in rawValue.entries) {
      final key = int.tryParse(entry.key.toString());
      final value = int.tryParse(entry.value.toString());
      if (key != null && value != null && value > 0) {
        parsed[key] = value;
      }
    }
    return parsed;
  }
}
