import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'reader_voice_capture.dart';

ReaderVoiceCapture createReaderVoiceCapture() => _LessonVoiceCapture();

class _LessonVoiceCapture extends ReaderVoiceCapture with WidgetsBindingObserver {
  _LessonVoiceCapture() : super.base() {
    WidgetsBinding.instance.addObserver(this);
  }
  static const _channel = MethodChannel('com.opplexify.quran/lesson_recording');
  final _session = base64UrlEncode(List.generate(16, (_) => Random.secure().nextInt(256))).replaceAll('=', '');
  bool _disposed = false;
  bool _polling = false;
  bool _hasRecording = false;
  bool _playing = false;
  int _revision = 0;
  int _statusVersion = 0;
  ReaderVoiceCapturePhase _phase = ReaderVoiceCapturePhase.idle;
  Duration _elapsed = Duration.zero;
  String? _error;
  Timer? _timer;
  @override
  bool get supported => Platform.isAndroid;
  @override
  bool get speechSupported => false;
  @override
  ReaderVoiceCapturePhase get phase => _phase;
  @override
  bool get isTranscribing => false;
  @override
  String get transcript => '';
  @override
  Duration get elapsed => _elapsed;
  @override
  String? get errorMessage => _error;
  @override
  bool get hasRecording => _hasRecording;
  @override
  bool get isPlaying => _playing;
  @override
  int get recordingRevision => _revision;
  @override
  String get recordingMimeType => _hasRecording ? 'audio/mp4' : '';

  Map<String, Object?> get _arguments => {'profileId': lessonProfileId, 'sessionId': _session};
  void _publish() { if (!_disposed) notifyListeners(); }
  void _releaseNative() => unawaited(
      _channel.invokeMethod<void>('captureCancel', _arguments).catchError((_) {}));
  String _message(Object error) => error is PlatformException
      ? error.message ?? 'Lesson recording is unavailable.'
      : 'Lesson recording is unavailable.';

  void _apply(Object? value) {
    if (value is! Map) throw StateError('Invalid lesson recording response.');
    final duration = value['durationMillis'];
    if (duration is! int || duration < 0 || duration > 60000) {
      throw StateError('Invalid lesson recording duration.');
    }
    _phase = ReaderVoiceCapturePhase.values.firstWhere((phase) => phase.name == value['phase']);
    _elapsed = Duration(milliseconds: duration);
    _hasRecording = value['hasRecording'] == true;
    _playing = value['playing'] == true;
    _error = value['error'] is String ? value['error'] as String : null;
    if (_phase != ReaderVoiceCapturePhase.recording && !_playing) {
      _timer?.cancel();
      _timer = null;
    }
    _publish();
  }

  void _watch() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => unawaited(_poll()));
  }

  Future<void> _poll() async {
    if (_disposed || _polling) return;
    _polling = true;
    final revision = _revision;
    final statusVersion = _statusVersion;
    try {
      final status = await _channel.invokeMethod<Object?>('captureStatus', _arguments);
      if (!_disposed && revision == _revision && statusVersion == _statusVersion) _apply(status);
    } catch (error) {
      if (!_disposed && revision == _revision && statusVersion == _statusVersion) {
        _releaseNative();
        _error = _message(error);
        _phase = ReaderVoiceCapturePhase.idle;
        _hasRecording = false;
        _playing = false;
        _timer?.cancel();
        _publish();
      }
    } finally { _polling = false; }
  }

  @override
  Future<void> start({String language = 'ar-SA', bool transcribe = false}) async {
    if (_disposed || isBusy) return;
    if (!supported || transcribe) {
      _error = transcribe ? 'Lesson recordings do not transcribe or assess recitation.'
          : 'Native lesson recording is available on Android.';
      _publish();
      return;
    }
    final revision = ++_revision;
    _statusVersion++;
    _phase = ReaderVoiceCapturePhase.requesting;
    _hasRecording = false;
    _playing = false;
    _elapsed = Duration.zero;
    _error = null;
    _publish();
    try {
      final status = await _channel.invokeMethod<Object?>('captureStart', _arguments);
      if (_disposed || revision != _revision) return;
      _apply(status);
      if (_phase == ReaderVoiceCapturePhase.recording) _watch();
    } catch (error) {
      if (!_disposed && revision == _revision) {
        _releaseNative();
        _timer?.cancel();
        _phase = ReaderVoiceCapturePhase.idle;
        _error = _message(error);
        _publish();
      }
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed || _phase != ReaderVoiceCapturePhase.recording) return;
    final revision = _revision;
    _statusVersion++;
    _phase = ReaderVoiceCapturePhase.stopping;
    _publish();
    try {
      final status = await _channel.invokeMethod<Object?>('captureStop', _arguments);
      if (!_disposed && revision == _revision) _apply(status);
    } catch (error) {
      if (!_disposed && revision == _revision) {
        _releaseNative();
        _error = _message(error);
        _phase = ReaderVoiceCapturePhase.idle;
        _hasRecording = false;
        _timer?.cancel();
        _publish();
      }
    }
  }

  @override
  Future<Uint8List> readRecordingBytes() async {
    if (_disposed || !_hasRecording || isBusy) throw StateError('No completed lesson recording is available.');
    final revision = _revision;
    final bytes = await _channel.invokeMethod<Uint8List>('captureRead', _arguments);
    if (_disposed || revision != _revision || bytes == null || bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
      throw StateError('The lesson recording changed before it could be read.');
    }
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> togglePlayback() async {
    if (_disposed || !_hasRecording || isBusy) return;
    final statusVersion = ++_statusVersion;
    try {
      final status = await _channel.invokeMethod<Object?>('capturePlay', _arguments);
      if (_disposed || statusVersion != _statusVersion) return;
      _apply(status);
      if (_playing) _watch();
    } catch (error) {
      if (!_disposed && statusVersion == _statusVersion) {
        unawaited(_channel.invokeMethod<void>('lessonStopPlayback', {'ownerId': 'capture_$_session'}).catchError((_) {}));
        _playing = false;
        _error = _message(error);
        _publish();
      }
    }
  }

  @override
  void download() {
    if (_disposed || !_hasRecording || isBusy) return;
    unawaited(_channel.invokeMethod<void>('captureExport', _arguments).catchError((Object error) {
      if (!_disposed) { _error = _message(error); _publish(); }
    }));
  }

  @override
  void cancel() {
    if (_disposed) return;
    _revision++;
    _statusVersion++;
    _timer?.cancel();
    _phase = ReaderVoiceCapturePhase.idle;
    _hasRecording = false;
    _playing = false;
    _elapsed = Duration.zero;
    _error = null;
    unawaited(_channel.invokeMethod<void>('captureCancel', _arguments).catchError((_) {}));
    _publish();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_phase != ReaderVoiceCapturePhase.idle) unawaited(_poll());
    } else {
      if (_phase == ReaderVoiceCapturePhase.requesting) {
        // Android owns the permission dialog; recording starts only after resume.
      } else if (_phase == ReaderVoiceCapturePhase.recording) {
        unawaited(stop());
      }
      if (_playing) {
        _statusVersion++;
        unawaited(_channel.invokeMethod<void>('lessonStopPlayback', {'ownerId': 'capture_$_session'}).catchError((_) {}));
        _playing = false;
        _publish();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _statusVersion++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_channel.invokeMethod<void>('captureCancel', _arguments).catchError((_) {}));
    super.dispose();
  }
}
