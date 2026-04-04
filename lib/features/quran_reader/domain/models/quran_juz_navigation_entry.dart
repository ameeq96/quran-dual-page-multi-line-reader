class QuranJuzNavigationEntry {
  const QuranJuzNavigationEntry({
    required this.number,
    required this.name,
    required this.nameArabic,
    required this.standardStartPage,
    required this.tajScanStartPage,
  });

  final int number;
  final String name;
  final String nameArabic;
  final int standardStartPage;
  final int tajScanStartPage;

  QuranJuzNavigationEntry copyWith({
    int? number,
    String? name,
    String? nameArabic,
    int? standardStartPage,
    int? tajScanStartPage,
  }) {
    return QuranJuzNavigationEntry(
      number: number ?? this.number,
      name: name ?? this.name,
      nameArabic: nameArabic ?? this.nameArabic,
      standardStartPage: standardStartPage ?? this.standardStartPage,
      tajScanStartPage: tajScanStartPage ?? this.tajScanStartPage,
    );
  }
}
