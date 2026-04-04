class QuranChapterSummary {
  const QuranChapterSummary({
    required this.id,
    required this.nameSimple,
    required this.nameArabic,
    required this.translatedName,
    required this.revelationPlace,
    required this.versesCount,
    required this.pages,
  });

  factory QuranChapterSummary.fromJson(Map<String, dynamic> json) {
    return QuranChapterSummary(
      id: json['id'] as int,
      nameSimple: json['nameSimple'] as String,
      nameArabic: json['nameArabic'] as String,
      translatedName: json['translatedName'] as String,
      revelationPlace: json['revelationPlace'] as String,
      versesCount: json['versesCount'] as int,
      pages: (json['pages'] as List<dynamic>).cast<int>(),
    );
  }

  final int id;
  final String nameSimple;
  final String nameArabic;
  final String translatedName;
  final String revelationPlace;
  final int versesCount;
  final List<int> pages;
}
