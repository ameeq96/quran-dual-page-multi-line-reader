import 'dart:io';
import 'package:flutter/services.dart';

class PrayerPlatform {
  static const _channel = MethodChannel('com.opplexify.quran/prayer_reminders');
  bool get isAndroid => Platform.isAndroid;
  bool get isWeb => false;
  bool get supported => isAndroid;
  bool get backgroundSupported => false;
  bool get audioEnabled => isAndroid;
  bool get playing => false;
  Stream<Map<String, dynamic>> get messages => const Stream.empty();
  Future<Map<String, dynamic>> _call(String method, [Map<String, dynamic>? args]) async {
    if (!isAndroid) return {};
    final value = await _channel.invokeMethod<dynamic>(method, args).timeout(const Duration(seconds: 20));
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }
  Future<Map<String, dynamic>> status() => _call('status');
  Future<Map<String, dynamic>> configure(Map<String, dynamic> settings) => _call('configure', settings);
  Future<void> cancel() async { await _call('cancel'); }
  Future<bool> enableAudio() async => isAndroid;
  Future<void> prepareAudio() async {}
  Future<void> play(String sound, double volume, bool respectSilent) async {
    await _call('preview', {'sound': sound, 'volume': volume, 'respectSilent': respectSilent});
  }
  Future<void> stop() async { await _call('stop'); }
  Future<Map<String, dynamic>> location() => _call('location');
  Future<Map<String, dynamic>> requestExactAlarm() => _call('requestExactAlarm');
  Future<Map<String, dynamic>> requestNotifications() => _call('requestNotificationPermission');
  Future<Map<String, dynamic>> subscribe(String key, {bool requestPermission = true}) async => throw UnsupportedError('Use native prayer alarms on Android.');
  Future<void> unsubscribe() async {}
  Future<bool> claim(String key, String value) async => true;
}
