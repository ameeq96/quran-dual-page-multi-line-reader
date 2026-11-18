import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final metadata = jsonEncode({
    'audio_file': {
      'audio_url': 'https://audio.example.com/one.mp3',
      'timestamps': <Object>[],
    }
  });
  late _Player player;
  late _Service service;
  setUp(() => player = _Player());
  tearDown(() => service.dispose());
  Future<void> load() => service.playChapter(
      reciterId: 7,
      chapterId: 1,
      chapterName: 'Al-Fatihah',
      reciterName: 'Test reciter');

  for (final action in ['pause', 'stop', 'reset']) {
    test('a late metadata response cannot auto-play after $action', () async {
      final requested = Completer<void>();
      final response = Completer<http.Response>();
      service = _Service(player, MockClient((_) {
        requested.complete();
        return response.future;
      }));
      final loading = load();
      await requested.future;
      if (action == 'pause') {
        await service.pause();
      } else if (action == 'stop') {
        await service.stop();
      } else {
        await service.resetPlayback();
      }
      response.complete(http.Response(metadata, 200));
      await loading;
      expect(player.plays, 0);
      expect(player.sourceLoads, 0);
      expect(service.loadedChapterId, isNull);
    });
  }

  test('a source already loading cannot auto-play after stop', () async {
    service =
        _Service(player, MockClient((_) async => http.Response(metadata, 200)));
    player.sourceGate = Completer<Duration?>();
    final loading = load();
    await player.sourceEntered.future;
    await service.stop();
    player.sourceGate!.complete(const Duration(minutes: 1));
    await loading;
    expect(player.sourceLoads, 1);
    expect(player.plays, 0);
    expect(service.loadedChapterId, isNull);
  });

  testWidgets('sleep expiry invalidates a pending metadata request',
      (tester) async {
    late Completer<http.Response> response;
    late Future<void> loading;
    await tester.runAsync(() async {
      final requested = Completer<void>();
      response = Completer<http.Response>();
      service = _Service(player, MockClient((_) {
        requested.complete();
        return response.future;
      }));
      loading = load();
      await requested.future;
    });
    service.practice.setSleepTimer(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      response.complete(http.Response(metadata, 200));
      await loading;
    });
    expect(player.plays, 0);
    expect(player.sourceLoads, 0);
    expect(player.pauses, greaterThan(0));
  });

  testWidgets(
      'manual resume cancels a repeat gap without cancelling valid practice starts',
      (tester) async {
    service =
        _Service(player, MockClient((_) async => http.Response(metadata, 200)));
    await tester.runAsync(load);
    await service.practice.begin(
        start: Duration.zero,
        end: const Duration(seconds: 4),
        repetitions: 3,
        gap: const Duration(seconds: 5));
    expect(service.practice.active, isTrue);
    expect(player.plays, 2);
    player.positions.add(const Duration(seconds: 4));
    await tester.pump();
    expect(service.practice.waiting, isTrue);
    await service.resume();
    final plays = player.plays;
    await tester.pump(const Duration(seconds: 10));
    expect(player.plays, plays);
    expect(service.practice.active, isFalse);
  });
}

class _Service extends QuranAudioService {
  _Service(AudioPlayer player, http.Client client)
      : super(player: player, client: client);
  @override
  Future<String?> localFilePathForChapter(
          {required int reciterId, required int chapterId}) async =>
      null;
}

class _Player implements AudioPlayer {
  final positions = StreamController<Duration>.broadcast(sync: true);
  final sourceEntered = Completer<void>();
  Completer<Duration?>? sourceGate;
  int plays = 0;
  int pauses = 0;
  int sourceLoads = 0;
  bool _playing = false;
  @override
  bool get playing => _playing;
  @override
  Duration? get duration => const Duration(minutes: 1);
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Future<Duration?> setAudioSource(AudioSource source,
      {bool preload = true,
      int? initialIndex,
      Duration? initialPosition}) async {
    sourceLoads++;
    sourceEntered.complete();
    return sourceGate == null ? const Duration(minutes: 1) : sourceGate!.future;
  }

  @override
  Future<void> pause() async {
    pauses++;
    _playing = false;
  }

  @override
  Future<void> stop() async {
    _playing = false;
  }

  @override
  Future<void> play() async {
    plays++;
    _playing = true;
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {}
  @override
  Future<void> setLoopMode(LoopMode mode) async {}
  @override
  Future<void> dispose() async {
    await positions.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
