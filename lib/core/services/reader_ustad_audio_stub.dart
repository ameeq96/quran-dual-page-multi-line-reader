import 'package:flutter/foundation.dart';

import 'reader_ustad_audio.dart';

ReaderUstadAudio createUstadAudio(String profileId, String ownerId) =>
    _UnavailableAudio();

class _UnavailableAudio extends ReaderUstadAudio {
  _UnavailableAudio() : super.base();
  @override
  bool get playing => false;
  @override
  String? get errorMessage => 'Audio playback is unavailable on this platform.';
  @override
  Future<void> play(Uint8List bytes, String mimeType) =>
      Future.error(StateError(errorMessage ?? 'Audio playback unavailable.'));
  @override
  Future<void> stop() async {}
}
