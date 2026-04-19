import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_settings.dart';

class QuranNavigationDataSource {
  static const String _legacyNavigationAssetPath =
      'assets/quran_pages/quran_navigation_index.json';
  static const String _fallbackNavigationAssetPath =
      'assets/quran_pages/quran_navigation_index_16_line.json';
  static final Map<String, Map<String, dynamic>> _decodedPayloadCache =
      <String, Map<String, dynamic>>{};

  final List<QuranSurahNavigationEntry> _surahs = <QuranSurahNavigationEntry>[];
  final List<QuranJuzNavigationEntry> _juzs = <QuranJuzNavigationEntry>[];
  final Map<MushafEdition, List<QuranSurahNavigationEntry>> _surahsByEdition =
      <MushafEdition, List<QuranSurahNavigationEntry>>{};
  final Map<MushafEdition, List<QuranJuzNavigationEntry>> _juzsByEdition =
      <MushafEdition, List<QuranJuzNavigationEntry>>{};
  final List<QuranSurahNavigationEntry> _standardSurahs =
      <QuranSurahNavigationEntry>[];
  final List<QuranJuzNavigationEntry> _standardJuzs =
      <QuranJuzNavigationEntry>[];
  List<QuranSurahNavigationEntry> _surahsView =
      const <QuranSurahNavigationEntry>[];
  List<QuranJuzNavigationEntry> _juzsView = const <QuranJuzNavigationEntry>[];
  List<QuranSurahNavigationEntry> _standardSurahsView =
      const <QuranSurahNavigationEntry>[];
  List<QuranJuzNavigationEntry> _standardJuzsView =
      const <QuranJuzNavigationEntry>[];
  bool _isInitialized = false;
  MushafEdition? _activeEdition;

  Future<void> initialize({
    ReaderAdminConfig? adminConfig,
    MushafEdition? edition,
    bool forceRefresh = false,
  }) async {
    final normalizedEdition = edition ?? MushafEdition.lines16;
    if (_isInitialized &&
        !forceRefresh &&
        _activeEdition == normalizedEdition &&
        _standardSurahs.isNotEmpty &&
        _standardJuzs.isNotEmpty &&
        _surahsByEdition.containsKey(normalizedEdition) &&
        _juzsByEdition.containsKey(normalizedEdition)) {
      return;
    }

    _activeEdition = normalizedEdition;
    final previousSurahs = List<QuranSurahNavigationEntry>.from(_surahs);
    final previousJuzs = List<QuranJuzNavigationEntry>.from(_juzs);

    await _initializeStandardPayload(forceRefresh: forceRefresh);

    final bundledPayload = await _tryLoadBundledPayload(
      _bundledNavigationAssetPathForEdition(normalizedEdition),
      forceRefresh: forceRefresh,
    );
    if (bundledPayload != null) {
      _cacheEditionPayload(normalizedEdition, bundledPayload);
      _activateEdition(normalizedEdition);
    } else {
      final fallbackPayload = await _loadBestAvailablePayload(
        normalizedEdition,
        forceRefresh: forceRefresh,
      );
      if (fallbackPayload != null) {
        _setActiveEntries(
          _surahEntriesFromPayload(fallbackPayload),
          _juzEntriesFromPayload(fallbackPayload),
        );
      } else if (previousSurahs.isNotEmpty || previousJuzs.isNotEmpty) {
        _setActiveEntries(previousSurahs, previousJuzs);
      } else {
        _setActiveEntries(const [], const []);
      }
    }

    await _warmEditionCaches(
      forceRefresh: forceRefresh,
      excludeEdition: normalizedEdition,
    );
    if (_surahsByEdition.containsKey(normalizedEdition) &&
        _juzsByEdition.containsKey(normalizedEdition)) {
      _activateEdition(normalizedEdition);
    } else if (previousSurahs.isNotEmpty || previousJuzs.isNotEmpty) {
      _setActiveEntries(previousSurahs, previousJuzs);
    }

    _isInitialized = true;
  }

  List<QuranSurahNavigationEntry> get surahs => _surahsView;

  List<QuranJuzNavigationEntry> get juzs => _juzsView;

  List<QuranSurahNavigationEntry> get standardSurahs => _standardSurahsView;

  List<QuranJuzNavigationEntry> get standardJuzs => _standardJuzsView;

