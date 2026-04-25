import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/quran_search_result.dart';

class QuranAiFeatureService {
  QuranAiFeatureService();

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
  }) async {
    if (userInput.isEmpty) {
      return QuranAiToolResult(
        tool: tool,
        output: _localize(
          settings,
          urdu:
              'AI smart search chalane ke liye theme ya topic likho, jaise sabr, namaz, Musa alaihissalam, ya dua.',
          english:
              'Type a theme or topic such as patience, salah, Musa, or dua to run AI smart search.',
        ),
        sourceLabel: 'Local search helper',
        usedOnlineModel: false,
      );
    }

    final terms = _expandSearchTerms(userInput);
    final collected = <QuranSearchResult>[];
    for (final term in terms) {
      collected
        ..addAll(ayahSearch(term).take(8))
        ..addAll(pageSearch(term).take(6));
    }

    final unique = <QuranSearchResult>[];
    final seen = <String>{};
    final lowerQuery = userInput.toLowerCase();
    for (final result in collected) {
      final key =
          '${result.pageNumber}|${result.verseKey ?? ''}|${result.title}';
      if (seen.add(key)) {
        unique.add(result);
      }
    }

    unique.sort((a, b) {
      final aScore = _searchScore(a, lowerQuery);
      final bScore = _searchScore(b, lowerQuery);
      return bScore.compareTo(aScore);
    });

    final topResults = unique.take(12).toList(growable: false);
    final summary = topResults.isEmpty
        ? _localize(
            settings,
            urdu:
                'Is topic par local Quran data mein direct result nahi mila. Thora different lafz, Urdu/English synonym, ya ayah key try karo.',
            english:
                'No direct result was found in local Quran data for this topic. Try a different word, synonym, or verse key.',
          )
        : _localize(
            settings,
            urdu:
                '${topResults.length} relevant result mile. Neeche wali list se page open karke direct jump kar sakte ho.',
            english:
                'Found ${topResults.length} relevant results. Use the list below to jump directly to a page.',
          );

    return QuranAiToolResult(
      tool: tool,
      output: summary,
      sourceLabel: 'Local semantic helper',
      usedOnlineModel: false,
      searchResults: topResults,
    );
  }

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

  Set<String> _expandSearchTerms(String query) {
    final terms = <String>{query};
    final lower = query.toLowerCase();
    const keywordMap = <String, List<String>>{
      'sabr': <String>['patience', 'steadfast', 'صبر'],
      'patience': <String>['sabr', 'steadfast', 'صبر'],
      'namaz': <String>['salah', 'salat', 'prayer', 'الصلاة'],
      'salah': <String>['namaz', 'salat', 'prayer', 'الصلاة'],
      'dua': <String>['supplication', 'ربنا', 'forgive', 'دعا'],
      'musa': <String>['moses', 'musa alaihissalam', 'موسى'],
      'rahmat': <String>['mercy', 'رحمة'],
      'jannah': <String>['paradise', 'garden', 'جنة'],
      'jahannam': <String>['hell', 'fire', 'جهنم'],
      'zakat': <String>['charity', 'spend', 'زكاة'],
      'roza': <String>['fasting', 'sawm', 'صوم'],
      'iman': <String>['faith', 'believe', 'ايمان'],
      'taqwa': <String>['god-consciousness', 'تقوى'],
      'shukar': <String>['gratitude', 'thanks', 'شكر'],
    };

    for (final entry in keywordMap.entries) {
      if (lower.contains(entry.key)) {
        terms.addAll(entry.value);
      }
    }

    if (query.contains(' ')) {
      terms.addAll(
        query
            .split(RegExp(r'\s+'))
            .where((part) => part.trim().length >= 3)
            .map((part) => part.trim()),
      );
    }
    return terms;
  }

  int _searchScore(QuranSearchResult result, String lowerQuery) {
    final title = result.title.toLowerCase();
    final snippet = result.snippet.toLowerCase();
    var score = 0;
    if (title == lowerQuery || (result.verseKey?.toLowerCase() == lowerQuery)) {
      score += 120;
    }
    if (title.contains(lowerQuery)) {
      score += 80;
    }
    if (snippet.contains(lowerQuery)) {
      score += 55;
    }
    if (result.category.toLowerCase().contains('ayah')) {
      score += 12;
    }
    return score;
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
