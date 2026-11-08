import 'package:flutter/foundation.dart';

import '../storage/reader_profile_store.dart';
import 'reader_recording_store_stub.dart'
    if (dart.library.html) 'reader_recording_store_web.dart' as platform;

class ReaderRecordingFailure implements Exception {
  const ReaderRecordingFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReaderRecordingLimits {
  const ReaderRecordingLimits(
      {this.count = 50,
      this.totalBytes = 100 * 1024 * 1024,
      this.singleBytes = 8 * 1024 * 1024});
  final int count;
  final int totalBytes;
  final int singleBytes;
  bool get valid =>
      count > 0 &&
      count <= 50 &&
      singleBytes > 0 &&
      singleBytes <= 8 * 1024 * 1024 &&
      totalBytes >= singleBytes &&
      totalBytes <= 100 * 1024 * 1024;
}

class ReaderLocalRecording {
  const ReaderLocalRecording(
      {required this.id,
      required this.profileId,
      required this.createdAt,
      required this.durationMillis,
      required this.bytes,
      required this.mimeType,
      this.label = '',
      this.reference = '',
      this.chapterId});
  final String id;
  final String profileId;
  final DateTime createdAt;
  final int durationMillis;
  final int bytes;
  final String mimeType;
  final String label;
  final String reference;
  final int? chapterId;

  static bool validId(String id) => RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(id);
  static bool validMime(String mime) =>
      RegExp(r'^audio/(webm|mp4|ogg|mpeg|wav)(?:;[A-Za-z0-9=, ._-]{1,60})?$')
          .hasMatch(mime);
  static ReaderLocalRecording? fromMap(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final profile = value['profileId'];
    final date = value['createdAt'];
    final duration = value['durationMillis'];
    final bytes = value['bytes'];
    final mime = value['mimeType'];
    final label = value['label'];
    final reference = value['reference'];
    final chapter = value['chapterId'];
    final parsed = date is String ? DateTime.tryParse(date) : null;
    if (id is! String ||
        !validId(id) ||
        profile is! String ||
        !ReaderProfileStore.validId(profile) ||
        parsed == null ||
        duration is! int ||
        duration < 0 ||
        duration > 60000 ||
        bytes is! int ||
        bytes <= 0 ||
        bytes > 8 * 1024 * 1024 ||
        mime is! String ||
        !validMime(mime) ||
        label is! String ||
        label.length > 120 ||
        reference is! String ||
        reference.length > 120 ||
        chapter != null && (chapter is! int || chapter < 1 || chapter > 114)) {
      return null;
    }
    return ReaderLocalRecording(
        id: id,
        profileId: profile,
        createdAt: parsed.toUtc(),
        durationMillis: duration,
        bytes: bytes,
        mimeType: mime,
        label: label,
        reference: reference,
        chapterId: chapter as int?);
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'profileId': profileId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'durationMillis': durationMillis,
        'bytes': bytes,
        'mimeType': mimeType,
        'label': label,
        'reference': reference,
        'chapterId': chapterId
      };
}

abstract class ReaderRecordingStore extends ChangeNotifier {
  ReaderRecordingStore.base({required this.profileId, required this.limits});
  factory ReaderRecordingStore(
      {String? profileId,
      ReaderRecordingLimits limits = const ReaderRecordingLimits()}) {
    final capturedProfile = profileId ?? ReaderProfileStore.instance.activeId;
    if (!ReaderProfileStore.validId(capturedProfile) || !limits.valid) {
      throw ArgumentError('Invalid recording profile or storage limits.');
    }
    return platform.createRecordingStore(capturedProfile, limits);
  }
  final String profileId;
  final ReaderRecordingLimits limits;
  bool get supported;
  bool get busy;
  List<ReaderLocalRecording> get recordings;
  String? get playingId;
  int get comparisonIndex;
  String? get errorMessage;
  Future<void> refresh();
  Future<ReaderLocalRecording> save(
      {required Uint8List bytes,
      required String mimeType,
      required Duration duration,
      String label = '',
      String reference = '',
      int? chapterId});
  Future<void> delete(String id);
  Future<void> play(String id);
  Future<void> compare(String first, String second);
  void stopPlayback();
}
