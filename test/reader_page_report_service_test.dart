import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_page_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledPreferences extends Fake implements SharedPreferences {
  _ControlledPreferences(this.delegate);
  final SharedPreferences delegate;
  bool failWrites = false;
  bool failRemovals = false;
  Completer<void>? writeStarted;
  Completer<void>? writeGate;

  @override
  Set<String> getKeys() => delegate.getKeys();
  @override
  bool containsKey(String key) => delegate.containsKey(key);
  @override
  String? getString(String key) => delegate.getString(key);
  @override
  Future<bool> setString(String key, String value) async {
    final started = writeStarted;
    if (started != null && !started.isCompleted) started.complete();
    await writeGate?.future;
    return failWrites ? false : delegate.setString(key, value);
  }
  @override
  Future<bool> remove(String key) async =>
      failRemovals ? false : delegate.remove(key);
}

class _ClosingMockClient extends MockClient {
  _ClosingMockClient(MockClientStreamHandler handler) : super.streaming(handler);
  bool closed = false;
  @override
  void close() { closed = true; super.close(); }
}

ReaderPageReportService _service(SharedPreferences preferences, {
  http.Client? client,
  String profileId = 'default',
  String baseUrl = 'https://example.com',
  Duration timeout = const Duration(seconds: 2),
}) {
  final service = ReaderPageReportService(
    preferences: preferences, profileId: profileId, baseUrl: baseUrl,
    timeout: timeout,
    client: client ?? MockClient((_) async => throw StateError('Unexpected HTTP request')),
  );
  addTearDown(service.dispose);
  return service;
}

Future<ReaderPageReport> _enqueue(ReaderPageReportService service, {
  String editionKey = '16_line',
  int pageNumber = 8,
  String issueType = 'blurred',
  String description = 'The scan is unclear.',
}) => service.enqueue(editionKey: editionKey, pageNumber: pageNumber,
  issueType: issueType, description: description);

http.Response _receipt(String id, {int reportId = 73}) => http.Response(
  jsonEncode({'success': true, 'clientReportId': id, 'reportId': reportId}), 201,
  headers: {'content-type': 'application/json'},
);

