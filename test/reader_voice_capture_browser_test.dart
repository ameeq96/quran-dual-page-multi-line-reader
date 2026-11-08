@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/core/services/reader_voice_capture.dart';

@JS('eval')
external JSAny? _evaluate(JSString source);

Object? _read(String expression) => _evaluate(expression.toJS)?.dartify();

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
    expect(capture.phase, ReaderVoiceCapturePhase.recording);
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
    expect(_read('window.__readerVoiceTest.allTracksStopped()'), isTrue);
  });

  test(
      'online recognition requires opt-in and uses the selected spoken language',
      () async {
    await capture.start(language: 'ur-PK', transcribe: true);
    expect(_read('window.__readerVoiceTest.speechStarts'), 1);
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
    expect(capture.errorMessage, isNull);
    expect(capture.phase, ReaderVoiceCapturePhase.recording);
    await capture.stop();
    expect(capture.hasRecording, isTrue);
  });

  test('an unexpected recorder stop also stops recognition and the microphone',
      () async {
    await capture.start(transcribe: true);
    _evaluate('window.__readerVoiceTest.lastRecorder.stop()'.toJS);
    await Future<void>.delayed(Duration.zero);
    expect(capture.hasRecording, isTrue);
    expect(capture.isBusy, isFalse);
    expect(_read('window.__readerVoiceTest.speechStops'), 1);
    expect(_read('window.__readerVoiceTest.allTracksStopped()'), isTrue);
  });

  test('dispose aborts recognition and ignores late capture events', () async {
    await capture.start(transcribe: true);
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
    getUserMediaCalls: 0, recorderStarts: 0, speechStarts: 0,
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
    emitTranscript(text) {
      const event = new SpeechRecognitionEvent('result');
      Object.defineProperty(event, 'results', {
        value: [{length: 1, isFinal: true, item: () => ({transcript: text})}],
      });
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
  window.MediaRecorder = class extends EventTarget {
    static isTypeSupported(type) { return type === 'audio/webm'; }
    constructor(stream, options) {
      super();
      this.stream = stream;
      this.mimeType = options.mimeType;
      this.state = 'inactive';
      state.lastRecorder = this;
    }
    start() { this.state = 'recording'; state.recorderStarts++; }
    stop() {
      if (this.state === 'inactive') return;
      this.state = 'inactive';
      queueMicrotask(() => {
        this.dispatchEvent(new BlobEvent('dataavailable', {
          data: new Blob(['local audio fixture'], {type: this.mimeType}),
        }));
        this.dispatchEvent(new Event('stop'));
      });
    }
  };
  window.SpeechRecognition = class extends EventTarget {
    constructor() { super(); state.lastRecognition = this; }
    start() { state.speechStarts++; }
    stop() {
      state.speechStops++;
      queueMicrotask(() => this.dispatchEvent(new Event('end')));
    }
    abort() { state.speechAborts++; }
  };
  window.webkitSpeechRecognition = window.SpeechRecognition;
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
