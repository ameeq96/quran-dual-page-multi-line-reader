class ReaderHistoryEntry {
  const ReaderHistoryEntry({
    required this.pageNumber,
    required this.viewedAtIso,
  });

  factory ReaderHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ReaderHistoryEntry(
      pageNumber: json['pageNumber'] as int,
      viewedAtIso: json['viewedAtIso'] as String,
    );
  }

  final int pageNumber;
  final String viewedAtIso;

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'viewedAtIso': viewedAtIso,
    };
  }
}
