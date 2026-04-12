import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/quran_text_page_data.dart';
import '../../domain/models/reader_admin_config.dart';

class QuranTextDataSource {
  static const Duration _requestTimeout = Duration(seconds: 8);

  QuranTextDataSource({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Map<int, QuranTextPageData> _pages = <int, QuranTextPageData>{};
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
      final payload = await _loadPayload(adminConfig);
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
      rethrow;
    }

    _isInitialized = true;
  }

  bool get hasTextPages => _pages.isNotEmpty;
  int get totalPages => _pages.length;
  Iterable<QuranTextPageData> get pages => _pages.values;

  QuranTextPageData? pageForNumber(int pageNumber) {
    return _pages[pageNumber];
  }

  Future<Map<String, dynamic>> _loadPayload(ReaderAdminConfig? adminConfig) async {
    final remoteDataset = adminConfig?.contentDataset('text_pages');
    if (remoteDataset == null || remoteDataset.url.trim().isEmpty) {
      throw StateError('Admin dataset "text_pages" is not configured.');
    }

    try {
      final response = await _client.get(
        Uri.parse(remoteDataset.url),
        headers: const <String, String>{'Accept': 'application/json'},
      ).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        return compute(_decodeTextPayload, response.body);
      }
      throw StateError(
        'Admin dataset "text_pages" request failed with status ${response.statusCode}.',
      );
    } catch (error) {
      if (error is StateError) {
        rethrow;
      }
      throw StateError('Unable to load admin dataset "text_pages" from API.');
    }
  }
}

Map<String, dynamic> _decodeTextPayload(String responseBody) {
  final payload = json.decode(responseBody);
  if (payload is Map<String, dynamic>) {
    return payload;
  }
  throw StateError('Text pages payload returned invalid JSON.');
}
