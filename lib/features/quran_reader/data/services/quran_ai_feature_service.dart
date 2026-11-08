import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/quran_search_result.dart';
import '../../domain/models/quran_study_models.dart';
import 'quran_study_data_source.dart';
import 'quran_navigation_data_source.dart';

class QuranAiFeatureService {
  QuranAiFeatureService();

  Future<Map<String, _AiSearchVerse>>? _searchIndexFuture;
  List<_AiSearchChapter> _searchChapters = const [];

  Future<Map<String, _AiSearchVerse>> _searchIndex() => _searchIndexFuture ??=
      _loadSearchIndex().catchError((Object error) {
        _searchIndexFuture = null;
        throw error;
      });

  Future<Map<String, _AiSearchVerse>> _loadSearchIndex() async {
    final source = QuranStudyDataSource();
    try {
      await source.initialize();
      if (source.verseCount != 6236) {
        throw StateError('The verified Quran search corpus is incomplete.');
      }
      final navigation = QuranNavigationDataSource();
      await navigation.initialize();
      final payload = jsonDecode(await rootBundle.loadString(
        'assets/quran_pages/quran_page_insights.json')) as Map<String, dynamic>;
      final metadata = {for (final chapter in payload['chapters'] as List)
        (chapter as Map)['id'] as int: chapter};
      if (navigation.surahs.length != 114 || metadata.length != 114) {
        throw StateError('The verified Surah catalogue is incomplete.');
      }
      final locations = <String, ({int page, Set<int> juz})>{};
      for (final page in payload['pages'] as List) {
        for (final verse in page['verses'] as List) {
          locations[verse['verseKey'] as String] = (page: page['pageNumber'] as int,
            juz: {verse['juzNumber'] as int});
        }
      }
      _searchChapters = List.unmodifiable(navigation.surahs.map((chapter) =>
        _AiSearchChapter(chapter.id, chapter.nameSimple, chapter.nameComplex,
          chapter.nameArabic, chapter.translatedName,
          metadata[chapter.id]!['versesCount'] as int,
          metadata[chapter.id]!['revelationPlace'] as String)));
      return Map.unmodifiable({
        for (final key in source.references)
          key: _AiSearchVerse(source.verse(key), _normalizeAiSearch,
            page: locations[key]?.page ?? 0, juz: locations[key]?.juz ?? const {}),
      });
    } finally {
      source.dispose();
    }
  }

