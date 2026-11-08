import 'dart:async';

import 'package:flutter/foundation.dart';

class ReaderAudioPractice extends ChangeNotifier {
  ReaderAudioPractice({
    required Stream<Duration> positions,
    required Duration? Function() duration,
    required String? Function() source,
    required bool Function() playing,
    required Future<void> Function() pause,
    required Future<void> Function(Duration) seek,
    required void Function() play,
    required Future<void> Function(bool) loop,
    required bool Function() repeatChapter,
  })  : _duration = duration,
        _source = source,
        _playing = playing,
        _pause = pause,
        _seek = seek,
        _play = play,
        _loop = loop,
        _repeatChapter = repeatChapter {
    _positions = positions.listen(_onPosition);
  }

  final Duration? Function() _duration;
  final String? Function() _source;
  final bool Function() _playing;
  final Future<void> Function() _pause;
  final Future<void> Function(Duration) _seek;
  final void Function() _play;
  final Future<void> Function(bool) _loop;
  final bool Function() _repeatChapter;
  late final StreamSubscription<Duration> _positions;
  Timer? _gapTimer;
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  Future<void> _step = Future<void>.value();
  int _generation = 0;
  int _sleepGeneration = 0;
  bool _disposed = false;
  bool _busy = false;
  bool _active = false;
  bool _waiting = false;
  int _completed = 0;
  int _repetitions = 3;
  Duration _start = Duration.zero;
  Duration _end = Duration.zero;
  Duration _gap = Duration.zero;
  String? _selectedSource;
  DateTime? _sleepUntil;
  String? _error;

  bool get active => _active;
  bool get waiting => _waiting;
  bool get busy => _busy;
  int get completed => _completed;
  int get repetitions => _repetitions;
  Duration get start => _start;
  Duration get end => _end;
  DateTime? get sleepUntil => _sleepUntil;
  String? get errorMessage => _error;

  bool _current(int generation) =>
      !_disposed &&
      generation == _generation &&
      _selectedSource != null &&
      _selectedSource == _source();
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> begin(
      {required Duration start,
      required Duration end,
      required int repetitions,
      Duration gap = Duration.zero}) async {
    final duration = _duration();
    final source = _source();
    if (source == null || duration == null || duration <= Duration.zero) {
      throw const FormatException(
          'Load a recitation before starting A–B practice.');
    }
    if (start < Duration.zero ||
        end <= start ||
        end > duration ||
        !const [3, 5, 10].contains(repetitions) ||
        gap < Duration.zero ||
        gap > const Duration(seconds: 30)) {
      throw const FormatException(
          'Choose valid A and B times, 3, 5 or 10 repeats, and a pause up to 30 seconds.');
    }
    await cancel();
    if (_disposed) return;
    if (_source() != source) {
      throw const FormatException(
          'The recitation changed. Start A–B practice again.');
    }
    final generation = ++_generation;
    _selectedSource = _source();
    _start = start;
    _end = end;
    _gap = gap;
    _repetitions = repetitions;
    _completed = 0;
    _active = true;
    _waiting = false;
    _busy = true;
    _error = null;
    _publish();
    _step = _startCycle(generation);
    await _step;
  }

  Future<void> _startCycle(int generation) async {
    try {
      await _pause();
      if (!_current(generation)) return;
      await _loop(false);
      if (!_current(generation)) return;
      await _seek(_start);
      if (!_current(generation)) return;
      _waiting = false;
      _play();
      _busy = false;
      _publish();
    } catch (_) {
      _fail(generation);
    }
  }

  void _onPosition(Duration position) {
    if (!_active || _busy || _waiting || !_playing()) return;
    if (_selectedSource != _source()) {
      unawaited(cancel());
      return;
    }
    if (position >= _end) {
      _busy = true;
      _step = _finishCycle(_generation);
    }
  }

  Future<void> _finishCycle(int generation) async {
    try {
      await _pause();
      if (!_current(generation)) return;
      _completed++;
      if (_completed >= _repetitions) {
        _active = false;
        _busy = false;
        await _loop(_repeatChapter());
        if (_current(generation)) _publish();
        return;
      }
      _waiting = true;
      _busy = false;
      _publish();
      _gapTimer = Timer(_gap, () {
        if (!_current(generation)) return;
        _busy = true;
        _step = _startCycle(generation);
      });
    } catch (_) {
      _fail(generation);
    }
  }

  void _fail(int generation) {
    if (!_current(generation)) return;
    _active = false;
    _busy = false;
    _waiting = false;
    _gapTimer?.cancel();
    _error = 'A–B practice stopped. Try loading the recitation again.';
    unawaited(_loop(_repeatChapter()).catchError((_) {}));
    _publish();
  }

  Future<void> cancel() async {
    final generation = ++_generation;
    _gapTimer?.cancel();
    _gapTimer = null;
    _active = false;
    _waiting = false;
    await _step;
    _busy = false;
    if (!_disposed && generation == _generation) {
      await _loop(_repeatChapter());
      _publish();
    }
  }

  void setSleepTimer(Duration? duration) {
    if (_disposed) return;
    if (duration != null &&
        (duration <= Duration.zero || duration > const Duration(hours: 2))) {
      throw const FormatException('Choose a sleep timer up to two hours.');
    }
    final generation = ++_sleepGeneration;
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepUntil = null;
    if (duration != null) {
      _sleepUntil = DateTime.now().add(duration);
      _sleepTicker =
          Timer.periodic(const Duration(seconds: 1), (_) => _publish());
      _sleepTimer = Timer(duration, () async {
        if (_disposed || generation != _sleepGeneration) return;
        _sleepTicker?.cancel();
        _sleepUntil = null;
        try {
          await Future.wait<void>([cancel(), _pause()]);
        } catch (_) {
          if (!_disposed && generation == _sleepGeneration) {
            _error =
                'The sleep timer could not pause playback. Pause it manually.';
          }
        }
        _publish();
      });
    }
    _publish();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    ++_sleepGeneration;
    _gapTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    unawaited(_positions.cancel());
    super.dispose();
  }
}
