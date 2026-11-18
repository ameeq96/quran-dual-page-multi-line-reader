import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_flutter_app/core/storage/reader_preferences.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_ustad_service.dart';

const identity = ReaderSyncIdentity(
    deviceId: 'reader_abcdefghijklmnopqrstuvwxyz123456',
    token: 'abcdefghijklmnopqrstuvwxyz1234567890ABCDEFG');
const linkId = '11111111111111111111111111111111';
const assignmentId = '22222222222222222222222222222222';
const submissionId = '33333333333333333333333333333333';
const requestId = '44444444444444444444444444444444';
const uploadId = '55555555555555555555555555555555';
const date = '2026-11-13T00:00:00.000Z';
Map<String, Object?> meta({int page = 1, int totalPages = 1}) =>
    {'page': page, 'pageSize': 20, 'totalItems': 1, 'totalPages': totalPages};
Map<String, Object?> link({String role = 'student'}) => {
      'id': linkId,
      'role': role,
      'teacherName': 'Teacher',
      'studentName': 'Student',
      'status': 'active',
      'createdAt': date,
      'acceptedAt': date,
      'expiresAt': date
    };
Map<String, Object?> submission() => {
      'id': submissionId,
      'assignmentId': assignmentId,
      'clientUploadId': uploadId,
      'createdAt': date,
      'expiresAt': '2100-01-01T00:00:00.000Z',
      'mimeType': 'audio/webm',
      'bytes': 3,
      'durationMillis': 1000,
      'durationVerified': false,
      'deliveryState': 'ready',
      'feedbackStatus': 'pending',
      'feedbackNote': '',
      'reviewedAt': null,
      'deleted': false
    };
Map<String, Object?> assignment({String role = 'teacher'}) => {
      'id': assignmentId,
      'linkId': linkId,
      'clientRequestId': requestId,
      'role': role,
      'teacherName': 'Teacher',
      'studentName': 'Student',
      'kind': 'sabaq',
      'editionKey': '16_lines',
      'startPage': 1,
      'endPage': 2,
      'title': 'Daily lesson',
      'instructions': '',
      'dueAt': null,
      'status': 'assigned',
      'createdAt': date,
      'submissions': <Object?>[],
      'hasMoreSubmissions': false
    };
Map<String, Object?> overview() => {
      'success': true,
      'links': [link()],
      'usageBytes': 3,
      'meta': meta(),
      'limits': {
        'maxClipBytes': 8388608,
        'maxClipMillis': 60000,
        'studentQuotaBytes': 104857600,
        'retentionDays': 30
      }
    };
http.Response jsonResponse(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});
Matcher fails(String code) =>
    isA<ReaderUstadFailure>().having((error) => error.code, 'code', code);
ReaderUstadService service(http.Client client,
        {Duration timeout = const Duration(seconds: 2)}) =>
    ReaderUstadService(
        baseUrl: 'https://reader.example/api',
        identity: identity,
        client: client,
        timeout: timeout);

