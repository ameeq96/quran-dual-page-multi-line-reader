import '../../domain/models/quran_page_verse.dart';

QuranPageVerse? resolveReaderAudioVerse({
  required String? verseKey,
  required int? chapterId,
  required bool active,
  required Iterable<QuranPageVerse> verses,
}) {
  if (!active || verseKey == null || chapterId == null) return null;
  final match =
      RegExp(r'^([1-9][0-9]{0,2}):([1-9][0-9]{0,2})$').firstMatch(verseKey);
  if (match == null || int.parse(match[1]!) != chapterId || chapterId > 114) {
    return null;
  }
  final verseNumber = int.parse(match[2]!);
  QuranPageVerse? selected;
  for (final verse in verses) {
    if (verse.verseKey != verseKey) continue;
    if (selected != null ||
        verse.chapterId != chapterId ||
        verse.verseNumber != verseNumber) {
      return null;
    }
    selected = verse;
  }
  return selected;
}