  List<QuranSurahNavigationEntry> surahsForEdition(MushafEdition edition) {
    final entries = _surahsByEdition[edition];
    if (entries != null) {
      return entries;
    }
    if (_activeEdition == edition) {
      return _surahsView;
    }
    return const <QuranSurahNavigationEntry>[];
  }

  List<QuranJuzNavigationEntry> juzsForEdition(MushafEdition edition) {
    final entries = _juzsByEdition[edition];
    if (entries != null) {
      return entries;
    }
    if (_activeEdition == edition) {
      return _juzsView;
    }
    return const <QuranJuzNavigationEntry>[];
  }

  void _setActiveEntries(
    List<QuranSurahNavigationEntry> surahs,
    List<QuranJuzNavigationEntry> juzs,
  ) {
    _surahs
      ..clear()
      ..addAll(surahs);
    _surahsView = List<QuranSurahNavigationEntry>.unmodifiable(_surahs);

    _juzs
      ..clear()
      ..addAll(juzs);
    _juzsView = List<QuranJuzNavigationEntry>.unmodifiable(_juzs);
  }

  void _cacheEditionPayload(
    MushafEdition edition,
    Map<String, dynamic> payload,
  ) {
    _surahsByEdition[edition] = List<QuranSurahNavigationEntry>.unmodifiable(
      _surahEntriesFromPayload(payload),
    );
    _juzsByEdition[edition] = List<QuranJuzNavigationEntry>.unmodifiable(
      _juzEntriesFromPayload(payload),
    );
  }

  void _activateEdition(MushafEdition edition) {
    final editionSurahs = _surahsByEdition[edition];
    final editionJuzs = _juzsByEdition[edition];
    if (editionSurahs == null || editionJuzs == null) {
      return;
    }
    _setActiveEntries(editionSurahs, editionJuzs);
  }

  void _hydrateStandardPayload(Map<String, dynamic> payload) {
    _standardSurahs
      ..clear()
      ..addAll(_surahEntriesFromPayload(payload));
    _standardSurahsView =
        List<QuranSurahNavigationEntry>.unmodifiable(_standardSurahs);
    _standardJuzs
      ..clear()
      ..addAll(_juzEntriesFromPayload(payload));
    _standardJuzsView = List<QuranJuzNavigationEntry>.unmodifiable(
      _standardJuzs,
    );
  }

  List<QuranSurahNavigationEntry> _surahEntriesFromPayload(
    Map<String, dynamic> payload,
  ) {
    final surahJson = payload['surahs'] as List<dynamic>? ?? const [];
    return surahJson
        .map((entry) => _parseSurahEntry(entry))
        .whereType<QuranSurahNavigationEntry>()
        .toList(growable: false);
  }

  List<QuranJuzNavigationEntry> _juzEntriesFromPayload(
    Map<String, dynamic> payload,
  ) {
    final juzJson = payload['siparas'] as List<dynamic>? ?? const [];
    return juzJson
        .map((entry) => _parseJuzEntry(entry))
        .whereType<QuranJuzNavigationEntry>()
        .toList(growable: false);
  }

  QuranSurahNavigationEntry? _parseSurahEntry(dynamic entry) {
    if (entry is! Map) {
      return null;
    }

    final id = _readInt(entry['id']);
    final standardStartPage = _readInt(entry['standardStartPage']);
    final tajScanStartPage =
        _readInt(entry['tajScanStartPage']) ?? standardStartPage;
    if (id == null || standardStartPage == null || tajScanStartPage == null) {
      return null;
    }

    return QuranSurahNavigationEntry(
      id: id,
      nameSimple: _readString(entry['nameSimple']),
      nameComplex: _readString(entry['nameComplex']),
      nameArabic: _readString(entry['nameArabic']),
      translatedName: _readString(entry['translatedName']),
      standardStartPage: standardStartPage,
      tajScanStartPage: tajScanStartPage,
    );
  }

