// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import 'reader_ustad_audio.dart';

ReaderUstadAudio createUstadAudio(String profileId, String ownerId) =>
    _BrowserAudio();

class _BrowserAudio extends ReaderUstadAudio {
  _BrowserAudio() : super.base();
  html.AudioElement? _audio;
  String? _url;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _playing = false;
  bool _disposed = false;
  int _generation = 0;
  String? _error;
  @override
  bool get playing => _playing;
  @override
  String? get errorMessage => _error;
  @override
  Future<void> play(Uint8List bytes, String mimeType) async {
    final generation = _generation + 1;
    await stop();
    if (_disposed || generation != _generation) return;
    _url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
    final audio = html.AudioElement(_url!);
    _audio = audio;
    _subscriptions.add(audio.onEnded.listen((_) => stop()));
    _subscriptions.add(audio.onError.listen((_) {
      _error = 'Audio playback could not start.';
      stop();
    }));
    try {
      await audio.play();
      if (_disposed || generation != _generation) {
        audio.pause();
        return;
      }
      _playing = true;
      _error = null;
      notifyListeners();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _error = 'Audio playback could not start.';
        await stop();
      }
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _playing = false;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _audio?.pause();
    _audio?.removeAttribute('src');
    _audio?.load();
    _audio = null;
    if (_url != null) {
      html.Url.revokeObjectUrl(_url!);
      _url = null;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    super.dispose();
  }
}
