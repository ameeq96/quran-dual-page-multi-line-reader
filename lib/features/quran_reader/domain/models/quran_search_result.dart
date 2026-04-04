class QuranSearchResult {
  const QuranSearchResult({
    required this.pageNumber,
    required this.referencePageNumber,
    required this.title,
    required this.snippet,
    required this.category,
    this.verseKey,
  });

  final int pageNumber;
  final int referencePageNumber;
  final String title;
  final String snippet;
  final String category;
  final String? verseKey;
}