  QuranJuzNavigationEntry? _parseJuzEntry(dynamic entry) {
    if (entry is! Map) {
      return null;
    }

    final number = _readInt(entry['number']);
    final standardStartPage = _readInt(entry['standardStartPage']);
    final tajScanStartPage =
        _readInt(entry['tajScanStartPage']) ?? standardStartPage;
    if (number == null ||
        standardStartPage == null ||
        tajScanStartPage == null) {
      return null;
    }

    return QuranJuzNavigationEntry(
      number: number,
      name: _readString(entry['name']),
      nameArabic: _readString(entry['nameArabic']),
      standardStartPage: standardStartPage,
      tajScanStartPage: tajScanStartPage,
    );
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final direct = int.tryParse(trimmed);
      if (direct != null) {
        return direct;
      }
      final match = RegExp(r'\d+').firstMatch(trimmed);
      if (match == null) {
        return null;
      }
      return int.tryParse(match.group(0)!);
    }
    return null;
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }

  Future<Map<String, dynamic>?> _loadBestAvailablePayload(
    MushafEdition edition, {
    required bool forceRefresh,
  }) async {
    final candidatePaths = <String>[
      _bundledNavigationAssetPathForEdition(edition),
      _fallbackNavigationAssetPath,
      'assets/quran_pages/quran_navigation_index_10_line.json',
      'assets/quran_pages/quran_navigation_index_13_line.json',
      'assets/quran_pages/quran_navigation_index_14_line.json',
      'assets/quran_pages/quran_navigation_index_15_line.json',
      'assets/quran_pages/quran_navigation_index_16_line.json',
      'assets/quran_pages/quran_navigation_index_17_line.json',
      'assets/quran_pages/quran_navigation_index_kanzul_iman.json',
      'assets/quran_pages/quran_navigation_index.json',
    ];

    final seenPaths = <String>{};
    for (final assetPath in candidatePaths) {
      if (!seenPaths.add(assetPath)) {
        continue;
      }
      final payload = await _tryLoadBundledPayload(
        assetPath,
        forceRefresh: forceRefresh,
      );
      if (payload != null) {
        return payload;
      }
    }

    return null;
  }

  Future<void> _initializeStandardPayload({
    required bool forceRefresh,
  }) async {
    if (!forceRefresh &&
        _standardSurahs.isNotEmpty &&
        _standardJuzs.isNotEmpty) {
      return;
    }
    final payload = await _tryLoadBundledPayload(
      _legacyNavigationAssetPath,
      forceRefresh: forceRefresh,
    );
    if (payload == null) {
      return;
    }
    _hydrateStandardPayload(payload);
  }

  Future<void> _warmEditionCaches({
    required bool forceRefresh,
    required MushafEdition excludeEdition,
  }) async {
    for (final edition in MushafEdition.values) {
      if (!forceRefresh &&
          _surahsByEdition.containsKey(edition) &&
          _juzsByEdition.containsKey(edition)) {
        continue;
      }
      final payload = await _tryLoadBundledPayload(
        _bundledNavigationAssetPathForEdition(edition),
        forceRefresh: forceRefresh,
      );
      if (payload == null) {
        continue;
      }
      _cacheEditionPayload(edition, payload);
    }
  }

  Future<Map<String, dynamic>?> _tryLoadBundledPayload(
    String assetPath, {
    required bool forceRefresh,
  }) async {
    if (!forceRefresh) {
      final cached = _decodedPayloadCache[assetPath];
      if (cached != null) {
        return cached;
      }
    }

    try {
      final payload = await rootBundle.loadString(assetPath);
      final decoded = await compute(_decodeNavigationPayload, payload);
      _decodedPayloadCache[assetPath] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  String _bundledNavigationAssetPathForEdition(MushafEdition edition) {
    switch (edition) {
      case MushafEdition.lines10:
        return 'assets/quran_pages/quran_navigation_index_10_line.json';
      case MushafEdition.lines13:
        return 'assets/quran_pages/quran_navigation_index_13_line.json';
      case MushafEdition.lines14:
        return 'assets/quran_pages/quran_navigation_index_14_line.json';
      case MushafEdition.lines15:
        return 'assets/quran_pages/quran_navigation_index_15_line.json';
      case MushafEdition.lines16:
        return 'assets/quran_pages/quran_navigation_index_16_line.json';
      case MushafEdition.lines17:
        return 'assets/quran_pages/quran_navigation_index_17_line.json';
      case MushafEdition.kanzulIman:
        return 'assets/quran_pages/quran_navigation_index_kanzul_iman.json';
    }
  }
}

Map<String, dynamic> _decodeNavigationPayload(String responseBody) {
  final payload = json.decode(responseBody);
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  throw StateError('Navigation payload returned invalid JSON.');
}
