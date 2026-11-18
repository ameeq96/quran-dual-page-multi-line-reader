import 'package:flutter/foundation.dart';

import '../storage/reader_profile_store.dart';
import 'reader_voice_capture_stub.dart'
    if (dart.library.io) 'reader_voice_capture_io.dart' as lesson_platform;
import 'reader_voice_capture_stub.dart'
    if (dart.library.html) 'reader_voice_capture_web.dart' as platform;

enum ReaderVoiceCapturePhase { idle, requesting, recording, stopping, ready }

abstract class ReaderVoiceCapture extends ChangeNotifier {
  ReaderVoiceCapture.base();

  factory ReaderVoiceCapture() => platform.createReaderVoiceCapture();

  factory ReaderVoiceCapture.forLesson({required String profileId}) {
    if (!ReaderProfileStore.validId(profileId)) {
      throw ArgumentError('Invalid lesson recording profile.');
    }
    final capture = kIsWeb ? platform.createReaderVoiceCapture()
        : lesson_platform.createReaderVoiceCapture();
    capture._lessonProfileId = profileId;
    return capture;
  }

  String? _lessonProfileId;
  String? get lessonProfileId => _lessonProfileId;

  bool get supported;
  bool get speechSupported;
  ReaderVoiceCapturePhase get phase;
  bool get isTranscribing;
  String get transcript;
  Duration get elapsed;
  String? get errorMessage;
  bool get hasRecording;
  bool get isPlaying;
  int get recordingRevision => 0;
  String get recordingMimeType => '';
  Future<Uint8List> readRecordingBytes() => Future.error(
      StateError('No completed recording is available.'));

  bool get isBusy =>
      phase == ReaderVoiceCapturePhase.requesting ||
      phase == ReaderVoiceCapturePhase.recording ||
      phase == ReaderVoiceCapturePhase.stopping ||
      isTranscribing;

  Future<void> start({String language = 'ar-SA', bool transcribe = false});
  Future<void> stop();
  void cancel();
  Future<void> togglePlayback();
  void download();
}
