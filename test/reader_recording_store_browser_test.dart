@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/core/services/reader_recording_store.dart';

@JS('eval')
external JSAny? _evaluate(JSString code);
Object? _read(String code) => _evaluate(code.toJS)?.dartify();

void main() {
  const profileA = 'p_aaaaaaaaaaaaaaaaaaaaaaaa';
  const profileB = 'p_bbbbbbbbbbbbbbbbbbbbbbbb';
  late ReaderRecordingStore first;
  late ReaderRecordingStore second;
  final stores = <ReaderRecordingStore>[];
  const limits =
      ReaderRecordingLimits(count: 2, totalBytes: 16, singleBytes: 8);
  Future<ReaderLocalRecording> save(ReaderRecordingStore store, String label) =>
      store.save(
          bytes: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
          mimeType: 'audio/webm',
          duration: const Duration(seconds: 2),
          label: label,
          reference: 'Al-Fatihah',
          chapterId: 1);
  Future<void> waitFor(bool Function() done) async {
    final until = DateTime.now().add(const Duration(seconds: 3));
    while (!done() && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), isTrue);
  }

  setUp(() async {
    _evaluate(_fakePlayback.toJS);
    first = ReaderRecordingStore(profileId: profileA, limits: limits);
    second = ReaderRecordingStore(profileId: profileB, limits: limits);
    stores.addAll([first, second]);
    for (final store in [first, second]) {
      await store.refresh();
      for (final recording in store.recordings) {
        await store.delete(recording.id);
      }
    }
  });
  tearDown(() async {
    for (final store in [first, second]) {
      await store.refresh();
      for (final recording in store.recordings) {
        await store.delete(recording.id);
      }
    }
    for (final store in stores) {
      store.dispose();
    }
    stores.clear();
    _evaluate('window.__recordingPlayback.restore()'.toJS);
  });
  test('saved audio and metadata survive opening a new library instance',
      () async {
    final saved = await save(first, 'First practice');
    final reopened = ReaderRecordingStore(profileId: profileA, limits: limits);
    stores.add(reopened);
    await reopened.refresh();
    expect(reopened.recordings.single.id, saved.id);
    expect(reopened.recordings.single.reference, 'Al-Fatihah');
    expect(reopened.recordings.single.bytes, 8);
  });
  test('profiles cannot read or delete each other recordings', () async {
    final saved = await save(first, 'Private to A');
    await second.refresh();
    expect(second.recordings, isEmpty);
    await second.delete(saved.id);
    await first.refresh();
    expect(first.recordings.single.id, saved.id);
    await expectLater(
        second.play(saved.id), throwsA(isA<ReaderRecordingFailure>()));
  });
  test('quota rejection retains both clips and deletion makes space', () async {
    await save(first, 'One');
    await save(first, 'Two');
    final ids = first.recordings.map((entry) => entry.id).toSet();
    await expectLater(
        save(first, 'Three'), throwsA(isA<ReaderRecordingFailure>()));
    await first.refresh();
    expect(first.recordings.map((entry) => entry.id).toSet(), ids);
    await first.delete(ids.first);
    await save(first, 'Replacement');
    expect(first.recordings.length, 2);
  });
  test(
      'comparison plays exactly two selected clips sequentially and revokes URLs',
      () async {
    final a = await save(first, 'One');
    final b = await save(first, 'Two');
    await first.compare(a.id, b.id);
    expect(first.playingId, a.id);
    expect(first.comparisonIndex, 1);
    _evaluate('window.__recordingPlayback.finish(0)'.toJS);
    await waitFor(() => first.playingId == b.id);
    expect(first.comparisonIndex, 2);
    _evaluate('window.__recordingPlayback.finish(1)'.toJS);
    await waitFor(() => first.playingId == null);
    expect(_read('window.__recordingPlayback.plays'), 2);
    expect(_read('window.__recordingPlayback.revokes'), 2);
  });
  test('stop during an asynchronous playback lookup cannot restart audio',
      () async {
    final a = await save(first, 'One');
    final playing = first.play(a.id);
    first.stopPlayback();
    await playing;
    expect(first.playingId, isNull);
    expect(_read('window.__recordingPlayback.plays'), 0);
  });
}

const _fakePlayback = r'''
(() => {
  const OriginalAudio = window.Audio;
  const originalRevoke = URL.revokeObjectURL;
  const state = window.__recordingPlayback = {elements: [], plays: 0, revokes: 0,
    finish(index) { this.elements[index].dispatchEvent(new Event('ended')); },
    restore() { window.Audio = OriginalAudio; URL.revokeObjectURL = originalRevoke; delete window.__recordingPlayback; }
  };
  function TestAudio(src) {
    const audio = new OriginalAudio();
    Object.defineProperties(audio, {
      play: {value: () => { state.plays++; return Promise.resolve(); }},
      pause: {value: () => {}},
    });
    state.elements.push(audio);
    return audio;
  }
  TestAudio.prototype = OriginalAudio.prototype;
  window.Audio = TestAudio;
  URL.revokeObjectURL = url => { state.revokes++; originalRevoke.call(URL, url); };
})();
''';
