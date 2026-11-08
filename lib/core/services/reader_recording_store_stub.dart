import 'dart:typed_data';

import 'reader_recording_store.dart';

ReaderRecordingStore createRecordingStore(
        String profileId, ReaderRecordingLimits limits) =>
    _UnavailableRecordingStore(profileId, limits);

class _UnavailableRecordingStore extends ReaderRecordingStore {
  _UnavailableRecordingStore(String profileId, ReaderRecordingLimits limits)
      : super.base(profileId: profileId, limits: limits);
  @override
  bool get supported => false;
  @override
  bool get busy => false;
  @override
  List<ReaderLocalRecording> get recordings => const [];
  @override
  String? get playingId => null;
  @override
  int get comparisonIndex => 0;
  @override
  String? get errorMessage => 'The recording library is available in Chrome.';
  @override
  Future<void> refresh() async {}
  @override
  Future<ReaderLocalRecording> save(
          {required Uint8List bytes,
          required String mimeType,
          required Duration duration,
          String label = '',
          String reference = '',
          int? chapterId}) async =>
      throw const ReaderRecordingFailure(
          'The recording library is available in Chrome.');
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> play(String id) async {}
  @override
  Future<void> compare(String first, String second) async {}
  @override
  void stopPlayback() {}
}
