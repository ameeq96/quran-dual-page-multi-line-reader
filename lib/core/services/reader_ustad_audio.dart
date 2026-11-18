import 'dart:math';

import 'package:flutter/foundation.dart';

import 'reader_ustad_audio_stub.dart'
    if (dart.library.io) 'reader_ustad_audio_io.dart'
    if (dart.library.html) 'reader_ustad_audio_web.dart' as platform;

abstract class ReaderUstadAudio extends ChangeNotifier {
  ReaderUstadAudio.base();
  factory ReaderUstadAudio({required String profileId}) {
    final random = Random.secure();
    final ownerId = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    return platform.createUstadAudio(profileId, ownerId);
  }
  bool get playing;
  String? get errorMessage;
  Future<void> play(Uint8List bytes, String mimeType);
  Future<void> stop();
}
