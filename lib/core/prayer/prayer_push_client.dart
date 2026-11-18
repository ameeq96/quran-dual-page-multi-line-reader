import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/reader_preferences.dart';
import '../storage/reader_profile_store.dart';
import 'prayer_models.dart';
import 'prayer_platform.dart';

bool Function()? prayerSettingsBusy;

class PrayerPushClient extends ChangeNotifier {
  PrayerPushClient._(this.baseUrl, this.profileId, this.platform);
  static final Map<String, PrayerPushClient> _instances = {};
  factory PrayerPushClient.forProfile(String baseUrl, String profileId, PrayerPlatform platform) {
    final base = ReaderPreferences.normalizeSyncBaseUrl(baseUrl);
    final uri = Uri.parse(base);
    if (uri.scheme != 'https' && !const {'localhost', '127.0.0.1', '::1'}.contains(uri.host)) {
      throw const FormatException('Background prayer reminders require HTTPS.');
    }
    return _instances.putIfAbsent('$profileId:$base', () => PrayerPushClient._(base, profileId, platform));
  }
  final String baseUrl, profileId;
  final PrayerPlatform platform;
  bool configured = false, enabled = false, busy = false;
  String? error, _publicKey, _instanceId;
  bool _saved = false;
  Future<void>? _loading;
  String? get instanceId => _instanceId;
  String get _key => ReaderProfileStore.keyFor('reader.prayerPush.${Uri.encodeComponent(baseUrl)}.v1', profileId);
  Future<void> initialize() => _loading ??= _load();
  Future<void> _load() async {
    if (!platform.backgroundSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final value = jsonDecode(raw);
        if (value is Map && value['instanceId'] is String && RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(value['instanceId'])) {
          _instanceId = value['instanceId'] as String;
          enabled = value['enabled'] == true;
          _saved = enabled;
        }
      }
      final result = await _request('GET', 'config');
      configured = result['configured'] == true && result['publicKey'] is String &&
          RegExp(r'^[A-Za-z0-9_-]{87}$').hasMatch(result['publicKey']);
      _publicKey = configured ? result['publicKey'] as String : null;
      error = configured ? null : 'Background prayer notifications are not configured on this server.';
    } catch (_) { error = 'Background prayer service is unavailable. Open-page reminders still work.'; }
    notifyListeners();
  }
  Future<void> refresh() async { _loading = null; await initialize(); }
  Future<bool> setEnabled(bool value, PrayerSettings settings, {bool locationConsent = false, bool requestPermission = true}) async {
    if (busy) return false;
    if (value && !enabled && !locationConsent) { error = 'Allow sending the selected location and prayer settings first.'; notifyListeners(); return false; }
    if (value && (!settings.enabled || settings.location == null)) { error = 'Enable prayer reminders and choose a location first.'; notifyListeners(); return false; }
    if (value && (!configured || _publicKey == null)) { error = 'Background prayer notifications are not configured on this server.'; notifyListeners(); return false; }
    busy = true; error = null; notifyListeners();
    final wasEnabled = enabled;
    try {
      final identity = await ReaderPreferences(profileId: profileId).loadOrCreateSyncIdentity(baseUrl);
      if (!value) { await _disable(identity); }
      else {
        final subscription = await platform.subscribe(_publicKey!, requestPermission: requestPermission);
        _instanceId ??= base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256))).replaceAll('=', '');
        try {
          await _request('POST', 'subscribe', identity: identity, body: {
            'deviceId': identity.deviceId, 'instanceId': _instanceId, 'subscription': subscription,
            'settings': settings.toJson(), 'language': settings.language,
          });
          await _persist(true); enabled = true;
        } catch (_) { if (!wasEnabled) await platform.unsubscribe(); rethrow; }
      }
      return true;
    } catch (_) {
      error = value ? 'Prayer background notifications could not be saved. Check permission and connection.' :
          'Background notifications could not be removed from the server. Reconnect and retry.';
      return false;
    } finally { busy = false; notifyListeners(); }
  }
  Future<void> _persist(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key, jsonEncode({'enabled': value, 'instanceId': _instanceId}))) {
      throw StateError('Prayer notification settings could not be saved.');
    }
    _saved = value;
  }
  Future<void> _disable(ReaderSyncIdentity identity) async {
    await platform.unsubscribe();
    if (_instanceId != null) await _request('POST', 'unsubscribe', identity: identity,
        body: {'deviceId': identity.deviceId, 'instanceId': _instanceId});
    await _persist(false); enabled = false;
  }
  Future<void> detach(ReaderSyncIdentity identity) async {
    await initialize();
    if (busy) throw StateError('Finish updating prayer notifications before changing account.');
    if (!enabled && !_saved) return;
    busy = true; notifyListeners();
    try { await _disable(identity); }
    finally { busy = false; notifyListeners(); }
  }
  Future<Map<String, dynamic>> _request(String method, String endpoint,
      {ReaderSyncIdentity? identity, Map<String, dynamic>? body}) async {
    final client = http.Client();
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 12), () { if (!abort.isCompleted) abort.complete(); });
    try {
      final request = http.AbortableRequest(method, Uri.parse('$baseUrl/public/reminders/prayer/$endpoint'), abortTrigger: abort.future)
        ..followRedirects = false
        ..headers.addAll({'Accept': 'application/json', 'Content-Type': 'application/json',
          if (identity != null) 'Authorization': 'Bearer ${identity.token}'});
      if (body != null) request.body = jsonEncode(body);
      final response = await client.send(request).then(http.Response.fromStream).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.length > 16384 ||
          !(response.headers['content-type'] ?? '').contains('application/json')) throw StateError('Prayer notification request failed.');
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic> || value['success'] != true) throw const FormatException('Invalid prayer notification response.');
      return value;
    } finally { timer.cancel(); if (!abort.isCompleted) abort.complete(); client.close(); }
  }
}

Future<void> detachPrayerBrowserReminders({required String baseUrl, required ReaderSyncIdentity identity}) async {
  if (!kIsWeb || baseUrl.isEmpty) return;
  final profile = ReaderProfileStore.instance.activeId;
  final client = PrayerPushClient.forProfile(baseUrl, profile, PrayerPlatform());
  final raw = (await SharedPreferences.getInstance()).getString(client._key);
  var savedEnabled = false;
  try { savedEnabled = raw != null && (jsonDecode(raw) as Map)['enabled'] == true; } catch (_) { /* No saved subscription. */ }
  if (!client.enabled && !savedEnabled) return;
  await client.detach(identity);
}
void ensurePrayerBrowserRemindersIdle(String baseUrl) {
  if (!kIsWeb || baseUrl.isEmpty) return;
  if (prayerSettingsBusy?.call() == true) throw StateError('Finish updating prayer settings before changing account.');
  final base = ReaderPreferences.normalizeSyncBaseUrl(baseUrl);
  if (PrayerPushClient._instances['${ReaderProfileStore.instance.activeId}:$base']?.busy == true) {
    throw StateError('Finish updating prayer notifications before changing account.');
  }
}
