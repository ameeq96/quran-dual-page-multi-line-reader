import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_audio_practice.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_audio_practice_panel.dart';

void main() {
  late _Playback playback;

  testWidgets('repeats exactly three sections and honours the recitation gap',
      (tester) async {
    playback = _Playback();
    addTearDown(playback.dispose);
    await playback.practice.begin(
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 5),
        repetitions: 3,
        gap: const Duration(seconds: 2));
    expect(playback.plays, 1);
    for (var cycle = 1; cycle <= 3; cycle++) {
      playback.positions.add(const Duration(seconds: 5));
      playback.positions.add(const Duration(seconds: 6));
      await tester.pump();
      expect(playback.practice.completed, cycle);
      expect(playback.playing, isFalse);
      if (cycle < 3) {
        await tester.pump(const Duration(seconds: 1));
        expect(playback.plays, cycle);
        await tester.pump(const Duration(seconds: 1));
        expect(playback.plays, cycle + 1);
      }
    }
    expect(playback.practice.active, isFalse);
    expect(playback.seeks, List.filled(3, const Duration(seconds: 2)));
    await tester.pump(const Duration(minutes: 1));
    expect(playback.plays, 3);
  });

  testWidgets('cancel during a gap cannot resume later', (tester) async {
    playback = _Playback();
    addTearDown(playback.dispose);
    await playback.practice.begin(
        start: Duration.zero,
        end: const Duration(seconds: 4),
        repetitions: 5,
        gap: const Duration(seconds: 5));
    playback.positions.add(const Duration(seconds: 4));
    await tester.pump();
    expect(playback.practice.waiting, isTrue);
    await playback.practice.cancel();
    await tester.pump(const Duration(seconds: 10));
    expect(playback.plays, 1);
    expect(playback.practice.active, isFalse);
  });

  testWidgets('a cancelled pending seek cannot play an obsolete source',
      (tester) async {
    playback = _Playback();
    addTearDown(playback.dispose);
    playback.seekGate = Completer<void>();
    final starting = playback.practice.begin(
        start: Duration.zero, end: const Duration(seconds: 4), repetitions: 10);
    await tester.pump();
    final cancelling = playback.practice.cancel();
    playback.source = 'new-source';
    playback.seekGate!.complete();
    await starting;
    await cancelling;
    expect(playback.plays, 0);
    expect(playback.practice.active, isFalse);
  });

  testWidgets('sleep expiry cancels a repeat gap and pauses once',
      (tester) async {
    playback = _Playback();
    addTearDown(playback.dispose);
    await playback.practice.begin(
        start: Duration.zero,
        end: const Duration(seconds: 4),
        repetitions: 10,
        gap: const Duration(seconds: 10));
    playback.positions.add(const Duration(seconds: 4));
    await tester.pump();
    playback.practice.setSleepTimer(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(playback.practice.sleepUntil, isNull);
    expect(playback.practice.active, isFalse);
    final pauses = playback.pauses;
    await tester.pump(const Duration(seconds: 20));
    expect(playback.plays, 1);
    expect(playback.pauses, pauses);
  });

  testWidgets('replacing and cancelling sleep timers prevents stale pauses',
      (tester) async {
    playback = _Playback();
    addTearDown(playback.dispose);
    playback.practice.setSleepTimer(const Duration(seconds: 1));
    playback.practice.setSleepTimer(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(playback.pauses, 0);
    playback.practice.setSleepTimer(null);
    await tester.pump(const Duration(seconds: 10));
    expect(playback.pauses, 0);
  });

  test('invalid ranges and unsupported counts leave playback untouched',
      () async {
    playback = _Playback();
    addTearDown(playback.dispose);
    for (final range in [
      (const Duration(seconds: 4), const Duration(seconds: 4), 3),
      (const Duration(seconds: -1), const Duration(seconds: 4), 3),
      (Duration.zero, const Duration(minutes: 2), 3),
      (Duration.zero, const Duration(seconds: 4), 4),
    ]) {
      await expectLater(
          playback.practice
              .begin(start: range.$1, end: range.$2, repetitions: range.$3),
          throwsFormatException);
    }
    expect(playback.pauses, 0);
    expect(playback.plays, 0);
  });

  test('timestamps preserve exact Ayah milliseconds and reject malformed input',
      () {
    for (final duration in [
      Duration.zero,
      const Duration(milliseconds: 1234),
      const Duration(minutes: 72, seconds: 5)
    ]) {
      expect(parseReaderAudioTime(formatReaderAudioTime(duration)), duration);
    }
    expect(parseReaderAudioTime('1:02:03.04'),
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 40));
    for (final value in [
      'abc',
      '-1:00',
      '1:99',
      '1:00:99',
      '00:1',
      '00:00.1234'
    ]) {
      expect(parseReaderAudioTime(value), isNull);
    }
  });
}

class _Playback {
  _Playback() {
    practice = ReaderAudioPractice(
        positions: positions.stream,
        duration: () => const Duration(minutes: 1),
        source: () => source,
        playing: () => playing,
        pause: () async {
          pauses++;
          playing = false;
        },
        seek: (position) async {
          seeks.add(position);
          await seekGate?.future;
        },
        play: () {
          plays++;
          playing = true;
        },
        loop: (enabled) async {},
        repeatChapter: () => true);
  }
  final positions = StreamController<Duration>.broadcast(sync: true);
  late final ReaderAudioPractice practice;
  String source = 'chapter-one';
  bool playing = false;
  int plays = 0;
  int pauses = 0;
  final seeks = <Duration>[];
  Completer<void>? seekGate;
  void dispose() {
    practice.dispose();
    positions.close();
  }
}
