import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/quran_juz_navigation_entry.dart';
import '../../domain/models/quran_navigation_marker.dart';
import '../../domain/models/quran_search_result.dart';
import '../../domain/models/quran_surah_navigation_entry.dart';
import 'quran_admin_config_service.dart';

class QuranSearchApiService {
  static const Duration _requestTimeout = Duration(seconds: 6);

  QuranSearchApiService({
    required QuranAdminConfigService adminConfigService,
    http.Client? client,
  })  : _adminConfigService = adminConfigService,
        _client = client ?? http.Client();

  final QuranAdminConfigService _adminConfigService;
  final http.Client _client;

  Future<List<QuranSurahNavigationEntry>> searchSurahs(String query) async {
    final payload = await _getJsonList(
      '/public/search/surahs',
      queryParameters: <String, String>{'q': query.trim()},
    );
    return payload.map(_parseSurah).toList(growable: false);
  }

  Future<List<QuranJuzNavigationEntry>> searchJuzs(String query) async {
    final payload = await _getJsonList(
      '/public/search/juzs',
      queryParameters: <String, String>{'q': query.trim()},
    );
    return payload.map(_parseJuz).toList(growable: false);
  }

  Future<List<QuranNavigationMarker>> searchMarkers({
    required String category,
    required String query,
  }) async {
    final payload = await _getJsonList(
      '/public/search/markers',
      queryParameters: <String, String>{
        'category': category,
        'q': query.trim(),
      },
    );
    return payload.map(_parseMarker).toList(growable: false);
  }

  Future<List<QuranSearchResult>> searchAyahs(
    String query, {
    int limit = 40,
  }) async {
    final payload = await _getJsonList(
      '/public/search/ayahs',
      queryParameters: <String, String>{
        'q': query.trim(),
        'limit': '$limit',
      },
    );
    return payload.map(_parseSearchResult).toList(growable: false);
  }

  Future<List<QuranSearchResult>> searchText(
    String query, {
    int limit = 40,
  }) async {
    final payload = await _getJsonList(
      '/public/search/text',
      queryParameters: <String, String>{
        'q': query.trim(),
        'limit': '$limit',
      },
    );
    return payload.map(_parseSearchResult).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _getJsonList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final baseUrl = _adminConfigService.currentBaseUrl.trim().isNotEmpty
        ? _adminConfigService.currentBaseUrl
        : _adminConfigService.currentConfig.publicBaseUrl;
    final normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    if (normalizedBaseUrl.isEmpty) {
      throw StateError('Admin API base URL is not configured.');
    }

    final uri = Uri.parse('$normalizedBaseUrl$path').replace(
      queryParameters: queryParameters,
    );

    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw StateError(
          'Admin search request failed with status ${response.statusCode}.',
        );
      }

      final payload = json.decode(response.body);
      if (payload is List<dynamic>) {
        return payload.whereType<Map<String, dynamic>>().toList(growable: false);
      }
      throw StateError('Admin search returned invalid JSON.');
    } catch (error) {
      if (error is StateError) {
        rethrow;
      }
      throw StateError('Unable to load search results from admin API.');
    }
  }

  QuranSurahNavigationEntry _parseSurah(Map<String, dynamic> item) {
    return QuranSurahNavigationEntry(
      id: (item['id'] as num? ?? 0).toInt(),
      nameSimple: (item['nameSimple'] as String? ?? '').trim(),
      nameComplex: (item['nameComplex'] as String? ?? '').trim(),
      nameArabic: (item['nameArabic'] as String? ?? '').trim(),
      translatedName: (item['translatedName'] as String? ?? '').trim(),
      standardStartPage: (item['standardStartPage'] as num? ?? 1).toInt(),
      tajScanStartPage: (item['tajScanStartPage'] as num? ?? 1).toInt(),
    );
  }

  QuranJuzNavigationEntry _parseJuz(Map<String, dynamic> item) {
    return QuranJuzNavigationEntry(
      number: (item['number'] as num? ?? 0).toInt(),
      name: (item['name'] as String? ?? '').trim(),
      nameArabic: (item['nameArabic'] as String? ?? '').trim(),
      standardStartPage: (item['standardStartPage'] as num? ?? 1).toInt(),
      tajScanStartPage: (item['tajScanStartPage'] as num? ?? 1).toInt(),
    );
  }

  QuranNavigationMarker _parseMarker(Map<String, dynamic> item) {
    return QuranNavigationMarker(
      id: (item['id'] as num? ?? 0).toInt(),
      title: (item['title'] as String? ?? '').trim(),
      subtitle: (item['subtitle'] as String? ?? '').trim(),
      pageNumber: (item['pageNumber'] as num? ?? 1).toInt(),
      category: (item['category'] as String? ?? '').trim(),
    );
  }

  QuranSearchResult _parseSearchResult(Map<String, dynamic> item) {
    return QuranSearchResult(
      pageNumber: (item['pageNumber'] as num? ?? 1).toInt(),
      referencePageNumber:
          (item['referencePageNumber'] as num? ?? item['pageNumber'] as num? ?? 1)
              .toInt(),
      title: (item['title'] as String? ?? '').trim(),
      snippet: (item['snippet'] as String? ?? '').trim(),
      category: (item['category'] as String? ?? '').trim(),
      verseKey: (item['verseKey'] as String?)?.trim(),
    );
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void dispose() {
    _client.close();
  }
}
