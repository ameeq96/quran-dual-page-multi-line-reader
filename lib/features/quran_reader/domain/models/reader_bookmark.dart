import 'reader_settings.dart';

class ReaderBookmark {
  const ReaderBookmark({
    required this.pageNumber,
    this.edition = MushafEdition.lines16,
    this.preferImageMode = true,
    required this.label,
    required this.folder,
    required this.createdAtIso,
  });

  factory ReaderBookmark.fromJson(Map<String, dynamic> json, {
    MushafEdition? fallbackEdition,
    bool fallbackPreferImageMode = true,
  }) {
    return ReaderBookmark(
      pageNumber: json['pageNumber'] as int,
      preferImageMode: json['preferImageMode'] as bool? ?? fallbackPreferImageMode,
      edition: MushafEditionX.fromStorageValue(
        json['edition'] as String? ?? fallbackEdition?.storageValue,
      ),
      label: json['label'] as String,
      folder: json['folder'] as String? ?? 'General',
      createdAtIso: json['createdAtIso'] as String,
    );
  }

  final int pageNumber;
  final MushafEdition edition;
  final bool preferImageMode;
  final String label;
  final String folder;
  final String createdAtIso;

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'edition': edition.storageValue,
      'preferImageMode': preferImageMode,
      'label': label,
      'folder': folder,
      'createdAtIso': createdAtIso,
    };
  }
}
