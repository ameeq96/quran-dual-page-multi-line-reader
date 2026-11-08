import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';

import 'reader_recording_store.dart';

ReaderRecordingStore createRecordingStore(
        String profileId, ReaderRecordingLimits limits) =>
    _BrowserRecordingStore(profileId, limits);

class _BrowserRecordingStore extends ReaderRecordingStore {
  _BrowserRecordingStore(String profileId, ReaderRecordingLimits limits)
      : super.base(profileId: profileId, limits: limits);
  dynamic _database;
  Future<void>? _opening;
  Future<void> _operations = Future<void>.value();
  bool _disposed = false;
  int _pending = 0;
  List<ReaderLocalRecording> _recordings = const [];
  html.AudioElement? _audio;
  String? _url;
  String? _playingId;
  int _playGeneration = 0;
  int _comparisonIndex = 0;
  final _audioSubscriptions = <StreamSubscription<html.Event>>[];
  String? _error;
  @override
  bool get supported => html.window.indexedDB != null;
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
  String _key(String id) => '$profileId:$id';
  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _open() => _opening ??= () async {
        final factory = html.window.indexedDB;
        if (factory == null) {
          throw const ReaderRecordingFailure(
              'Recording storage is unavailable in this browser.');
        }
        final database = await factory.open('quran_reader_recordings_v1',
            version: 1,
            onUpgradeNeeded: (event) => (event.target as dynamic)
                .result
                .createObjectStore('recordings'));
        if (_disposed) {
          database.close();
          throw const ReaderRecordingFailure(
              'The recording library is closed.');
        }
        _database = database;
      }()
          .catchError((Object error) {
        _opening = null;
        throw error;
      });

