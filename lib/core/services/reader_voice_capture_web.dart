import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';

import 'reader_voice_capture.dart';

@JS('window.MediaRecorder')
external JSFunction? get _mediaRecorderConstructor;

extension type _VoiceSpeechEvent(JSObject _) implements JSObject {
  external _VoiceSpeechResults? get results;
}

extension type _VoiceSpeechResults(JSObject _) implements JSObject {
  external JSNumber get length;
  external _VoiceSpeechResult? item(int index);
}

extension type _VoiceSpeechResult(JSObject _) implements JSObject {
  external JSNumber get length;
  external _VoiceSpeechAlternative? item(int index);
}

extension type _VoiceSpeechAlternative(JSObject _) implements JSObject {
  external JSString? get transcript;
}

ReaderVoiceCapture createReaderVoiceCapture() => _BrowserVoiceCapture();

class _BrowserVoiceCapture extends ReaderVoiceCapture {
  _BrowserVoiceCapture() : super.base();

  static const _maximumDuration = Duration(seconds: 60);
  static const _maximumBytes = 8 * 1024 * 1024;
  final _chunks = <html.Blob>[];
  final _recordingSubscriptions = <StreamSubscription<dynamic>>[];
  final _speechSubscriptions = <StreamSubscription<dynamic>>[];
  final _playbackSubscriptions = <StreamSubscription<dynamic>>[];
  final _clock = Stopwatch();
  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  html.SpeechRecognition? _recognition;
  html.AudioElement? _audio;
  Timer? _timer;
  Timer? _speechStopTimer;
  Timer? _recordingStopTimer;
  Completer<void>? _stopped;
  String? _recordingUrl;
  String _mimeType = '';
  int _recordedBytes = 0;
  int _generation = 0;
  bool _disposed = false;
  ReaderVoiceCapturePhase _phase = ReaderVoiceCapturePhase.idle;
  bool _isTranscribing = false;
  bool _isPlaying = false;
  String _transcript = '';
  Duration _elapsed = Duration.zero;
  String? _errorMessage;

  @override
  bool get supported =>
      _mediaRecorderConstructor != null &&
      html.window.navigator.mediaDevices != null;
  @override
  bool get speechSupported => html.SpeechRecognition.supported;
  @override
  ReaderVoiceCapturePhase get phase => _phase;
  @override
  bool get isTranscribing => _isTranscribing;
  @override
  String get transcript => _transcript;
  @override
  Duration get elapsed => _elapsed;
  @override
  String? get errorMessage => _errorMessage;
  @override
  bool get hasRecording => _recordingUrl != null;
  @override
  bool get isPlaying => _isPlaying;

