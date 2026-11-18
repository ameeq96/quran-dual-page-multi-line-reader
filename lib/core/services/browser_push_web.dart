import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

@JS('globalThis.PushManager')
external JSAny? get _pushManager;
@JS('Intl.DateTimeFormat')
external _TimeZoneFormatter _timeZoneFormatter();
extension type _TimeZoneFormatter(JSObject _) implements JSObject {
  external _TimeZoneOptions resolvedOptions();
}
extension type _TimeZoneOptions(JSObject _) implements JSObject {
  external String get timeZone;
}

class BrowserPush {
  html.ServiceWorkerRegistration? _registration;
  bool get supported => html.window.isSecureContext == true &&
      html.window.navigator.serviceWorker != null &&
      _pushManager != null && html.Notification.supported;

  String get timeZone {
    return _timeZoneFormatter().resolvedOptions().timeZone;
  }

  Uri get _worker => Uri.parse(html.document.baseUri ?? Uri.base.toString())
      .resolve('reader-notifications/push-worker.js');

  Future<html.ServiceWorkerRegistration> _register() async {
    if (!supported) throw StateError('Background notifications need a supported secure browser.');
    final registration = _registration ??= await html.window.navigator.serviceWorker!
        .register(_worker.toString(), {'scope': _worker.resolve('./').toString()});
    for (var attempt = 0; attempt < 100 && registration.active == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (registration.active == null) throw StateError('Notification worker could not start. Try again.');
    return registration;
  }

  Future<Map<String, dynamic>> subscribe(String publicKey, {bool requestPermission = true}) async {
    if (!supported) throw StateError('Background notifications need a supported secure browser.');
    // This method is called directly from the user's enable button.
    final permission = requestPermission ? await html.Notification.requestPermission() : html.Notification.permission;
    if (permission != 'granted') throw StateError('Notifications are blocked. Enable them in browser settings.');
    final registration = await _register();
    final manager = registration.pushManager;
    if (manager == null) throw StateError('This browser does not support push notifications.');
    dynamic subscription = await manager.getSubscription();
    final expectedKey = Uint8List.fromList(base64Url.decode(base64Url.normalize(publicKey)));
    if (subscription != null) {
      final existingKey = (subscription as html.PushSubscription).options?.applicationServerKey?.asUint8List();
      final matches = existingKey != null && existingKey.length == expectedKey.length &&
          List<int>.generate(expectedKey.length, (index) => index).every((index) => existingKey[index] == expectedKey[index]);
      if (!matches) {
        if (!requestPermission) throw StateError('Notification keys changed. Enable background notifications again.');
        if (!await subscription.unsubscribe()) throw StateError('Notification keys could not be updated. Try again.');
        subscription = null;
      }
    }
    subscription ??= await manager.subscribe({
      'userVisibleOnly': true,
      'applicationServerKey': expectedKey,
    });
    final html.PushSubscription current = subscription as html.PushSubscription;
    final publicBytes = current.getKey('p256dh');
    final authBytes = current.getKey('auth');
    if (publicBytes == null || authBytes == null || current.endpoint == null) {
      throw StateError('Browser subscription could not be read.');
    }
    String encode(ByteBuffer data) => base64Url.encode(data.asUint8List()).replaceAll('=', '');
    return {'endpoint': current.endpoint, 'keys': {'p256dh': encode(publicBytes), 'auth': encode(authBytes)}};
  }

  Future<void> unsubscribe() async {
    if (!supported) return;
    final dynamic registration = _registration ?? await html.window.navigator.serviceWorker!
        .getRegistration(_worker.resolve('./').toString());
    if (registration == null) return;
    if ((registration as html.ServiceWorkerRegistration).scope != _worker.resolve('./').toString()) return;
    final dynamic subscription = await registration.pushManager?.getSubscription();
    if (subscription != null && !await (subscription as html.PushSubscription).unsubscribe()) {
      throw StateError('Browser notifications could not be disabled. Try again.');
    }
  }
}
