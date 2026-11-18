import 'dart:async';

import 'package:flutter/services.dart';

import 'reader_ustad_audio.dart';

ReaderUstadAudio createUstadAudio(String profileId, String ownerId) =>
    _NativeAudio(profileId, ownerId);

class _NativeAudio extends ReaderUstadAudio {
  _NativeAudio(this.profileId, this.ownerId) : super.base();
  static const _channel = MethodChannel('com.opplexify.quran/lesson_recording');
  final String profileId;
  final String ownerId;
  bool _playing = false;
  bool _disposed = false;
  int _generation = 0;
  String? _error;
  Timer? _poll;
  bool _polling = false;
  @override
  bool get playing => _playing;
  @override
  String? get errorMessage => _error;
  @override
  Future<void> play(Uint8List bytes, String mimeType) async {
    final generation = _generation + 1;
    await stop();
    if (_disposed || generation != _generation) return;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
          'lessonPlayBytes', {
        'profileId': profileId,
        'ownerId': ownerId,
        'bytes': bytes,
        'mimeType': mimeType
      });
      if (_disposed || generation != _generation) return;
      if (result?['playing'] != true) {
        throw StateError('Playback did not start.');
      }
      _playing = true;
      _error = null;
      notifyListeners();
      _poll =
          Timer.periodic(const Duration(milliseconds: 400), (_) => _status());
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _error = 'Audio playback could not start.';
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> _status() async {
    if (_polling || _disposed) return;
    _polling = true;
    final generation = _generation;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
          'lessonPlaybackStatus', {'ownerId': ownerId});
      if (!_disposed &&
          generation == _generation &&
          result?['playing'] != true) {
        _poll?.cancel();
        _playing = false;
        _error = result?['error'] as String?;
        notifyListeners();
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        await stop();
      }
    } finally {
      _polling = false;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _poll?.cancel();
    _poll = null;
    _playing = false;
    try {
      await _channel
          .invokeMethod<void>('lessonStopPlayback', {'ownerId': ownerId});
    } catch (_) {}
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