  Future<String> searchCatalog() async {
    await _searchIndex();
    return 'Coverage: 6236 Arabic Ayahs, English/Urdu, roots/POS. '
        'Offline gloss/transliteration: Al-Fatihah only. '
        'No global remote Tafsir, image OCR or personal data.\n'
        'Surahs: ID | name | Arabic | English title\n'
        '${_searchChapters.map((chapter) => '${chapter.id}|${chapter.simple}|'
          '${chapter.arabic}|${chapter.translated}').join('\n')}\n'
        'Study collections: ID | title\n'
        '${quranStudyCollections.map((collection) => '${collection.id}|${collection.title}').join('\n')}';
  }

  Future<String> searchPlanningContext(String userInput) async {
    if (userInput.length > 4000) throw const FormatException('Use at most 4000 characters.');
    await _searchIndex();
    final chapter = _resolveAiChapterQuery(_normalizeAiSearch(userInput), _searchChapters);
    return 'Tool coverage: all 6236 Quran Ayahs and all 114 Surahs are available '
        'locally in Arabic, English and Urdu, with roots/POS and study collections. '
        'Offline word glosses/transliteration cover Al-Fatihah only.\n'
        'The app already resolves named Surahs, Ayah references, Juz/page filters '
        'and explicit root/POS requests. Translate only the user topic into short '
        'English search terms. Do not prepend invented Surah names or references '
        'to a topic. Unmentioned Surah IDs and unknown references stay empty.\n'
        '${chapter.ids.isEmpty ? 'Named Surah filters: none. Search the whole Quran.' :
          'Locally resolved named Surahs:\n${_searchChapters.where((item) => chapter.ids.contains(item.id))
            .map((item) => '${item.id}|${item.simple}|${item.arabic}|${item.translated}').join('\n')}'}\n'
        'Available study collection tools (ID | title):\n'
        '${quranStudyCollections.map((collection) => '${collection.id}|${collection.title}').join('\n')}';
  }

  Future<bool> needsSearchPlanning(String userInput) async {
    await _searchIndex();
    final query = _normalizeAiSearch(userInput);
    if (_explicitAiSearchKey(query) != null) return false;
    final chapter = _resolveAiChapterQuery(query, _searchChapters);
    final location = _AiDataLocation.parse(chapter.remaining);
    if (location.remaining.isEmpty && (location.juz != null || location.page != null)) return false;
    final structured = _AiDataQuery(location.remaining);
    if (structured.root != null || structured.pos != null) return false;
    return chapter.ids.isEmpty || chapter.remaining.isNotEmpty;
  }

  Future<QuranAiToolResult> searchQuranData({
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
    Map<String, dynamic>? plan,
    required List<QuranSearchResult> Function(String) ayahSearch,
  }) async {
    if (userInput.length > 4000) throw const FormatException('Use at most 4000 characters.');
    final index = await _searchIndex();
    final retrieval = _AiDataPlan.parse(plan, index);
    final query = _normalizeAiSearch(userInput);
    final exact = _explicitAiSearchKey(query);
    final chapter = _resolveAiChapterQuery(query, _searchChapters);
    final filters = _AiDataLocation.parse(chapter.remaining);
    final chapterIds = chapter.ids.isNotEmpty ? chapter.ids : retrieval.surahIds;
    if (exact == null && chapter.ids.isNotEmpty &&
        retrieval.surahIds.any((id) => !chapter.ids.contains(id))) {
      throw const FormatException('The search plan does not match the named Surah.');
    }
    if (exact == null && chapter.ids.isEmpty && retrieval.surahIds.isNotEmpty) {
      final tokens = query.split(' ');
      for (final id in retrieval.surahIds) {
        var named = false;
        for (var start = 0; start < tokens.length; start++) {
          if (start == 0 || !const {'in', 'from', 'within', 'mein', 'main'}.contains(tokens[start - 1])) {
            continue;
          }
          for (var end = start + 1; end <= tokens.length && end <= start + 6; end++) {
            if (_matchAiChapter(tokens.sublist(start, end).join(' '), _searchChapters,
                explicit: false)?.id == id) {
              named = true;
            }
          }
        }
        if (!named) throw const FormatException('The search plan contains an unmentioned Surah filter.');
      }
    }
    bool allowed(_AiSearchVerse verse) =>
        (chapterIds.isEmpty || chapterIds.contains(verse.chapterId)) &&
        (filters.juz == null || verse.juz.contains(filters.juz)) &&
        (filters.page == null || verse.page == filters.page);
    final scores = <String, int>{};
    void add(String key, int score) {
      final verse = index[key];
      if (verse != null && (exact != null || allowed(verse))) {
        if (score > (scores[key] ?? -1)) scores[key] = score;
      }
    }
    if (userInput.trim().isNotEmpty) {
      if (exact != null) {
        add(exact, 1000000);
      } else {
        final local = filters.remaining;
        final pureScope = local.isEmpty && (chapterIds.isNotEmpty ||
            filters.juz != null || filters.page != null);
        final structured = _AiDataQuery(local);
        final localOnly = pureScope || structured.root != null || structured.pos != null;
        final queries = {if (local.isNotEmpty) local,
          if (!localOnly) ...retrieval.queries.map(_normalizeAiSearch)};
        final rawScorer = local.isEmpty ? null : _AiDataQuery(local);
        final plannedScorers = localOnly ? const <_AiDataQuery>[] : retrieval.queries
          .map(_normalizeAiSearch).toSet().map((phrase) => _AiDataQuery(phrase, highRecall: true)).toList(growable: false);
        for (final verse in index.values) {
          if (!allowed(verse)) continue;
          if (pureScope && queries.isEmpty) {
            add(verse.reference, chapterIds.length > 1 ? 5000 - verse.verseNumber : 5000);
          }
          final rawScore = rawScorer?.score(verse) ?? 0;
          if (rawScore > 0) add(verse.reference, rawScore);
          var bestPlannedScore = 0;
          var matchingPlannedQueries = 0;
          for (final scorer in plannedScorers) {
            final score = scorer.score(verse);
            if (score > 0) {
              matchingPlannedQueries++;
              if (score > bestPlannedScore) bestPlannedScore = score;
            }
          }
          if (matchingPlannedQueries > 0) {
            add(verse.reference, bestPlannedScore + (matchingPlannedQueries - 1) * 600);
          }
        }
        for (final key in localOnly ? const <String>[] : retrieval.references) {
          add(key, 18000);
        }
        final collections = quranStudyCollections.where((collection) =>
          (!localOnly && retrieval.collectionIds.contains(collection.id)) ||
          _normalizeAiSearch(collection.title) == local || collection.id == local);
        for (final collection in collections) {
          for (var position = 0; position < collection.references.length; position++) {
            add(collection.references[position], 12000 - position);
          }
        }
      }
    }
    final ordered = scores.keys.toList()..sort((a, b) {
      final score = scores[b]!.compareTo(scores[a]!);
      if (score != 0) return score;
      final chapterOrder = index[a]!.chapterId.compareTo(index[b]!.chapterId);
      return chapterOrder != 0 ? chapterOrder : index[a]!.verseNumber.compareTo(index[b]!.verseNumber);
    });
    final results = <QuranSearchResult>[];
    for (final key in ordered) {
      final navigation = ayahSearch(key).where((result) => result.verseKey == key);
      if (navigation.isEmpty) continue;
      final target = navigation.first;
      final verse = index[key]!;
      results.add(QuranSearchResult(pageNumber: target.pageNumber,
        referencePageNumber: target.referencePageNumber,
        title: '$key - ${verse.chapterName}',
        snippet: verse.canonical.translationFor(settings.responseLanguage),
        category: 'Ayah translation', verseKey: key, navigationNote: target.navigationNote));
      if (results.length == 12) break;
    }
    return QuranAiToolResult(tool: QuranAiTool.smartSearch,
      output: results.isEmpty ? _localize(settings,
        urdu: 'Is sawal ke liye verified Quran data mein result nahi mila. Surah, Ayah, root ya doosre alfaaz try karein.',
        english: 'No verified Quran result was found. Try a Surah, Ayah, Arabic root, or different wording.')
        : _localize(settings, urdu: '${results.length} verified Quran results mile.',
          english: 'Found ${results.length} verified Quran results.'),
      sourceLabel: 'Verified Quran and study data', usedOnlineModel: false,
      searchResults: List.unmodifiable(results),
      selectionLabel: chapterIds.isEmpty ? '' : _searchChapters
        .where((item) => chapterIds.contains(item.id)).map((item) => item.simple).join(', '),
      sourceNotes: [
        'Search coverage: 6236 canonical Arabic Ayahs, English/Urdu translations, Quranic Corpus roots/POS and 20 study collections. Offline word glosses and pronunciation transliterations cover Al-Fatihah only.',
        for (final item in _searchChapters.where((item) => chapterIds.contains(item.id)))
          'Surah ${item.id}: ${item.simple} (${item.arabic}); ${item.count} Ayahs; revelation place: ${item.revelation}.',
        for (final collection in quranStudyCollections.where((item) => retrieval.collectionIds.contains(item.id)))
          'Study collection: ${collection.title} (${collection.references.join(', ')}).',
        if (filters.juz != null) 'Juz ${filters.juz} is filtered by each canonical Ayah\'s verified Juz metadata.',
        if (filters.page != null) 'Canonical page ${filters.page}; edition scans have different page numbers.',
        'Printed-scan navigation uses the edition\'s estimated Surah anchor. Exact Ayah-to-scan-page alignment is unavailable.',
      ]);
  }

  Future<QuranAiStudyMaterial> prepareStudy({
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required String userInput,
    String referenceSelection = '',
    List<String> historyReferences = const [],
    required List<QuranSearchResult> Function(String) ayahSearch,
    required List<String> defaultReferences,
  }) async {
    if (userInput.length > 4000) throw const FormatException('Use at most 4000 characters.');
    final index = await _searchIndex();
    final defaults = _validateStudyKeys(defaultReferences, index);
    final history = _validateStudyKeys(historyReferences, index);
    final query = userInput.trim();
    final writtenPractice = tool == QuranAiTool.hifzCoach || tool == QuranAiTool.recitationFollow;
    if (writtenPractice && referenceSelection.trim().isEmpty) {
      throw const FormatException('Select an explicit Ayah or range for written-text practice.');
    }
    List<String> keys;
    var navigation = <QuranSearchResult>[];
    final referenceInput = _studyDigits(query);
    if (referenceSelection.trim().isNotEmpty) {
      keys = _parseStudySelection(referenceSelection, index);
    } else if (RegExp(r'^\s*\d+\s*:').hasMatch(referenceInput)) {
      keys = _parseStudySelection(query, index);
    } else if (query.isEmpty || _studyFollowups.contains(_normalizeAiSearch(query))) {
      keys = query.isNotEmpty && history.isNotEmpty ? history : defaults;
      if (keys.isEmpty) throw const FormatException('Select an Ayah or enter a study topic.');
    } else {
      final found = await _runSmartSearch(tool: QuranAiTool.smartSearch,
        settings: settings, context: _studyLookupContext, userInput: query,
        pageSearch: (_) => const [], ayahSearch: ayahSearch);
      navigation = List.of(found.searchResults);
      keys = navigation.map((hit) => hit.verseKey!).toList(growable: false);
    }
    final candidates = keys.map((key) => index[key]!.canonical).toList(growable: false);
    if (navigation.isEmpty) {
      for (final key in keys) {
        final matches = ayahSearch(key).where((hit) => hit.verseKey == key);
        if (matches.isNotEmpty) navigation.add(matches.first);
      }
    }
    QuranAiTextComparison? comparison;
    if (writtenPractice) {
      if (!RegExp(r'[\u0621-\u064A\u0671\u06A9\u06CC]').hasMatch(query)) {
        throw const FormatException('Paste the Arabic text you want to compare.');
      }
      if (tool == QuranAiTool.hifzCoach) {
        comparison = _compareStudyText(candidates.first.verseKey,
          candidates.map((verse) => verse.arabic).join('\n'), query,
          verseKeys: keys);
      } else {
        for (final verse in candidates) {
          final current = _compareStudyText(verse.verseKey, verse.arabic, query,
            verseKeys: [verse.verseKey]);
          if (current.matchedWordCount > 0 && (comparison == null ||
              current.matchedWordCount > comparison.matchedWordCount ||
              (current.matchedWordCount == comparison.matchedWordCount &&
                current.expectedWordCount < comparison.expectedWordCount))) {
            comparison = current;
          }
        }
      }
    }
    return QuranAiStudyMaterial(selectionLabel: keys.join(', '),
      candidates: List.unmodifiable(candidates),
      searchResults: List.unmodifiable(navigation), textComparison: comparison);
  }

  Future<QuranAiToolResult> finishStudy({
    required QuranAiStudyMaterial material,
    required List<String> selectedKeys,
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    int quizCount = 5,
    int revisionDays = 7,
    int minutesPerDay = 10,
  }) async {
    if (quizCount < 1 || quizCount > 8 || revisionDays < 1 || revisionDays > 30 ||
        minutesPerDay < 5 || minutesPerDay > 120) {
      throw const FormatException('Use 1–8 quiz questions, 1–30 days, and 5–120 minutes.');
    }
    final index = await _searchIndex();
    final allowed = material.candidates.map((verse) => verse.verseKey).toSet();
    if (allowed.length != material.candidates.length || allowed.length > 12 ||
        allowed.any((key) => !index.containsKey(key)) ||
        selectedKeys.length > 12 || selectedKeys.toSet().length != selectedKeys.length ||
        selectedKeys.any((key) => !allowed.contains(key) || !index.containsKey(key)) ||
        (allowed.isNotEmpty && selectedKeys.isEmpty)) {
      throw const FormatException('Choose unique references from the supplied verified sources.');
    }
    final completeSelection = tool != QuranAiTool.smartSearch && tool != QuranAiTool.studyChat;
    final remaining = allowed.where((key) => !selectedKeys.contains(key)).toList()
      ..sort((a, b) {
        final aa = a.split(':').map(int.parse).toList();
        final bb = b.split(':').map(int.parse).toList();
        return aa[0] != bb[0] ? aa[0].compareTo(bb[0]) : aa[1].compareTo(bb[1]);
      });
    final resultKeys = [ ...selectedKeys, if (completeSelection) ...remaining ];
    final verses = resultKeys.map((key) => index[key]!.canonical).toList(growable: false);
    final hits = <QuranSearchResult>[];
    for (final verse in verses) {
      final matches = material.searchResults.where((hit) => hit.verseKey == verse.verseKey);
      if (matches.isEmpty) continue;
      final hit = matches.first;
      hits.add(QuranSearchResult(pageNumber: hit.pageNumber,
        referencePageNumber: hit.referencePageNumber,
        title: '${verse.verseKey} - ${verse.chapterName}',
        snippet: verse.translationFor(settings.responseLanguage),
        category: 'Ayah translation', verseKey: verse.verseKey,
        navigationNote: hit.navigationNote));
    }
    final notes = <String>[
      QuranStudyDataSource.corpusNotice,
      QuranStudyDataSource.translationNotice,
      'Sources are selected Ayahs, not verified positions on the original Mushaf scans. Navigation opens the Surah start where exact alignment is unavailable.',
    ];
    final questions = <QuranAiQuizQuestion>[];
    final days = <QuranAiRevisionDay>[];
    QuranAiBookmarkSuggestion? bookmark;
    QuranAiTextComparison? comparison;
    final preparedComparison = material.textComparison;
    if (preparedComparison != null &&
        (tool == QuranAiTool.hifzCoach || tool == QuranAiTool.recitationFollow)) {
      final keys = preparedComparison.verseKeys.isEmpty
          ? [preparedComparison.verseKey] : preparedComparison.verseKeys;
      if (keys.any((key) => !allowed.contains(key))) {
        throw const FormatException('Written comparison must use the selected verified sources.');
      }
      comparison = _compareStudyText(keys.first,
        keys.map((key) => index[key]!.arabic).join('\n'), preparedComparison.recalled,
        verseKeys: keys);
    }
    var output = _localize(settings,
      urdu: 'منتخب آیات اور مستند تراجم نیچے پڑھیں۔ اپنی سمجھ اپنے الفاظ میں لکھیں اور غیر واضح بات استاد سے پوچھیں۔',
      english: 'Read the selected Ayahs and their verified translations below. Write your understanding in your own words and ask a teacher about anything unclear.');
    if (verses.isEmpty) {
      output = _localize(settings, urdu: 'اس درخواست کے لیے مستند آیت نہیں ملی۔ موضوع یا حوالہ بدل کر کوشش کریں۔',
        english: 'No verified Ayah sources matched this request. Try another topic or reference.');
    } else if (tool == QuranAiTool.quranQuiz) {
      final pool = index.values.toList()..shuffle();
      for (final verse in verses.take(quizCount)) {
        final correct = verse.translationFor(settings.responseLanguage);
        final seen = {_normalizeAiSearch(correct)};
        final options = <QuranAiQuizOption>[
          QuranAiQuizOption(verseKey: verse.verseKey, translation: correct),
        ];
        for (final candidate in pool) {
          if (candidate.reference == verse.verseKey ||
              _normalizeAiSearch(candidate.arabic) == _normalizeAiSearch(verse.arabic)) {
            continue;
          }
          final translation = candidate.canonical.translationFor(settings.responseLanguage);
          if (!seen.add(_normalizeAiSearch(translation))) continue;
          options.add(QuranAiQuizOption(verseKey: candidate.reference, translation: translation));
          if (options.length == 4) break;
        }
        if (options.length != 4) throw StateError('Not enough distinct verified quiz options.');
        options.shuffle();
        questions.add(QuranAiQuizQuestion(verseKey: verse.verseKey, arabic: verse.arabic,
          options: List.unmodifiable(options),
          correctOptionIndex: options.indexWhere((option) => option.verseKey == verse.verseKey)));
      }
      output = _localize(settings, urdu: 'اصل عربی کے مطابق اسی آیت کا مستند ترجمہ منتخب کریں۔ جواب دینے کے بعد اصل ماخذ دیکھیں۔',
        english: 'Choose the recorded translation for the original Arabic Ayah. Check the verified source after answering.');
      notes.add('Quiz options are real bundled translations. Similar meanings can occur elsewhere; the correct option is the recorded translation of this reference.');
    } else if (tool == QuranAiTool.revisionPlan) {
      final orderedKeys = material.candidates.map((verse) => verse.verseKey).toList()
        ..sort((a, b) {
          final aa = a.split(':').map(int.parse).toList();
          final bb = b.split(':').map(int.parse).toList();
          return aa[0] != bb[0] ? aa[0].compareTo(bb[0]) : aa[1].compareTo(bb[1]);
        });
      final suggestedDaily = minutesPerDay ~/ 5;
      final minimumDaily = (orderedKeys.length / revisionDays).ceil();
      var perDay = suggestedDaily > minimumDaily ? suggestedDaily : minimumDaily;
      if (perDay > orderedKeys.length) perDay = orderedKeys.length;
      final starts = <String, int>{for (var i = 0; i < orderedKeys.length; i++)
        orderedKeys[i]: i ~/ perDay + 1};
      for (var day = 1; day <= revisionDays; day++) {
        final learn = orderedKeys.where((key) => starts[key] == day).toList();
        final review = orderedKeys.where((key) => day > starts[key]! &&
          (const {1, 3, 7, 14, 21}.contains(day - starts[key]!) || day == revisionDays)).toList();
        if (learn.isEmpty && review.isEmpty) {
          final introduced = orderedKeys.where((key) => starts[key]! < day).toList();
          if (introduced.isNotEmpty) review.add(introduced[(day - 1) % introduced.length]);
        }
        days.add(QuranAiRevisionDay(day: day, minutes: minutesPerDay,
          learnReferences: List.unmodifiable(learn), reviewReferences: List.unmodifiable(review)));
      }
      output = _localize(settings, urdu: 'ہر دن کے مقررہ وقت میں منتخب آیات پڑھیں، یاد کریں اور دہرائیں۔ اپنی رفتار کے مطابق وقفہ لیں۔',
        english: 'Use each daily time budget to read, recall and review the selected Ayahs. Adjust the pace to your needs.');
      notes.add('Minutes are a study budget, not a promised completion time. This preview does not create reminders or alter your saved reading plan.');
      if (perDay > suggestedDaily) {
        notes.add('This selection needs more new Ayahs per day than the suggested time budget. Choose more days or fewer Ayahs if the workload is too high.');
      }
    } else if (tool == QuranAiTool.flashcards) {
      output = _localize(settings, urdu: 'پہلے اصل عربی پڑھیں، پھر کارڈ پلٹ کر مستند ترجمہ دیکھیں۔',
        english: 'Read the original Arabic first, then reveal the verified translation on each card.');
    } else if (tool == QuranAiTool.studyChat || tool == QuranAiTool.askCurrentPage || tool == QuranAiTool.voiceQna) {
      final intro = _localize(settings, urdu: 'آپ کے سوال کے لیے منتخب مستند آیات اور ان کے اصل تراجم:',
        english: 'Verified Ayah sources and their recorded translations for your question:');
      final passages = verses.map((verse) => '${verse.verseKey} — ${verse.chapterName}\n${verse.translationFor(settings.responseLanguage)}').join('\n\n');
      output = '$intro\n\n$passages';
      notes.add('This source-based reply contains recorded translations, not generated paraphrase or new tafsir.');
    } else if (tool == QuranAiTool.hifzCoach || tool == QuranAiTool.recitationFollow) {
      output = comparison == null
        ? _localize(settings, urdu: 'منتخب آیات میں لکھے ہوئے الفاظ کا واضح ملاپ نہیں ملا۔',
            english: 'No written-word match was found within the selected Ayahs.')
        : _localize(settings,
            urdu: 'تحریری موازنہ: ${comparison.expectedWordCount} اصل الفاظ میں سے ${comparison.matchedWordCount} الفاظ ترتیب سے ملے۔ یہ تلفظ کی جانچ نہیں ہے۔',
            english: 'Written-text comparison: ${comparison.matchedWordCount} of ${comparison.expectedWordCount} source words matched in order. This does not assess pronunciation.');
      notes.add('Written matching ignores vowel marks and common Arabic/Urdu spelling variants. It is not a recitation, pronunciation or Tajweed score.');
      if (tool == QuranAiTool.recitationFollow) notes.add('Closest typed phrase match within the selected Ayahs only. Unmatched surrounding words are not evidence of a recitation mistake; no audio or printed-line following is performed.');
    } else if (tool == QuranAiTool.tajweedTutor) {
      final text = verses.map((verse) => verse.arabic).join(' ');
      final marks = <String>[
        if (text.contains('\u0651')) 'shadda (ّ)',
        if (text.contains('\u0652')) 'sukun (ْ)',
        if (RegExp(r'[\u064B-\u064D]').hasMatch(text)) 'tanwin (ً ٍ ٌ)',
        if (text.contains('\u0653')) 'maddah (ٓ)',
      ];
      output = _localize(settings,
        urdu: 'منتخب اصل عربی میں نظر آنے والی علامات: ${marks.isEmpty ? 'فہرست میں شامل کوئی علامت نہیں ملی' : marks.join('، ')}۔ ان کی قراءت استاد سے سیکھیں۔',
        english: 'Visible marks in the selected original Arabic: ${marks.isEmpty ? 'none of the listed marks found' : marks.join(', ')}. Learn how to read them with a qualified teacher.');
      notes.add('This is a visible-mark study checklist, not inferred Tajweed rules or acoustic analysis.');
    } else if (tool == QuranAiTool.bookmarkAssistant) {
      bookmark = QuranAiBookmarkSuggestion(folder: 'Review',
        label: '${verses.first.chapterName} ${verses.first.verseKey}',
        reason: 'Saves your current reading page; selected Ayah references are study context, not verified scan positions.');
    } else if (tool == QuranAiTool.tafsirAssistant) {
      output = _localize(settings, urdu: 'یہ آیات اور تراجم ہیں، تفسیر نہیں۔ تفسیر صرف الگ مستند ماخذ سے پڑھی جائے۔',
        english: 'These are original Ayahs and verified translations, not tafsir. Tafsir must come from a separately verified tafsir source.');
    } else if (tool == QuranAiTool.translationSimplifier) {
      output = _localize(settings, urdu: 'مستند ترجمہ بغیر تبدیلی دکھایا گیا ہے۔ ایک وقت میں ایک جملہ پڑھیں اور اصل عربی سے موازنہ کریں۔',
        english: 'The verified translation is shown unchanged. Read one sentence at a time and compare it with the original Arabic.');
      final layout = <String>[];
      for (final verse in verses) {
        final translations = [
          if (settings.responseLanguage != AiResponseLanguage.urdu) verse.translationEn,
          if (settings.responseLanguage != AiResponseLanguage.english) verse.translationUr,
        ];
        for (final translation in translations) {
          final sentences = translation.split(RegExp(r'(?<=[.!?۔؟])\s+'));
          layout.add('${verse.verseKey}\n${[for (var i = 0; i < sentences.length; i++) '${i + 1}. ${sentences[i]}'].join('\n')}');
        }
      }
      output = '$output\n\n${layout.join('\n\n')}';
      notes.add('This is a sentence-by-sentence reading layout of the recorded translation, not a new translation or generated paraphrase.');
    } else if (tool == QuranAiTool.explainer || tool == QuranAiTool.studyNotes || tool == QuranAiTool.dailyLesson) {
      final passages = verses.map((verse) => '${verse.verseKey} — ${verse.chapterName}\n${verse.translationFor(settings.responseLanguage)}').join('\n\n');
      final steps = _localize(settings, urdu: 'مطالعے کے مراحل:\n1. اصل عربی پڑھیں۔\n2. مستند ترجمہ دیکھیں۔\n3. اپنی سمجھ اپنے الفاظ میں لکھیں۔\n4. ایک سوال نوٹ کریں اور آیات دہرائیں۔',
        english: 'Study steps:\n1. Read the original Arabic.\n2. Check the verified translation.\n3. Write your understanding in your own words.\n4. Note one question and review the Ayahs.');
      output = '$passages\n\n$steps';
      notes.add('Passages are the recorded source translations. Reading and reflection prompts are study instructions, not new tafsir or factual claims.');
    }
    return QuranAiToolResult(tool: tool, output: output,
      sourceLabel: 'Verified Quran study sources', usedOnlineModel: false,
      searchResults: List.unmodifiable(hits), bookmarkSuggestion: bookmark,
      canonicalVerses: List.unmodifiable(verses), quizQuestions: List.unmodifiable(questions),
      revisionDays: List.unmodifiable(days), textComparison: comparison,
      selectionLabel: completeSelection ? material.selectionLabel : resultKeys.join(', '),
      sourceNotes: List.unmodifiable(notes));
  }

  List<String> _validateStudyKeys(List<String> input, Map<String, _AiSearchVerse> index) {
    if (input.length > 12) throw const FormatException('Select at most 12 Ayahs.');
    final keys = <String>[];
    for (final raw in input) {
      final parsed = _parseStudySelection(raw, index);
      if (parsed.length != 1) throw const FormatException('History and defaults require single Ayah references.');
      if (!keys.contains(parsed.single)) keys.add(parsed.single);
    }
    return keys;
  }

  List<String> _parseStudySelection(String selection, Map<String, _AiSearchVerse> index) {
    final text = _studyDigits(selection).trim().replaceAll('–', '-').replaceAll('—', '-');
    final match = RegExp(r'^(\d{1,3})\s*:\s*(\d{1,3})(?:\s*-\s*(?:(\d{1,3})\s*:\s*)?(\d{1,3}))?$').firstMatch(text);
    if (match == null) throw const FormatException('Use a reference such as 2:255 or a same-Surah range such as 112:1-4.');
    final chapter = int.parse(match[1]!);
    final start = int.parse(match[2]!);
    final end = int.parse(match[4] ?? match[2]!);
    if ((match[3] != null && int.parse(match[3]!) != chapter) || end < start || end - start + 1 > 12) {
      throw const FormatException('Use an ordered range of at most 12 Ayahs within one Surah.');
    }
    final keys = [for (var verse = start; verse <= end; verse++) '$chapter:$verse'];
    if (keys.any((key) => !index.containsKey(key))) throw const FormatException('The selection contains an invalid Quran reference.');
    return keys;
  }

  QuranAiTextComparison _compareStudyText(String key, String expected, String recalled,
      {required List<String> verseKeys}) {
    List<String> words(String value) => value.split(RegExp(r'[\s،؛,.:!?؟0-9٠-٩۰-۹]+'))
        .where((word) => _normalizeAiSearch(word).isNotEmpty).toList();
    final source = words(expected);
    final input = words(recalled);
    final a = source.map(_normalizeAiSearch).toList();
    final b = input.map(_normalizeAiSearch).toList();
    final table = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (var i = a.length - 1; i >= 0; i--) {
      for (var j = b.length - 1; j >= 0; j--) {
        table[i][j] = a[i] == b[j] ? table[i + 1][j + 1] + 1
          : table[i + 1][j] >= table[i][j + 1] ? table[i + 1][j] : table[i][j + 1];
      }
    }
    final missing = <String>[];
    final extra = <String>[];
    var i = 0;
    var j = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) { i++; j++; }
      else if (table[i + 1][j] >= table[i][j + 1]) { missing.add(source[i++]); }
      else { extra.add(input[j++]); }
    }
    missing.addAll(source.skip(i));
    extra.addAll(input.skip(j));
    return QuranAiTextComparison(verseKey: key, verseKeys: List.unmodifiable(verseKeys),
      expected: expected, recalled: recalled, missingWords: List.unmodifiable(missing),
      extraWords: List.unmodifiable(extra), matchedWordCount: table[0][0], expectedWordCount: source.length);
  }

  Future<QuranAiToolResult> runTool({
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
    required List<QuranSearchResult> Function(String query) pageSearch,
    required List<QuranSearchResult> Function(String query) ayahSearch,
  }) async {
    final normalizedInput = userInput.trim();

    switch (tool) {
      case QuranAiTool.studyChat:
      case QuranAiTool.quranQuiz:
      case QuranAiTool.flashcards:
      case QuranAiTool.revisionPlan:
        final material = await prepareStudy(tool: tool, settings: settings,
          userInput: normalizedInput, ayahSearch: ayahSearch, defaultReferences: context.verseKeys);
        return finishStudy(material: material,
          selectedKeys: material.candidates.map((verse) => verse.verseKey).toList(),
          tool: tool, settings: settings);
      case QuranAiTool.smartSearch:
        return _runSmartSearch(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
          pageSearch: pageSearch,
          ayahSearch: ayahSearch,
        );
      case QuranAiTool.bookmarkAssistant:
        return _runBookmarkAssistant(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
        );
      case QuranAiTool.recitationFollow:
        return _runRecitationFollow(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
        );
      case QuranAiTool.hifzCoach:
        return _runHifzCoach(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
        );
      case QuranAiTool.tajweedTutor:
        return _runTajweedTutor(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
        );
      case QuranAiTool.explainer:
        return _runNarrativeTool(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
          offlineText: _buildExplainerText(settings, context, normalizedInput),
          toolInstruction:
              'Explain the current Quran page simply. Focus on key themes, main message, and practical understanding. Keep it grounded in the provided context only.',
        );
      case QuranAiTool.translationSimplifier:
        return _runNarrativeTool(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
          offlineText: _buildTranslationSimplifierText(
            settings,
            context,
            normalizedInput,
          ),
          toolInstruction:
              'Rewrite the current page translation in easier words. Keep the meaning faithful and student-friendly.',
        );
      case QuranAiTool.tafsirAssistant:
        return _runNarrativeTool(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
          offlineText: _buildTafsirAssistantText(
            settings,
            context,
            normalizedInput,
          ),
          toolInstruction:
              'Answer the tafsir/context question using only the supplied page context, chapter info, and tafsir excerpt. Mention uncertainty if the context is limited.',
        );
      case QuranAiTool.askCurrentPage:
        return _runNarrativeTool(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
          offlineText: _buildAskCurrentPageText(
            settings,
            context,
            normalizedInput,
          ),
          toolInstruction:
              'Answer the user question about the current Quran page. Be concise, practical, and do not claim unsupported details.',
        );
      case QuranAiTool.studyNotes:
        return _runNarrativeTool(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
          offlineText: _buildStudyNotesText(
            settings,
            context,
            normalizedInput,
          ),
          toolInstruction:
              'Generate study notes for the current page. Include themes, reflection points, and dars-ready summary points.',
        );
      case QuranAiTool.dailyLesson:
        return _runNarrativeTool(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
          offlineText: _buildDailyLessonText(
            settings,
            context,
            normalizedInput,
          ),
          toolInstruction:
              'Create a short daily lesson from the current page with one reflection and one action point.',
        );
      case QuranAiTool.voiceQna:
        return _runNarrativeTool(
          tool: tool,
          settings: settings,
          context: context,
          userInput: normalizedInput,
          offlineText: _buildVoiceQnaText(settings, context, normalizedInput),
          toolInstruction:
              'Answer the user voice-style question in a clear, conversational way. Treat the input as a transcript or typed question.',
        );
    }
  }

  Future<QuranAiToolResult> _runNarrativeTool({
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
    required String offlineText,
    required String toolInstruction,
  }) async {
    return QuranAiToolResult(
      tool: tool,
      output: offlineText,
      sourceLabel: 'Free local assistant',
      usedOnlineModel: false,
    );
  }

  Future<QuranAiToolResult> _runSmartSearch({
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
    required List<QuranSearchResult> Function(String query) pageSearch,
    required List<QuranSearchResult> Function(String query) ayahSearch,
  }) => searchQuranData(settings: settings, context: context,
      userInput: userInput, ayahSearch: ayahSearch);
  Future<QuranAiToolResult> _runBookmarkAssistant({
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
  }) async {
    final suggestion = _buildBookmarkSuggestion(context, userInput);
    final fallbackOutput = _localize(
      settings,
      urdu:
          'Best folder: ${suggestion.folder}\nSuggested label: ${suggestion.label}\nReason: ${suggestion.reason}',
      english:
          'Best folder: ${suggestion.folder}\nSuggested label: ${suggestion.label}\nReason: ${suggestion.reason}',
    );
    return QuranAiToolResult(
      tool: tool,
      output: fallbackOutput,
      sourceLabel: 'Free local bookmark helper',
      usedOnlineModel: false,
      bookmarkSuggestion: suggestion,
    );
  }

  Future<QuranAiToolResult> _runRecitationFollow({
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
  }) async {
    if (userInput.isEmpty) {
      return QuranAiToolResult(
        tool: tool,
        output: _localize(
          settings,
          urdu:
              'Suni hui phrase paste karo. Main current page ki qareebi line match karke bataunga ke qari kis line par lagta hai.',
          english:
              'Paste the phrase you heard and I will match it to the closest line on the current page.',
        ),
        sourceLabel: 'Local line matcher',
        usedOnlineModel: false,
      );
    }

    final match = _findBestLineMatch(userInput, context.arabicLines);
    if (match == null || match.score < 0.18) {
      return QuranAiToolResult(
        tool: tool,
        output: _localize(
          settings,
          urdu:
              'Current page par clear line match nahi mila. Thora lamba phrase ya zyada exact Arabic paste karo.',
          english:
              'No clear line match was found on the current page. Paste a slightly longer or more exact Arabic phrase.',
        ),
        sourceLabel: 'Local line matcher',
        usedOnlineModel: false,
      );
    }

    return QuranAiToolResult(
      tool: tool,
      output: _localize(
        settings,
        urdu:
            'Qari sab se zyada Line ${match.lineNumber} ke qareeb lagta hai. Match score ${(match.score * 100).round()}% hai.',
        english:
            'The recitation is closest to Line ${match.lineNumber}. Estimated match score is ${(match.score * 100).round()}%.',
      ),
      sourceLabel: 'Local line matcher',
      usedOnlineModel: false,
      matchedLineNumber: match.lineNumber,
      matchedLineText: match.text,
    );
  }

  Future<QuranAiToolResult> _runHifzCoach({
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
  }) async {
    if (userInput.isEmpty) {
      return QuranAiToolResult(
        tool: tool,
        output: _localize(
          settings,
          urdu:
              'Apni yaad ki hui Arabic line ya lines paste karo. Main current page se compare karke weak spots aur review hint dunga.',
          english:
              'Paste the Arabic lines you recalled. I will compare them with the current page and show weak spots and review hints.',
        ),
        sourceLabel: 'Local hifz checker',
        usedOnlineModel: false,
      );
    }

    final match = _findBestLineMatch(userInput, context.arabicLines);
    if (match == null || match.score < 0.14) {
      return QuranAiToolResult(
        tool: tool,
        output: _localize(
          settings,
          urdu:
              'Input current page ki visible lines se clearly match nahi hua. Page check karke dobara paste karo.',
          english:
              'The input did not clearly match the visible lines on this page. Check the page and try again.',
        ),
        sourceLabel: 'Local hifz checker',
        usedOnlineModel: false,
      );
    }

    final missingWords = _missingWords(userInput, match.text).take(6).toList();
    final offlineText = _localize(
      settings,
      urdu:
          'Closest match: Line ${match.lineNumber}\nSimilarity: ${(match.score * 100).round()}%\n${missingWords.isEmpty ? 'Missing lafz clear nahi nikle, lekin line dobara aahista repeat karo.' : 'Review lafz: ${missingWords.join('، ')}'}\nTip: Is line se aglay 1-2 lines bhi saath revise karo.',
      english:
          'Closest match: Line ${match.lineNumber}\nSimilarity: ${(match.score * 100).round()}%\n${missingWords.isEmpty ? 'No obvious missing words were detected, but repeat the line slowly once more.' : 'Words to review: ${missingWords.join(', ')}'}\nTip: Revise the next one or two lines together with it.',
    );

    return QuranAiToolResult(
      tool: tool,
      output: offlineText,
      sourceLabel: 'Free local hifz coach',
      usedOnlineModel: false,
      matchedLineNumber: match.lineNumber,
      matchedLineText: match.text,
    );
  }

  Future<QuranAiToolResult> _runTajweedTutor({
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
  }) async {
    final focusItems = _collectTajweedFocus(context.arabicLines);
    final offlineText = _localize(
      settings,
      urdu:
          'Current page ke liye tajweed focus:\n${focusItems.isEmpty ? 'Visible lines se strong tajweed markers extract nahi huay. Slow recitation aur waqf positions par focus rakho.' : focusItems.join('\n')}\n${userInput.isEmpty ? 'Agar transcript paste karo to aur focused feedback milegi.' : 'Pasted text ko current page ke saath review karte waqt madd, ghunna, aur qalqala par khas tawajjoh do.'}',
      english:
          'Tajweed focus for the current page:\n${focusItems.isEmpty ? 'No strong tajweed markers were extracted from the visible lines. Focus on slow recitation and proper stopping points.' : focusItems.join('\n')}\n${userInput.isEmpty ? 'Paste a transcript for more focused feedback.' : 'While reviewing the pasted text, pay extra attention to madd, ghunna, and qalqala spots.'}',
    );

    return QuranAiToolResult(
      tool: tool,
      output: offlineText,
      sourceLabel: 'Free local tajweed helper',
      usedOnlineModel: false,
    );
  }

  String _buildExplainerText(
    ReaderAiSettings settings,
    QuranAiPageContext context,
    String userInput,
  ) {
    final focus = userInput.isEmpty ? '' : ' Focus: $userInput.';
    return _localize(
      settings,
      urdu:
          '${context.pageReference} ${context.chapterName == null ? 'ka hissa hai.' : 'Surah ${context.chapterName} ka hissa hai.'}$focus Is page mein bunyadi theme ${_bestTheme(context)} nazar aati hai. Translation aur chapter context ke mutabiq yeh page hidayat, imaan, aur amal par tawajjoh deta hai.',
      english:
          '${context.pageReference} belongs to ${context.chapterName == null ? 'the current Quran reading flow.' : 'Surah ${context.chapterName}.'}$focus The page mainly points toward ${_bestTheme(context)} and emphasizes guidance, faith, and practical response.',
    );
  }

  String _buildTranslationSimplifierText(
    ReaderAiSettings settings,
    QuranAiPageContext context,
    String userInput,
  ) {
    final simpleUr = context.translationUr.trim().isEmpty
        ? 'Is page ki translation local data mein short hai, lekin overall message hidayat aur amal ki taraf bulata hai.'
        : 'Asan alfaaz mein: ${_trimText(context.translationUr, 240)}';
    final simpleEn = context.translationEn.trim().isEmpty
        ? 'The local translation is limited here, but the overall message points toward guidance and sincere action.'
        : 'In simple words: ${_trimText(context.translationEn, 240)}';

    return _localize(
      settings,
      urdu:
          '$simpleUr${userInput.isEmpty ? '' : ' Requested focus: $userInput.'}',
      english:
          '$simpleEn${userInput.isEmpty ? '' : ' Requested focus: $userInput.'}',
    );
  }

  String _buildTafsirAssistantText(
    ReaderAiSettings settings,
    QuranAiPageContext context,
    String userInput,
  ) {
    final tafsir = context.tafsirExcerpt.trim().isEmpty
        ? context.chapterInfo.trim()
        : context.tafsirExcerpt.trim();
    final summary = tafsir.isEmpty
        ? _localize(
            settings,
            urdu:
                'Local tafsir excerpt available nahi hai, lekin chapter info ke mutabiq page ka context ${_bestTheme(context)} ki taraf jata hai.',
            english:
                'A local tafsir excerpt is not available, but the chapter context points toward ${_bestTheme(context)}.',
          )
        : _trimText(tafsir, 420);

    return _localize(
      settings,
      urdu:
          '${userInput.isEmpty ? 'Current page ka short tafsir context:' : 'Sawal: $userInput\nShort tafsir context:'}\n$summary',
      english:
          '${userInput.isEmpty ? 'Short tafsir context for the current page:' : 'Question: $userInput\nShort tafsir context:'}\n$summary',
    );
  }

  String _buildAskCurrentPageText(
    ReaderAiSettings settings,
    QuranAiPageContext context,
    String userInput,
  ) {
    if (userInput.isEmpty) {
      return _localize(
        settings,
        urdu:
            'Current page ke bare mein sawal likho, jaise: is page ka summary do, important ayat kaun si hain, ya yeh kis surah ka part hai?',
        english:
            'Type a question about the current page, such as: summarize this page, which ayat are important here, or which surah is this part of?',
      );
    }

    return _localize(
      settings,
      urdu:
          'Sawal: $userInput\nLocal page context ke mutabiq yeh page ${_bestTheme(context)} ko highlight karta hai. ${context.chapterName == null ? '' : 'Yeh Surah ${context.chapterName} ka hissa hai. '}Translation aur summary se lagta hai ke is page ki practical direction imaan aur amal ko mazboot karna hai.',
      english:
          'Question: $userInput\nBased on the local page context, this page highlights ${_bestTheme(context)}. ${context.chapterName == null ? '' : 'It belongs to Surah ${context.chapterName}. '}The translation and summary suggest a practical focus on strengthening faith and response.',
    );
  }

  String _buildStudyNotesText(
    ReaderAiSettings settings,
    QuranAiPageContext context,
    String userInput,
  ) {
    final focus = userInput.isEmpty ? '' : '\nFocus: $userInput';
    return _localize(
      settings,
      urdu:
          'Study notes:\n1. Main theme: ${_bestTheme(context)}\n2. Reflection: Is page ka paigham sirf maloomat nahi, balke amal aur hidayat ki taraf dawat deta hai.\n3. Dars point: ${_trimText(context.chapterInfo.isEmpty ? context.translationUr : context.chapterInfo, 180)}$focus',
      english:
          'Study notes:\n1. Main theme: ${_bestTheme(context)}\n2. Reflection: The page calls not only to understanding but also to action and guidance.\n3. Teaching point: ${_trimText(context.chapterInfo.isEmpty ? context.translationEn : context.chapterInfo, 180)}$focus',
    );
  }

  String _buildDailyLessonText(
    ReaderAiSettings settings,
    QuranAiPageContext context,
    String userInput,
  ) {
    final focus = userInput.isEmpty ? _bestTheme(context) : userInput;
    return _localize(
      settings,
      urdu:
          'Aaj ka lesson:\nTheme: $focus\nReflection: ${context.pageReference} yaad dilata hai ke Quran ki hidayat ko rozmarrah amal se jorna hai.\nAction: Aaj ek choti si cheez choose karo jo is page ke paigham ko zindagi mein apply kare.\nProgress: ${context.dailyProgressSummary}',
      english:
          'Today\'s lesson:\nTheme: $focus\nReflection: ${context.pageReference} reminds you to connect Quranic guidance with daily action.\nAction: Choose one small step today that reflects this page.\nProgress: ${context.dailyProgressSummary}',
    );
  }

  String _buildVoiceQnaText(
    ReaderAiSettings settings,
    QuranAiPageContext context,
    String userInput,
  ) {
    if (userInput.isEmpty) {
      return _localize(
        settings,
        urdu:
            'Voice Q&A ke liye apna sawal type karo ya keyboard mic ka transcript paste karo.',
        english:
            'Type your question or paste a keyboard mic transcript to use voice Q&A.',
      );
    }

    return _localize(
      settings,
      urdu:
          'Transcript-based jawab:\n$userInput\nCurrent page context ke mutabiq short jawab: yeh page ${_bestTheme(context)} ko foreground mein rakhta hai, is liye sawal ka jawab isi bunyadi paigham ke gird samjha ja sakta hai.',
      english:
          'Transcript-based answer:\n$userInput\nFrom the current page context, the page centers on ${_bestTheme(context)}, so the answer should be understood around that main message.',
    );
  }

  QuranAiBookmarkSuggestion _buildBookmarkSuggestion(
    QuranAiPageContext context,
    String userInput,
  ) {
    final haystack = [
      context.translationUr,
      context.translationEn,
      context.chapterInfo,
      context.tafsirExcerpt,
      userInput,
    ].join(' ').toLowerCase();

    if (_containsAny(haystack, <String>[
      'دعا',
      'dua',
      'supplication',
      'ربنا',
      'forgive',
      'mercy',
    ])) {
      return const QuranAiBookmarkSuggestion(
        folder: 'Dua',
        label: 'Dua reflection',
        reason:
            'This page strongly leans toward dua, mercy, or turning back to Allah.',
      );
    }
    if (_containsAny(haystack, <String>[
      'namaz',
      'salah',
      'salat',
      'pray',
      'prayer',
      'الصلاة',
    ])) {
      return const QuranAiBookmarkSuggestion(
        folder: 'Namaz',
        label: 'Namaz reminder',
        reason: 'This page appears to focus on salah or worship.',
      );
    }
    if (_containsAny(haystack, <String>[
      'akhlaq',
      'character',
      'manners',
      'conduct',
      'morals',
      'رحمة',
      'justice',
    ])) {
      return const QuranAiBookmarkSuggestion(
        folder: 'Akhlaq',
        label: 'Akhlaq lesson',
        reason:
            'This page has a strong character, conduct, or human behavior theme.',
      );
    }
    if (_containsAny(haystack, <String>[
      'hifz',
      'memor',
      'remember',
      'revise',
      'review',
      'repeat',
    ])) {
      return const QuranAiBookmarkSuggestion(
        folder: 'Hifz',
        label: 'Hifz review',
        reason: 'This page looks suitable for memorization or later revision.',
      );
    }
    return const QuranAiBookmarkSuggestion(
      folder: 'Review later',
      label: 'Review later',
      reason:
          'This is the safest bookmark folder for general study and later review.',
    );
  }

  List<String> _collectTajweedFocus(List<QuranAiArabicLine> lines) {
    final focus = <String>[];
    for (final line in lines) {
      final tags = <String>[];
      if (RegExp(r'[نم]ّ').hasMatch(line.text)) {
        tags.add('ghunna');
      }
      if (RegExp(r'[قطبجد][ْۡ]').hasMatch(line.text)) {
        tags.add('qalqala');
      }
      if (RegExp(r'ٰ|ٓ|ۤ').hasMatch(line.text)) {
        tags.add('madd');
      }
      if (RegExp(r'[ًٌٍ]|ن[ْۡ]').hasMatch(line.text)) {
        tags.add('tanween/noon sakin');
      }
      if (tags.isNotEmpty) {
        focus.add('Line ${line.lineNumber}: ${tags.join(', ')}');
      }
      if (focus.length >= 5) {
        break;
      }
    }
    return focus;
  }

  _LineMatch? _findBestLineMatch(
    String input,
    List<QuranAiArabicLine> lines,
  ) {
    if (lines.isEmpty) {
      return null;
    }

    final normalizedInput = _normalizeArabic(input);
    if (normalizedInput.isEmpty) {
      return null;
    }

    _LineMatch? bestMatch;
    for (final line in lines) {
      final normalizedLine = _normalizeArabic(line.text);
      if (normalizedLine.isEmpty) {
        continue;
      }
      final score = _tokenSimilarity(normalizedInput, normalizedLine);
      if (bestMatch == null || score > bestMatch.score) {
        bestMatch = _LineMatch(
          lineNumber: line.lineNumber,
          text: line.text,
          score: score,
        );
      }
    }
    return bestMatch;
  }

  Iterable<String> _missingWords(String input, String target) sync* {
    final inputTokens =
        _normalizeArabic(input).split(' ').where((e) => e.isNotEmpty).toSet();
    final targetTokens =
        _normalizeArabic(target).split(' ').where((e) => e.isNotEmpty);
    for (final token in targetTokens) {
      if (!inputTokens.contains(token)) {
        yield token;
      }
    }
  }

  String _bestTheme(QuranAiPageContext context) {
    final haystack = '${context.translationUr} ${context.translationEn} '
            '${context.chapterInfo} ${context.tafsirExcerpt}'
        .toLowerCase();
    if (_containsAny(haystack, <String>['prayer', 'salah', 'salat', 'namaz'])) {
      return 'worship and salah';
    }
    if (_containsAny(haystack, <String>['patience', 'sabr', 'steadfast'])) {
      return 'patience and steadiness';
    }
    if (_containsAny(haystack, <String>['mercy', 'forgive', 'رحمة'])) {
      return 'mercy and return to Allah';
    }
    if (_containsAny(haystack, <String>['faith', 'believe', 'iman'])) {
      return 'faith and guidance';
    }
    if (_containsAny(haystack, <String>['warning', 'fire', 'jahannam'])) {
      return 'warning and consequences';
    }
    return 'guidance and action';
  }

  bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  String _trimText(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength - 3).trim()}...';
  }

  String _localize(
    ReaderAiSettings settings, {
    required String urdu,
    required String english,
  }) {
    switch (settings.responseLanguage) {
      case AiResponseLanguage.urdu:
        return urdu;
      case AiResponseLanguage.english:
        return english;
      case AiResponseLanguage.bilingual:
        return '$urdu\n\n$english';
    }
  }

  String _normalizeArabic(String value) {
    return value
        .replaceAll(RegExp(r'[0-9٠-٩]'), ' ')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll(RegExp(r'[^\u0621-\u063A\u0641-\u064A\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _tokenSimilarity(String a, String b) {
    final aTokens = a.split(' ').where((entry) => entry.isNotEmpty).toList();
    final bTokens = b.split(' ').where((entry) => entry.isNotEmpty).toList();
    if (aTokens.isEmpty || bTokens.isEmpty) {
      return 0;
    }

    final remaining = List<String>.from(bTokens);
    var matches = 0;
    for (final token in aTokens) {
      final index = remaining.indexOf(token);
      if (index >= 0) {
        matches += 1;
        remaining.removeAt(index);
      }
    }

    final overlap = (2 * matches) / (aTokens.length + bTokens.length);
    if (b.contains(a) || a.contains(b)) {
      return overlap + 0.18;
    }
    return overlap;
  }
}

class _LineMatch {
  const _LineMatch({
    required this.lineNumber,
    required this.text,
    required this.score,
  });

  final int lineNumber;
  final String text;
  final double score;
}

class _AiDataPlan {
  const _AiDataPlan(this.surahIds, this.queries, this.references, this.collectionIds);
  final Set<int> surahIds;
  final List<String> queries;
  final List<String> references;
  final Set<String> collectionIds;
  static _AiDataPlan parse(Map<String, dynamic>? value, Map<String, _AiSearchVerse> index) {
    if (value == null) return const _AiDataPlan({}, [], [], {});
    const keys = {'surahIds', 'queries', 'references', 'collectionIds'};
    if (value.length != keys.length || value.keys.any((key) => !keys.contains(key))) {
      throw const FormatException('Invalid Quran search plan.');
    }
    List<Object?> list(String key, int limit) {
      final items = value[key];
      if (items is! List || items.length > limit) throw const FormatException('Invalid Quran search plan.');
      return items;
    }
    final ids = list('surahIds', 4);
    if (ids.any((id) => id is! int || id < 1 || id > 114) || ids.toSet().length != ids.length) {
      throw const FormatException('Invalid Surah in search plan.');
    }
    List<String> strings(String key, int limit, int length) {
      final values = list(key, limit);
      if (values.any((item) => item is! String || item.trim().isEmpty || item.length > length) ||
          values.toSet().length != values.length) {
        throw const FormatException('Invalid Quran search plan.');
      }
      return values.cast<String>();
    }
    final queries = strings('queries', 3, 120);
    final references = strings('references', 4, 12);
    if (references.any((key) => !RegExp(r'^\d{1,3}:\d{1,3}$').hasMatch(key) || !index.containsKey(key))) {
      throw const FormatException('Invalid Ayah in search plan.');
    }
    final collections = strings('collectionIds', 4, 64);
    if (collections.any((id) => !quranStudyCollections.any((item) => item.id == id))) {
      throw const FormatException('Invalid study collection in search plan.');
    }
    return _AiDataPlan(ids.cast<int>().toSet(), queries, references, collections.toSet());
  }
}

class _AiSearchChapter {
  const _AiSearchChapter(this.id, this.simple, this.complex, this.arabic,
      this.translated, this.count, this.revelation);
  final int id;
  final String simple;
  final String complex;
  final String arabic;
  final String translated;
  final int count;
  final String revelation;
  Set<String> aliases({required bool explicit}) {
    final names = <String>{simple, complex, arabic,
      simple.replaceFirst(RegExp(r'^(?:Al|An|Ar|Ash|As|At|Ad|Az)-'), ''),
      complex.replaceFirst(RegExp(r'^(?:Al|An|Ar|Ash|As|At|Ad|Az)-'), ''),
      if (explicit) translated,
      if (explicit) translated.replaceFirst(RegExp(r'^The\s+'), ''),
      if (explicit) arabic.replaceFirst(RegExp(r'^ال'), ''),
      ...switch (id) {
        1 => const ['fatiha', 'al fatiha'],
        6 => const ['inam', 'inaam', 'anaam', 'al inam', 'al inaam', 'al anaam'],
        36 => const ['yaseen', 'ya seen'],
        55 => const ['rehman', 'ar rehman', 'al rehman', 'al rahman'],
        _ => const <String>[],
      },
    };
    return names.map(_entityName).where((name) => name.isNotEmpty).toSet();
  }
}

String _entityName(String value) => _normalizeAiSearch(value
    .replaceAll(RegExp(r'[ĥḩ]'), 'h').replaceAll(RegExp(r'[đḏ]'), 'd')
    .replaceAll('ş', 's').replaceAll('ţ', 't')).replaceAll(' ', '');

String _entitySound(String name) {
  var value = name.replaceAll('ee', 'i').replaceAll('oo', 'u').replaceAll('aa', 'a');
  value = value.replaceAllMapped(RegExp(r'([a-z])\1+'), (match) => match[1]!);
  if (value.length > 4 && value.endsWith('h')) value = value.substring(0, value.length - 1);
  return value;
}

int _nameDistance(String a, String b) {
  var previous = List.generate(b.length + 1, (index) => index);
  for (var i = 0; i < a.length; i++) {
    final next = List<int>.filled(b.length + 1, 0)..[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final substitution = previous[j] + (a[i] == b[j] ? 0 : 1);
      final insertion = next[j] + 1;
      final deletion = previous[j + 1] + 1;
      next[j + 1] = substitution < insertion ? substitution : insertion;
      if (deletion < next[j + 1]) next[j + 1] = deletion;
    }
    previous = next;
  }
  return previous.last;
}

({int id, int distance})? _matchAiChapter(String phrase,
    List<_AiSearchChapter> chapters, {required bool explicit, bool fuzzy = false}) {
  final name = _entityName(phrase);
  if (name.isEmpty) return null;
  if (explicit && RegExp(r'^\d{1,3}$').hasMatch(name)) {
    final id = int.parse(name);
    return id >= 1 && id <= 114 ? (id: id, distance: 0) : null;
  }
  final exact = chapters.where((item) => item.aliases(explicit: explicit).contains(name)).toList();
  if (exact.length == 1) return (id: exact.single.id, distance: 0);
  if (exact.isNotEmpty || !fuzzy || name.length < 4) return null;
  final sound = _entitySound(name);
  final distances = <({int id, int distance})>[];
  for (final item in chapters) {
    var distance = 1000;
    for (final alias in item.aliases(explicit: explicit)) {
      final current = _nameDistance(sound, _entitySound(alias));
      if (current < distance) distance = current;
    }
    distances.add((id: item.id, distance: distance));
  }
  distances.sort((a, b) => a.distance.compareTo(b.distance));
  final best = distances.first;
  final maximum = sound.length >= 7 ? 2 : 1;
  return best.distance <= maximum && distances[1].distance > best.distance ? best : null;
}

const _aiChapterMarker = r'(surah|surat|sure|sura|soorah|soora|sooray|suray|sureh|chapter|سوره|سورت)';
final _aiDataCommands = {'please', 'open', 'show', 'read', 'find', 'give', 'tell', 'display',
  'me', 'i', 'want', 'to', 'the', 'of', 'in', 'from', 'and', 'or', 'do',
  'mujhe', 'mujhy', 'muje', 'dikha', 'dikhao', 'dikhaao', 'kholo', 'khol',
  'parho', 'parhao', 'chalao', 'batao', 'bata', 'hai', 'hain', 'ki', 'ke', 'ka', 'e',
  'مجھے', 'دکھاؤ', 'دکھاو', 'کھولو', 'بتاؤ', 'كي', 'كے', 'كا', 'ہے', 'هے',
  'اعطني', 'ارني', 'افتح', 'من', 'في', 'عن', 'فضلا',
  'how', 'many', 'count', 'number', 'verse', 'verses', 'ayah', 'ayahs', 'ayat', 'ayats',
  'kitni', 'kitne', 'ayatein', 'ayatain'}.map(_normalizeAiSearch).toSet();

({Set<int> ids, String remaining}) _resolveAiChapterQuery(String query,
    List<_AiSearchChapter> chapters) {
  final marker = RegExp('^$_aiChapterMarker\$');
  final prefixes = _aiChapterMarker.substring(1, _aiChapterMarker.length - 1).split('|')
    ..sort((a, b) => b.length.compareTo(a.length));
  final tokens = <String>[];
  for (final word in query.split(' ').where((word) => word.isNotEmpty)) {
    if (marker.hasMatch(word)) {
      tokens.add(word);
      continue;
    }
    final attached = prefixes.where((prefix) => word.startsWith(prefix) && word.length > prefix.length);
    if (attached.isEmpty) {
      tokens.add(word);
    } else {
      final prefix = attached.first;
      tokens.addAll([prefix, word.substring(prefix.length)]);
    }
  }
  final removed = <int>{};
  final ids = <int>{};
  for (var i = 0; i < tokens.length; i++) {
    if (!marker.hasMatch(tokens[i])) continue;
    var start = i + 1;
    while (start < tokens.length && const {'e', 'named', 'called'}.contains(tokens[start])) {
      start++;
    }
    ({int id, int distance})? chosen;
    var chosenEnd = start;
    for (final fuzzy in [false, true]) {
      for (var end = start + 1; end <= tokens.length && end <= start + 6; end++) {
        if (tokens.sublist(start, end).any(marker.hasMatch)) break;
        final candidate = _matchAiChapter(tokens.sublist(start, end).join(' '), chapters,
            explicit: true, fuzzy: fuzzy);
        if (candidate != null && (chosen == null || candidate.distance < chosen.distance ||
            (candidate.distance == chosen.distance && end > chosenEnd))) {
          chosen = candidate; chosenEnd = end;
        }
      }
      if (chosen != null) break;
    }
    if (chosen != null) {
      ids.add(chosen.id);
      for (var position = i; position < chosenEnd; position++) { removed.add(position); }
    }
  }
  if (ids.isNotEmpty) {
    return (ids: ids, remaining: [for (var i = 0; i < tokens.length; i++)
      if (!removed.contains(i) && !_aiDataCommands.contains(tokens[i])) tokens[i]].join(' '));
  }
  final bare = tokens.where((word) => !_aiDataCommands.contains(word)).join(' ');
  final whole = _matchAiChapter(bare, chapters, explicit: false);
  return whole == null ? (ids: <int>{}, remaining: query) : (ids: {whole.id}, remaining: '');
}

String? _explicitAiSearchKey(String query) {
  final reference = RegExp(r'(?:^|\s)(\d+)\s*:\s*(\d+)(?=\s|$)').firstMatch(query);
  if (reference != null) return '${int.parse(reference[1]!)}:${int.parse(reference[2]!)}';
  return const ['ayatul kursi', 'ayat ul kursi', 'ayat al kursi', 'ayatal kursi',
    'ayatulkursi', 'ayatalkursi', 'آیت الکرسی', 'آية الكرسي', 'اية الكرسي']
      .any((alias) => _hasAiSearchTerm(query, _normalizeAiSearch(alias))) ? '2:255' : null;
}

class _AiDataLocation {
  const _AiDataLocation(this.remaining, this.juz, this.page);
  final String remaining;
  final int? juz;
  final int? page;
  static _AiDataLocation parse(String query) {
    final juz = RegExp(r'(?:^|\s)(?:juz|para|parah|sipara|siparah|جزء|جز|پاره|پارا|سپاره)\s*(\d{1,2})(?=\s|$)').firstMatch(query);
    final page = RegExp(r'(?:^|\s)(?:canonical page|page|صفحہ|صفحه)\s*(\d{1,3})(?=\s|$)').firstMatch(query);
    final juzNumber = juz == null ? null : int.parse(juz[1]!);
    final pageNumber = page == null ? null : int.parse(page[1]!);
    if (juzNumber != null && (juzNumber < 1 || juzNumber > 30) ||
        pageNumber != null && (pageNumber < 1 || pageNumber > 604)) {
      throw const FormatException('Use a Juz from 1 to 30 or a canonical page from 1 to 604.');
    }
    var remaining = query;
    if (juz != null) remaining = remaining.replaceFirst(juz[0]!, ' ');
    if (page != null) remaining = remaining.replaceFirst(page[0]!, ' ');
    if (juz != null || page != null) {
      remaining = remaining.split(' ')
        .where((word) => word.isNotEmpty && !_aiDataCommands.contains(word)).join(' ');
    }
    return _AiDataLocation(remaining, juzNumber, pageNumber);
  }
}

String _aiLatinStem(String value) {
  var word = value;
  if (word.length > 5 && word.endsWith('ies')) return '${word.substring(0, word.length - 3)}y';
  for (final suffix in ['ingly', 'edly', 'ing', 'ness', 'ed', 'ly', 'es', 's']) {
    if (word.length > suffix.length + 2 && word.endsWith(suffix)) {
      word = word.substring(0, word.length - suffix.length); break;
    }
  }
  if (word.length > 4 && word.endsWith('e')) word = word.substring(0, word.length - 1);
  return word;
}

class _AiDataQuery {
  _AiDataQuery(this.phrase, {this.highRecall = false});
  final String phrase;
  final bool highRecall;
  late final Match? root = RegExp(r'^(?:arabic\s+)?(?:root|جذر|جذور|ماده)\s+(.+)$').firstMatch(phrase);
  late final Match? pos = RegExp(r'^(?:(?:pos|part of speech)\s+)?(nouns?|verbs?|adjectives?|pronouns?|prepositions?)$').firstMatch(phrase);
  late final List<_AiSearchTopic> topics = _aiSearchTopics.where((topic) => topic.mentions(phrase)).toList();
  late final Set<String> tokens = _buildTokens();
  Set<String> _buildTokens() {
    final result = phrase.split(' ').where((token) => token.length >= 2 &&
        !_aiSearchStopwords.contains(token) && !topics.any((topic) => topic.mentions(token))).toSet();
    if (topics.isEmpty && result.isEmpty && const {'allah', 'الله', 'god', 'lord'}.contains(phrase)) result.add(phrase);
    return result;
  }
  int score(_AiSearchVerse verse) {
    final rootMatch = root;
    if (rootMatch != null) {
      return verse.roots.contains(rootMatch[1]!.replaceAll(' ', '')) ? 20000 : 0;
    }
    final posMatch = pos;
    if (posMatch != null) {
      final value = posMatch[1]!;
      final tag = value.startsWith('noun') ? 'N' : value.startsWith('verb') ? 'V'
          : value.startsWith('adject') ? 'ADJ' : value.startsWith('pronoun') ? 'PRON' : 'P';
      return verse.partsOfSpeech.contains(tag) ? 18000 : 0;
    }
    final total = topics.length + tokens.length;
    if (total == 0) return 0;
    var matched = 0;
    var curated = 0;
    for (final topic in topics) {
      final curatedHit = topic.references.contains(verse.reference);
      if (curatedHit || topic.terms.any(verse.containsData)) matched++;
      if (curatedHit) curated++;
    }
    matched += tokens.where(verse.containsData).length;
    if (matched < (highRecall || total == 1 ? 1 : (total * 0.67).ceil())) return 0;
    return matched * 10000 ~/ total + matched * 300 +
        (verse.containsData(phrase) ? 2000 : 0) + curated * 150;
  }
}
String _normalizeAiSearch(String value) {
  const latin = {'ā': 'a', 'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
    'ī': 'i', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ū': 'u', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ē': 'e', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'ō': 'o', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o',
    'ḥ': 'h', 'ṣ': 's', 'ḍ': 'd', 'ṭ': 't', 'ẓ': 'z', 'ñ': 'n', 'ç': 'c'};
  var text = value.toLowerCase().split('').map((char) => latin[char] ?? char).join();
  text = text.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
    final code = match[0]!.codeUnitAt(0);
    return (code - (code >= 0x6f0 ? 0x6f0 : 0x660)).toString();
  });
  return text
      .replaceAll(RegExp(r'[\u0300-\u036F\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0898-\u089F\u08CA-\u08FF\u0640\u200C-\u200F]'), '')
      .replaceAll(RegExp(r"['’‘ʿʾ]"), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll(RegExp(r'[ىیېئ]'), 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll(RegExp(r'[کڪ]'), 'ك')
      .replaceAll(RegExp(r'[ةۃہھ]'), 'ه')
      .replaceAll(RegExp(r'[^a-z0-9\u0621-\u063A\u0641-\u064A:\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _hasAiSearchTerm(String text, String term) {
  if (term.isEmpty) return false;
  if (' $text '.contains(' $term ')) return true;
  if (!RegExp(r'^[\u0621-\u064A]+$').hasMatch(term)) return false;
  return const ['و', 'ف', 'ب', 'ل', 'ك', 'وب', 'ول', 'فب', 'ال', 'وال', 'بال', 'لل', 'كال', 'فال']
      .any((prefix) => ' $text '.contains(' $prefix$term '));
}

String _studyDigits(String value) => value.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
  final code = match[0]!.codeUnitAt(0);
  return (code - (code >= 0x6f0 ? 0x6f0 : 0x660)).toString();
});

final _studyFollowups = const ['more', 'more detail', 'explain more', 'explain further',
  'tell me more', 'continue', 'again', 'explain this', 'explain this ayah',
  'aur batao', 'mazeed', 'مزید', 'مزید بتاؤ', 'اس کی وضاحت',
  'المزيد', 'تابع', 'اشرح اكثر'].map(_normalizeAiSearch).toSet();

const _studyLookupContext = QuranAiPageContext(pageNumber: 0, standardPageNumber: 0,
  pageReference: '', mushafEditionLabel: '', chapterName: null, chapterSummary: '',
  chapterInfo: '', tafsirExcerpt: '', translationUr: '', translationEn: '',
  arabicLines: [], verseKeys: [], notes: '', dailyProgressSummary: '');

final _aiArabicWord = RegExp(r'^[\u0621-\u064A]+$');

class _AiSearchVerse {
  _AiSearchVerse(QuranStudyVerse verse, String Function(String) normalize,
      {required this.page, required this.juz})
      : reference = verse.reference, chapterName = verse.chapterName,
        english = verse.english, urdu = verse.urdu, arabic = verse.arabic,
        fields = [normalize(verse.english), normalize(verse.urdu), normalize(verse.arabic)],
        roots = verse.words.expand((word) => (word.root ?? '').split('/'))
          .map((root) => normalize(root).replaceAll(' ', '')).where((root) => root.isNotEmpty).toSet(),
        partsOfSpeech = verse.words.expand((word) => word.partOfSpeech.split(' + ')).toSet(),
        wordFields = verse.words.expand((word) => [if (word.meaning != null) normalize(word.meaning!),
          if (word.transliteration != null) normalize(word.transliteration!)]).toList();
  final String reference;
  final String chapterName;
  final String english;
  final String urdu;
  final String arabic;
  final int page;
  final Set<int> juz;
  final Set<String> roots;
  final Set<String> partsOfSpeech;
  final List<String> wordFields;
  int get chapterId => int.parse(reference.split(':').first);
  int get verseNumber => int.parse(reference.split(':').last);
  late final Set<String> _stems = fields.expand((text) => text.split(' '))
    .where((word) => RegExp(r'^[a-z]{3,}$').hasMatch(word)).map(_aiLatinStem).toSet();
  bool containsData(String term) => contains(term) || roots.contains(term) ||
    wordFields.any((field) => _hasAiSearchTerm(field, term) || field.replaceAll(' ', '') == term) ||
    (RegExp(r'^[a-z]{3,}$').hasMatch(term) && _stems.contains(_aiLatinStem(term)));
  QuranAiCanonicalVerse get canonical => QuranAiCanonicalVerse(verseKey: reference,
    chapterName: chapterName, arabic: arabic, translationEn: english, translationUr: urdu);
  final List<String> fields;
  late final Set<String> _tokens = fields.expand((text) => text.split(' ')).toSet();
  bool contains(String term) {
    if (term.contains(' ')) return fields.any((text) => _hasAiSearchTerm(text, term));
    if (_tokens.contains(term)) return true;
    return _aiArabicWord.hasMatch(term) &&
        const ['و', 'ف', 'ب', 'ل', 'ك', 'وب', 'ول', 'فب', 'ال', 'وال', 'بال', 'لل', 'كال', 'فال']
            .any((prefix) => _tokens.contains('$prefix$term'));
  }
}

class _AiSearchTopic {
  _AiSearchTopic(List<String> values, {List<String> collections = const [], bool duas = false})
      : terms = values.map(_normalizeAiSearch).toSet(),
        references = quranStudyCollections.where((collection) =>
            collections.contains(collection.id) || (duas && collection.isDua))
            .expand((collection) => collection.references).toSet();
  final Set<String> terms;
  final Set<String> references;
  bool mentions(String query) => terms.any((term) {
    if (_hasAiSearchTerm(query, term)) return true;
    if (!RegExp(r'^[a-z]+$').hasMatch(term)) return false;
    return query.split(' ').any((token) => token.startsWith(term) &&
        const {'kesath', 'kesaath', 'wali', 'wale', 'waliayat', 'kiayat', 'keayat'}
            .contains(token.substring(term.length)));
  });
}

final _aiSearchStopwords = <String>{
  'a', 'an', 'the', 'of', 'for', 'and', 'or', 'to', 'in', 'on', 'with', 'from',
  'me', 'us', 'is', 'are', 'some', 'can', 'you', 'that', 'this', 'all', 'my', 'your',
  'i', 'want', 'where', 'does', 'do', 'did', 'what', 'which', 'how', 'about',
  'talk', 'talks', 'say', 'says', 'discuss', 'discusses', 'regarding', 'related',
  'teach', 'teaches', 'please', 'show', 'find', 'give', 'tell', 'explain',
  'quran', 'koran', 'holy', 'verse', 'verses', 'ayah', 'ayahs', 'ayat', 'ayats', 'surah',
  'prophet', 'alaihissalam', 'alaihissalaam', 'alaihis', 'salam', 'عليه', 'علیہ', 'السلام',
  'ke', 'ki', 'ka', 'kay', 'ko', 'hai', 'hain', 'mein', 'main', 'mujhe', 'batao',
  'bataiye', 'dikhao', 'dhundo', 'bare', 'baray', 'aur', 'se', 'par',
  'wali', 'wale', 'waliayat', 'waliayaat', 'sath', 'saath', 'kesath', 'kesaath',
  'قرآن', 'قران', 'مجھے', 'میں', 'کے', 'کی', 'کا', 'اور', 'سے', 'پر', 'متعلق',
  'بارے', 'آیت', 'آیات', 'کوئی', 'بتاؤ', 'دکھاؤ', 'کہاں', 'کہ', 'ہے', 'ہیں', 'والی',
  'ساتھ', 'والا', 'والے', 'بھی',
  'القرآن', 'القران', 'عن', 'في', 'من', 'ما', 'هي', 'هو', 'التي', 'الذي', 'هل',
  'اذكر', 'اريد', 'اعطني', 'ارني', 'ابحث', 'اين', 'اية', 'ايات', 'سورة',
  'يتحدث', 'تتحدث', 'حول', 'مع', 'الله', 'allah', 'god', 'lord',
}.map(_normalizeAiSearch).toSet();

final _aiSearchTopics = <_AiSearchTopic>[
  _AiSearchTopic(['prayer', 'prayers', 'salah', 'salat', 'namaz', 'نماز', 'صلاة', 'الصلاة', 'صلوة', 'الصلوة']),
  _AiSearchTopic(['patience', 'patient', 'patiently', 'persevere', 'sabr', 'sabar', 'صبر', 'الصبر', 'صابرين'], collections: ['patience']),
  _AiSearchTopic(['dua', 'duas', 'duaa', 'supplication', 'supplications', 'invoke', 'invocation', 'call upon', 'دعا', 'دعاء', 'الدعاء', 'ربنا'], duas: true),
  _AiSearchTopic(['forgiveness', 'forgive', 'forgiven', 'forgiving', 'maghfirat', 'bakhshish', 'maafi', 'maaf', 'معافی', 'معاف', 'مغفرت', 'بخشش', 'استغفار', 'غفران', 'اغفر', 'غفور'], collections: ['repentance']),
  _AiSearchTopic(['musa', 'moosa', 'moses', 'موسى', 'موسی', 'موسي']),
  _AiSearchTopic(['pharaoh', 'firawn', 'firaun', 'فرعون']),
  _AiSearchTopic(['mercy', 'merciful', 'rahmat', 'rehmat', 'رحمت', 'رحمة', 'رحيم'], collections: ['mercy']),
  _AiSearchTopic(['trust', 'rely', 'reliance', 'tawakkul', 'tawakal', 'بھروسہ', 'توكل', 'توکل'], collections: ['trust']),
  _AiSearchTopic(['parents', 'parent', 'mother', 'father', 'walidain', 'والدین', 'والدين', 'ماں', 'باپ'], collections: ['family']),
  _AiSearchTopic(['knowledge', 'learn', 'learning', 'read', 'ilm', 'علم', 'تعلم', 'اقرأ'], collections: ['learning', 'knowledge']),
  _AiSearchTopic(['gratitude', 'grateful', 'thank', 'thanks', 'thankful', 'shukar', 'shukr', 'شکر', 'شكر'], collections: ['gratitude', 'gratitude-dua']),
  _AiSearchTopic(['charity', 'charities', 'alms', 'zakat', 'zakaat', 'sadaqah', 'زكاة', 'زکوۃ', 'صدقہ', 'صدقه'], collections: ['charity']),
  _AiSearchTopic(['fasting', 'fast', 'sawm', 'roza', 'روزہ', 'روزه', 'صوم', 'صيام']),
  _AiSearchTopic(['faith', 'believe', 'believers', 'iman', 'imaan', 'ایمان', 'ايمان']),
  _AiSearchTopic(['taqwa', 'righteous', 'righteousness', 'god consciousness', 'تقوى', 'تقوی', 'پرہیزگاری']),
  _AiSearchTopic(['paradise', 'jannah', 'heaven', 'جنت', 'جنة']),
  _AiSearchTopic(['hell', 'jahannam', 'دوزخ', 'جهنم']),
  _AiSearchTopic(['justice', 'just', 'fairness', 'عدل', 'انصاف'], collections: ['justice']),
];
