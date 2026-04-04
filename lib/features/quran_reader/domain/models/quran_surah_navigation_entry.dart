class QuranSurahNavigationEntry {
  const QuranSurahNavigationEntry({
    required this.id,
    required this.nameSimple,
    required this.nameComplex,
    required this.nameArabic,
    required this.translatedName,
    required this.standardStartPage,
    required this.tajScanStartPage,
  });

  final int id;
  final String nameSimple;
  final String nameComplex;
  final String nameArabic;
  final String translatedName;
  final int standardStartPage;
  final int tajScanStartPage;

  QuranSurahNavigationEntry copyWith({
    int? id,
    String? nameSimple,
    String? nameComplex,
    String? nameArabic,
    String? translatedName,
    int? standardStartPage,
    int? tajScanStartPage,
  }) {
    return QuranSurahNavigationEntry(
      id: id ?? this.id,
      nameSimple: nameSimple ?? this.nameSimple,
      nameComplex: nameComplex ?? this.nameComplex,
      nameArabic: nameArabic ?? this.nameArabic,
      translatedName: translatedName ?? this.translatedName,
      standardStartPage: standardStartPage ?? this.standardStartPage,
      tajScanStartPage: tajScanStartPage ?? this.tajScanStartPage,
    );
  }
}