Matcher _state(String reason) =>
    isA<StateError>().having((error) => error.message, 'reason', reason);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('capture is saved durably before HTTP and later page or payload changes cannot alter it', () async {
    final disk = await SharedPreferences.getInstance();
    final preferences = _ControlledPreferences(disk);
    var calls = 0;
    late ReaderPageReport report;
    final service = _service(preferences, client: MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://example.com/public/page-reports');
      expect(request.followRedirects, isFalse);
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers['accept'], 'application/json');
      expect(request.headers.containsKey('Authorization'), isFalse);
      final body = jsonDecode(request.body) as Map;
      final key = disk.getKeys().single;
      final saved = Map<String, dynamic>.from(jsonDecode(disk.getString(key)!) as Map)
        ..remove('lastError');
      expect(body, saved);
      expect(body, report.payload);
      expect(body['pageNumber'], 8);
      expect(body['editionKey'], '16_line');
      expect(body['description'], 'The scan is unclear.');
      return _receipt(report.clientReportId);
    }));
    var page = 8;
    var edition = '16_line';
    var description = '  The scan is unclear.  ';
    report = await _enqueue(service, pageNumber: page,
      editionKey: edition, description: description);
    expect(calls, 0);
    await disk.reload();
    expect(jsonDecode(disk.getString(disk.getKeys().single)!), report.payload);
    page = 94; edition = '10_line'; description = 'Different page';
    final changedCopy = report.payload
      ..['pageNumber'] = page
      ..['editionKey'] = edition
      ..['description'] = description;
    expect(changedCopy, isNot(report.payload));
    final pending = await service.pending();
    expect(pending.single.payload, report.payload);
    expect(() => pending.clear(), throwsUnsupportedError);
    final gate = Completer<void>();
    preferences.writeStarted = Completer<void>();
    preferences.writeGate = gate;
    addTearDown(() { if (!gate.isCompleted) gate.complete(); });
    final sending = service.send(report.clientReportId);
    await preferences.writeStarted!.future;
    expect(calls, 0);
    gate.complete();
    expect(await sending, 73);
    expect(calls, 1);
    await disk.reload();
    expect(await service.pending(), isEmpty);
  });

  test('a matching receipt removes only its item and stale acknowledged IDs never send again', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('reader.unrelated', 'keep');
    var calls = 0;
    final service = _service(preferences, client: MockClient((request) async {
      calls++;
      return _receipt((jsonDecode(request.body) as Map)['clientReportId'] as String);
    }));
    final first = await _enqueue(service);
    final second = await _enqueue(service, pageNumber: 9);
    final secondKey = preferences.getKeys().singleWhere((key) => key.endsWith(second.clientReportId));
    final secondRaw = preferences.getString(secondKey);
    expect(await service.send(first.clientReportId), 73);
    await preferences.reload();
    expect((await service.pending()).single.clientReportId, second.clientReportId);
    expect(preferences.getString(secondKey), secondRaw);
    expect(preferences.getString('reader.unrelated'), 'keep');
    expect(await service.send(first.clientReportId), isNull);
    expect(await service.send('0' * 32), isNull);
    expect(calls, 1);
    expect((await service.pending()).single.payload, second.payload);
  });

  final invalidReceipts = <String, String Function(String)>{
    'wrong client ID': (id) => jsonEncode({'success': true,
      'clientReportId': '${id.startsWith('0') ? '1' : '0'}${id.substring(1)}', 'reportId': 1}),
    'false success': (id) => jsonEncode({'success': false, 'clientReportId': id, 'reportId': 1}),
    'string report ID': (id) => jsonEncode({'success': true, 'clientReportId': id, 'reportId': '1'}),
    'nonpositive report ID': (id) => jsonEncode({'success': true, 'clientReportId': id, 'reportId': 0}),
    'malformed JSON': (_) => 'not a receipt',
    'oversized receipt': (_) => 'x' * 16385,
  };
  for (final item in invalidReceipts.entries) {
    test('${item.key} cannot acknowledge or discard the saved report', () async {
      final preferences = await SharedPreferences.getInstance();
      late ReaderPageReport report;
      final service = _service(preferences, client: MockClient((_) async =>
        http.Response(item.value(report.clientReportId), 200)));
      report = await _enqueue(service);
      expect(await service.send(report.clientReportId), isNull);
      await preferences.reload();
      final saved = (await service.pending()).single;
      expect(saved.payload, report.payload);
      expect(saved.lastError, 'invalid_receipt');
    });
  }

  test('network errors keep the same durable report with a safe error code', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = _service(preferences, client: MockClient((_) async =>
      throw http.ClientException('private upstream details')));
    final report = await _enqueue(service);
    expect(await service.send(report.clientReportId), isNull);
    await preferences.reload();
    final saved = (await service.pending()).single;
    expect(saved.payload, report.payload);
    expect(saved.lastError, 'network');
    expect(preferences.getString(preferences.getKeys().single),
      isNot(contains('private upstream details')));
  });

  test('redirects and non-2xx responses stay pending without following another host', () async {
    final preferences = await SharedPreferences.getInstance();
    var status = 302;
    var calls = 0;
    final service = _service(preferences, client: MockClient((request) async {
      calls++;
      expect(request.followRedirects, isFalse);
      expect(request.url.host, 'example.com');
      return http.Response('not accepted', status,
        headers: {'location': 'https://other.invalid/collect'});
    }));
    final report = await _enqueue(service);
    for (final code in [302, 400, 401, 429, 500]) {
      status = code;
      expect(await service.send(report.clientReportId), isNull);
      await preferences.reload();
      final saved = (await service.pending()).single;
      expect(saved.payload, report.payload);
      expect(saved.lastError, 'http_$code');
    }
    expect(calls, 5);
  });

  test('a timed-out request is aborted and retained for retry', () async {
    final preferences = await SharedPreferences.getInstance();
    var aborted = false;
    final service = _service(preferences, timeout: const Duration(milliseconds: 30),
      client: MockClient.streaming((request, body) async {
        await body.drain<void>();
        expect(request, isA<http.AbortableRequest>());
        await (request as http.AbortableRequest).abortTrigger!;
        aborted = true;
        throw http.RequestAbortedException(request.url);
      }));
    final report = await _enqueue(service);
    expect(await service.send(report.clientReportId), isNull);
    expect(aborted, isTrue);
    await preferences.reload();
    final saved = (await service.pending()).single;
    expect(saved.payload, report.payload);
    expect(saved.lastError, 'timeout');
  });

  test('storage failure cannot enqueue, start HTTP or report an acknowledgement as sent', () async {
    final disk = await SharedPreferences.getInstance();
    final preferences = _ControlledPreferences(disk);
    var calls = 0;
    final service = _service(preferences, client: MockClient((request) async {
      calls++;
      return _receipt((jsonDecode(request.body) as Map)['clientReportId'] as String);
    }));
    preferences.failWrites = true;
    await expectLater(_enqueue(service), throwsA(_state('save_failed')));
    expect(disk.getKeys(), isEmpty);
    expect(calls, 0);
    preferences.failWrites = false;
    final report = await _enqueue(service);
    preferences.failWrites = true;
    await expectLater(service.send(report.clientReportId), throwsA(_state('save_failed')));
    expect(calls, 0);
    expect((await service.pending()).single.payload, report.payload);
    preferences.failWrites = false;
    preferences.failRemovals = true;
    await expectLater(service.send(report.clientReportId), throwsA(_state('save_failed')));
    expect(calls, 1);
    await disk.reload();
    expect((await service.pending()).single.payload, report.payload);
    preferences.failRemovals = false;
    expect(await service.send(report.clientReportId), 73);
    expect(calls, 2);
    expect(await service.pending(), isEmpty);
  });

  test('failure to persist the retry error is surfaced without losing the original report', () async {
    final disk = await SharedPreferences.getInstance();
    final preferences = _ControlledPreferences(disk);
    final service = _service(preferences, client: MockClient((_) async {
      preferences.failWrites = true;
      throw http.ClientException('offline');
    }));
    final report = await _enqueue(service);
    await expectLater(service.send(report.clientReportId), throwsA(_state('save_failed')));
    await disk.reload();
    final saved = (await service.pending()).single;
    expect(saved.payload, report.payload);
    expect(saved.lastError, isNull);
  });

  test('pending reports and retry IDs are isolated by captured profile and normalized server', () async {
    final preferences = await SharedPreferences.getInstance();
    var calls = 0;
    final client = MockClient((_) async { calls++; return http.Response('{}', 500); });
    final original = _service(preferences, client: client);
    final sameServer = _service(preferences, baseUrl: 'https://EXAMPLE.com/');
    final otherProfile = _service(preferences, profileId: 'p_${'a' * 24}', client: client);
    final otherServer = _service(preferences, baseUrl: 'https://other.example', client: client);
    final first = await _enqueue(original);
    final second = await _enqueue(otherProfile);
    final third = await _enqueue(otherServer);
    expect((await original.pending()).single.clientReportId, first.clientReportId);
    expect((await sameServer.pending()).single.clientReportId, first.clientReportId);
    expect((await otherProfile.pending()).single.clientReportId, second.clientReportId);
    expect((await otherServer.pending()).single.clientReportId, third.clientReportId);
    expect(await otherProfile.send(first.clientReportId), isNull);
    expect(await otherServer.send(first.clientReportId), isNull);
    expect(calls, 0);
    expect((await original.pending()).single.payload, first.payload);
  });

  test('a new service retries the identical captured ID and body instead of creating another report', () async {
    final preferences = await SharedPreferences.getInstance();
    final bodies = <Map<String, dynamic>>[];
    final firstService = _service(preferences, client: MockClient((request) async {
      bodies.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      return http.Response('', 503);
    }));
    final report = await _enqueue(firstService);
    expect(await firstService.send(report.clientReportId), isNull);
    await preferences.reload();
    final retryService = _service(preferences, client: MockClient((request) async {
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      bodies.add(body);
      return _receipt(body['clientReportId'] as String, reportId: 91);
    }));
    expect((await retryService.pending()).single.clientReportId, report.clientReportId);
    expect(await retryService.send(report.clientReportId), 91);
    expect(bodies, [report.payload, report.payload]);
    expect(await retryService.pending(), isEmpty);
  });

  test('the 20-item limit rejects new captures and draining a legacy batch preserves its 21st item', () async {
    final preferences = await SharedPreferences.getInstance();
    var calls = 0;
    final service = _service(preferences, client: MockClient((request) async {
      calls++;
      return _receipt((jsonDecode(request.body) as Map)['clientReportId'] as String,
        reportId: calls);
    }));
    final captured = <ReaderPageReport>[];
    for (var page = 1; page <= 20; page++) {
      captured.add(await _enqueue(service, pageNumber: page));
    }
    final ids = captured.map((report) => report.clientReportId).toSet();
    expect(ids.length, 20);
    for (final id in ids) { expect(id, matches(r'^[a-f0-9]{32}$')); }
    await expectLater(_enqueue(service, pageNumber: 21), throwsA(_state('queue_full')));
    expect((await service.pending()).length, 20);
    final firstKey = preferences.getKeys().singleWhere((key) => key.endsWith(captured.first.clientReportId));
    final prefix = firstKey.substring(0, firstKey.length - 32);
    final overflowId = List.generate(21, (index) => index.toRadixString(16).padLeft(32, '0'))
      .firstWhere((id) => !ids.contains(id));
    await preferences.setString('$prefix$overflowId', jsonEncode({
      ...captured.first.payload, 'clientReportId': overflowId, 'pageNumber': 21,
    }));
    final allIds = {...ids, overflowId};
    final batch = await service.pending();
    expect(batch.length, 20);
    final excluded = allIds.difference(batch.map((report) => report.clientReportId).toSet()).single;
    final excludedRaw = preferences.getString('$prefix$excluded');
    for (final report in batch) {
      expect(await service.send(report.clientReportId), isNotNull);
    }
    await preferences.reload();
    expect(calls, 20);
    expect((await service.pending()).single.clientReportId, excluded);
    expect(preferences.getString('$prefix$excluded'), excludedRaw);
    expect(await service.send(excluded), 21);
    expect(await service.pending(), isEmpty);
  });

  test('payload validation rejects invalid pages, issue types, editions, oversized text and controls including DEL', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = _service(preferences);
    for (final page in [-1, 0, 10001]) {
      await expectLater(_enqueue(service, pageNumber: page), throwsArgumentError);
    }
    for (final type in ['', 'blur', 'BLURRED', 'resolved']) {
      await expectLater(_enqueue(service, issueType: type), throwsArgumentError);
    }
    for (final edition in ['', '16 Line', '../16_line', 'A', 'a' * 65]) {
      await expectLater(_enqueue(service, editionKey: edition), throwsArgumentError);
    }
    await expectLater(_enqueue(service, description: 'x' * 1001), throwsArgumentError);
    for (final control in [0, 8, 11, 12, 14, 31, 127]) {
      await expectLater(_enqueue(service, description: 'before${String.fromCharCode(control)}after'),
        throwsArgumentError);
    }
    expect(await service.pending(), isEmpty);
    for (final type in ['missing', 'blurred', 'wrong_page', 'other']) {
      expect((await _enqueue(service, issueType: type)).issueType, type);
    }
    expect((await _enqueue(service, pageNumber: 1)).pageNumber, 1);
    expect((await _enqueue(service, pageNumber: 10000)).pageNumber, 10000);
    expect((await _enqueue(service, description: 'x' * 1000)).description.length, 1000);
    expect((await _enqueue(service, description: '  first\tline\nsecond\r\nthird  ')).description,
      'first\tline\nsecond\r\nthird');
    expect((await _enqueue(service, description: '   ')).description, isEmpty);
  });

  test('remote HTTP keeps reports private while loopback HTTP is usable for local QA', () async {
    final preferences = await SharedPreferences.getInstance();
    var remoteCalls = 0;
    final remote = _service(preferences, baseUrl: 'http://example.com',
      client: MockClient((_) async { remoteCalls++; return http.Response('{}', 200); }));
    final report = await _enqueue(remote);
    expect(await remote.send(report.clientReportId), isNull);
    expect(remoteCalls, 0);
    expect((await remote.pending()).single.lastError, 'insecure_server');
    final local = _service(preferences, baseUrl: 'http://127.0.0.1:54123',
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:54123/public/page-reports');
        return _receipt((jsonDecode(request.body) as Map)['clientReportId'] as String);
      }));
    final localReport = await _enqueue(local);
    expect(await local.send(localReport.clientReportId), 73);
    expect((await remote.pending()).single.clientReportId, report.clientReportId);
  });

  test('dispose aborts the active request, keeps its capture and prevents later sends or enqueues', () async {
    final preferences = await SharedPreferences.getInstance();
    final started = Completer<void>();
    var aborted = false;
    final client = _ClosingMockClient((request, body) async {
      await body.drain<void>();
      expect(request, isA<http.AbortableRequest>());
      started.complete();
      await (request as http.AbortableRequest).abortTrigger!;
      aborted = true;
      throw http.RequestAbortedException(request.url);
    });
    final service = _service(preferences, client: client);
    final report = await _enqueue(service);
    final sending = service.send(report.clientReportId);
    await started.future;
    service.dispose();
    expect(await sending, isNull);
    expect(aborted, isTrue);
    expect(client.closed, isTrue);
    final saved = (await service.pending()).single;
    expect(saved.payload, report.payload);
    expect(saved.lastError, 'cancelled');
    expect(await service.send(report.clientReportId), isNull);
    await expectLater(_enqueue(service), throwsA(_state('closed')));
  });
}
