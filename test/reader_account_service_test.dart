import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_flutter_app/core/storage/reader_preferences.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_account_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final identity = ReaderSyncIdentity(deviceId: 'reader_${'a' * 32}', token: 'b' * 43);
  Map<String, dynamic> account({String? email = 'reader@example.com'}) => {
    'success': true, 'deviceId': identity.deviceId, 'token': identity.token, 'email': email,
  };
  Matcher failure(String text) => isA<ReaderAccountFailure>().having((error) => error.message, 'safe message', contains(text));

  test('sign in normalizes email, uses POST JSON and refuses redirects', () async {
    final service = ReaderAccountService(client: MockClient((request) async {
      expect(request.url.toString(), 'https://example.com/public/sync/account/login');
      expect(request.method, 'POST');
      expect(request.followRedirects, isFalse);
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(json.decode(request.body), {'email': 'reader@example.com', 'password': 'long-password-123'});
      return http.Response(json.encode(account()), 200);
    }));
    addTearDown(service.dispose);
    final result = await service.login('https://example.com/', email: ' Reader@EXAMPLE.com ', password: 'long-password-123');
    expect(result.email, 'reader@example.com');
    expect(result.identity.deviceId, identity.deviceId);
    expect(result.recoveryKey, isNull);
  });

  test('private status uses bearer header and device body without leaking token in URL', () async {
    final service = ReaderAccountService(client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer ${identity.token}');
      expect(request.url.toString(), isNot(contains(identity.token)));
      expect(json.decode(request.body), {'deviceId': identity.deviceId});
      return http.Response('{"success":true,"email":null,"recoveryEnabled":false}', 200);
    }));
    addTearDown(service.dispose);
    final result = await service.status('https://example.com', identity);
    expect(result.email, isNull);
    expect(result.recoveryEnabled, isFalse);
  });

  test('insecure remote host is rejected before sending credentials', () async {
    var calls = 0;
    final service = ReaderAccountService(client: MockClient((_) async { calls++; return http.Response('{}', 200); }));
    addTearDown(service.dispose);
    await expectLater(service.login('http://example.com', email: 'reader@example.com', password: 'long-password-123'), throwsA(failure('HTTPS')));
    expect(calls, 0);
  });

  test('loopback HTTP is available for isolated local QA', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response(json.encode(account()), 200)));
    addTearDown(service.dispose);
    expect((await service.login('http://127.0.0.1:54123', email: 'reader@example.com', password: 'long-password-123')).email, 'reader@example.com');
  });

  test('unauthorized errors never display server response or supplied secrets', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response('secret-token password database stack', 401)));
    addTearDown(service.dispose);
    await expectLater(service.login('https://example.com', email: 'reader@example.com', password: 'long-password-123'), throwsA(failure('not accepted')));
  });

  test('redirect responses cannot return a candidate account', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response(json.encode(account()), 302, headers: {'location': 'https://attacker.invalid'})));
    addTearDown(service.dispose);
    await expectLater(service.login('https://example.com', email: 'reader@example.com', password: 'long-password-123'), throwsA(failure('failed')));
  });

  test('malformed account identity cannot be adopted', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response(json.encode({...account(), 'token': 'short'}), 200)));
    addTearDown(service.dispose);
    await expectLater(service.login('https://example.com', email: 'reader@example.com', password: 'long-password-123'), throwsA(failure('invalid data')));
  });

  test('registration requires a valid one-time recovery key', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response(json.encode(account()), 200)));
    addTearDown(service.dispose);
    await expectLater(service.register('https://example.com', identity, email: 'reader@example.com', password: 'long-password-123'), throwsA(failure('invalid data')));
  });

  test('a sign-in response must match the requested normalized account email', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response(json.encode(account(email: 'different@example.com')), 200)));
    addTearDown(service.dispose);
    await expectLater(service.login('https://example.com', email: 'reader@example.com', password: 'long-password-123'), throwsA(failure('invalid data')));
  });

  test('cancelling UI does not discard an issued registration rotation response', () async {
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    final service = ReaderAccountService(client: MockClient((_) { sent.complete(); return response.future; }));
    addTearDown(service.dispose);
    final result = service.register('https://example.com', identity, email: 'reader@example.com', password: 'long-password-123');
    await sent.future;
    service.cancelPending();
    response.complete(http.Response(json.encode({...account(), 'recoveryKey': 'r' * 43}), 200));
    expect((await result).recoveryKey, 'r' * 43);
  });

  test('pairing response permits an anonymous private backup', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response(json.encode(account(email: null)), 200)));
    addTearDown(service.dispose);
    final result = await service.redeemPairing('https://example.com', 'c' * 43);
    expect(result.email, isNull);
    expect(result.identity.token, identity.token);
  });

  test('expired pairing codes returned by server are rejected', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response(json.encode({
      'success': true, 'code': 'c' * 43, 'expiresAt': DateTime.now().subtract(const Duration(minutes: 1)).toUtc().toIso8601String(),
    }), 200)));
    addTearDown(service.dispose);
    await expectLater(service.createPairing('https://example.com', identity), throwsA(failure('invalid data')));
  });

  test('oversized passwords and invalid pairing codes are rejected before HTTP', () async {
    var calls = 0;
    final service = ReaderAccountService(client: MockClient((_) async { calls++; return http.Response('{}', 200); }));
    addTearDown(service.dispose);
    await expectLater(service.login('https://example.com', email: 'reader@example.com', password: 'ض' * 40), throwsA(failure('72 UTF-8 bytes')));
    await expectLater(service.redeemPairing('https://example.com', 'https://example.com/?token=secret'), throwsA(failure('valid pairing')));
    expect(calls, 0);
  });

  test('candidate backup must belong to candidate identity', () async {
    final service = ReaderAccountService(client: MockClient((_) async => http.Response(json.encode({
      'success': true, 'found': true, 'payload': {'deviceId': 'another_device'},
    }), 200)));
    addTearDown(service.dispose);
    await expectLater(service.fetchBackup('https://example.com', identity), throwsA(failure('invalid data')));
  });

  test('pending account responses are discarded after cancellation', () async {
    final response = Completer<http.Response>();
    final sent = Completer<void>();
    final service = ReaderAccountService(client: MockClient((_) { sent.complete(); return response.future; }));
    addTearDown(service.dispose);
    final result = service.login('https://example.com', email: 'reader@example.com', password: 'long-password-123');
    await sent.future;
    service.cancelPending();
    response.complete(http.Response(json.encode(account()), 200));
    await expectLater(result, throwsA(failure('cancelled')));
  });

  test('hung requests return a bounded timeout', () async {
    final service = ReaderAccountService(timeout: const Duration(milliseconds: 10), client: MockClient((_) => Completer<http.Response>().future));
    addTearDown(service.dispose);
    await expectLater(service.login('https://example.com', email: 'reader@example.com', password: 'long-password-123'), throwsA(failure('timed out')));
  });

  test('saving account identity preserves other backend credentials and reader settings', () async {
    SharedPreferences.setMockInitialValues({'reader.interface.language': 'arabic', 'unrelated': 'keep'});
    final preferences = ReaderPreferences();
    final other = await preferences.loadOrCreateSyncIdentity('https://other.example');
    await preferences.saveSyncIdentity('https://example.com/', identity);
    final saved = await preferences.loadOrCreateSyncIdentity('https://example.com');
    expect(saved.deviceId, identity.deviceId);
    expect(saved.token, identity.token);
    expect((await preferences.loadOrCreateSyncIdentity('https://other.example')).token, other.token);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('reader.interface.language'), 'arabic');
    expect(prefs.getString('unrelated'), 'keep');
  });

  test('invalid identity never overwrites the saved private backup identity', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = ReaderPreferences();
    await preferences.saveSyncIdentity('https://example.com', identity);
    await expectLater(preferences.saveSyncIdentity('https://example.com', const ReaderSyncIdentity(deviceId: 'bad', token: 'bad')), throwsFormatException);
    expect((await preferences.loadOrCreateSyncIdentity('https://example.com')).token, identity.token);
  });
}