  bool _current(int generation) => !_disposed && generation == _generation;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> start(
      {String language = 'ar-SA', bool transcribe = false}) async {
    if (_disposed || isBusy) return;
    _releaseSession();
    _clearRecording();
    final generation = ++_generation;
    _transcript = '';
    _elapsed = Duration.zero;
    _errorMessage = null;
    if (!supported) {
      _phase = ReaderVoiceCapturePhase.idle;
      _errorMessage =
          'Voice recording is available in Chrome on HTTPS or localhost.';
      _publish();
      return;
    }
    _phase = ReaderVoiceCapturePhase.requesting;
    _publish();
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'audio': true,
        'video': false,
      });
      if (!_current(generation)) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        return;
      }
      _stream = stream;
      final preferredType = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/mp4'
      ].where(html.MediaRecorder.isTypeSupported).firstOrNull;
      final recorder = html.MediaRecorder(stream, {
        if (preferredType != null) 'mimeType': preferredType,
        'audioBitsPerSecond': 96000,
      });
      _recorder = recorder;
      _mimeType = recorder.mimeType ?? preferredType ?? '';
      _recordingSubscriptions.add(
        const html.EventStreamProvider<html.BlobEvent>('dataavailable')
            .forTarget(recorder)
            .listen((event) {
          if (!_current(generation)) return;
          final chunk = event.data;
          if (chunk == null || chunk.size == 0) return;
          _chunks.add(chunk);
          _recordedBytes += chunk.size;
          if (_recordedBytes >= _maximumBytes &&
              _phase == ReaderVoiceCapturePhase.recording) {
            _errorMessage = 'Recording reached the size limit.';
            unawaited(stop());
          }
        }),
      );
      _recordingSubscriptions.add(
        const html.EventStreamProvider<html.Event>('stop')
            .forTarget(recorder)
            .listen((_) {
          if (_current(generation)) _finishRecording();
        }),
      );
      _recordingSubscriptions.add(recorder.onError.listen((_) {
        if (!_current(generation)) return;
        _errorMessage = 'Recording could not be completed. Try again.';
        _releaseSession();
        _clearRecording();
        _phase = ReaderVoiceCapturePhase.idle;
        _publish();
      }));
      recorder.start(250);
      _clock
        ..reset()
        ..start();
      _phase = ReaderVoiceCapturePhase.recording;
      if (transcribe) _startSpeech(language, generation);
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!_current(generation)) return;
        _elapsed = _clock.elapsed;
        if (_elapsed >= _maximumDuration) {
          _elapsed = _maximumDuration;
          unawaited(stop());
        } else {
          _publish();
        }
      });
      _publish();
    } catch (error) {
      if (!_current(generation)) return;
      _errorMessage = _microphoneError(error);
      _releaseSession();
      _clearRecording();
      _phase = ReaderVoiceCapturePhase.idle;
      _publish();
    }
  }

  void _startSpeech(String language, int generation) {
    if (!speechSupported) {
      _errorMessage =
          'Online transcription is unavailable. Recording continues; type your transcript.';
      return;
    }
    try {
      final recognition = html.SpeechRecognition()
        ..lang = language
        ..continuous = true
        ..interimResults = true
        ..maxAlternatives = 1;
      _recognition = recognition;
      _isTranscribing = true;
      _speechSubscriptions.add(recognition.onResult.listen((event) {
        if (!_current(generation)) return;
        final results = _VoiceSpeechEvent(event as JSObject).results;
        if (results == null) return;
        final phrases = <String>[];
        for (var index = 0; index < results.length.toDartInt; index++) {
          final result = results.item(index);
          if (result == null || result.length.toDartInt == 0) continue;
          final text = result.item(0)?.transcript?.toDart.trim() ?? '';
          if (text.isNotEmpty) phrases.add(text);
        }
        _transcript = phrases.join(' ');
        if (_transcript.length > 16000) {
          _transcript = _transcript.substring(0, 16000);
          unawaited(stop());
        }
        _publish();
      }));
      _speechSubscriptions.add(recognition.onError.listen((event) {
        if (!_current(generation)) return;
        if (event.error != 'aborted') {
          _errorMessage =
              'Online transcription stopped. You can continue recording or type your transcript.';
        }
        _stopSpeech();
        _publish();
      }));
      _speechSubscriptions.add(recognition.onEnd.listen((_) {
        if (!_current(generation)) return;
        _stopSpeech();
        _publish();
      }));
      recognition.start();
    } catch (_) {
      _stopSpeech();
      _errorMessage =
          'Online transcription is unavailable. Recording continues; type your transcript.';
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    if (_phase == ReaderVoiceCapturePhase.requesting) {
      cancel();
      return;
    }
    if (_phase == ReaderVoiceCapturePhase.stopping) {
      await _stopped?.future;
      return;
    }
    if (_phase != ReaderVoiceCapturePhase.recording) return;
    final generation = _generation;
    _phase = ReaderVoiceCapturePhase.stopping;
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _elapsed =
        _clock.elapsed > _maximumDuration ? _maximumDuration : _clock.elapsed;
    final stopped = _stopped = Completer<void>();
    _requestSpeechStop(generation);
    _recordingStopTimer = Timer(const Duration(seconds: 3), () {
      if (!_current(generation) || _phase != ReaderVoiceCapturePhase.stopping) {
        return;
      }
      _errorMessage = 'Recording could not be completed. Try again.';
      _releaseSession();
      _clearRecording();
      _phase = ReaderVoiceCapturePhase.idle;
      _publish();
    });
    try {
      _recorder?.stop();
    } catch (_) {
      _errorMessage = 'Recording could not be completed. Try again.';
      _releaseSession();
      _clearRecording();
      _phase = ReaderVoiceCapturePhase.idle;
    }
    _stopTracks();
    _publish();
    await stopped.future;
  }

  void _finishRecording() {
    _timer?.cancel();
    _timer = null;
    _recordingStopTimer?.cancel();
    _recordingStopTimer = null;
    _clock.stop();
    _elapsed =
        _clock.elapsed > _maximumDuration ? _maximumDuration : _clock.elapsed;
    _requestSpeechStop(_generation);
    _stopTracks();
    _recorder = null;
    _cancelSubscriptions(_recordingSubscriptions);
    if (_chunks.isNotEmpty) {
      final blob = html.Blob(_chunks, _mimeType);
      if (blob.size > 0) _recordingUrl = html.Url.createObjectUrlFromBlob(blob);
    }
    _chunks.clear();
    _recordedBytes = 0;
    _phase = hasRecording
        ? ReaderVoiceCapturePhase.ready
        : ReaderVoiceCapturePhase.idle;
    if (!hasRecording) {
      _errorMessage = 'No audio was captured. Try recording again.';
    }
    _completeStop();
    _publish();
  }

  @override
  void cancel() {
    if (_disposed) return;
    ++_generation;
    _releaseSession();
    _clearRecording();
    _transcript = '';
    _elapsed = Duration.zero;
    _errorMessage = null;
    _phase = ReaderVoiceCapturePhase.idle;
    _publish();
  }

  @override
  Future<void> togglePlayback() async {
    if (_disposed || isBusy || !hasRecording) return;
    if (_isPlaying) {
      _audio?.pause();
      _isPlaying = false;
      _publish();
      return;
    }
    final generation = _generation;
    final audio = _audio ??= html.AudioElement(_recordingUrl);
    if (_playbackSubscriptions.isEmpty) {
      _playbackSubscriptions.add(audio.onEnded.listen((_) {
        if (!_current(generation)) return;
        _isPlaying = false;
        _publish();
      }));
      _playbackSubscriptions.add(audio.onError.listen((_) {
        if (!_current(generation)) return;
        _isPlaying = false;
        _errorMessage =
            'This recording could not be played. You can download it instead.';
        _publish();
      }));
    }
    try {
      if (audio.ended) audio.currentTime = 0;
      await audio.play();
      if (!_current(generation)) {
        audio.pause();
        return;
      }
      _isPlaying = true;
      _publish();
    } catch (_) {
      if (!_current(generation)) return;
      _errorMessage =
          'This recording could not be played. You can download it instead.';
      _isPlaying = false;
      _publish();
    }
  }

  @override
  void download() {
    if (_disposed || isBusy || !hasRecording) return;
    final extension = _mimeType.contains('mp4') ? 'm4a' : 'webm';
    final anchor = html.AnchorElement(href: _recordingUrl)
      ..download =
          'quran-recitation-${DateTime.now().millisecondsSinceEpoch}.$extension'
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  void _stopTracks() {
    final stream = _stream;
    _stream = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      track.stop();
    }
  }

  void _stopSpeech() {
    _speechStopTimer?.cancel();
    _speechStopTimer = null;
    final recognition = _recognition;
    _recognition = null;
    _isTranscribing = false;
    _cancelSubscriptions(_speechSubscriptions);
    try {
      recognition?.abort();
    } catch (_) {}
  }

  void _requestSpeechStop(int generation) {
    if (_recognition == null || _speechStopTimer != null) return;
    try {
      _recognition!.stop();
    } catch (_) {
      _stopSpeech();
      return;
    }
    if (!_isTranscribing) return;
    _speechStopTimer = Timer(const Duration(seconds: 2), () {
      if (!_current(generation)) return;
      _stopSpeech();
      _publish();
    });
  }

  void _completeStop() {
    final stopped = _stopped;
    _stopped = null;
    if (stopped != null && !stopped.isCompleted) stopped.complete();
  }

  void _releaseSession() {
    _timer?.cancel();
    _timer = null;
    _recordingStopTimer?.cancel();
    _recordingStopTimer = null;
    _clock.stop();
    _stopSpeech();
    _cancelSubscriptions(_recordingSubscriptions);
    final recorder = _recorder;
    _recorder = null;
    try {
      if (recorder?.state != 'inactive') recorder?.stop();
    } catch (_) {}
    _stopTracks();
    _completeStop();
  }

  void _clearRecording() {
    _audio?.pause();
    _audio?.src = '';
    _audio = null;
    _isPlaying = false;
    _cancelSubscriptions(_playbackSubscriptions);
    final url = _recordingUrl;
    _recordingUrl = null;
    if (url != null) html.Url.revokeObjectUrl(url);
    _chunks.clear();
    _recordedBytes = 0;
  }

  void _cancelSubscriptions(List<StreamSubscription<dynamic>> subscriptions) {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    subscriptions.clear();
  }

  String _microphoneError(Object error) {
    if (error is html.DomException) {
      if (error.name == 'NotAllowedError' || error.name == 'SecurityError') {
        return 'Microphone access is blocked. Allow it in your browser settings and try again.';
      }
      if (error.name == 'NotFoundError') {
        return 'No microphone was found. Connect one and try again.';
      }
      if (error.name == 'NotReadableError') {
        return 'The microphone is busy or unavailable. Close other recording apps and try again.';
      }
    }
    return 'Recording could not be started. Check your microphone and try again.';
  }

  @override
  void dispose() {
    if (_disposed) return;
    ++_generation;
    _disposed = true;
    _releaseSession();
    _clearRecording();
    super.dispose();
  }
}
