// Uses the same conditional browser bridge as the existing reader notification service.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

@JS('globalThis.PushManager')
external JSAny? get _pushManager;
@JS('Intl.DateTimeFormat')
external _ZoneFormatter _zoneFormatter();
extension type _ZoneFormatter(JSObject _) implements JSObject {
  external _ZoneOptions resolvedOptions();
}
extension type _ZoneOptions(JSObject _) implements JSObject {
  external String get timeZone;
}

class PrayerPlatform {
  PrayerPlatform() {
    html.window.navigator.serviceWorker?.onMessage.listen((event) {
      final data = event.data;
      if (data is Map && data['type'] == 'PRAYER_PUSH') _messages.add(Map<String, dynamic>.from(data));
    });
  }
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _audio = html.AudioElement()..preload = 'auto';
  html.ServiceWorkerRegistration? _registration;
  bool _unlocked = false;
  bool _unlocking = false;
  Future<void>? _preparing;
  bool get isAndroid => false;
  bool get isWeb => true;
  bool get supported => true;
  bool get backgroundSupported => html.window.isSecureContext == true &&
      html.window.navigator.serviceWorker != null && _pushManager != null && html.Notification.supported;
  bool get audioEnabled => _unlocked;
  bool get playing => !_unlocking && !_audio.paused && !_audio.ended;
  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Uri get _base => Uri.parse(html.document.baseUri ?? Uri.base.toString());
  Uri get _worker => _base.resolve('prayer-notifications/push-worker.js');
  String _asset(String sound) => _base.resolve(sound == 'tone' ? 'assets/assets/prayer_audio/reminder_tone.wav' :
      'assets/assets/prayer_audio/adhan_${sound == 'fajr' ? 'fajr' : 'general'}.mp3').toString();
  Future<void> prepareAudio() => _preparing ??= _prepareAudio().catchError((Object error) {
    _preparing = null; throw error;
  });
  Future<void> _prepareAudio() async {
    for (final sound in ['general', 'fajr', 'tone']) {
      final response = await html.HttpRequest.request(_asset(sound), responseType: 'arraybuffer')
          .timeout(const Duration(seconds: 30));
      if (response.status != 200) throw StateError('Offline Azan audio could not be downloaded.');
    }
  }
  Future<Map<String, dynamic>> status() async => {
    'supported': true, 'notificationsAllowed': html.Notification.permission == 'granted',
    'exactAlarmAllowed': false, 'playing': playing,
  };
  Future<Map<String, dynamic>> configure(Map<String, dynamic> settings) => status();
  Future<void> cancel() => stop();
  Future<bool> enableAudio() async {
    _unlocking = true;
    // play() must be invoked before an await, while the button's activation is live.
    _audio.src = _asset('general');
    _audio.volume = 0;
    final started = _audio.play();
    try {
      await started.timeout(const Duration(seconds: 20));
      _audio.pause();
      _audio.currentTime = 0;
      _unlocked = true;
      return true;
    } catch (_) {
      _audio.pause();
      _unlocked = false;
      return false;
    } finally { _unlocking = false; }
  }
  Future<void> play(String sound, double volume, bool respectSilent) async {
    _audio.pause();
    _audio.src = _asset(sound);
    _audio.volume = volume.clamp(0, 1);
    try { await _audio.play().timeout(const Duration(seconds: 20)); _unlocked = true; }
    catch (_) { _audio.pause(); _unlocked = false; rethrow; }
  }
  Future<void> stop() async { _audio.pause(); _audio.currentTime = 0; }
  Future<Map<String, dynamic>> location() async {
    final position = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: false, timeout: const Duration(seconds: 12), maximumAge: const Duration(minutes: 10));
    return {'latitude': position.coords!.latitude, 'longitude': position.coords!.longitude,
      'accuracyMeters': position.coords!.accuracy, 'zone': _zoneFormatter().resolvedOptions().timeZone,
      'label': 'Current location'};
  }
  Future<Map<String, dynamic>> requestExactAlarm() => status();
  Future<Map<String, dynamic>> requestNotifications() async {
    if (html.Notification.supported) await html.Notification.requestPermission();
    return status();
  }
  Future<html.ServiceWorkerRegistration> _register() async {
    if (!backgroundSupported) throw StateError('Background notifications need a supported secure browser.');
    final registration = _registration ??= await html.window.navigator.serviceWorker!
        .register(_worker.toString(), {'scope': _worker.resolve('./').toString()});
    for (var attempt = 0; attempt < 100 && registration.active == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (registration.active == null) throw StateError('Prayer notification worker could not start.');
    return registration;
  }
  Future<Map<String, dynamic>> subscribe(String key, {bool requestPermission = true}) async {
    if (!backgroundSupported) throw StateError('Background notifications are unavailable.');
    final permission = requestPermission ? await html.Notification.requestPermission() : html.Notification.permission;
    if (permission != 'granted') throw StateError('Enable notifications in browser settings.');
    final registration = await _register();
    final manager = registration.pushManager;
    if (manager == null) throw StateError('Push notifications are unavailable.');
    final dynamic savedSubscription = await manager.getSubscription();
    html.PushSubscription? subscription = savedSubscription;
    final expected = Uint8List.fromList(base64Url.decode(base64Url.normalize(key)));
    if (subscription != null) {
      final old = subscription.options?.applicationServerKey?.asUint8List();
      if (old == null || old.length != expected.length ||
          List.generate(expected.length, (i) => i).any((i) => expected[i] != old[i])) {
        if (!requestPermission) throw StateError('Notification keys changed. Enable background reminders again.');
        if (!await subscription.unsubscribe()) throw StateError('Old notification subscription could not be removed.');
        subscription = null;
      }
    }
    subscription ??= await manager.subscribe({'userVisibleOnly': true, 'applicationServerKey': expected});
    final publicBytes = subscription.getKey('p256dh');
    final authBytes = subscription.getKey('auth');
    if (publicBytes == null || authBytes == null || subscription.endpoint == null) throw StateError('Invalid browser subscription.');
    String encode(ByteBuffer value) => base64Url.encode(value.asUint8List()).replaceAll('=', '');
    return {'endpoint': subscription.endpoint, 'keys': {'p256dh': encode(publicBytes), 'auth': encode(authBytes)}};
  }
  Future<void> unsubscribe() async {
    if (!backgroundSupported) return;
    final dynamic savedRegistration = _registration ?? await html.window.navigator.serviceWorker!.getRegistration(_worker.resolve('./').toString());
    final html.ServiceWorkerRegistration? registration = savedRegistration;
    if (registration == null || registration.scope != _worker.resolve('./').toString()) return;
    final subscription = await registration.pushManager?.getSubscription();
    if (subscription != null && !await subscription.unsubscribe()) throw StateError('Prayer notifications could not be disabled.');
  }
  Future<bool> claim(String key, String value) async {
    // Shared storage also deduplicates the same alarm across normal browser tabs.
    if (html.window.localStorage.containsKey(key)) return false;
    html.window.localStorage[key] = value;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    return html.window.localStorage[key] == value;
  }
}
