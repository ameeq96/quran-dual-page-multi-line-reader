@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/core/services/reader_voice_capture.dart';

@JS('eval')
external JSAny? _evaluate(JSString source);

Object? _read(String expression) => _evaluate(expression.toJS)?.dartify();

String _captureDiagnostics(ReaderVoiceCapture capture) =>
    '${capture.errorMessage}; ${_read('JSON.stringify({'
        'recorderConstructs: window.__readerVoiceTest.recorderConstructs,'
        'recorderStarts: window.__readerVoiceTest.recorderStarts,'
        'speechConstructs: window.__readerVoiceTest.speechConstructs,'
        'speechStarts: window.__readerVoiceTest.speechStarts,'
        'constructionError: window.__readerVoiceTest.constructionError})')}';

void _expectCapturing(ReaderVoiceCapture capture) {
  expect(capture.phase, ReaderVoiceCapturePhase.recording,
      reason: _captureDiagnostics(capture));
  expect(_read('window.__readerVoiceTest.recorderConstructs'), 1);
  expect(_read('window.__readerVoiceTest.hasNativeRecorder()'), isTrue);
}

void main() {
  late ReaderVoiceCapture capture;

  setUp(() {
    _evaluate(_installBrowserFakes.toJS);
    capture = ReaderVoiceCapture();
  });

  tearDown(() {
    capture.dispose();
    _evaluate('window.__readerVoiceTest.restore()'.toJS);
  });

  test('recording stays local, stops tracks, and releases its object URL',
      () async {
    await capture.start();
    _expectCapturing(capture);
    expect(_read('window.__readerVoiceTest.speechStarts'), 0);
    expect(_read('window.__readerVoiceTest.getUserMediaCalls'), 1);
    await capture.stop();
    expect(capture.hasRecording, isTrue);
    expect(capture.isBusy, isFalse);
    expect(_read('window.__readerVoiceTest.allTracksStopped()'), isTrue);
    expect(_read('window.__readerVoiceTest.createdUrls.length'), 1);
    capture.cancel();
    expect(capture.hasRecording, isFalse);
    expect(_read('window.__readerVoiceTest.revokedUrls.length'), 1);
  });

  test('cancelling a pending permission request stops its late stream',
      () async {
    _evaluate('window.__readerVoiceTest.pendingPermission = true'.toJS);
    final starting = capture.start();
    expect(capture.phase, ReaderVoiceCapturePhase.requesting);
    capture.cancel();
    _evaluate('window.__readerVoiceTest.resolvePermission()'.toJS);
    await starting;
    expect(capture.phase, ReaderVoiceCapturePhase.idle);
    expect(capture.hasRecording, isFalse);
    expect(_read('window.__readerVoiceTest.recorderStarts'), 0);
    expect(_read('window.__readerVoiceTest.recorderConstructs'), 0);
    expect(_read('window.__readerVoiceTest.allTracksStopped()'), isTrue);
  });

  test(
      'online recognition requires opt-in and uses the selected spoken language',
      () async {
    await capture.start(language: 'ur-PK', transcribe: true);
    _expectCapturing(capture);
    expect(_read('window.__readerVoiceTest.speechStarts'), 1,
        reason: _captureDiagnostics(capture));
    expect(_read('window.__readerVoiceTest.hasNativeRecognition()'), isTrue);
    expect(_read('window.__readerVoiceTest.lastRecognition.lang'), 'ur-PK');
    _evaluate("window.__readerVoiceTest.emitTranscript('السلام عليكم')".toJS);
    expect(capture.transcript, 'السلام عليكم');
    await capture.stop();
    await Future<void>.delayed(Duration.zero);
    expect(capture.transcript, 'السلام عليكم');
    expect(capture.isTranscribing, isFalse);
    expect(_read('window.__readerVoiceTest.speechStops'), 1);
    expect(_read('window.__readerVoiceTest.allTracksStopped()'), isTrue);
  });

  test('a denied microphone leaves no recording and can be retried', () async {
    _evaluate('window.__readerVoiceTest.denyPermission = true'.toJS);
    await capture.start();
    expect(capture.isBusy, isFalse);
    expect(capture.hasRecording, isFalse);
    expect(capture.errorMessage, contains('Microphone access is blocked'));
    _evaluate('window.__readerVoiceTest.denyPermission = false'.toJS);
    await capture.start();
    expect(capture.errorMessage, isNull, reason: _captureDiagnostics(capture));
    _expectCapturing(capture);
    await capture.stop();
    expect(capture.hasRecording, isTrue);
  });

  test('an unexpected recorder stop also stops recognition and the microphone',
      () async {
    await capture.start(transcribe: true);
    _expectCapturing(capture);
    _evaluate('window.__readerVoiceTest.lastRecorder.stop()'.toJS);
    await Future<void>.delayed(Duration.zero);
    expect(capture.hasRecording, isTrue);
    expect(capture.isBusy, isFalse);
    expect(_read('window.__readerVoiceTest.speechStops'), 1);
    expect(_read('window.__readerVoiceTest.allTracksStopped()'), isTrue);
  });

  test('dispose aborts recognition and ignores late capture events', () async {
    await capture.start(transcribe: true);
    _expectCapturing(capture);
    var notifications = 0;
    capture.addListener(() => notifications++);
    capture.dispose();
    _evaluate(
        "window.__readerVoiceTest.emitTranscript('late transcript')".toJS);
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 0);
    expect(_read('window.__readerVoiceTest.speechAborts'), greaterThan(0));
    expect(_read('window.__readerVoiceTest.allTracksStopped()'), isTrue);
    expect(_read('window.__readerVoiceTest.createdUrls.length'), 0);
  });
}

