import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/quran_study_models.dart';

class QuranStudyDataSource {
  QuranStudyDataSource({AssetBundle? bundle, http.Client? client})
      : _bundle = bundle ?? rootBundle, _client = client ?? http.Client();
  final AssetBundle _bundle;
  final http.Client _client;
  Future<void>? _initializing;
  Map<String, List<QuranStudyWord>> _words = {};
  final Map<String, Map<String, dynamic>> _verses = {};
  final Map<int, String> _chapters = {};
  Map<String, dynamic> _glosses = {};
  final Map<String, ({DateTime at, QuranStudyVerse verse})> _online = {};
  bool _disposed = false;

  static const corpusSource = 'https://corpus.quran.com';
  static const corpusNotice = 'Quranic Arabic Corpus (morphology v0.4), Copyright (C) 2011 Kais Dukes; GNU GPL with terms of use. Arabic text: Tanzil.info (Uthmani v1.0.2), Copyright (C) 2008-2009; CC BY-ND 3.0. The original data and copyright notices are bundled unchanged.';
  static const translationNotice = 'Verse translations: bundled Quran.com resources 84 (English) and 97 (Urdu).';

  int get verseCount => _words.length;
  Iterable<String> get references => _words.keys;
  List<String> get chapterLabels => List.generate(114, (i) => '${i + 1}. ${_chapters[i + 1] ?? ''}');

  Future<void> initialize() => _initializing ??= _initialize().catchError((Object error) {
    _initializing = null;
    throw error;
  });

  Future<void> _initialize() async {
    final payloads = await Future.wait([
      _bundle.loadString('assets/quran_pages/quranic-corpus-morphology-0.4.txt'),
      _bundle.loadString('assets/quran_pages/quran_page_insights.json'),
      _bundle.loadString('assets/quran_pages/quran_study_fatihah_glosses.json'),
    ]);
    final words = await compute(parseQuranStudyMorphology, payloads[0]);
    final insights = jsonDecode(payloads[1]) as Map<String, dynamic>;
    final glosses = jsonDecode(payloads[2]) as Map<String, dynamic>;
    if (_disposed) return;
    _words = words;
    _glosses = Map<String, dynamic>.from(glosses['verses'] as Map);
    for (final chapter in insights['chapters'] as List) {
      final value = chapter as Map;
      _chapters[value['id'] as int] = value['nameSimple'] as String;
    }
    for (final page in insights['pages'] as List) {
      for (final verse in (page as Map)['verses'] as List) {
        final value = Map<String, dynamic>.from(verse as Map);
        _verses[value['verseKey'] as String] = value;
      }
    }
  }

  QuranStudyVerse verse(String reference) {
    final key = reference.trim();
    final words = _words[key];
    final translation = _verses[key];
    if (words == null || translation == null) throw const FormatException('Enter a valid Surah:Ayah reference.');
    final cached = _online[key];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(hours: 1)) return cached.verse;
    _online.remove(key);
    final glosses = _glosses[key] as List?;
    return QuranStudyVerse(reference: key,
      chapterName: _chapters[translation['chapterId']] ?? '',
      english: _plain(translation['translationEn'] as String? ?? ''),
      urdu: _plain(translation['translationUr'] as String? ?? ''),
      words: List.unmodifiable(words.map((word) {
        if (glosses == null || glosses.length != words.length) return word;
        final gloss = glosses[word.position - 1] as List;
        return word.withGloss(gloss[0] as String, gloss[1] as String);
      })));
  }

  Future<QuranStudyVerse> loadOnlineMeanings(String reference, {bool urdu = false}) async {
    final local = verse(reference);
    final uri = Uri.https('api.quran.com', '/api/v4/verses/by_key/${local.reference}', {
      'words': 'true', 'word_fields': 'text_uthmani', 'language': urdu ? 'ur' : 'en',
    });
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 12), () { if (!abort.isCompleted) abort.complete(); });
    try {
      final request = http.AbortableRequest('GET', uri, abortTrigger: abort.future)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json';
      final response = await (() async => http.Response.fromStream(await _client.send(request)))()
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.length > 524288) throw const FormatException('Word meanings could not be loaded.');
      final payload = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final verse = payload['verse'] as Map;
      if (verse['verse_key'] != local.reference) throw const FormatException('Word meanings did not match this Ayah.');
      final words = (verse['words'] as List).where((value) => value is Map && value['char_type_name'] == 'word').toList();
      if (words.length != local.words.length) throw const FormatException('Word meanings did not match this Ayah.');
      final seen = <int>{};
      final updated = List<QuranStudyWord>.of(local.words);
      for (final value in words) {
        final word = value as Map;
        final position = word['position'];
        if (position is! int || position < 1 || position > updated.length || !seen.add(position)) {
          throw const FormatException('Word meanings did not match this Ayah.');
        }
        final arabic = word['text_uthmani'];
        if (arabic is! String || _normalize(arabic) != _normalize(local.words[position - 1].arabic)) {
          throw const FormatException('Word meanings did not match this Ayah.');
        }
        final meaning = (word['translation'] as Map?)?['text'];
        final transliteration = (word['transliteration'] as Map?)?['text'];
        updated[position - 1] = updated[position - 1].withGloss(
          meaning is String ? _plain(meaning) : null,
          transliteration is String ? _plain(transliteration) : null);
      }
      final result = QuranStudyVerse(reference: local.reference, chapterName: local.chapterName,
        english: local.english, urdu: local.urdu, words: List.unmodifiable(updated), onlineMeanings: true);
      // Regular Content API results stay in session memory; no persistent offline copy.
      // Long-term offline word glosses require the official Content Sync API.
      if (!_disposed) _online[local.reference] = (at: DateTime.now(), verse: result);
      return result;
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<String> licenses() async {
    final raw = await _bundle.loadString('assets/quran_pages/quranic-corpus-morphology-0.4.txt');
    final license = await _bundle.loadString('assets/quran_pages/quran-study-gpl-3.0.txt');
    return '${raw.substring(0, raw.indexOf('LOCATION\t'))}\n\n$license';
  }

  void dispose() { _disposed = true; _online.clear(); _client.close(); }
}

