import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/core/services/reader_recording_store.dart';

void main() {
  final valid = ReaderLocalRecording(
      id: 'a' * 22,
      profileId: 'default',
      createdAt: DateTime.utc(2026, 11, 8),
      durationMillis: 2500,
      bytes: 8,
      mimeType: 'audio/webm',
      label: 'My practice',
      reference: 'Al-Fatihah',
      chapterId: 1);
  test(
      'recording metadata round-trips without losing profile, reference or duration',
      () {
    final restored = ReaderLocalRecording.fromMap(valid.toMap())!;
    expect(restored.id, valid.id);
    expect(restored.profileId, 'default');
    expect(restored.reference, 'Al-Fatihah');
    expect(restored.chapterId, 1);
    expect(restored.durationMillis, 2500);
    expect(restored.createdAt.isUtc, isTrue);
  });
  test(
      'unsafe MIME, invalid reference and unbounded audio metadata are rejected',
      () {
    for (final change in [
      {'mimeType': 'text/html'},
      {'profileId': '../other'},
      {'bytes': 0},
      {'bytes': 8 * 1024 * 1024 + 1},
      {'durationMillis': 60001},
      {'chapterId': 115},
      {'label': 'a' * 121},
      {'createdAt': 'bad'},
    ]) {
      expect(
          ReaderLocalRecording.fromMap({...valid.toMap(), ...change}), isNull);
    }
  });
  test('storage limits can be reduced but cannot exceed hard safety bounds',
      () {
    expect(const ReaderRecordingLimits().valid, isTrue);
    expect(
        const ReaderRecordingLimits(count: 2, totalBytes: 20, singleBytes: 10)
            .valid,
        isTrue);
    expect(const ReaderRecordingLimits(count: 51).valid, isFalse);
    expect(const ReaderRecordingLimits(totalBytes: 1).valid, isFalse);
    expect(
        () => ReaderRecordingStore(profileId: '../other'), throwsArgumentError);
  });
}
