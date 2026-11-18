import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class WorshipSpeech {
  static const _channel = MethodChannel('com.opplexify.quran/prayer_reminders');
  static WorshipSpeech? _owner;
  bool _disposed = false;
  int _generation = 0;

  Future<void> speakArabic(String text) async {
    if (_disposed) throw StateError('Arabic device pronunciation is closed.');
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Arabic device pronunciation is unavailable on this device.',
      );
    }
    final value = text.trim();
    if (value.isEmpty ||
        value.length > 2000 ||
        !RegExp(r'[\u0600-\u06FF]').hasMatch(value)) {
      throw const FormatException(
        'Choose an Arabic dhikr of up to 2000 characters.',
      );
    }
    final generation = ++_generation;
    _owner = this;
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('worshipSpeak', {'text': value})
          .timeout(const Duration(seconds: 12));
      if (_disposed || generation != _generation || !identical(_owner, this)) {
        throw StateError('Arabic device pronunciation was stopped.');
      }
      if (result?['started'] != true) {
        throw StateError(
          'An Arabic voice is unavailable. Install an Arabic text-to-speech voice in device settings.',
        );
      }
    } catch (_) {
      if (identical(_owner, this) && generation == _generation) await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    ++_generation;
    if (!identical(_owner, this)) return;
    _owner = null;
    if (!Platform.isAndroid) return;
    try {
      await _channel
          .invokeMethod<void>('worshipSpeechStop')
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Native speech may already have stopped with its activity.
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
  }
}
