import 'dart:io';

import 'package:flutter/services.dart';

class QiblaPlatform {
  static const _methods = MethodChannel('com.opplexify.quran/prayer_reminders');
  static const _events = EventChannel(
    'com.opplexify.quran/prayer_reminders/compass',
  );

  Stream<Map<String, dynamic>> get headings => Platform.isAndroid
      ? _events.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        )
      : const Stream.empty();

  Future<bool> start({
    required double latitude,
    required double longitude,
  }) async {
    if (!Platform.isAndroid) return false;
    final result = await _methods
        .invokeMapMethod<String, dynamic>('compassStart', {
          'latitude': latitude,
          'longitude': longitude,
        })
        .timeout(const Duration(seconds: 8));
    return result?['supported'] == true;
  }

  Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _methods
          .invokeMethod<void>('compassStop')
          .timeout(const Duration(seconds: 3));
    } on MissingPluginException {
      // Older builds still provide the north-referenced bearing.
    } on PlatformException {
      // A stopped activity may already have released its sensors.
    }
  }

  Future<void> dispose() => stop();
}
