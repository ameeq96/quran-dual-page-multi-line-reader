import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_audio_verse_lookup.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_page_insight.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_page_verse.dart';
import 'package:my_flutter_app/features/quran_reader/presentation/widgets/reader_audio_sheet.dart';

void main() {
  late List<QuranPageVerse> verses;

  setUpAll(() {
    final payload = jsonDecode(
      File('assets/quran_pages/quran_page_insights.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    verses = (payload['pages'] as List<dynamic>)
        .map((page) => QuranPageInsight.fromJson(page as Map<String, dynamic>))
        .expand((page) => page.verses)
        .toList(growable: false);
  });

  test('resolves the first and last verified Ayah with their own translations',
      () {
    final first = resolveReaderAudioVerse(
      verseKey: '1:1',
      chapterId: 1,
      active: true,
      verses: verses,
    );
    final last = resolveReaderAudioVerse(
      verseKey: '114:6',
      chapterId: 114,
      active: true,
      verses: verses,
    );
    expect(verses.length, 6236);
    expect(first?.verseKey, '1:1');
    expect(last?.verseKey, '114:6');
    expect(first!.translationEn, isNotEmpty);
    expect(first.translationUr, isNotEmpty);
    expect(last!.translationEn, isNotEmpty);
    expect(last.translationUr, isNotEmpty);
    expect(first.translationEn, isNot(last.translationEn));
  });

  test('does not substitute a neighbouring Ayah or a different Surah', () {
    for (final key in [
      '1:0',
      '1:8',
      '114:7',
      '115:1',
      '01:1',
      '1:01',
      '1:1 '
    ]) {
      expect(
          resolveReaderAudioVerse(
            verseKey: key,
            chapterId: 1,
            active: true,
            verses: verses,
          ),
          isNull,
          reason: key);
    }
    expect(
        resolveReaderAudioVerse(
          verseKey: '114:6',
          chapterId: 1,
          active: true,
          verses: verses,
        ),
        isNull);
    expect(
        resolveReaderAudioVerse(
          verseKey: null,
          chapterId: 1,
          active: true,
          verses: verses,
        ),
        isNull);
  });

  test('paused, disabled or unavailable timing cannot produce an active Ayah',
      () {
    expect(
        resolveReaderAudioVerse(
          verseKey: '1:1',
          chapterId: 1,
          active: false,
          verses: verses,
        ),
        isNull);
    expect(
        resolveReaderAudioVerse(
          verseKey: '1:1',
          chapterId: null,
          active: true,
          verses: verses,
        ),
        isNull);
  });

  test('conflicting or duplicated verse metadata is rejected', () {
    final first = verses.firstWhere((verse) => verse.verseKey == '1:1');
    expect(
        resolveReaderAudioVerse(
          verseKey: '1:1',
          chapterId: 1,
          active: true,
          verses: [first, first],
        ),
        isNull);
    expect(
        resolveReaderAudioVerse(
          verseKey: '1:1',
          chapterId: 1,
          active: true,
          verses: [
            const QuranPageVerse(
              verseKey: '1:1',
              chapterId: 2,
              verseNumber: 1,
              juzNumber: 1,
              hizbNumber: 1,
              rubElHizbNumber: 1,
              rukuNumber: 1,
              manzilNumber: 1,
              sajdahNumber: null,
              translationEn: 'Wrong chapter',
              translationUr: '',
            )
          ],
        ),
        isNull);
  });

  testWidgets('shows the audio reference and preserves translation directions',
      (tester) async {
    final verse = resolveReaderAudioVerse(
      verseKey: '114:6',
      chapterId: 114,
      active: true,
      verses: verses,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
        child: ReaderAudioVersePanel(verse: verse),
      )),
    ));
    expect(find.text('Audio Ayah'), findsOneWidget);
    expect(find.text('114:6'), findsOneWidget);
    final english = tester
        .widget<SelectableText>(find.byKey(const ValueKey('audio-ayah-en')));
    final urdu = tester
        .widget<SelectableText>(find.byKey(const ValueKey('audio-ayah-ur')));
    expect(english.data, verse!.translationEn);
    expect(english.textDirection, TextDirection.ltr);
    expect(urdu.data, verse.translationUr);
    expect(urdu.textDirection, TextDirection.rtl);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ReaderAudioVersePanel(verse: null)),
    ));
    expect(find.text('Audio Ayah'), findsNothing);
    expect(find.byKey(const ValueKey('audio-ayah-en')), findsNothing);
  });
}
