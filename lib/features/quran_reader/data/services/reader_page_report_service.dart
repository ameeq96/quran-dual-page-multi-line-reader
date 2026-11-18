import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/reader_preferences.dart';
import '../../../../core/storage/reader_profile_store.dart';

class ReaderPageReport {
  const ReaderPageReport({required this.clientReportId, required this.editionKey,
    required this.pageNumber, required this.issueType, required this.description, this.lastError});
  final String clientReportId;
  final String editionKey;
  final int pageNumber;
  final String issueType;
  final String description;
  final String? lastError;

  Map<String, Object?> get payload => {
    'clientReportId': clientReportId, 'editionKey': editionKey,
    'pageNumber': pageNumber, 'issueType': issueType, 'description': description,
  };
}

class ReaderPageReportService {
  ReaderPageReportService({required this.profileId, required String baseUrl,
    SharedPreferences? preferences, http.Client? client,
    this.timeout = const Duration(seconds: 12)})
      : baseUrl = ReaderPreferences.normalizeSyncBaseUrl(baseUrl),
        _injectedPreferences = preferences, _client = client ?? http.Client() {
    if (!ReaderProfileStore.validId(profileId)) throw ArgumentError('Invalid report profile.');
  }

  static const maxPendingReports = 20;
  static const issueTypes = {'missing', 'blurred', 'wrong_page', 'other'};
  static Future<void> _writes = Future<void>.value();
  final String profileId;
  final String baseUrl;
  final Duration timeout;
  final SharedPreferences? _injectedPreferences;
  final http.Client _client;
  final _requests = <Completer<void>>{};
  bool _closed = false;

  String get _prefix => 'reader.pageReports.v1.${base64Url.encode(utf8.encode('$profileId|$baseUrl')).replaceAll('=', '')}.';
  Future<SharedPreferences> get _preferences async =>
      _injectedPreferences ?? await SharedPreferences.getInstance();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  static bool _validPayload(Map value) =>
      value['clientReportId'] is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(value['clientReportId'] as String) &&
      value['editionKey'] is String && RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(value['editionKey'] as String) &&
      value['pageNumber'] is int && (value['pageNumber'] as int) > 0 && (value['pageNumber'] as int) <= 10000 &&
      issueTypes.contains(value['issueType']) && value['description'] is String &&
      (value['description'] as String).length <= 1000 &&
      !RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]').hasMatch(value['description'] as String);

  ReaderPageReport _decode(String key, String? raw) {
    if (raw == null || raw.length > 10000) throw StateError('invalid_queue');
    final value = jsonDecode(raw);
    if (value is! Map || !_validPayload(value) || key != '$_prefix${value['clientReportId']}' ||
        (value['lastError'] != null && (value['lastError'] is! String || (value['lastError'] as String).length > 100))) {
      throw StateError('invalid_queue');
    }
    return ReaderPageReport(clientReportId: value['clientReportId'] as String,
      editionKey: value['editionKey'] as String, pageNumber: value['pageNumber'] as int,
      issueType: value['issueType'] as String, description: value['description'] as String,
      lastError: value['lastError'] as String?);
  }

  Future<List<ReaderPageReport>> pending() async {
    final preferences = await _preferences;
    final keys = preferences.getKeys().where((key) => key.startsWith(_prefix)).toList()..sort();
    return List<ReaderPageReport>.unmodifiable(keys.take(maxPendingReports).map((key) => _decode(key, preferences.getString(key))));
  }

  Future<ReaderPageReport> enqueue({required String editionKey, required int pageNumber,
    required String issueType, required String description}) => _serial(() async {
    if (_closed) throw StateError('closed');
    final random = Random.secure();
    final report = ReaderPageReport(
      clientReportId: List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join(),
      editionKey: editionKey, pageNumber: pageNumber, issueType: issueType, description: description.trim());
    if (!_validPayload(report.payload)) throw ArgumentError('Invalid page report.');
    final preferences = await _preferences;
    if (preferences.getKeys().where((key) => key.startsWith(_prefix)).length >= maxPendingReports) {
      throw StateError('queue_full');
    }
    if (!await preferences.setString('$_prefix${report.clientReportId}', jsonEncode(report.payload))) {
      throw StateError('save_failed');
    }
    return report;
  });

  Future<int?> send(String clientReportId) => _serial(() async {
    if (_closed) return null;
    final preferences = await _preferences;
    final key = '$_prefix$clientReportId';
    if (!preferences.containsKey(key)) return null;
    final report = _decode(key, preferences.getString(key));
    if (!await preferences.setString(key, jsonEncode({...report.payload, 'lastError': report.lastError}))) {
      throw StateError('save_failed');
    }
    final uri = Uri.parse('$baseUrl/public/page-reports');
    final abort = Completer<void>();
    _requests.add(abort);
    var error = 'network';
    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final receipt = await (() async {
        if (uri.scheme != 'https' && !(uri.scheme == 'http' && const {'localhost', '127.0.0.1', '::1'}.contains(uri.host))) {
          error = 'insecure_server';
          return null;
        }
        final request = http.AbortableRequest('POST', uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll({'Accept': 'application/json', 'Content-Type': 'application/json'})
          ..body = jsonEncode(report.payload);
        final response = await _client.send(request);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          error = 'http_${response.statusCode}';
          await response.stream.listen(null).cancel();
          return null;
        }
        error = 'invalid_receipt';
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 16384) throw const FormatException('Receipt too large.');
          bytes.addAll(chunk);
        }
        final value = jsonDecode(utf8.decode(bytes));
        if (value is! Map || value['success'] != true || value['clientReportId'] != clientReportId ||
            value['reportId'] is! int || (value['reportId'] as int) <= 0) {
          return null;
        }
        return value['reportId'] as int;
      })().timeout(timeout);
      if (receipt != null) {
        if (!await preferences.remove(key)) throw StateError('save_failed');
        return receipt;
      }
    } on TimeoutException {
      error = 'timeout';
    } on http.RequestAbortedException {
      error = timedOut ? 'timeout' : 'cancelled';
    } on FormatException {
      error = 'invalid_receipt';
    } on StateError {
      rethrow;
    } catch (_) {
      error = timedOut ? 'timeout' : 'network';
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      _requests.remove(abort);
    }
    if (!await preferences.setString(key, jsonEncode({...report.payload, 'lastError': error}))) {
      throw StateError('save_failed');
    }
    return null;
  });

  void dispose() {
    _closed = true;
    for (final request in _requests) {
      if (!request.isCompleted) request.complete();
    }
    _client.close();
  }
}
