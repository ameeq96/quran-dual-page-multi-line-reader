import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/quran_reciter.dart';

class QuranAudioService {
  QuranAudioService({
    AudioPlayer? player,
    http.Client? client,
  })  : _player = player ?? AudioPlayer(),
        _client = client ?? http.Client();

  final AudioPlayer _player;
  final http.Client _client;
  List<QuranReciter>? _recitersCache;
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
          Uri.parse('https://api.quran.com/api/v4/resources/recitations');
      final response =
          await _client.get(uri, headers: _headers).timeout(_networkTimeout);
      if (response.statusCode != 200) {
        _recitersCache = _fallbackReciters;
        return _recitersCache!;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final recitations = payload['recitations'] as List<dynamic>? ?? const [];
      final reciters = recitations
          .map((entry) => QuranReciter.fromJson(entry as Map<String, dynamic>))
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
    final localFilePath = await localFilePathForChapter(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    final sourceUri = localFilePath == null
        ? Uri.parse(
            await _resolveAudioUrl(reciterId: reciterId, chapterId: chapterId))
        : Uri.file(localFilePath);
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
    await _player.play();
  }

  Future<void> downloadChapter({
    required int reciterId,
    required int chapterId,
  }) async {
    final audioUrl = await _resolveAudioUrl(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    final response = await _client
        .get(Uri.parse(audioUrl), headers: _headers)
        .timeout(_networkTimeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw StateError('Unable to download recitation audio right now.');
    }

    final outputFile = await _audioFileForChapter(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(response.bodyBytes, flush: true);
  }

  Future<void> deleteChapterDownload({
    required int reciterId,
    required int chapterId,
  }) async {
    final file = await _audioFileForChapter(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String?> localFilePathForChapter({
    required int reciterId,
    required int chapterId,
  }) async {
    final file = await _audioFileForChapter(
      reciterId: reciterId,
      chapterId: chapterId,
    );
    if (await file.exists()) {
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
    final directory = await _audioDirectory();
    if (!await directory.exists()) {
      return <String>{};
    }

    final files = directory.listSync();
    final keys = <String>{};
    for (final entity in files) {
      if (entity is! File) {
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

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.play();

  Future<void> stop() => _player.stop();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setRepeatEnabled(bool enabled) {
    return _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);
  }

  void dispose() {
    _client.close();
    _player.dispose();
  }

  Future<String> _resolveAudioUrl({
    required int reciterId,
    required int chapterId,
  }) async {
    final uri = Uri.parse(
      'https://api.quran.com/api/v4/chapter_recitations/$reciterId/$chapterId',
    );
    final response =
        await _client.get(uri, headers: _headers).timeout(_networkTimeout);
    if (response.statusCode != 200) {
      throw StateError('Unable to load recitation for chapter $chapterId.');
    }

    final payload = json.decode(response.body) as Map<String, dynamic>;
    final audioFile = payload['audio_file'] as Map<String, dynamic>?;
    final audioUrl = audioFile?['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) {
      throw StateError('Recitation audio is unavailable.');
    }
    return audioUrl;
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
