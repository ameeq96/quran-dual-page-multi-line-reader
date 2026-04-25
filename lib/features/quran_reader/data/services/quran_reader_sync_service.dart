import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/reader_sync_snapshot.dart';

class QuranReaderSyncService {
  QuranReaderSyncService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  Future<bool> pushSnapshot({
    required String baseUrl,
    required String deviceId,
    required ReaderSyncSnapshot snapshot,
  }) async {
    final uri = Uri.tryParse('${_normalize(baseUrl)}/public/sync/push');
    if (uri == null) {
      return false;
    }

    try {
      final response = await _client.post(
        uri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(<String, dynamic>{
          'deviceId': deviceId,
          'lastPageNumber': snapshot.lastPageNumber,
          'appVersion': '1.0',
          'payload': snapshot.toJson(),
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<ReaderSyncSnapshot?> pullSnapshot({
    required String baseUrl,
    required String deviceId,
  }) async {
    final uri = Uri.tryParse(
      '${_normalize(baseUrl)}/public/sync/pull?deviceId=$deviceId',
    );
    if (uri == null) {
      return null;
    }

    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        return null;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      if (payload['found'] != true) {
        return null;
      }
      final snapshotJson =
          payload['payload'] as Map<String, dynamic>? ?? const {};
      return ReaderSyncSnapshot.fromJson(snapshotJson);
    } catch (_) {
      return null;
    }
  }

  String _normalize(String value) {
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
