import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/storage/reader_preferences.dart';

class ReaderAccountFailure implements Exception {
  const ReaderAccountFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReaderAccountIdentity {
  const ReaderAccountIdentity({required this.identity, required this.email, this.recoveryKey});
  final ReaderSyncIdentity identity;
  final String? email;
  final String? recoveryKey;
}

class ReaderAccountStatus {
  const ReaderAccountStatus({required this.email, required this.recoveryEnabled});
  final String? email;
  final bool recoveryEnabled;
}

class ReaderPairingCode {
  const ReaderPairingCode({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
  bool get expired => !expiresAt.isAfter(DateTime.now().toUtc());
}

class ReaderAccountBackup extends MapView<String, dynamic> {
  ReaderAccountBackup(super.map, {required this.syncRevision});
  final int syncRevision;
}

class ReaderAccountService {
  ReaderAccountService({http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();
  final http.Client _client;
  final Duration timeout;
  final Set<Completer<void>> _pending = {};
  final Set<Completer<void>> _rotating = {};
  int _generation = 0;

  static bool validCode(String value) => RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value);

  Future<ReaderAccountStatus> status(String baseUrl, ReaderSyncIdentity identity) async {
    final data = await _request(baseUrl, 'account/status', {'deviceId': identity.deviceId}, identity: identity);
    final email = data['email'];
    if (email != null && (email is! String || !_validEmail(email)) || data['recoveryEnabled'] is! bool) _invalid();
    return ReaderAccountStatus(email: email as String?, recoveryEnabled: data['recoveryEnabled'] as bool);
  }

  Future<ReaderAccountIdentity> register(String baseUrl, ReaderSyncIdentity identity,
      {required String email, required String password}) async {
    _validateLogin(email, password);
    return _identity(await _request(baseUrl, 'account/register', {
      'deviceId': identity.deviceId, 'email': email.trim().toLowerCase(), 'password': password,
    }, identity: identity), recoveryRequired: true, expectedEmail: email.trim().toLowerCase());
  }

  Future<ReaderAccountIdentity> login(String baseUrl, {required String email, required String password}) async {
    _validateLogin(email, password);
    return _identity(await _request(baseUrl, 'account/login', {
      'email': email.trim().toLowerCase(), 'password': password,
    }), expectedEmail: email.trim().toLowerCase());
  }

  Future<ReaderAccountIdentity> recover(String baseUrl,
      {required String email, required String password, required String recoveryKey}) async {
    _validateLogin(email, password);
    if (!validCode(recoveryKey.trim())) throw const ReaderAccountFailure('Enter a valid recovery key.');
    return _identity(await _request(baseUrl, 'account/recover', {
      'email': email.trim().toLowerCase(), 'password': password, 'recoveryKey': recoveryKey.trim(),
    }), recoveryRequired: true, expectedEmail: email.trim().toLowerCase());
  }

  Future<ReaderPairingCode> createPairing(String baseUrl, ReaderSyncIdentity identity) async {
    final data = await _request(baseUrl, 'pairing/create', {'deviceId': identity.deviceId}, identity: identity);
    final code = data['code'];
    final expiry = data['expiresAt'] is String ? DateTime.tryParse(data['expiresAt'] as String) : null;
    if (code is! String || !validCode(code) || expiry == null || !expiry.isAfter(DateTime.now().toUtc()) ||
        expiry.difference(DateTime.now().toUtc()) > const Duration(minutes: 6)) {
      _invalid();
    }
    return ReaderPairingCode(code: code, expiresAt: expiry.toUtc());
  }

  Future<ReaderAccountIdentity> redeemPairing(String baseUrl, String code) async {
    if (!validCode(code.trim())) throw const ReaderAccountFailure('Enter a valid pairing code.');
    return _identity(await _request(baseUrl, 'pairing/redeem', {'code': code.trim()}), allowAnonymous: true);
  }

  Future<void> cancelPairing(String baseUrl, ReaderSyncIdentity identity) async {
    await _request(baseUrl, 'pairing/cancel', {'deviceId': identity.deviceId}, identity: identity);
  }

  Future<Map<String, dynamic>> fetchBackup(String baseUrl, ReaderSyncIdentity identity) async {
    final data = await _request(baseUrl, 'pull', {'deviceId': identity.deviceId}, identity: identity, get: true);
    if (data['found'] != true || data['payload'] is! Map<String, dynamic>) {
      throw const ReaderAccountFailure('This account has no reader backup yet. Sync its original device first.');
    }
    final payload = data['payload'] as Map<String, dynamic>;
    if (payload['deviceId'] != identity.deviceId) _invalid();
    final revision = data.containsKey('syncRevision') ? data['syncRevision'] : 0;
    if (revision is! int || revision < 0 || revision > 9007199254740991) _invalid();
    return ReaderAccountBackup(payload, syncRevision: revision);
  }

  Future<Map<String, dynamic>> _request(String baseUrl, String path, Map<String, dynamic> body,
      {ReaderSyncIdentity? identity, bool get = false}) async {
    final normalized = ReaderPreferences.normalizeSyncBaseUrl(baseUrl);
    var uri = Uri.parse('$normalized/public/sync/$path');
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && const {'localhost', '127.0.0.1', '::1'}.contains(uri.host))) {
      throw const ReaderAccountFailure('Accounts require HTTPS or a local test server.');
    }
    if (identity != null && !ReaderPreferences.isValidSyncIdentity(identity)) _invalid();
    if (get) uri = uri.replace(queryParameters: body.map((key, value) => MapEntry(key, value.toString())));
    final generation = _generation;
    final abort = Completer<void>();
    _pending.add(abort);
    final rotatesIdentity = path == 'account/register' || path == 'account/recover';
    if (rotatesIdentity) _rotating.add(abort);
    var timedOut = false;
    final timer = Timer(timeout, () { timedOut = true; if (!abort.isCompleted) abort.complete(); });
    try {
      final request = http.AbortableRequest(get ? 'GET' : 'POST', uri, abortTrigger: abort.future)..followRedirects = false;
      request.headers.addAll({'Accept': 'application/json', 'Content-Type': 'application/json'});
      if (identity != null) request.headers['Authorization'] = 'Bearer ${identity.token}';
      if (!get) request.body = json.encode(body);
      final response = await (() async => http.Response.fromStream(await _client.send(request)))().timeout(timeout);
      if (generation != _generation && !rotatesIdentity) throw const ReaderAccountFailure('Account request was cancelled.');
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ReaderAccountFailure('Account credentials or pairing code were not accepted.');
      }
      if (response.statusCode == 409) throw const ReaderAccountFailure('This email or device already has an account. Sign in instead.');
      if (response.statusCode == 429) throw const ReaderAccountFailure('Too many attempts. Wait a few minutes and try again.');
      if (response.statusCode == 404 || response.statusCode == 503) throw const ReaderAccountFailure('Accounts are unavailable on this server. Your local reader is unchanged.');
      if (response.statusCode != 200 && response.statusCode != 201) throw const ReaderAccountFailure('Account request failed. Your local reader is unchanged.');
      if (response.body.length > 10000000) _invalid();
      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) _invalid();
      return decoded;
    } on ReaderAccountFailure {
      rethrow;
    } on http.RequestAbortedException {
      if (timedOut && rotatesIdentity) {
        throw const ReaderAccountFailure('Account request timed out. If creation or recovery completed, sign in with your password.');
      }
      throw ReaderAccountFailure(timedOut ? 'Account request timed out. Try again.' : 'Account request was cancelled.');
    } on TimeoutException {
      throw ReaderAccountFailure(rotatesIdentity
          ? 'Account request timed out. If creation or recovery completed, sign in with your password.'
          : 'Account request timed out. Try again.');
    } on FormatException {
      _invalid();
    } catch (_) {
      throw ReaderAccountFailure(generation != _generation ? 'Account request was cancelled.' : 'Account server could not be reached. Try again.');
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      _pending.remove(abort);
      _rotating.remove(abort);
    }
  }

