import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';

class QuranNavigationDataSource {
  static const Duration _requestTimeout = Duration(seconds: 4);

  QuranNavigationDataSource({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final List<QuranSurahNavigationEntry> _surahs = <QuranSurahNavigationEntry>[];
  final List<QuranJuzNavigationEntry> _juzs = <QuranJuzNavigationEntry>[];
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
      final payloadFuture = _loadPrimaryPayload(adminConfig);
      final overridePayloadFuture = _loadOptionalOverridePayload(adminConfig);
      final payload = await payloadFuture;
      final overridePayload = await overridePayloadFuture;
      final surahOverrides = _parseOverrideMap(
        overridePayload['surahStartPages'],
      );
      final juzOverrides = _parseOverrideMap(
        overridePayload['siparaStartPages'],
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
      rethrow;
    }

    _isInitialized = true;
  }

  List<QuranSurahNavigationEntry> get surahs =>
      List<QuranSurahNavigationEntry>.unmodifiable(_surahs);

  List<QuranJuzNavigationEntry> get juzs =>
      List<QuranJuzNavigationEntry>.unmodifiable(_juzs);

  Future<Map<String, dynamic>> _loadPrimaryPayload(
    ReaderAdminConfig? adminConfig,
  ) async {
    return _loadRemotePayload(
      adminConfig?.contentDataset('navigation_index'),
      datasetKey: 'navigation_index',
    );
  }

  Future<Map<String, dynamic>> _loadOptionalOverridePayload(
    ReaderAdminConfig? adminConfig,
  ) async {
    final dataset = adminConfig?.contentDataset('taj_navigation_overrides');
    if (dataset == null || dataset.url.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      return await _loadRemotePayload(
        dataset,
        datasetKey: 'taj_navigation_overrides',
      );
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _loadRemotePayload(
    ReaderRemoteContentDataset? dataset,
    {
    required String datasetKey,
  }
  ) async {
    if (dataset == null || dataset.url.trim().isEmpty) {
      throw StateError('Admin dataset "$datasetKey" is not configured.');
    }

    try {
      final response = await _client.get(
        Uri.parse(dataset.url),
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        return compute(_decodeNavigationPayload, response.body);
      }
      throw StateError(
        'Admin dataset "$datasetKey" request failed with status ${response.statusCode}.',
      );
    } catch (error) {
      if (error is StateError) {
        rethrow;
      }
      throw StateError('Unable to load admin dataset "$datasetKey" from API.');
    }
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

Map<String, dynamic> _decodeNavigationPayload(String responseBody) {
  final payload = json.decode(responseBody);
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  throw StateError('Navigation payload returned invalid JSON.');
}
