import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/reader_preferences.dart';
import 'browser_push.dart';

class ReaderBrowserReminderService extends ChangeNotifier {
  ReaderBrowserReminderService._(this.baseUrl, {BrowserPush? browser, http.Client Function()? clientFactory})
      : _browser = browser ?? BrowserPush(), _clientFactory = clientFactory ?? http.Client.new;
  @visibleForTesting
  ReaderBrowserReminderService.forTesting(String baseUrl, {required BrowserPush browser, required http.Client Function() clientFactory})
      : this._(baseUrl, browser: browser, clientFactory: clientFactory);
  static final Map<String, ReaderBrowserReminderService> _instances = {};
  factory ReaderBrowserReminderService.forBaseUrl(String value) {
    final base = ReaderPreferences.normalizeSyncBaseUrl(value);
    final uri = Uri.parse(base);
    if (uri.scheme != 'https' && !const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)) {
      throw const FormatException('Background reminders require HTTPS.');
    }
    return _instances.putIfAbsent(base, () => ReaderBrowserReminderService._(base));
  }

  final String baseUrl;
  final BrowserPush _browser;
  final http.Client Function() _clientFactory;
  bool configured = false;
  bool enabled = false;
  bool busy = false;
  String? error;
  String? _publicKey;
  String? _instanceId;
  Future<void>? _loading;
  bool get supported => _browser.supported;
  String get _key => 'reader.push.${Uri.encodeComponent(baseUrl)}.v1';

  Future<void> initialize() => _loading ??= _load();

  Future<void> _load() async {
    if (!supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final saved = jsonDecode(raw);
        if (saved is Map && saved['instanceId'] is String &&
            RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(saved['instanceId'] as String)) {
          _instanceId = saved['instanceId'] as String;
          enabled = saved['enabled'] == true;
        }
      }
      final config = await _request('GET', 'config');
      configured = config['configured'] == true && config['publicKey'] is String &&
          RegExp(r'^[A-Za-z0-9_-]{87}$').hasMatch(config['publicKey'] as String);
      _publicKey = configured ? config['publicKey'] as String : null;
    } catch (_) {
      error = 'Background reminder service is unavailable. Local reminders still work.';
    }
    notifyListeners();
  }

  Future<void> refresh() async { _loading = null; error = null; await initialize(); }

  Future<void> setEnabled(bool value, {required int hour, required int minute, required String language, bool requestPermission = true}) async {
    if (busy) return;
    if (value && (!supported || !configured || _publicKey == null)) {
      error = 'Background reminders are not configured on this server.';
      notifyListeners(); return;
    }
    busy = true; error = null; notifyListeners();
    final wasEnabled = enabled;
    try {
      final identity = await ReaderPreferences().loadOrCreateSyncIdentity(baseUrl);
      if (!value) {
        await _disable(identity);
      } else {
        final subscription = await _browser.subscribe(_publicKey!, requestPermission: requestPermission);
        _instanceId ??= base64UrlEncode(List<int>.generate(24, (_) => Random.secure().nextInt(256))).replaceAll('=', '');
        try {
          await _request('POST', 'subscribe', identity: identity, body: {
            'deviceId': identity.deviceId, 'instanceId': _instanceId,
            'subscription': subscription, 'hour': hour, 'minute': minute,
            'zone': _browser.timeZone, 'language': language,
          });
          await _persist(true);
          enabled = true;
        } catch (_) {
          // No orphan browser subscription if the server refused registration.
          if (!wasEnabled) await _browser.unsubscribe();
          rethrow;
        }
      }
    } catch (_) {
      error = value
          ? 'Background reminder could not be enabled. Check notification permission and try again.'
          : 'Background reminder could not be disabled. Try again.';
    } finally { busy = false; notifyListeners(); }
  }

  Future<void> updateTime({required int hour, required int minute, required String language}) async {
    if (!enabled || busy) return;
    await setEnabled(true, hour: hour, minute: minute, language: language, requestPermission: false);
  }

  Future<void> detach(ReaderSyncIdentity identity) async {
    await initialize();
    if (busy) throw StateError('Finish updating background reminders before changing account.');
    if (!enabled) return;
    busy = true; notifyListeners();
    try { await _disable(identity); }
    finally { busy = false; notifyListeners(); }
  }

  Future<void> _disable(ReaderSyncIdentity identity) async {
    // Unsubscribe locally first: even a temporary server outage cannot keep delivering.
    await _browser.unsubscribe();
    if (_instanceId != null) {
      await _request('POST', 'unsubscribe', identity: identity,
          body: {'deviceId': identity.deviceId, 'instanceId': _instanceId});
    }
    await _persist(false);
    enabled = false;
  }

  Future<void> _persist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode({'instanceId': _instanceId, 'enabled': value}))) {
      throw StateError('Background reminder settings could not be saved.');
    }
  }

  Future<Map<String, dynamic>> _request(String method, String endpoint,
      {ReaderSyncIdentity? identity, Map<String, dynamic>? body}) async {
    final client = _clientFactory();
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 12), () { if (!abort.isCompleted) abort.complete(); });
    try {
      final request = http.AbortableRequest(method, Uri.parse('$baseUrl/public/reminders/$endpoint'), abortTrigger: abort.future)
        ..followRedirects = false
        ..headers.addAll({'Accept': 'application/json', 'Content-Type': 'application/json',
          if (identity != null) 'Authorization': 'Bearer ${identity.token}'});
      if (body != null) request.body = jsonEncode(body);
      final response = await client.send(request).then(http.Response.fromStream).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.length > 16384) throw StateError('Background reminder request failed.');
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic> || value['success'] != true) throw const FormatException('Invalid reminder response.');
      return value;
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
      client.close();
    }
  }
}

Future<void> detachReaderBrowserReminders({required String baseUrl, required ReaderSyncIdentity identity}) async {
  if (!kIsWeb || baseUrl.isEmpty) return;
  final service = ReaderBrowserReminderService.forBaseUrl(baseUrl);
  ensureReaderBrowserRemindersIdle(baseUrl);
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(service._key);
  bool savedEnabled = false;
  try { savedEnabled = raw != null && (jsonDecode(raw) as Map)['enabled'] == true; } catch (_) { /* No active saved binding. */ }
  if (!service.enabled && !savedEnabled) return;
  await service.detach(identity);
}

void ensureReaderBrowserRemindersIdle(String baseUrl) {
  if (!kIsWeb || baseUrl.isEmpty) return;
  final base = ReaderPreferences.normalizeSyncBaseUrl(baseUrl);
  if (ReaderBrowserReminderService._instances[base]?.busy == true) {
    throw StateError('Finish updating background reminders before changing account.');
  }
}
