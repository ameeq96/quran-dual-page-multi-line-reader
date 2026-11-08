import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/storage/reader_preferences.dart';
import '../../domain/models/reader_sync_snapshot.dart';

enum ReaderSyncStatus { success, notFound, unauthorized, forbidden, conflict, networkError, cancelled, invalidResponse }

class ReaderSyncPullResult {
  const ReaderSyncPullResult({required this.status, this.snapshot, this.syncRevision});
  final ReaderSyncStatus status;
  final ReaderSyncSnapshot? snapshot;
  final int? syncRevision;
  bool get found => status == ReaderSyncStatus.success && snapshot != null;
}

class ReaderSyncPushResult {
  const ReaderSyncPushResult({required this.status, this.syncRevision});
  final ReaderSyncStatus status;
  final int? syncRevision;
  bool get success => status == ReaderSyncStatus.success;
}

class QuranReaderSyncService {
  QuranReaderSyncService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final Set<Completer<void>> _pending = {};
  int _generation = 0;

  Future<ReaderSyncPushResult> pushSnapshot({required String baseUrl, required String deviceId,
    required String token, required ReaderSyncSnapshot snapshot, int? baseRevision}) async {
    if (baseRevision != null && (baseRevision < 0 || baseRevision > 9007199254740991)) {
      return const ReaderSyncPushResult(status: ReaderSyncStatus.invalidResponse);
    }
    final result = await _request('POST', baseUrl, deviceId, token, {
      'deviceId': deviceId, 'lastPageNumber': snapshot.lastPageNumber,
      'appVersion': '1.0', 'payload': snapshot.toJson(),
      if (baseRevision != null) 'baseRevision': baseRevision,
    });
    if (result.status != ReaderSyncStatus.success) return ReaderSyncPushResult(status: result.status);
    final body = result.body;
    final revision = body == null ? null : _readRevision(body);
    if (body?['success'] != true || revision == null) {
      return const ReaderSyncPushResult(status: ReaderSyncStatus.invalidResponse);
    }
    return ReaderSyncPushResult(status: ReaderSyncStatus.success, syncRevision: revision);
  }

  Future<ReaderSyncPullResult> pullSnapshot({required String baseUrl, required String deviceId, required String token}) async {
    final result = await _request('GET', baseUrl, deviceId, token, null);
    if (result.status != ReaderSyncStatus.success) return ReaderSyncPullResult(status: result.status);
    final body = result.body;
    if (body?['success'] != true || body?['found'] is! bool) return const ReaderSyncPullResult(status: ReaderSyncStatus.invalidResponse);
    final revision = _readRevision(body!);
    if (revision == null || body['found'] == false && revision != 0) {
      return const ReaderSyncPullResult(status: ReaderSyncStatus.invalidResponse);
    }
    if (body['found'] == false) return const ReaderSyncPullResult(status: ReaderSyncStatus.notFound, syncRevision: 0);
    try {
      final value = body['payload'];
      if (value is! Map<String, dynamic> || value['deviceId'] != deviceId || value['settings'] is! Map || value['lastPageNumber'] is! num) {
        return const ReaderSyncPullResult(status: ReaderSyncStatus.invalidResponse);
      }
      return ReaderSyncPullResult(status: ReaderSyncStatus.success, snapshot: ReaderSyncSnapshot.fromJson(value), syncRevision: revision);
    } catch (_) { return const ReaderSyncPullResult(status: ReaderSyncStatus.invalidResponse); }
  }

  Future<_SyncResponse> _request(String method, String baseUrl, String deviceId, String token, Map<String,dynamic>? body) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,255}$').hasMatch(deviceId) || (token.length != 43 || !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token))) {
      return const _SyncResponse(ReaderSyncStatus.unauthorized);
    }
    final generation = _generation;
    final abort = Completer<void>();
    _pending.add(abort);
    var timedOut = false;
    final timer = Timer(const Duration(seconds: 15), () { timedOut = true; if (!abort.isCompleted) abort.complete(); });
    try {
      final base = ReaderPreferences.normalizeSyncBaseUrl(baseUrl);
      var uri = Uri.parse('$base/public/sync/${method == 'GET' ? 'pull' : 'push'}');
      if (uri.scheme != 'https' && !const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)) {
        return const _SyncResponse(ReaderSyncStatus.invalidResponse);
      }
      if (method == 'GET') uri = uri.replace(queryParameters: {'deviceId': deviceId});
      final request = http.AbortableRequest(method, uri, abortTrigger: abort.future);
      request.followRedirects = false;
      request.headers.addAll({'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'});
      if (body != null) request.body = json.encode(body);
      final response = await http.Response.fromStream(await _client.send(request)).timeout(const Duration(seconds: 15));
      if (generation != _generation) return const _SyncResponse(ReaderSyncStatus.cancelled);
      if (response.statusCode == 401) return const _SyncResponse(ReaderSyncStatus.unauthorized);
      if (response.statusCode == 403) return const _SyncResponse(ReaderSyncStatus.forbidden);
      if (response.statusCode == 409) return const _SyncResponse(ReaderSyncStatus.conflict);
      if (response.statusCode != 200 && response.statusCode != 201) return const _SyncResponse(ReaderSyncStatus.networkError);
      final decoded = json.decode(response.body);
      if (decoded is! Map<String,dynamic>) return const _SyncResponse(ReaderSyncStatus.invalidResponse);
      return _SyncResponse(ReaderSyncStatus.success, decoded);
    } on http.RequestAbortedException {
      return _SyncResponse(timedOut ? ReaderSyncStatus.networkError : ReaderSyncStatus.cancelled);
    } on FormatException { return const _SyncResponse(ReaderSyncStatus.invalidResponse); }
    catch (_) { return _SyncResponse(generation != _generation ? ReaderSyncStatus.cancelled : ReaderSyncStatus.networkError); }
    finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      _pending.remove(abort);
    }
  }

  static int? _readRevision(Map<String, dynamic> body) {
    if (!body.containsKey('syncRevision')) return 0;
    final value = body['syncRevision'];
    return value is int && value >= 0 && value <= 9007199254740991 ? value : null;
  }

  void cancelPending() {
    _generation++;
    for (final request in _pending.toList()) { if (!request.isCompleted) request.complete(); }
  }

  void dispose() { cancelPending(); _client.close(); }
}

class _SyncResponse {
  const _SyncResponse(this.status, [this.body]);
  final ReaderSyncStatus status;
  final Map<String,dynamic>? body;
}