  Future<T> _serial<T>(Future<T> Function() action) {
    if (_disposed) {
      return Future.error(
          const ReaderRecordingFailure('The recording library is closed.'));
    }
    _pending++;
    _error = null;
    _publish();
    final task = _operations.then((_) => action()).catchError((Object error) {
      _error = error is ReaderRecordingFailure
          ? error.message
          : 'Recording storage is full or unavailable. Delete an older recording and try again.';
      throw ReaderRecordingFailure(_error!);
    }).whenComplete(() {
      _pending--;
      _publish();
    });
    _operations =
        task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<void> _loadEntries() async {
    await _open();
    final transaction = _database.transaction('recordings', 'readonly');
    final entries = <ReaderLocalRecording>[];
    await for (final cursor in transaction
        .objectStore('recordings')
        .openCursor(autoAdvance: true)) {
      final metadata = ReaderLocalRecording.fromMap(cursor.value);
      if (metadata != null &&
          metadata.profileId == profileId &&
          cursor.key == _key(metadata.id)) {
        entries.add(metadata);
      }
    }
    await transaction.completed;
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _recordings = entries;
  }

  @override
  Future<void> refresh() => _serial(_loadEntries);

  @override
  Future<ReaderLocalRecording> save(
      {required Uint8List bytes,
      required String mimeType,
      required Duration duration,
      String label = '',
      String reference = '',
      int? chapterId}) {
    if (bytes.isEmpty ||
        bytes.length > limits.singleBytes ||
        duration < Duration.zero ||
        duration > const Duration(seconds: 60) ||
        !ReaderLocalRecording.validMime(mimeType) ||
        label.trim().length > 120 ||
        reference.trim().length > 120 ||
        chapterId != null && (chapterId < 1 || chapterId > 114)) {
      return Future.error(const ReaderRecordingFailure(
          'This recording is invalid or exceeds the recording limit.'));
    }
    final snapshot = Uint8List.fromList(bytes);
    final random = Random.secure();
    final id = base64UrlEncode(List.generate(16, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final metadata = ReaderLocalRecording(
        id: id,
        profileId: profileId,
        createdAt: DateTime.now().toUtc(),
        durationMillis: duration.inMilliseconds,
        bytes: snapshot.length,
        mimeType: mimeType,
        label: label.trim(),
        reference: reference.trim(),
        chapterId: chapterId);
    return _serial(() async {
      await _open();
      final transaction = _database.transaction('recordings', 'readwrite');
      final store = transaction.objectStore('recordings');
      var count = 0;
      var total = 0;
      await for (final cursor in store.openCursor(autoAdvance: true)) {
        if (cursor.key is String &&
            (cursor.key as String).startsWith('$profileId:')) {
          count++;
          final value = cursor.value;
          if (value is Map && value['audio'] is html.Blob) {
            total += (value['audio'] as html.Blob).size;
          }
        }
      }
      if (count >= limits.count ||
          total + snapshot.length > limits.totalBytes) {
        transaction.abort();
        try {
          await transaction.completed;
        } catch (_) {}
        throw const ReaderRecordingFailure(
            'Recording storage is full. Delete an older recording and try again.');
      }
      await store.add({
        ...metadata.toMap(),
        'audio': html.Blob([snapshot], mimeType)
      }, _key(id));
      await transaction.completed;
      await _loadEntries();
      return metadata;
    });
  }

  @override
  Future<void> delete(String id) => _serial(() async {
        if (!ReaderLocalRecording.validId(id)) {
          throw const ReaderRecordingFailure('Recording not found.');
        }
        stopPlayback();
        await _open();
        final transaction = _database.transaction('recordings', 'readwrite');
        await transaction.objectStore('recordings').delete(_key(id));
        await transaction.completed;
        await _loadEntries();
      });

  @override
  Future<void> play(String id) => _play([id]);
  @override
  Future<void> compare(String first, String second) async {
    if (first == second) {
      throw const ReaderRecordingFailure(
          'Select two different recordings to compare.');
    }
    await _play([first, second]);
  }

  Future<void> _play(List<String> ids) async {
    if (_disposed || ids.any((id) => !ReaderLocalRecording.validId(id))) {
      throw const ReaderRecordingFailure('Recording not found.');
    }
    stopPlayback();
    _error = null;
    final generation = _playGeneration;
    await _playItem(ids, 0, generation);
  }

  Future<void> _playItem(List<String> ids, int index, int generation) async {
    try {
      await _open();
      if (_disposed || generation != _playGeneration) return;
      final transaction = _database.transaction('recordings', 'readonly');
      final value = await transaction
          .objectStore('recordings')
          .getObject(_key(ids[index]));
      await transaction.completed;
      if (_disposed || generation != _playGeneration) return;
      final metadata = ReaderLocalRecording.fromMap(value);
      if (metadata == null ||
          metadata.profileId != profileId ||
          value['audio'] is! html.Blob ||
          (value['audio'] as html.Blob).size != metadata.bytes) {
        throw const ReaderRecordingFailure('Recording not found.');
      }
      _releaseAudio();
      _url = html.Url.createObjectUrlFromBlob(value['audio'] as html.Blob);
      final audio = _audio = html.AudioElement(_url);
      _playingId = ids[index];
      _comparisonIndex = ids.length == 2 ? index + 1 : 0;
      _audioSubscriptions.add(audio.onEnded.listen((_) {
        if (_disposed || generation != _playGeneration) return;
        _releaseAudio();
        _playingId = null;
        if (index + 1 < ids.length) {
          unawaited(_playItem(ids, index + 1, generation).catchError((_) {}));
        } else {
          stopPlayback();
        }
      }));
      _audioSubscriptions.add(audio.onError.listen((_) {
        if (_disposed || generation != _playGeneration) return;
        _error = 'This saved recording could not be played.';
        stopPlayback();
      }));
      _publish();
      await audio.play();
      if (_disposed || generation != _playGeneration) audio.pause();
    } catch (error) {
      if (_disposed || generation != _playGeneration) return;
      _error = error is ReaderRecordingFailure
          ? error.message
          : 'This saved recording could not be played.';
      stopPlayback();
      throw ReaderRecordingFailure(_error!);
    }
  }

  void _releaseAudio() {
    for (final subscription in _audioSubscriptions) {
      unawaited(subscription.cancel());
    }
    _audioSubscriptions.clear();
    _audio?.pause();
    _audio?.removeAttribute('src');
    _audio = null;
    if (_url != null) html.Url.revokeObjectUrl(_url!);
    _url = null;
  }

  @override
  void stopPlayback() {
    _playGeneration++;
    _releaseAudio();
    _playingId = null;
    _comparisonIndex = 0;
    _publish();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPlayback();
    _operations.whenComplete(() {
      _database?.close();
    });
    super.dispose();
  }
}