String _plain(String value) => value.replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');

String _normalize(String value) => value.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
    .replaceAll('ٱ', 'ا').replaceAll('آ', 'ا').replaceAll('أ', 'ا').replaceAll('إ', 'ا');

Map<String, List<QuranStudyWord>> parseQuranStudyMorphology(String payload) {
  final verses = <String, Map<int, _WordParts>>{};
  final row = RegExp(r'^\((\d+):(\d+):(\d+):(\d+)\)\t([^\t]*)\t([^\t]*)\t(.+)$');
  final root = RegExp(r'(?:^|\|)ROOT:([^|]+)');
  for (final line in const LineSplitter().convert(payload)) {
    if (!line.startsWith('(')) continue;
    final match = row.firstMatch(line);
    if (match == null) throw const FormatException('Invalid Quranic Corpus row.');
    final key = '${int.parse(match[1]!)}:${int.parse(match[2]!)}';
    final position = int.parse(match[3]!);
    final word = verses.putIfAbsent(key, () => {}).putIfAbsent(position, _WordParts.new);
    word.arabic.write(quranStudyBuckwalterToArabic(match[5]!));
    final features = match[7]!;
    if (features.startsWith('STEM')) word.tags.add(match[6]!);
    final found = root.firstMatch(features);
    if (found != null) word.roots.add(quranStudyBuckwalterToArabic(found[1]!));
  }
  return verses.map((key, words) {
    final positions = words.keys.toList()..sort();
    if (positions.isEmpty || positions.last != positions.length || positions.first != 1) {
      throw const FormatException('Invalid Quranic Corpus word order.');
    }
    return MapEntry(key, List.unmodifiable(positions.map((position) {
      final word = words[position]!;
      return QuranStudyWord(position: position, arabic: word.arabic.toString(),
        root: word.roots.isEmpty ? null : word.roots.join(' / '), partOfSpeech: word.tags.join(' + '));
    })));
  });
}

class _WordParts {
  final arabic = StringBuffer();
  final roots = <String>{};
  final tags = <String>{};
}

String quranStudyBuckwalterToArabic(String value) {
  // Reversible character mapping documented by the source, not pronunciation.
  // https://corpus.quran.com/java/buckwalter.jsp
  const map = <String, String>{
    "'": 'ء', '>': 'أ', '&': 'ؤ', '<': 'إ', '}': 'ئ', 'A': 'ا', 'b': 'ب', 'p': 'ة',
    't': 'ت', 'v': 'ث', 'j': 'ج', 'H': 'ح', 'x': 'خ', 'd': 'د', '*': 'ذ', 'r': 'ر',
    'z': 'ز', 's': 'س', r'$': 'ش', 'S': 'ص', 'D': 'ض', 'T': 'ط', 'Z': 'ظ', 'E': 'ع',
    'g': 'غ', '_': 'ـ', 'f': 'ف', 'q': 'ق', 'k': 'ك', 'l': 'ل', 'm': 'م', 'n': 'ن',
    'h': 'ه', 'w': 'و', 'Y': 'ى', 'y': 'ي', 'F': 'ً', 'N': 'ٌ', 'K': 'ٍ', 'a': 'َ',
    'u': 'ُ', 'i': 'ِ', '~': 'ّ', 'o': 'ْ', '^': 'ٓ', '#': 'ٔ', '`': 'ٰ', '{': 'ٱ',
    ':': 'ۜ', '@': '۟', '"': '۠', '[': 'ۢ', ';': 'ۣ', ',': 'ۥ', '.': 'ۦ', '!': 'ۨ',
    '-': '۪', '+': '۫', '%': '۬', ']': 'ۭ', ' ': ' ',
  };
  return value.split('').map((character) {
    final mapped = map[character];
    if (mapped == null) throw const FormatException('Unknown Quranic Corpus encoding.');
    return mapped;
  }).join();
}