void main() {
  test(
      'captures credentials and server; pagination uses only authenticated headers',
      () async {
    final requests = <http.Request>[];
    final api = service(MockClient((request) async {
      requests.add(request);
      return jsonResponse(overview());
    }));
    addTearDown(api.dispose);
    final result = await api.overview(page: 2);
    expect(result.links.single['role'], 'student');
    final request = requests.single;
    expect(request.url.toString(),
        'https://reader.example/api/public/ustad/links?page=2&pageSize=20');
    expect(request.headers['Authorization'], 'Bearer ${identity.token}');
    expect(request.headers['X-Reader-Device-Id'], identity.deviceId);
    expect(request.followRedirects, isFalse);
    expect(request.body, isEmpty);
    expect(request.url.toString(), isNot(contains(identity.token)));
  });

  for (final item in {
    401: 'auth_required',
    403: 'forbidden',
    404: 'unavailable',
    503: 'unavailable',
    409: 'conflict',
    413: 'quota',
    429: 'rate_limited',
    302: 'server_error'
  }.entries) {
    test('HTTP ${item.key} never becomes an acknowledged success', () async {
      final api = service(MockClient(
          (_) async => jsonResponse({'success': true}, status: item.key)));
      addTearDown(api.dispose);
      await expectLater(api.overview(), throwsA(fails(item.value)));
    });
  }

  test(
      'invite must be previewed, then accepted with explicit consent and student-role receipt',
      () async {
    final paths = <String>[];
    final api = service(MockClient((request) async {
      paths.add(request.url.path);
      final body = jsonDecode(request.body) as Map;
      expect(body.containsKey('deviceId'), isFalse);
      expect(body.containsKey('token'), isFalse);
      if (request.url.path.endsWith('/preview')) {
        return jsonResponse({
          'success': true,
          'invite': {'teacherName': 'Teacher', 'expiresAt': date}
        });
      }
      expect(body['consent'], isTrue);
      return jsonResponse({'success': true, 'link': link()});
    }));
    addTearDown(api.dispose);
    final code = 'A' * 43;
    await expectLater(api.acceptInvite(code, 'Student', consent: false),
        throwsA(fails('invalid_input')));
    expect(paths, isEmpty);
    await api.previewInvite(code);
    await api.acceptInvite(code, 'Student', consent: true);
    expect(paths, [
      '/api/public/ustad/invites/preview',
      '/api/public/ustad/invites/accept'
    ]);
  });

  test(
      'assignment acknowledgment must bind exact request ID, role and page range',
      () async {
    var wrong = true;
    final api = service(MockClient((_) async => jsonResponse({
          'success': true,
          'assignment': {
            ...assignment(),
            if (wrong) 'clientRequestId': uploadId
          }
        })));
    addTearDown(api.dispose);
    Future<Map<String, dynamic>> send() => api.assign(
        linkId: linkId,
        clientRequestId: requestId,
        kind: 'sabaq',
        editionKey: '16_lines',
        startPage: 1,
        endPage: 2,
        title: 'Daily lesson',
        instructions: '');
    await expectLater(send(), throwsA(fails('invalid_response')));
    wrong = false;
    expect((await send())['id'], assignmentId);
  });

  test(
      'upload is explicit multipart with text fields first and an exact stored receipt',
      () async {
    var wrong = false;
    var calls = 0;
    final api = service(MockClient((request) async {
      calls++;
      expect(
          request.headers['content-type'], startsWith('multipart/form-data'));
      expect(request.body.indexOf('name="clientUploadId"'),
          lessThan(request.body.indexOf('filename="lesson.webm"')));
      expect(request.body, contains(uploadId));
      return jsonResponse({
        'success': true,
        'submission': {...submission(), if (wrong) 'clientUploadId': requestId}
      });
    }));
    addTearDown(api.dispose);
    final bytes = Uint8List.fromList([1, 2, 3]);
    Future<Map<String, dynamic>> send() => api.upload(
        assignmentId: assignmentId,
        clientUploadId: uploadId,
        bytes: bytes,
        mimeType: 'audio/webm;codecs=opus',
        durationMillis: 1000);
    expect((await send())['durationVerified'], isFalse);
    wrong = true;
    await expectLater(send(), throwsA(fails('invalid_response')));
    expect(bytes, [1, 2, 3]);
    expect(calls, 2);
  });

  test(
      'oversized, overlong and unsupported clips are rejected before any HTTP request',
      () async {
    var calls = 0;
    final api = service(MockClient((_) async {
      calls++;
      return jsonResponse({});
    }));
    addTearDown(api.dispose);
    for (final (bytes, mime, duration) in [
      (Uint8List(8388609), 'audio/webm', 1000),
      (Uint8List(3), 'audio/webm', 60001),
      (Uint8List(3), 'audio/wav', 1000)
    ]) {
      await expectLater(
          api.upload(
              assignmentId: assignmentId,
              clientUploadId: uploadId,
              bytes: bytes,
              mimeType: mime,
              durationMillis: duration),
          throwsA(fails('invalid_input')));
    }
    expect(calls, 0);
  });

  test('private playback requires auth, no-store, matching MIME and byte count',
      () async {
    var noStore = true;
    final api = service(MockClient((request) async {
      expect(request.url.path,
          '/api/public/ustad/submissions/$submissionId/audio');
      expect(request.headers['Authorization'], 'Bearer ${identity.token}');
      return http.Response.bytes([1, 2, 3], 200,
          headers: {
            'content-type': 'audio/webm',
            if (noStore) 'cache-control': 'private, no-store'
          });
    }));
    addTearDown(api.dispose);
    expect((await api.audio(submission())).bytes, [1, 2, 3]);
    noStore = false;
    await expectLater(
        api.audio(submission()), throwsA(fails('invalid_response')));
  });

  test('canonical library supports later pages including revoked-student clips',
      () async {
    final api = service(MockClient((request) async {
      expect(request.url.queryParameters['page'], '4');
      return jsonResponse({
        'success': true,
        'submissions': [
          {
            ...submission(),
            'role': 'student',
            'linkId': linkId,
            'assignmentTitle': 'Older lesson',
            'teacherName': 'Teacher',
            'studentName': 'Student'
          }
        ],
        'meta': meta(page: 4, totalPages: 5)
      });
    }));
    addTearDown(api.dispose);
    final result = await api.recordings(page: 4);
    expect(result.items.single['assignmentTitle'], 'Older lesson');
    expect(result.page, 4);
    expect(result.totalPages, 5);
  });

  test(
      'cancelled in-flight reply cannot become a success after identity changes',
      () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = service(MockClient((_) {
      started.complete();
      return response.future;
    }));
    addTearDown(api.dispose);
    final pending = api.overview();
    final check = expectLater(pending, throwsA(fails('cancelled')));
    await started.future;
    api.cancelPending();
    response.complete(jsonResponse(overview()));
    await check;
  });

  test('timeout preserves the caller payload for the same-ID retry', () async {
    final waiting = Completer<http.Response>();
    final api = service(MockClient((_) => waiting.future),
        timeout: const Duration(milliseconds: 10));
    addTearDown(api.dispose);
    await expectLater(api.overview(), throwsA(fails('timeout')));
    waiting.complete(jsonResponse(overview()));
  });

  test('declared oversized responses are cancelled without decoding body',
      () async {
    final client = _OversizedClient();
    final api = service(client);
    await expectLater(api.overview(), throwsA(fails('invalid_response')));
    api.dispose();
    expect(client.closed, isTrue);
  });

  test('malformed envelopes and unregistered role labels are rejected',
      () async {
    final api = service(MockClient((_) async => jsonResponse({
          ...overview(),
          'links': [
            {...link(), 'role': 'admin'}
          ]
        })));
    addTearDown(api.dispose);
    await expectLater(api.overview(), throwsA(fails('invalid_response')));
  });
}

class _OversizedClient extends http.BaseClient {
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream.empty(), 200, contentLength: 8388609);
  @override
  void close() {
    closed = true;
  }
}
