import 'reader_voice_capture.dart';

ReaderVoiceCapture createReaderVoiceCapture() => _UnavailableVoiceCapture();

class _UnavailableVoiceCapture extends ReaderVoiceCapture {
  _UnavailableVoiceCapture() : super.base();

  bool _disposed = false;
  String? _errorMessage;

  @override
  bool get supported => false;
  @override
  bool get speechSupported => false;
  @override
  ReaderVoiceCapturePhase get phase => ReaderVoiceCapturePhase.idle;
  @override
  bool get isTranscribing => false;
  @override
  String get transcript => '';
  @override
  Duration get elapsed => Duration.zero;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool get hasRecording => false;
  @override
  bool get isPlaying => false;

  @override
  Future<void> start(
      {String language = 'ar-SA', bool transcribe = false}) async {
    if (_disposed) return;
    _errorMessage =
        'Voice recording is available in Chrome on HTTPS or localhost.';
    notifyListeners();
  }

  @override
  Future<void> stop() async {}
  @override
  void cancel() {
    if (_disposed) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  Future<void> togglePlayback() async {}
  @override
  void download() {}

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
