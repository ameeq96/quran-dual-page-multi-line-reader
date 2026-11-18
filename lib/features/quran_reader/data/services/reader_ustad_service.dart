import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../core/storage/reader_preferences.dart';

class ReaderUstadFailure implements Exception {
  const ReaderUstadFailure(this.code);
  final String code;
  @override
  String toString() => code;
}

class ReaderUstadOverview {
  const ReaderUstadOverview(
      this.links, this.usageBytes, this.page, this.totalPages);
  final List<Map<String, dynamic>> links;
  final int usageBytes;
  final int page;
  final int totalPages;
}

class ReaderUstadPage {
  const ReaderUstadPage(this.items, this.page, this.totalPages);
  final List<Map<String, dynamic>> items;
  final int page;
  final int totalPages;
}

class ReaderUstadAudioBytes {
  const ReaderUstadAudioBytes(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

class ReaderUstadService {
  ReaderUstadService(
      {required String baseUrl,
      required this.identity,
      http.Client? client,
      this.timeout = const Duration(seconds: 30),
      this.uploadTimeout = const Duration(seconds: 130)})
      : baseUrl = ReaderPreferences.normalizeSyncBaseUrl(baseUrl),
        _client = client ?? http.Client() {
    final uri = Uri.parse(this.baseUrl);
    if (!ReaderPreferences.isValidSyncIdentity(identity) ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' &&
                const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)))) {
      throw const ReaderUstadFailure('identity_required');
    }
  }

  static const maxClipBytes = 8 * 1024 * 1024;
  static const maxClipMillis = 60000;
  static const studentQuotaBytes = 100 * 1024 * 1024;
  static const retentionDays = 30;
  static const _maxJsonBytes = 8 * 1024 * 1024;
  final String baseUrl;
  final ReaderSyncIdentity identity;
  final http.Client _client;
  final Duration timeout;
  final Duration uploadTimeout;
  final _pending = <Completer<void>>{};
  int _generation = 0;
  bool _disposed = false;

  static String requestId() {
    final random = Random.secure();
    return List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static bool validId(Object? value) =>
      value is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(value);
  static bool validCode(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value);
  static bool validMime(String value) =>
      RegExp(r'^audio/(webm|mp4|ogg)(?:;\s*codecs=(?:opus|mp4a\.40\.2))?$')
          .hasMatch(value);
  static String mimeBase(String value) => value.split(';').first.trim();
  static bool _text(Object? value, int max, {bool required = false}) =>
      value is String &&
      value.length <= max &&
      (!required || value.trim().isNotEmpty) &&
      !RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]')
          .hasMatch(value);
  static void _input(bool valid) {
    if (!valid) throw const ReaderUstadFailure('invalid_input');
  }

  static Never _invalid() => throw const ReaderUstadFailure('invalid_response');
  static Map<String, dynamic> _object(Object? value) =>
      value is Map<String, dynamic> ? value : _invalid();
  static bool _date(Object? value, {bool nullable = false}) => value == null
      ? nullable
      : value is String &&
          value.length <= 40 &&
          DateTime.tryParse(value) != null;

  static Map<String, dynamic> _link(Object? value) {
    final item = _object(value);
    if (!validId(item['id']) ||
        !const {'teacher', 'student'}.contains(item['role']) ||
        !_text(item['teacherName'], 80, required: true) ||
        (item['studentName'] != null &&
            !_text(item['studentName'], 80, required: true)) ||
        !const {'pending', 'active', 'revoked'}.contains(item['status']) ||
        !_date(item['createdAt']) ||
        !_date(item['acceptedAt'], nullable: true) ||
        !_date(item['expiresAt'])) {
      _invalid();
    }
    return Map.unmodifiable(item);
  }

  static Map<String, dynamic> _submission(Object? value) {
    final item = _object(value);
    if (!validId(item['id']) ||
        !validId(item['assignmentId']) ||
        !validId(item['clientUploadId']) ||
        !_date(item['createdAt']) ||
        !_date(item['expiresAt']) ||
        item['mimeType'] is! String ||
        !validMime(item['mimeType'] as String) ||
        item['bytes'] is! int ||
        (item['bytes'] as int) < 1 ||
        (item['bytes'] as int) > maxClipBytes ||
        item['durationMillis'] is! int ||
        (item['durationMillis'] as int) < 1 ||
        (item['durationMillis'] as int) > maxClipMillis ||
        item['durationVerified'] != false ||
        item['deleted'] is! bool ||
        !const {'uploading', 'ready', 'deleting', 'deleted'}
            .contains(item['deliveryState']) ||
        !const {'pending', 'complete', 'repeat'}
            .contains(item['feedbackStatus']) ||
        !_text(item['feedbackNote'], 1000) ||
        !_date(item['reviewedAt'], nullable: true)) {
      _invalid();
    }
    return Map.unmodifiable(item);
  }

  static Map<String, dynamic> _assignment(Object? value) {
    final item = _object(value);
    if (!validId(item['id']) ||
        !validId(item['linkId']) ||
        !validId(item['clientRequestId']) ||
        !const {'teacher', 'student'}.contains(item['role']) ||
        !_text(item['teacherName'], 80, required: true) ||
        !_text(item['studentName'], 80, required: true) ||
        !const {'sabaq', 'sabqi', 'manzil'}.contains(item['kind']) ||
        item['editionKey'] is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$')
            .hasMatch(item['editionKey'] as String) ||
        item['startPage'] is! int ||
        item['endPage'] is! int ||
        (item['startPage'] as int) < 1 ||
        (item['endPage'] as int) < (item['startPage'] as int) ||
        (item['endPage'] as int) > 10000 ||
        !_text(item['title'], 120, required: true) ||
        !_text(item['instructions'], 1000) ||
        !_date(item['dueAt'], nullable: true) ||
        !_date(item['createdAt']) ||
        !const {'assigned', 'cancelled'}.contains(item['status']) ||
        item['submissions'] is! List ||
        (item['submissions'] as List).length > 20) {
      _invalid();
    }
    final submissions =
        (item['submissions'] as List).map(_submission).toList(growable: false);
    if (submissions
        .any((submission) => submission['assignmentId'] != item['id'])) {
      _invalid();
    }
    return Map.unmodifiable(
        {...item, 'submissions': List.unmodifiable(submissions)});
  }

  Future<ReaderUstadOverview> overview({int page = 1}) async {
    _input(page >= 1 && page <= 1000000);
    final body = await _json('GET', '/links?page=$page&pageSize=20');
    final limits = _object(body['limits']);
    if (body['links'] is! List ||
        (body['links'] as List).length > 100 ||
        body['usageBytes'] is! int ||
        (body['usageBytes'] as int) < 0 ||
        limits['maxClipBytes'] != maxClipBytes ||
        limits['maxClipMillis'] != maxClipMillis ||
        limits['studentQuotaBytes'] != studentQuotaBytes ||
        limits['retentionDays'] != retentionDays) {
      _invalid();
    }
    final meta = _meta(body['meta']);
    return ReaderUstadOverview(
        List.unmodifiable((body['links'] as List).map(_link)),
        body['usageBytes'] as int,
        meta.$1,
        meta.$2);
  }

  Future<ReaderUstadPage> assignments({String? linkId, int page = 1}) async {
    _input((linkId == null || validId(linkId)) && page >= 1 && page <= 1000000);
    final body = await _json('GET',
        '/assignments?page=$page&pageSize=20${linkId == null ? '' : '&linkId=$linkId'}');
    if (body['assignments'] is! List ||
        (body['assignments'] as List).length > 100) {
      _invalid();
    }
    final items =
        (body['assignments'] as List).map(_assignment).toList(growable: false);
    if (linkId != null && items.any((item) => item['linkId'] != linkId)) {
      _invalid();
    }
    final meta = _meta(body['meta']);
    return ReaderUstadPage(List.unmodifiable(items), meta.$1, meta.$2);
  }

  static (int, int) _meta(Object? value) {
    final meta = _object(value);
    if (meta['page'] is! int ||
        (meta['page'] as int) < 1 ||
        meta['pageSize'] is! int ||
        (meta['pageSize'] as int) < 1 ||
        (meta['pageSize'] as int) > 100 ||
        meta['totalPages'] is! int ||
        (meta['totalPages'] as int) < 1 ||
        meta['totalItems'] is! int ||
        (meta['totalItems'] as int) < 0) {
      _invalid();
    }
    return (meta['page'] as int, meta['totalPages'] as int);
  }

  Future<ReaderUstadPage> recordings({int page = 1}) async {
    _input(page >= 1 && page <= 1000000);
    final body = await _json('GET', '/submissions?page=$page&pageSize=20');
    if (body['submissions'] is! List ||
        (body['submissions'] as List).length > 100) {
      _invalid();
    }
    final items = (body['submissions'] as List).map((raw) {
      final item = _submission(raw);
      if (!validId(item['linkId']) ||
          !const {'teacher', 'student'}.contains(item['role']) ||
          !_text(item['assignmentTitle'], 120, required: true) ||
          !_text(item['teacherName'], 80, required: true) ||
          !_text(item['studentName'], 80, required: true)) {
        _invalid();
      }
      return item;
    }).toList(growable: false);
    final meta = _meta(body['meta']);
    return ReaderUstadPage(List.unmodifiable(items), meta.$1, meta.$2);
  }

  Future<Map<String, dynamic>> createInvite(String teacherName) async {
    _input(_text(teacherName, 80, required: true));
    final body = await _json('POST', '/invites',
        body: {'teacherName': teacherName.trim()});
    final invite = _object(body['invite']);
    if (!validId(invite['id']) ||
        invite['code'] is! String ||
        !validCode(invite['code'] as String) ||
        invite['teacherName'] != teacherName.trim() ||
        !_date(invite['expiresAt'])) {
      _invalid();
    }
    return Map.unmodifiable(invite);
  }

  Future<Map<String, dynamic>> previewInvite(String code) async {
    _input(validCode(code.trim()));
    final body =
        await _json('POST', '/invites/preview', body: {'code': code.trim()});
    final invite = _object(body['invite']);
    if (!_text(invite['teacherName'], 80, required: true) ||
        !_date(invite['expiresAt'])) {
      _invalid();
    }
    return Map.unmodifiable(invite);
  }

  Future<Map<String, dynamic>> acceptInvite(String code, String studentName,
      {required bool consent}) async {
    _input(validCode(code.trim()) &&
        _text(studentName, 80, required: true) &&
        consent);
    final body = await _json('POST', '/invites/accept', body: {
      'code': code.trim(),
      'studentName': studentName.trim(),
      'consent': true
    });
    final link = _link(body['link']);
    if (link['role'] != 'student' ||
        link['status'] != 'active' ||
        link['studentName'] != studentName.trim()) {
      _invalid();
    }
    return link;
  }

  Future<void> revoke(String linkId) async {
    _input(validId(linkId));
    await _json('POST', '/links/$linkId/revoke', body: {});
  }

  Future<void> deleteLinkData(String linkId) async {
    _input(validId(linkId));
    await _json('DELETE', '/links/$linkId/data');
  }

  Future<void> cancelAssignment(String id) async {
    _input(validId(id));
    await _json('POST', '/assignments/$id/cancel', body: {});
  }

  Future<void> deleteSubmission(String id) async {
    _input(validId(id));
    await _json('DELETE', '/submissions/$id');
  }

  Future<Map<String, dynamic>> assign(
      {required String linkId,
      required String clientRequestId,
      required String kind,
      required String editionKey,
      required int startPage,
      required int endPage,
      required String title,
      required String instructions,
      DateTime? dueAt}) async {
    _input(validId(linkId) &&
        validId(clientRequestId) &&
        const {'sabaq', 'sabqi', 'manzil'}.contains(kind) &&
        RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(editionKey) &&
        startPage >= 1 &&
        endPage >= startPage &&
        endPage <= 10000 &&
        _text(title, 120, required: true) &&
        _text(instructions, 1000));
    final request = {
      'clientRequestId': clientRequestId,
      'kind': kind,
      'editionKey': editionKey,
      'startPage': startPage,
      'endPage': endPage,
      'title': title.trim(),
      'instructions': instructions.trim(),
      'dueAt': dueAt?.toUtc().toIso8601String()
    };
    final body =
        await _json('POST', '/links/$linkId/assignments', body: request);
    final item = _assignment(body['assignment']);
    if (item['linkId'] != linkId ||
        item['role'] != 'teacher' ||
        item['clientRequestId'] != clientRequestId ||
        item['kind'] != kind ||
        item['editionKey'] != editionKey ||
        item['startPage'] != startPage ||
        item['endPage'] != endPage ||
        item['title'] != title.trim() ||
        item['instructions'] != instructions.trim() ||
        (item['dueAt'] == null
            ? dueAt != null
            : dueAt == null ||
                !DateTime.parse(item['dueAt'] as String)
                    .isAtSameMomentAs(dueAt))) {
      _invalid();
    }
    return item;
  }

  Future<Map<String, dynamic>> upload(
      {required String assignmentId,
      required String clientUploadId,
      required Uint8List bytes,
      required String mimeType,
      required int durationMillis}) async {
    _input(validId(assignmentId) &&
        validId(clientUploadId) &&
        bytes.isNotEmpty &&
        bytes.length <= maxClipBytes &&
        durationMillis >= 1 &&
        durationMillis <= maxClipMillis &&
        validMime(mimeType));
    final response = await _perform(
        'POST', '/assignments/$assignmentId/submissions', build: (uri, abort) {
      final request =
          http.AbortableMultipartRequest('POST', uri, abortTrigger: abort);
      request.fields.addAll({
        'clientUploadId': clientUploadId,
        'durationMillis': '$durationMillis'
      });
      final extension = mimeBase(mimeType) == 'audio/mp4'
          ? 'm4a'
          : mimeBase(mimeType).split('/').last;
      request.files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: 'lesson.$extension',
          contentType: http.MediaType.parse(mimeType)));
      return request;
    }, deadline: uploadTimeout);
    final item = _submission(_decode(response.$1)['submission']);
    if (item['assignmentId'] != assignmentId ||
        item['clientUploadId'] != clientUploadId ||
        item['bytes'] != bytes.length ||
        item['durationMillis'] != durationMillis ||
        mimeBase(item['mimeType'] as String) != mimeBase(mimeType) ||
        item['deleted'] != false ||
        item['deliveryState'] != 'ready') {
      _invalid();
    }
    return item;
  }

  Future<Map<String, dynamic>> feedback(
      String id, String status, String note) async {
    _input(validId(id) &&
        const {'complete', 'repeat'}.contains(status) &&
        _text(note, 1000));
    final body = await _json('PATCH', '/submissions/$id/feedback',
        body: {'status': status, 'note': note.trim()});
    final item = _submission(body['submission']);
    if (item['id'] != id ||
        item['feedbackStatus'] != status ||
        item['feedbackNote'] != note.trim()) {
      _invalid();
    }
    return item;
  }

  Future<ReaderUstadAudioBytes> audio(Map<String, dynamic> submission) async {
    final item = _submission(submission);
    _input(item['deleted'] == false && item['deliveryState'] == 'ready');
    final response =
        await _perform('GET', '/submissions/${item['id']}/audio', audio: true);
    final mime = response.$2['content-type']?.split(';').first.trim() ?? '';
    if (!validMime(mime) ||
        mime != mimeBase(item['mimeType'] as String) ||
        response.$1.length != item['bytes']) {
      _invalid();
    }
    return ReaderUstadAudioBytes(response.$1, mime);
  }

  Future<Map<String, dynamic>> _json(String method, String path,
      {Map<String, Object?>? body}) async {
    final response = await _perform(method, path, body: body);
    return _decode(response.$1);
  }

  Map<String, dynamic> _decode(Uint8List bytes) {
    try {
      final value = _object(jsonDecode(utf8.decode(bytes)));
      if (value['success'] != true) {
        _invalid();
      }
      return value;
    } on FormatException {
      _invalid();
    }
  }

  Future<(Uint8List, Map<String, String>)> _perform(String method, String path,
      {Map<String, Object?>? body,
      bool audio = false,
      Duration? deadline,
      http.BaseRequest Function(Uri, Future<void>)? build}) async {
    if (_disposed) throw const ReaderUstadFailure('cancelled');
    final generation = _generation;
    final abort = Completer<void>();
    _pending.add(abort);
    var timedOut = false;
    final limit = deadline ?? timeout;
    final timer = Timer(limit, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    try {
      return await (() async {
        final uri = Uri.parse('$baseUrl/public/ustad$path');
        final request = build?.call(uri, abort.future) ??
            http.AbortableRequest(method, uri, abortTrigger: abort.future);
        request.followRedirects = false;
        request.headers.addAll({
          'Authorization': 'Bearer ${identity.token}',
          'X-Reader-Device-Id': identity.deviceId,
          'Accept': audio ? 'audio/*' : 'application/json'
        });
        if (body != null && request is http.Request) {
          request.headers['Content-Type'] = 'application/json';
          request.body = jsonEncode(body);
        }
        final response = await _client.send(request);
        if (generation != _generation || _disposed) {
          throw const ReaderUstadFailure('cancelled');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          unawaited(
              response.stream.listen(null).cancel().catchError((Object _) {}));
          throw ReaderUstadFailure(switch (response.statusCode) {
            401 => 'auth_required',
            403 => 'forbidden',
            404 || 503 => 'unavailable',
            409 => 'conflict',
            413 => 'quota',
            429 => 'rate_limited',
            _ => 'server_error',
          });
        }
        if (audio &&
            !(response.headers['cache-control']
                    ?.toLowerCase()
                    .contains('no-store') ??
                false)) {
          unawaited(
              response.stream.listen(null).cancel().catchError((Object _) {}));
          _invalid();
        }
        final maxBytes = audio ? maxClipBytes : _maxJsonBytes;
        if ((response.contentLength ?? 0) > maxBytes) {
          unawaited(
              response.stream.listen(null).cancel().catchError((Object _) {}));
          _invalid();
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > maxBytes) {
            _invalid();
          }
          bytes.add(chunk);
        }
        if (generation != _generation || _disposed) {
          throw const ReaderUstadFailure('cancelled');
        }
        return (bytes.takeBytes(), response.headers);
      })()
          .timeout(limit);
    } on ReaderUstadFailure {
      rethrow;
    } on TimeoutException {
      throw const ReaderUstadFailure('timeout');
    } on http.RequestAbortedException {
      throw ReaderUstadFailure(timedOut ? 'timeout' : 'cancelled');
    } catch (_) {
      throw ReaderUstadFailure(
          _disposed || generation != _generation ? 'cancelled' : 'network');
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      _pending.remove(abort);
    }
  }

  void cancelPending() {
    _generation++;
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.complete();
    }
  }

  void dispose() {
    _disposed = true;
    cancelPending();
    _client.close();
  }
}