const _installBrowserFakes = r'''
(() => {
  const original = {
    recorder: window.MediaRecorder,
    recognition: window.SpeechRecognition,
    webkitRecognition: window.webkitSpeechRecognition,
    getUserMedia: navigator.mediaDevices.getUserMedia,
    createUrl: URL.createObjectURL,
    revokeUrl: URL.revokeObjectURL,
  };
  const context = new AudioContext();
  const state = window.__readerVoiceTest = {
    pendingPermission: false, denyPermission: false,
    getUserMediaCalls: 0, recorderConstructs: 0, recorderStarts: 0,
    speechConstructs: 0, speechStarts: 0, constructionError: null,
    speechStops: 0, speechAborts: 0, streams: [],
    createdUrls: [], revokedUrls: [],
    stream() {
      const stream = context.createMediaStreamDestination().stream;
      this.streams.push(stream);
      return stream;
    },
    allTracksStopped() {
      return this.streams.length > 0 && this.streams.every(stream =>
        stream.getTracks().every(track => track.readyState === 'ended'));
    },
    hasNativeRecorder() {
      return this.lastRecorder instanceof original.recorder;
    },
    hasNativeRecognition() {
      return this.lastRecognition instanceof
        (original.recognition || original.webkitRecognition);
    },
    emitTranscript(text) {
      const event = new SpeechRecognitionEvent('result');
      const alternative = {transcript: text, confidence: 1};
      const result = {
        length: 1, isFinal: true, 0: alternative, item: () => alternative,
      };
      const results = {length: 1, 0: result, item: () => result};
      Object.defineProperty(event, 'results', {value: results});
      this.lastRecognition.dispatchEvent(event);
    },
    restore() {
      this.streams.forEach(stream => stream.getTracks().forEach(track => track.stop()));
      context.close();
      window.MediaRecorder = original.recorder;
      window.SpeechRecognition = original.recognition;
      window.webkitSpeechRecognition = original.webkitRecognition;
      navigator.mediaDevices.getUserMedia = original.getUserMedia;
      URL.createObjectURL = original.createUrl;
      URL.revokeObjectURL = original.revokeUrl;
      delete window.__readerVoiceTest;
    },
  };
  navigator.mediaDevices.getUserMedia = () => {
    state.getUserMediaCalls++;
    if (state.denyPermission) {
      return Promise.reject(new DOMException('Denied', 'NotAllowedError'));
    }
    if (state.pendingPermission) {
      return new Promise(resolve => {
        state.resolvePermission = () => resolve(state.stream());
      });
    }
    return Promise.resolve(state.stream());
  };
  function TestMediaRecorder(stream, options) {
    state.recorderConstructs++;
    try {
      const recorder = new original.recorder(stream, options);
      let recordingState = 'inactive';
      Object.defineProperties(recorder, {
        state: {get: () => recordingState},
        start: {value: () => {
          recordingState = 'recording';
          state.recorderStarts++;
        }},
        stop: {value: () => {
          if (recordingState === 'inactive') return;
          recordingState = 'inactive';
          queueMicrotask(() => {
            recorder.dispatchEvent(new BlobEvent('dataavailable', {
              data: new Blob(['local audio fixture'], {type: recorder.mimeType}),
            }));
            recorder.dispatchEvent(new Event('stop'));
          });
        }},
      });
      state.lastRecorder = recorder;
      return recorder;
    } catch (error) {
      state.constructionError = String(error);
      throw error;
    }
  }
  TestMediaRecorder.prototype = original.recorder.prototype;
  TestMediaRecorder.isTypeSupported = type =>
    type === 'audio/webm' && original.recorder.isTypeSupported(type);
  window.MediaRecorder = TestMediaRecorder;
  const NativeRecognition = original.recognition || original.webkitRecognition;
  function TestSpeechRecognition() {
    state.speechConstructs++;
    try {
      const recognition = new NativeRecognition();
      Object.defineProperties(recognition, {
        start: {value: () => { state.speechStarts++; }},
        stop: {value: () => {
          state.speechStops++;
          queueMicrotask(() => recognition.dispatchEvent(new Event('end')));
        }},
        abort: {value: () => { state.speechAborts++; }},
      });
      state.lastRecognition = recognition;
      return recognition;
    } catch (error) {
      state.constructionError = String(error);
      throw error;
    }
  }
  TestSpeechRecognition.prototype = NativeRecognition.prototype;
  window.SpeechRecognition = TestSpeechRecognition;
  window.webkitSpeechRecognition = TestSpeechRecognition;
  URL.createObjectURL = blob => {
    const url = original.createUrl.call(URL, blob);
    state.createdUrls.push(url);
    return url;
  };
  URL.revokeObjectURL = url => {
    state.revokedUrls.push(url);
    return original.revokeUrl.call(URL, url);
  };
})();
''';
