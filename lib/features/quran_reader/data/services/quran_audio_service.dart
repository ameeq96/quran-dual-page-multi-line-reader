import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/browser_file_store.dart';
import '../../domain/models/quran_reciter.dart';
import 'reader_audio_practice.dart';

class QuranAudioService {
  QuranAudioService({
    AudioPlayer? player,
    http.Client? client,
  })  : _player = player ?? AudioPlayer(),
        _client = client ?? http.Client();

  final AudioPlayer _player;
  final http.Client _client;
  final StreamController<String> _playbackErrors = StreamController<String>.broadcast();
  Stream<String> get playbackErrors => _playbackErrors.stream;
  List<QuranReciter>? _recitersCache;
  final Map<String, _QuranChapterAudio> _chapterAudioCache = {};
  List<Map<String, dynamic>> _currentTimings = const [];
  int? loadedReciterId;
  int? loadedChapterId;
  static int _downloadSequence = 0;
  ReaderAudioPractice? _practice;
  bool _repeatChapter = false;
  int _sourceGeneration = 0;
  ReaderAudioPractice get practice => _practice ??= ReaderAudioPractice(
    positions: _player.positionStream, duration: () => _player.duration,
    source: () => loadedChapterId == null || loadedReciterId == null
        ? null : '$loadedReciterId:$loadedChapterId',
    playing: () => _player.playing,
    pause: _pauseForPractice, seek: _player.seek, play: _startPlayback,
    loop: (enabled) => _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off),
    repeatChapter: () => _repeatChapter,
  );

  ({Duration start, Duration end})? practiceRangeForAyah(String key) {
    if (loadedChapterId == null || !key.startsWith('$loadedChapterId:')) return null;
    for (final timing in _currentTimings) {
      if (timing['verse_key'] == key) {
        return (
          start: Duration(milliseconds: timing['timestamp_from'] as int),
          end: Duration(milliseconds: timing['timestamp_to'] as int),
        );
      }
    }
    return null;
  }
  bool get isPlaybackCompleted => _player.processingState == ProcessingState.completed;
  bool get isPlaying => _player.playing;

  Future<void> _pauseForPractice() {
    ++_sourceGeneration;
    return _player.pause();
  }

  String? verseKeyAtPosition(Duration position) {
    final milliseconds = position.inMilliseconds;
    for (final timing in _currentTimings) {
      final from = timing['timestamp_from'] as int;
      final to = timing['timestamp_to'] as int;
      if (milliseconds >= from && milliseconds < to) return timing['verse_key'] as String;
    }
    return null;
  }
  static const Duration _networkTimeout = Duration(seconds: 8);

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'my_flutter_app/1.0',
  };

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Duration? get currentDuration => _player.duration;
  Duration get currentPosition => _player.position;
  List<QuranReciter> get fallbackReciters => _fallbackReciters;

  Future<List<QuranReciter>> loadReciters() async {
    if (_recitersCache != null) {
      return _recitersCache!;
    }

    try {
      final uri =
          Uri.parse('https://api.quran.com/api/v4/resources/chapter_reciters');
      final response =
          await _client.get(uri, headers: _headers).timeout(_networkTimeout);
      if (response.statusCode != 200) {
        _recitersCache = _fallbackReciters;
        return _recitersCache!;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final recitations = payload['reciters'] as List<dynamic>? ?? const [];
      final reciters = recitations.whereType<Map<String, dynamic>>()
          .map((entry) => QuranReciter(
                id: (entry['id'] as num).toInt(),
                name: (entry['name'] ?? entry['reciter_name']) as String,
                style: entry['style'] is Map ? (entry['style'] as Map)['name'] as String? : entry['style'] as String?,
              ))
          .toList(growable: false);
      _recitersCache = reciters.isEmpty ? _fallbackReciters : reciters;
      return _recitersCache!;
    } catch (_) {
      _recitersCache = _fallbackReciters;
      return _recitersCache!;
    }
  }

  Future<void> playChapter({
    required int reciterId,
    required int chapterId,
    required String chapterName,
    required String reciterName,
    Duration? initialPosition,
  }) async {
    final generation = ++_sourceGeneration;
    await _practice?.cancel();
    if (generation != _sourceGeneration) return;
    final localFilePath = await localFilePathForChapter(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    if (generation != _sourceGeneration) return;
    _currentTimings = const [];
    final cachedTimings = await _loadSavedTimings(reciterId, chapterId);
    _QuranChapterAudio? chapterAudio;
    if (localFilePath == null || cachedTimings.isEmpty) {
      try {
        chapterAudio = await _loadChapterAudio(reciterId: reciterId, chapterId: chapterId);
      } catch (_) {
        if (localFilePath == null) rethrow;
      }
    }
    if (generation != _sourceGeneration) return;
    _currentTimings = chapterAudio?.timings ?? cachedTimings;
    final sourceUri = localFilePath == null
        ? Uri.parse(chapterAudio!.url)
        : kIsWeb ? Uri.parse(localFilePath) : Uri.file(localFilePath);
    final mediaItem = MediaItem(
      id: 'quran-$reciterId-$chapterId',
      album: 'Quran Pak Dual Page Reader',
      title: chapterName,
      artist: reciterName,
      extras: <String, dynamic>{
        'reciterId': reciterId,
        'chapterId': chapterId,
        'offline': localFilePath != null,
      },
    );

    await _player.setAudioSource(
      AudioSource.uri(
        sourceUri,
        tag: mediaItem,
      ),
      initialPosition: initialPosition,
    );
    if (generation != _sourceGeneration) return;
    loadedReciterId = reciterId;
    loadedChapterId = chapterId;
    _startPlayback();
  }

  Future<void> downloadChapter({
    required int reciterId,
    required int chapterId,
  }) async {
    final chapterAudio = await _loadChapterAudio(reciterId: reciterId, chapterId: chapterId);
    final audioUrl = chapterAudio.url;
    final response = await _client
        .get(Uri.parse(audioUrl), headers: _headers)
        .timeout(const Duration(minutes: 3));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw StateError('Unable to download recitation audio right now.');
    }

    if (kIsWeb) {
      final store = BrowserFileStore.instance;
      await store.putBytes('audio:$reciterId:$chapterId:file', Uint8List.fromList(response.bodyBytes), 'audio/mpeg');
      await store.putManifest('audio:$reciterId:$chapterId:timings', {'timestamps': chapterAudio.timings});
      return;
    }
    final outputFile = await _audioFileForChapter(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    await _writeNativeDownload(outputFile, response.bodyBytes, chapterAudio.timings);
  }

  Future<void> _writeNativeDownload(
    File output,
    List<int> bytes,
    List<Map<String, dynamic>> timings,
  ) async {
    await output.parent.create(recursive: true);
    final suffix = '${DateTime.now().microsecondsSinceEpoch}-${_downloadSequence++}';
    final metadata = File('${output.path}.timings.json');
    final pendingAudio = File('${output.path}.pending-$suffix');
    final pendingMetadata = File('${metadata.path}.pending-$suffix');
    final previousAudio = File('${output.path}.backup-$suffix');
    final previousMetadata = File('${metadata.path}.backup-$suffix');
    var audioBackedUp = false;
    var metadataBackedUp = false;
    var audioPublished = false;
    var metadataPublished = false;
    var committed = false;
    try {
      await pendingAudio.writeAsBytes(bytes, flush: true);
      if (await pendingAudio.length() != bytes.length) {
        throw StateError('Downloaded recitation was not saved completely.');
      }
      await pendingMetadata.writeAsString(json.encode(timings), flush: true);
      if (await output.exists()) {
        await output.rename(previousAudio.path);
        audioBackedUp = true;
      }
      if (await metadata.exists()) {
        await metadata.rename(previousMetadata.path);
        metadataBackedUp = true;
      }
      await pendingAudio.rename(output.path);
      audioPublished = true;
      await pendingMetadata.rename(metadata.path);
      metadataPublished = true;
      committed = true;
    } catch (error, stack) {
      try {
        if (metadataPublished && await metadata.exists()) await metadata.delete();
        if (audioPublished && await output.exists()) await output.delete();
        if (audioBackedUp) await previousAudio.rename(output.path);
        if (metadataBackedUp) await previousMetadata.rename(metadata.path);
      } catch (_) {
        // Keep any recoverable previous files if the filesystem rejects rollback.
      }
      Error.throwWithStackTrace(error, stack);
    } finally {
      for (final file in [pendingAudio, pendingMetadata,
        if (committed) previousAudio, if (committed) previousMetadata]) {
        try {
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Staging filenames are never treated as completed audio downloads.
        }
      }
    }
  }

  Future<void> deleteChapterDownload({
    required int reciterId,
    required int chapterId,
  }) async {
    if (kIsWeb) {
      await BrowserFileStore.instance.removePrefix('audio:$reciterId:$chapterId:');
      return;
    }
    final file = await _audioFileForChapter(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    if (await file.exists()) {
      await file.delete();
    }
    final timings = File('${file.path}.timings.json');
    if (await timings.exists()) await timings.delete();
  }

  Future<String?> localFilePathForChapter({
    required int reciterId,
    required int chapterId,
  }) async {
    if (kIsWeb) {
      try {
        await BrowserFileStore.instance.initialize();
        return BrowserFileStore.instance.urlFor('audio:$reciterId:$chapterId:file');
      } catch (_) {
        return null;
      }
    }
    final file = await _audioFileForChapter(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }
    return null;
  }

  Future<bool> isChapterDownloaded({
    required int reciterId,
    required int chapterId,
  }) async {
    return (await localFilePathForChapter(
          reciterId: reciterId,
          chapterId: chapterId,
        )) !=
        null;
  }

  Future<Set<String>> downloadedChapterKeys() async {
    if (kIsWeb) {
      await BrowserFileStore.instance.initialize();
      return BrowserFileStore.instance.keys.map((key) => RegExp(r'^audio:(\d+):(\d+):file$').firstMatch(key))
          .whereType<RegExpMatch>().map((match) => '${match.group(1)}-${match.group(2)}').toSet();
    }
    final directory = await _audioDirectory();
    if (!await directory.exists()) {
      return <String>{};
    }

    final files = directory.listSync();
    final keys = <String>{};
    for (final entity in files) {
      if (entity is! File || entity.lengthSync() == 0) {
        continue;
      }
      final name =
          entity.uri.pathSegments.isEmpty ? '' : entity.uri.pathSegments.last;
      final match = RegExp(r'^r(\d+)_c(\d+)\.mp3$').firstMatch(name);
      if (match == null) {
        continue;
      }
      keys.add('${match.group(1)}-${match.group(2)}');
    }
    return keys;
  }

  Future<void> pause() async {
    final generation = ++_sourceGeneration;
    await _practice?.cancel();
    if (generation != _sourceGeneration) return;
    await _player.pause();
  }

  Future<void> resume() async {
    final generation = ++_sourceGeneration;
    await _practice?.cancel();
    if (generation != _sourceGeneration) return;
    if (isPlaybackCompleted) await _player.seek(Duration.zero);
    if (generation != _sourceGeneration) return;
    _startPlayback();
  }

  void _startPlayback() {
    unawaited(_player.play().catchError((Object error) {
      if (!_playbackErrors.isClosed) _playbackErrors.add(error.toString());
    }));
  }

  Future<void> stop() async {
    final generation = ++_sourceGeneration;
    _practice?.setSleepTimer(null);
    await _practice?.cancel();
    if (generation != _sourceGeneration) return;
    await _player.stop();
  }

  Future<void> resetPlayback() async {
    final generation = ++_sourceGeneration;
    _practice?.setSleepTimer(null);
    await _practice?.cancel();
    if (generation != _sourceGeneration) return;
    await _player.stop();
    if (generation != _sourceGeneration) return;
    loadedReciterId = null;
    loadedChapterId = null;
    _currentTimings = const [];
  }

  Future<void> seek(Duration position) async {
    await _practice?.cancel();
    await _player.seek(position);
  }

  Future<void> setRepeatEnabled(bool enabled) {
    _repeatChapter = enabled;
    return _player.setLoopMode(enabled && !(_practice?.active ?? false) ? LoopMode.one : LoopMode.off);
  }

  void dispose() {
    ++_sourceGeneration;
    _practice?.dispose();
    _client.close();
    _playbackErrors.close();
    _player.dispose();
  }

  Future<_QuranChapterAudio> _loadChapterAudio({required int reciterId, required int chapterId}) async {
    final key = '$reciterId:$chapterId';
    final cached = _chapterAudioCache[key];
    if (cached != null) return cached;
    final uri = Uri.parse('https://api.quran.com/api/v4/chapter_recitations/$reciterId/$chapterId?segments=true');
    final response = await _client.get(uri, headers: _headers).timeout(_networkTimeout);
    if (response.statusCode != 200) throw StateError('Unable to load recitation for chapter $chapterId.');
    final payload = json.decode(response.body) as Map<String, dynamic>;
    final audioFile = payload['audio_file'] as Map<String, dynamic>?;
    final audioUrl = audioFile?['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) throw StateError('Recitation audio is unavailable.');
    final result = _QuranChapterAudio(audioUrl, _normalizeTimings(audioFile?['timestamps']));
    _chapterAudioCache[key] = result;
    return result;
  }

  List<Map<String, dynamic>> _normalizeTimings(Object? value) {
    if (value is! List) return const [];
    final result = <Map<String, dynamic>>[];
    for (final item in value.whereType<Map>()) {
      final verse = item['verse_key'];
      final from = item['timestamp_from'];
      final to = item['timestamp_to'];
      if (verse is String && RegExp(r'^\d+:\d+$').hasMatch(verse) && from is num && to is num && from >= 0 && to > from) {
        result.add({'verse_key': verse, 'timestamp_from': from.toInt(), 'timestamp_to': to.toInt()});
      }
    }
    result.sort((left, right) => (left['timestamp_from'] as int).compareTo(right['timestamp_from'] as int));
    return result;
  }

  Future<List<Map<String, dynamic>>> _loadSavedTimings(int reciterId, int chapterId) async {
    try {
      if (kIsWeb) {
        await BrowserFileStore.instance.initialize();
        return _normalizeTimings(BrowserFileStore.instance.manifests['audio:$reciterId:$chapterId:timings']?['timestamps']);
      }
      final file = await _audioFileForChapter(reciterId: reciterId, chapterId: chapterId);
      final metadata = File('${file.path}.timings.json');
      return await metadata.exists() ? _normalizeTimings(json.decode(await metadata.readAsString())) : const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Directory> _audioDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory =
        Directory('${root.path}${Platform.pathSeparator}quran_audio');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _audioFileForChapter({
    required int reciterId,
    required int chapterId,
  }) async {
    final directory = await _audioDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}r$reciterId'
      '_c$chapterId.mp3',
    );
  }

  List<QuranReciter> get _fallbackReciters => const [
        QuranReciter(id: 7, name: 'Mishary Rashid Alafasy', style: 'Murattal'),
        QuranReciter(id: 3, name: 'Abdur-Rahman as-Sudais', style: null),
        QuranReciter(id: 5, name: 'Maher Al-Muaiqly', style: null),
        QuranReciter(id: 2, name: 'AbdulBaset AbdulSamad', style: 'Murattal'),
      ];
}

class _QuranChapterAudio {
  const _QuranChapterAudio(this.url, this.timings);
  final String url;
  final List<Map<String, dynamic>> timings;
}
