import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/core/services/reader_recording_store.dart';
import 'package:my_flutter_app/core/services/reader_voice_capture.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_recording_library.dart';

void main() {
  testWidgets(
      'cancelling and then saving keeps dialog controllers alive through route animations',
      (tester) async {
    final capture = _Capture();
    final store = _Store();
    addTearDown(capture.dispose);
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ReaderRecordingSaveControls(
      capture: capture,
      store: store,
      profileId: 'default',
      chapterId: 1,
      chapterName: 'Al-Fatihah',
    ))));
    await tester.tap(find.text('Save recording'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'First attempt');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.saved, isEmpty);
    await tester.tap(find.text('Save recording'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Daily practice');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(store.saved.single.label, 'Daily practice');
    expect(store.saved.single.reference, 'Al-Fatihah');
    expect(store.saved.single.chapterId, 1);
    expect(find.text('Recording saved to this profile.'), findsOneWidget);
  });
}

class _Capture extends ReaderVoiceCapture {
  _Capture() : super.base();
  @override
  bool get supported => true;
  @override
  bool get speechSupported => false;
  @override
  ReaderVoiceCapturePhase get phase => ReaderVoiceCapturePhase.ready;
  @override
  bool get isTranscribing => false;
  @override
  String get transcript => '';
  @override
  Duration get elapsed => const Duration(seconds: 2);
  @override
  String? get errorMessage => null;
  @override
  bool get hasRecording => true;
  @override
  bool get isPlaying => false;
  @override
  String get recordingMimeType => 'audio/webm';
  @override
  Future<Uint8List> readRecordingBytes() async => Uint8List.fromList([1, 2, 3]);
  @override
  Future<void> start(
      {String language = 'ar-SA', bool transcribe = false}) async {}
  @override
  Future<void> stop() async {}
  @override
  void cancel() {}
  @override
  Future<void> togglePlayback() async {}
  @override
  void download() {}
}

class _Store extends ReaderRecordingStore {
  _Store()
      : super.base(profileId: 'default', limits: const ReaderRecordingLimits());
  final saved = <ReaderLocalRecording>[];
  @override
  bool get supported => true;
  @override
  bool get busy => false;
  @override
  List<ReaderLocalRecording> get recordings => saved;
  @override
  String? get playingId => null;
  @override
  int get comparisonIndex => 0;
  @override
  String? get errorMessage => null;
  @override
  Future<void> refresh() async {}
  @override
  Future<ReaderLocalRecording> save(
      {required Uint8List bytes,
      required String mimeType,
      required Duration duration,
      String label = '',
      String reference = '',
      int? chapterId}) async {
    final value = ReaderLocalRecording(
        id: 'a' * 22,
        profileId: profileId,
        createdAt: DateTime.now().toUtc(),
        durationMillis: duration.inMilliseconds,
        bytes: bytes.length,
        mimeType: mimeType,
        label: label,
        reference: reference,
        chapterId: chapterId);
    saved.add(value);
    return value;
  }

  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> play(String id) async {}
  @override
  Future<void> compare(String first, String second) async {}
  @override
  void stopPlayback() {}
}
