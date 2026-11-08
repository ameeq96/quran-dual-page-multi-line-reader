import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_flutter_app/core/services/quran_study_export.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_study_data_source.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_study_models.dart';

class _StudyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

Future<QuranStudyDataSource> _source({http.Client? client}) async {
  final source = QuranStudyDataSource(bundle: _StudyBundle(), client: client ?? MockClient((_) async => throw StateError('Unexpected network request')));
  await source.initialize();
  return source;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full unmodified Corpus covers every Ayah, preserves word order and does not infer roots', () async {
    final raw = await File('assets/quran_pages/quranic-corpus-morphology-0.4.txt').readAsString();
    expect(raw, contains('Copyright (C) 2011 Kais Dukes'));
    expect(raw, contains('Copyright (C) 2008-2009 Tanzil.info'));
    final source = await _source();
    addTearDown(source.dispose);
    expect(source.verseCount, 6236);
    final first = source.verse('1:1');
    expect(first.words.length, 4);
    expect(first.words.first.arabic, 'بِسْمِ');
    expect(first.words.first.root, 'سمو');
    expect(first.words[2].root, 'رحم');
    expect(first.words.first.meaning, 'In (the) name');
    expect(first.words.first.transliteration, "bis'mi");
    expect(source.verse('1:5').words.first.root, null);
    expect(source.verse('114:6').words.length, 3);
    expect(source.verse('2:201').words.every((word) => word.meaning == null), true);
    expect(source.verse('2:201').english, isNotEmpty);
    expect(source.verse('2:201').urdu, isNotEmpty);
    expect(() => source.verse('115:1'), throwsFormatException);
    expect(() => source.verse('2:287'), throwsFormatException);
  });

  test('all curated dua and topic references exist and every collection exports complete Ayahs', () async {
    final source = await _source();
    addTearDown(source.dispose);
    expect(quranStudyCollections.length, 20);
    expect(quranStudyCollections.map((value) => value.id).toSet().length, 20);
    for (final collection in quranStudyCollections) {
      expect(collection.references, isNotEmpty);
      expect(collection.references.toSet().length, collection.references.length);
      for (final key in collection.references) {
        final verse = source.verse(key);
        expect(verse.reference, key);
        expect(verse.words, isNotEmpty);
        expect(verse.english, isNotEmpty);
        expect(verse.urdu, isNotEmpty);
      }
    }
  });

  test('documented Buckwalter mapping is reversible character decoding, not guessed pronunciation', () {
    expect(quranStudyBuckwalterToArabic('bisomi'), 'بِسْمِ');
    expect(quranStudyBuckwalterToArabic('{l'), 'ٱل');
    expect(quranStudyBuckwalterToArabic(':@"[;,.!-+%]'), 'ۣۜ۟۠ۢۥۦ۪ۭۨ۫۬');
    expect(() => quranStudyBuckwalterToArabic('?'), throwsFormatException);
    expect(() => parseQuranStudyMorphology('(1:1:2:1)\tbi\tP\tSTEM|POS:P'), throwsFormatException);
  });

  test('online glosses must match the requested reference, positions and Arabic before session use', () async {
    late QuranStudyDataSource source;
    final client = MockClient((request) async {
      expect(request.followRedirects, false);
      expect(request.url.scheme, 'https');
      expect(request.url.host, 'api.quran.com');
      expect(request.url.queryParameters['language'], 'en');
      final local = source.verse('1:1');
      return http.Response(jsonEncode({'verse': {'verse_key': '1:1', 'words': local.words.map((word) => {
        'position': word.position, 'char_type_name': 'word', 'text_uthmani': word.arabic,
        'translation': {'text': 'meaning-${word.position}'}, 'transliteration': {'text': 'sound-${word.position}'},
      }).toList()}}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    source = await _source(client: client);
    addTearDown(source.dispose);
    final verse = await source.loadOnlineMeanings('1:1');
    expect(verse.onlineMeanings, true);
    expect(verse.words.first.meaning, 'meaning-1');
    expect(verse.words.first.root, 'سمو');
    expect(source.verse('1:1').words.first.meaning, 'meaning-1');
  });

  test('mismatched online content cannot replace local Arabic, roots or offline meanings', () async {
    for (final invalid in ['reference', 'word-count', 'arabic', 'position']) {
      late QuranStudyDataSource source;
      source = await _source(client: MockClient((_) async {
        final words = source.verse('1:1').words.map((word) => <String, dynamic>{
          'position': word.position, 'char_type_name': 'word', 'text_uthmani': word.arabic,
          'translation': {'text': 'wrong'}, 'transliteration': {'text': 'wrong'},
        }).toList();
        if (invalid == 'word-count') words.removeLast();
        if (invalid == 'arabic') words[0]['text_uthmani'] = 'اختبار';
        if (invalid == 'position') words[0]['position'] = 2;
        return http.Response(jsonEncode({'verse': {'verse_key': invalid == 'reference' ? '2:1' : '1:1', 'words': words}}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      await expectLater(source.loadOnlineMeanings('1:1'), throwsFormatException);
      expect(source.verse('1:1').words.first.meaning, 'In (the) name');
      expect(source.verse('1:1').words.first.root, 'سمو');
      source.dispose();
    }
  });

  test('PDF keeps every image page, exact RGB stream, dimensions and valid byte offsets', () {
    QuranStudyCard card(List<int> rgb) => QuranStudyCard(png: Uint8List(0), rgb: Uint8List.fromList(rgb), width: 2, height: 1);
    final pixels = [255, 0, 0, 0, 255, 0];
    final pdf = QuranStudyExport.pdf([card(pixels), card(pixels.reversed.toList())]);
    final text = latin1.decode(pdf);
    expect(text, startsWith('%PDF-1.4'));
    expect(text, contains('/Count 2 /Kids [5 0 R 8 0 R]'));
    expect(RegExp(r'/Type /Page /Parent').allMatches(text).length, 2);
    final xref = int.parse(RegExp(r'startxref\n(\d+)\n%%EOF').firstMatch(text)![1]!);
    expect(text.substring(xref), startsWith('xref\n0 9\n'));
    final entries = text.substring(xref).split('\n').skip(3).take(8).toList();
    for (var index = 0; index < entries.length; index++) {
      final offset = int.parse(entries[index].substring(0, 10));
      expect(text.substring(offset), startsWith('${index + 1} 0 obj'));
    }
    final image = text.indexOf('/Subtype /Image');
    final streamStart = text.indexOf('stream\n', image) + 7;
    final length = int.parse(RegExp(r'/Length (\d+)').firstMatch(text.substring(image))![1]!);
    expect(const ZLibDecoder().decodeBytes(pdf.sublist(streamStart, streamStart + length)), pixels);
    expect(() => QuranStudyExport.pdf([]), throwsFormatException);
    expect(() => QuranStudyExport.pdf([QuranStudyCard(png: Uint8List(0), rgb: Uint8List(1), width: 2, height: 1)]), throwsFormatException);
  });

  testWidgets('longest Ayah renders a complete PNG and a full-height PDF without clipping', (tester) async {
    final source = await tester.runAsync(_source);
    expect(source, isNotNull);
    addTearDown(source!.dispose);
    final card = await tester.runAsync(() => QuranStudyExport.render(source.verse('2:282'), urdu: true,
      notes: 'Personal revision note. Keep this separate from the Quran text.'));
    expect(card, isNotNull);
    expect(card!.width, 1080);
    expect(card.height, lessThanOrEqualTo(8192));
    expect(card.png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    final dimensions = ByteData.sublistView(card.png);
    expect(dimensions.getUint32(16), card.width);
    expect(dimensions.getUint32(20), card.height);
    final pdf = QuranStudyExport.pdf([card]);
    final text = latin1.decode(pdf);
    expect(text, contains('/Width 1080 /Height ${card.height}'));
    final pageHeight = double.parse(RegExp(r'/MediaBox \[0 0 595.28 ([0-9.]+)\]').firstMatch(text)![1]!);
    expect(pageHeight, greaterThanOrEqualTo(card.height * 595.28 / card.width));
    await expectLater(QuranStudyExport.render(source.verse('2:282'), notes: 'x' * 2001), throwsFormatException);
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(card.png);
      final frame = await codec.getNextFrame();
      expect(frame.image.height, card.height);
      frame.image.dispose(); codec.dispose();
    });
  });
}
