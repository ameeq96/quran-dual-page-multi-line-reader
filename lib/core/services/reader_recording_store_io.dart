import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'reader_recording_store.dart';

ReaderRecordingStore createLessonRecordingStore(String profileId, ReaderRecordingLimits limits) =>
    _LessonRecordingStore(profileId, limits);

class _LessonRecordingStore extends ReaderRecordingStore with WidgetsBindingObserver {
  _LessonRecordingStore(String profileId, ReaderRecordingLimits limits)
      : super.base(profileId: profileId, limits: limits) {
    WidgetsBinding.instance.addObserver(this);
  }
  static const _channel = MethodChannel('com.opplexify.quran/lesson_recording');
  final _owner = 'store_${base64UrlEncode(List.generate(16, (_) => Random.secure().nextInt(256))).replaceAll('=', '')}';
  Future<void> _operations = Future<void>.value();
  bool _disposed = false;
  bool _polling = false;
  int _pending = 0;
  int _generation = 0;
  List<ReaderLocalRecording> _recordings = const [];
  String? _playingId;
  int _comparisonIndex = 0;
  String? _error;
  Timer? _timer;
  @override
  bool get supported => Platform.isAndroid;
  @override
  bool get busy => _pending > 0;
  @override
  List<ReaderLocalRecording> get recordings => List.unmodifiable(_recordings);
  @override
  String? get playingId => _playingId;
  @override
  int get comparisonIndex => _comparisonIndex;
  @override
  String? get errorMessage => _error;
  Map<String, Object?> get _arguments => {'profileId': profileId, 'ownerId': _owner,
    'countLimit': limits.count, 'totalLimit': limits.totalBytes, 'singleLimit': limits.singleBytes};

  void _publish() { if (!_disposed) notifyListeners(); }
  Future<T?> _invoke<T>(String method, [Map<String, Object?> extra = const {}]) async {
    if (!supported || _disposed) throw const ReaderRecordingFailure('Android lesson recording storage is unavailable.');
    try { return await _channel.invokeMethod<T>(method, {..._arguments, ...extra}); }
    on PlatformException catch (error) {
      throw ReaderRecordingFailure(error.message ?? 'Lesson recording storage is unavailable.');
    }
  }
  Future<T> _serial<T>(Future<T> Function() operation) {
    if (_disposed) return Future.error(const ReaderRecordingFailure('The lesson recording library is closed.'));
    _pending++;
    _error = null;
    _publish();
    final next = _operations.then((_) => operation()).catchError((Object error) {
      _error = error is ReaderRecordingFailure ? error.message : 'Lesson recording storage is unavailable.';
      throw ReaderRecordingFailure(_error!);
    }).whenComplete(() { _pending--; _publish(); });
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
  Future<void> _load() async {
    final values = await _invoke<List<dynamic>>('storeList');
    if (values == null) throw const ReaderRecordingFailure('Lesson recordings could not be read.');
    final entries = values.map(ReaderLocalRecording.fromMap).toList();
    if (entries.any((entry) => entry == null || entry.profileId != profileId)) {
      throw const ReaderRecordingFailure('Lesson recording metadata is invalid.');
    }
    _recordings = List.unmodifiable(entries.cast<ReaderLocalRecording>());
  }
  @override
  Future<void> refresh() => _serial(_load);

  @override
  Future<ReaderLocalRecording> save({required Uint8List bytes, required String mimeType,
      required Duration duration, String label = '', String reference = '', int? chapterId}) {
    if (bytes.isEmpty || bytes.length > limits.singleBytes || duration < Duration.zero ||
        duration > const Duration(seconds: 60) || !ReaderLocalRecording.validMime(mimeType) ||
        label.trim().length > 120 || reference.trim().length > 120 ||
        chapterId != null && (chapterId < 1 || chapterId > 114)) {
      return Future.error(const ReaderRecordingFailure('This lesson recording exceeds its limits.'));
    }
    final snapshot = Uint8List.fromList(bytes);
    final random = Random.secure();
    final metadata = ReaderLocalRecording(
      id: base64UrlEncode(List.generate(16, (_) => random.nextInt(256))).replaceAll('=', ''),
      profileId: profileId, createdAt: DateTime.now().toUtc(),
      durationMillis: duration.inMilliseconds, bytes: snapshot.length, mimeType: mimeType,
      label: label.trim(), reference: reference.trim(), chapterId: chapterId);
    return _serial(() async {
      final saved = ReaderLocalRecording.fromMap(await _invoke<Object?>('storeSave',
        {'metadata': metadata.toMap(), 'bytes': snapshot}));
      if (saved == null || saved.id != metadata.id || saved.profileId != profileId || saved.bytes != snapshot.length) {
        throw const ReaderRecordingFailure('The lesson recording could not be saved.');
      }
      await _load();
      return saved;
    });
  }

  @override
  Future<Uint8List> readBytes(String id) => _serial(() async {
    if (!ReaderLocalRecording.validId(id)) throw const ReaderRecordingFailure('Lesson recording not found.');
    final bytes = await _invoke<Uint8List>('storeRead', {'id': id});
    if (bytes == null || bytes.isEmpty || bytes.length > limits.singleBytes) {
      throw const ReaderRecordingFailure('Lesson recording not found.');
    }
    return Uint8List.fromList(bytes);
  });

  @override
  Future<void> delete(String id) => _serial(() async {
    if (!ReaderLocalRecording.validId(id)) throw const ReaderRecordingFailure('Lesson recording not found.');
    if (_playingId == id) stopPlayback();
    await _invoke<void>('storeDelete', {'id': id});
    await _load();
  });

  @override
  Future<void> play(String id) => _play([id]);
  @override
  Future<void> compare(String first, String second) async {
    if (first == second) throw const ReaderRecordingFailure('Choose two different lesson recordings.');
    await _play([first, second]);
  }
  Future<void> _play(List<String> ids) async {
    if (ids.any((id) => !ReaderLocalRecording.validId(id))) throw const ReaderRecordingFailure('Lesson recording not found.');
    stopPlayback();
    final generation = _generation;
    await _invoke<Object?>('storePlay', {'ids': ids});
    if (_disposed || generation != _generation) return;
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => unawaited(_poll()));
    await _poll();
  }
  Future<void> _poll() async {
    if (_disposed || _polling) return;
    final generation = _generation;
    _polling = true;
    try {
      final value = await _invoke<Map<dynamic, dynamic>>('lessonPlaybackStatus');
      if (_disposed || generation != _generation) return;
      _playingId = value?['playing'] == true && value?['id'] is String ? value!['id'] as String : null;
      _comparisonIndex = value?['comparisonIndex'] is int ? value!['comparisonIndex'] as int : 0;
      if (value?['error'] is String) _error = value!['error'] as String;
      if (_playingId == null) { _timer?.cancel(); _comparisonIndex = 0; }
      _publish();
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _error = 'The lesson recording could not be played.';
        stopPlayback();
      }
    } finally { _polling = false; }
  }
  @override
  void stopPlayback() {
    _generation++;
    _timer?.cancel();
    _playingId = null;
    _comparisonIndex = 0;
    unawaited(_channel.invokeMethod<void>('lessonStopPlayback', {'ownerId': _owner}).catchError((_) {}));
    _publish();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stopPlayback();
  }
  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    stopPlayback();
    super.dispose();
  }
}
