class ReaderBookmark {
  const ReaderBookmark({
    required this.pageNumber,
    required this.label,
    required this.folder,
    required this.createdAtIso,
  });

  factory ReaderBookmark.fromJson(Map<String, dynamic> json) {
    return ReaderBookmark(
      pageNumber: json['pageNumber'] as int,
      label: json['label'] as String,
      folder: json['folder'] as String? ?? 'General',
      createdAtIso: json['createdAtIso'] as String,
    );
  }

  final int pageNumber;
  final String label;
  final String folder;
  final String createdAtIso;

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'label': label,
      'folder': folder,
      'createdAtIso': createdAtIso,
    };
  }
}
