// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';

@JS('globalThis.SpeechSynthesisUtterance')
external JSFunction? get _utteranceConstructor;

class WorshipSpeech {
  WorshipSpeech() {
    // Chrome populates its voice list asynchronously; warm it before the tap.
    html.window.speechSynthesis?.getVoices();
  }

  static WorshipSpeech? _owner;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  html.SpeechSynthesisUtterance? _utterance;
  Completer<void>? _started;
  Timer? _startTimeout;
  int _generation = 0;
  bool _disposed = false;

  Future<void> speakArabic(String text) async {
    if (_disposed) throw StateError('Arabic device pronunciation is closed.');
    final synthesis = html.window.speechSynthesis;
    if (synthesis == null || _utteranceConstructor == null) {
      throw UnsupportedError(
        'Arabic device pronunciation is unavailable in this browser.',
      );
    }
    final value = text.trim();
    if (value.isEmpty ||
        value.length > 2000 ||
        !RegExp(r'[\u0600-\u06FF]').hasMatch(value)) {
      throw const FormatException(
        'Choose an Arabic dhikr of up to 2000 characters.',
      );
    }
    final voices = synthesis.getVoices().where((voice) {
      final language = (voice.lang ?? '').toLowerCase().replaceAll('_', '-');
      return language == 'ar' || language.startsWith('ar-');
    }).toList();
    if (voices.isEmpty) {
      throw StateError(
        'An Arabic voice is unavailable. Enable an Arabic speech voice in your device or browser settings, then try again.',
      );
    }
    voices.sort(
      (a, b) => (b.localService == true ? 1 : 0).compareTo(
        a.localService == true ? 1 : 0,
      ),
    );
    _owner?._release('Arabic device pronunciation was stopped.');
    synthesis.cancel();
    _owner = this;
    final generation = ++_generation;
    final completion = Completer<void>();
    _started = completion;
    final utterance = html.SpeechSynthesisUtterance(value)
      ..voice = voices.first
      ..lang = voices.first.lang ?? 'ar'
      ..rate = 0.85
      ..pitch = 1
      ..volume = 1;
    _utterance = utterance;
    _subscriptions.add(
      utterance.onStart.listen((_) {
        if (_disposed ||
            generation != _generation ||
            !identical(_utterance, utterance) ||
            !identical(_owner, this)) {
          return;
        }
        _startTimeout?.cancel();
        if (!completion.isCompleted) completion.complete();
      }),
    );
    _subscriptions.add(
      utterance.onEnd.listen((_) {
        if (generation == _generation &&
            identical(_utterance, utterance) &&
            identical(_owner, this)) {
          _release();
          _owner = null;
        }
      }),
    );
    _subscriptions.add(
      utterance.onError.listen((_) {
        if (generation == _generation &&
            identical(_utterance, utterance) &&
            identical(_owner, this)) {
          _release(
            'Arabic pronunciation could not start. Check your Arabic voice and tap Listen again.',
          );
          _owner = null;
        }
      }),
    );
    _startTimeout = Timer(const Duration(seconds: 8), () {
      if (generation == _generation &&
          identical(_utterance, utterance) &&
          identical(_owner, this)) {
        _release(
          'Arabic pronunciation did not start. Tap Listen again or enable an Arabic speech voice.',
        );
        _owner = null;
        synthesis.cancel();
      }
    });
    try {
      synthesis.speak(utterance);
    } catch (_) {
      _release('Arabic pronunciation could not start. Tap Listen again.');
      if (identical(_owner, this)) {
        _owner = null;
        synthesis.cancel();
      }
    }
    await completion.future;
  }

  void _release([String? error]) {
    ++_generation;
    _startTimeout?.cancel();
    _startTimeout = null;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _utterance = null;
    final completion = _started;
    _started = null;
    if (completion != null && !completion.isCompleted) {
      if (error == null) {
        completion.complete();
      } else {
        completion.completeError(StateError(error));
      }
    }
  }

  Future<void> stop() async {
    _release('Arabic device pronunciation was stopped.');
    if (identical(_owner, this)) {
      _owner = null;
      html.window.speechSynthesis?.cancel();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
  }
}
