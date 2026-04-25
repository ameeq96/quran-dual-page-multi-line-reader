import 'quran_page_verse.dart';

class QuranPageInsight {
  const QuranPageInsight({
    required this.pageNumber,
    required this.chapterIds,
    required this.juzNumbers,
    required this.hizbNumbers,
    required this.rubElHizbNumbers,
    required this.rukuNumbers,
    required this.manzilNumbers,
    required this.sajdahVerseKeys,
    required this.translationEn,
    required this.translationUr,
    required this.verses,
  });

  factory QuranPageInsight.fromJson(Map<String, dynamic> json) {
    return QuranPageInsight(
      pageNumber: json['pageNumber'] as int,
      chapterIds: (json['chapterIds'] as List<dynamic>).cast<int>(),
      juzNumbers: (json['juzNumbers'] as List<dynamic>).cast<int>(),
      hizbNumbers: (json['hizbNumbers'] as List<dynamic>).cast<int>(),
      rubElHizbNumbers: (json['rubElHizbNumbers'] as List<dynamic>).cast<int>(),
      rukuNumbers: (json['rukuNumbers'] as List<dynamic>).cast<int>(),
      manzilNumbers: (json['manzilNumbers'] as List<dynamic>).cast<int>(),
      sajdahVerseKeys:
          (json['sajdahVerseKeys'] as List<dynamic>).cast<String>(),
      translationEn: json['translationEn'] as String? ?? '',
      translationUr: json['translationUr'] as String? ?? '',
      verses: (json['verses'] as List<dynamic>)
          .map(
              (entry) => QuranPageVerse.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final int pageNumber;
  final List<int> chapterIds;
  final List<int> juzNumbers;
  final List<int> hizbNumbers;
  final List<int> rubElHizbNumbers;
  final List<int> rukuNumbers;
  final List<int> manzilNumbers;
  final List<String> sajdahVerseKeys;
  final String translationEn;
  final String translationUr;
  final List<QuranPageVerse> verses;

  int? get primaryChapterId {
    for (final verse in verses) {
      if (verse.verseNumber == 1) {
        return verse.chapterId;
      }
    }
    return chapterIds.isEmpty ? null : chapterIds.first;
  }

  bool get hasSajdah => sajdahVerseKeys.isNotEmpty;
}
