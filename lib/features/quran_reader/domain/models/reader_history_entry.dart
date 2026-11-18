import 'reader_settings.dart';

class ReaderHistoryEntry {
  const ReaderHistoryEntry({
    required this.pageNumber,
    this.edition = MushafEdition.lines16,
    this.preferImageMode = true,
    required this.viewedAtIso,
  });

  factory ReaderHistoryEntry.fromJson(Map<String, dynamic> json, {
    MushafEdition? fallbackEdition,
    bool fallbackPreferImageMode = true,
  }) {
    return ReaderHistoryEntry(
      pageNumber: json['pageNumber'] as int,
      preferImageMode: json['preferImageMode'] as bool? ?? fallbackPreferImageMode,
      edition: MushafEditionX.fromStorageValue(
        json['edition'] as String? ?? fallbackEdition?.storageValue,
      ),
      viewedAtIso: json['viewedAtIso'] as String,
    );
  }

  final int pageNumber;
  final MushafEdition edition;
  final bool preferImageMode;
  final String viewedAtIso;

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'edition': edition.storageValue,
      'preferImageMode': preferImageMode,
      'viewedAtIso': viewedAtIso,
    };
  }
}
