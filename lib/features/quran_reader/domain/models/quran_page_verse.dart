class QuranPageVerse {
  const QuranPageVerse({
    required this.verseKey,
    required this.chapterId,
    required this.verseNumber,
    required this.juzNumber,
    required this.hizbNumber,
    required this.rubElHizbNumber,
    required this.rukuNumber,
    required this.manzilNumber,
    required this.sajdahNumber,
    required this.translationEn,
    required this.translationUr,
  });

  factory QuranPageVerse.fromJson(Map<String, dynamic> json) {
    return QuranPageVerse(
      verseKey: json['verseKey'] as String,
      chapterId: json['chapterId'] as int,
      verseNumber: json['verseNumber'] as int,
      juzNumber: json['juzNumber'] as int,
      hizbNumber: json['hizbNumber'] as int,
      rubElHizbNumber: json['rubElHizbNumber'] as int,
      rukuNumber: json['rukuNumber'] as int,
      manzilNumber: json['manzilNumber'] as int,
      sajdahNumber: json['sajdahNumber'] as int?,
      translationEn: json['translationEn'] as String? ?? '',
      translationUr: json['translationUr'] as String? ?? '',
    );
  }

  final String verseKey;
  final int chapterId;
  final int verseNumber;
  final int juzNumber;
  final int hizbNumber;
  final int rubElHizbNumber;
  final int rukuNumber;
  final int manzilNumber;
  final int? sajdahNumber;
  final String translationEn;
  final String translationUr;
}