  static bool _validEmail(String value) => value.length <= 254 && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  static void _validateLogin(String email, String password) {
    if (!_validEmail(email.trim())) throw const ReaderAccountFailure('Enter a valid email address.');
    if (password.length < 12 || utf8.encode(password).length > 72) {
      throw const ReaderAccountFailure('Use a password of at least 12 characters and at most 72 UTF-8 bytes.');
    }
  }

  ReaderAccountIdentity _identity(Map<String, dynamic> data, {bool recoveryRequired = false, bool allowAnonymous = false, String? expectedEmail}) {
    final id = data['deviceId'];
    final token = data['token'];
    final email = data['email'];
    final recovery = data['recoveryKey'];
    if (expectedEmail != null && email != expectedEmail) _invalid();
    if (id is! String || token is! String ||
        (!(allowAnonymous && email == null) && (email is! String || !_validEmail(email))) ||
        !ReaderPreferences.isValidSyncIdentity(ReaderSyncIdentity(deviceId: id, token: token)) ||
        (recoveryRequired && (recovery is! String || !validCode(recovery)))) {
      _invalid();
    }
    return ReaderAccountIdentity(identity: ReaderSyncIdentity(deviceId: id, token: token),
        email: email as String?, recoveryKey: recoveryRequired ? recovery as String : null);
  }

  static Never _invalid() => throw const ReaderAccountFailure('The account server returned invalid data. Your local reader is unchanged.');
  void cancelPending() {
    _generation++;
    for (final abort in _pending.toList()) { if (!_rotating.contains(abort) && !abort.isCompleted) abort.complete(); }
  }
  void dispose() { cancelPending(); _client.close(); }
}
