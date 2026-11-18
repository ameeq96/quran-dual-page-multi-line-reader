import 'quran_search_result.dart';

enum AiResponseLanguage {
  urdu,
  english,
  bilingual,
}

enum AiResponseDepth {
  fast,
  balanced,
  deep,
}

extension AiResponseDepthX on AiResponseDepth {
  String get storageValue => switch (this) {
        AiResponseDepth.fast => 'fast',
        AiResponseDepth.balanced => 'balanced',
        AiResponseDepth.deep => 'deep',
      };

  String get label => switch (this) {
        AiResponseDepth.fast => 'Fast',
        AiResponseDepth.balanced => 'Balanced',
        AiResponseDepth.deep => 'Deep',
      };

  String get promptLabel => switch (this) {
        AiResponseDepth.fast =>
          'Prefer short answers, minimal context, and the quickest helpful output.',
        AiResponseDepth.balanced =>
          'Balance speed and depth. Use concise explanation with enough detail to be useful.',
        AiResponseDepth.deep =>
          'Use slightly deeper explanation, stronger structure, and more complete study help.',
      };

  static AiResponseDepth fromStorageValue(String? value) {
    return AiResponseDepth.values.firstWhere(
      (entry) => entry.storageValue == value,
      orElse: () => AiResponseDepth.fast,
    );
  }
}

extension AiResponseLanguageX on AiResponseLanguage {
  String get storageValue => switch (this) {
        AiResponseLanguage.urdu => 'urdu',
        AiResponseLanguage.english => 'english',
        AiResponseLanguage.bilingual => 'bilingual',
      };

  String get label => switch (this) {
        AiResponseLanguage.urdu => 'Urdu',
        AiResponseLanguage.english => 'English',
        AiResponseLanguage.bilingual => 'English + Urdu',
      };

  String get promptLabel => switch (this) {
        AiResponseLanguage.urdu =>
          'Answer in easy Urdu with short practical wording.',
        AiResponseLanguage.english =>
          'Answer in clear English with concise practical wording.',
        AiResponseLanguage.bilingual =>
          'Answer in English first, then add a short Urdu follow-up.',
      };

  static AiResponseLanguage fromStorageValue(String? value) {
    return AiResponseLanguage.values.firstWhere(
      (entry) => entry.storageValue == value,
      orElse: () => AiResponseLanguage.urdu,
    );
  }
}

enum QuranAiTool {
  explainer,
  smartSearch,
  hifzCoach,
  tafsirAssistant,
  studyNotes,
  translationSimplifier,
  askCurrentPage,
  tajweedTutor,
  dailyLesson,
  bookmarkAssistant,
  voiceQna,
  recitationFollow,
  studyChat,
  quranQuiz,
  flashcards,
  revisionPlan,
}

extension QuranAiToolX on QuranAiTool {
  String get title => switch (this) {
        QuranAiTool.explainer => 'AI Quran explainer',
        QuranAiTool.smartSearch => 'AI smart search',
        QuranAiTool.hifzCoach => 'AI hifz coach',
        QuranAiTool.tafsirAssistant => 'AI tafsir assistant',
        QuranAiTool.studyNotes => 'AI study notes',
        QuranAiTool.translationSimplifier => 'Translation simplifier',
        QuranAiTool.askCurrentPage => 'Ask current page',
        QuranAiTool.tajweedTutor => 'AI tajweed tutor',
        QuranAiTool.dailyLesson => 'AI daily lesson',
        QuranAiTool.bookmarkAssistant => 'AI bookmarks assistant',
        QuranAiTool.voiceQna => 'AI voice Q&A',
        QuranAiTool.recitationFollow => 'Recitation follow mode',
        QuranAiTool.studyChat => 'AI study chat',
        QuranAiTool.quranQuiz => 'Quran quiz',
        QuranAiTool.flashcards => 'Quran flashcards',
        QuranAiTool.revisionPlan => 'AI revision plan',
      };

  String get subtitle => switch (this) {
        QuranAiTool.explainer =>
          'Explain the current page, ayah, or surah in simple words.',
        QuranAiTool.smartSearch =>
          'Find ayahs by theme or meaning without exact wording.',
        QuranAiTool.hifzCoach =>
          'Compare recalled lines and identify weak spots.',
        QuranAiTool.tafsirAssistant =>
          'Get short tafsir, context, and ayah background help.',
        QuranAiTool.studyNotes =>
          'Generate study notes, reflection points, and key themes.',
        QuranAiTool.translationSimplifier =>
          'Rewrite difficult translation in simpler language.',
        QuranAiTool.askCurrentPage =>
          'Ask any question about the current page.',
        QuranAiTool.tajweedTutor =>
          'Review likely tajweed focus points on the current page.',
        QuranAiTool.dailyLesson =>
          'Create a short daily lesson with one action point.',
        QuranAiTool.bookmarkAssistant =>
          'Get a smart bookmark label and folder suggestion.',
        QuranAiTool.voiceQna =>
          'Use a transcript or typed question for AI Q&A.',
        QuranAiTool.recitationFollow =>
          'Match a heard phrase to the closest line on the page.',
        QuranAiTool.studyChat => 'Ask follow-up questions using verified Ayah sources.',
        QuranAiTool.quranQuiz => 'Test your understanding with verified Quran text and translations.',
        QuranAiTool.flashcards => 'Review original Arabic with verified translations.',
        QuranAiTool.revisionPlan => 'Build a revision schedule for selected Ayahs.',
      };

  String get actionLabel => switch (this) {
        QuranAiTool.explainer => 'Explain page',
        QuranAiTool.smartSearch => 'Search ayahs',
        QuranAiTool.hifzCoach => 'Review memorization',
        QuranAiTool.tafsirAssistant => 'Open tafsir assistant',
        QuranAiTool.studyNotes => 'Generate notes',
        QuranAiTool.translationSimplifier => 'Simplify translation',
        QuranAiTool.askCurrentPage => 'Ask now',
        QuranAiTool.tajweedTutor => 'Review tajweed',
        QuranAiTool.dailyLesson => 'Create lesson',
        QuranAiTool.bookmarkAssistant => 'Suggest bookmark',
        QuranAiTool.voiceQna => 'Answer question',
        QuranAiTool.recitationFollow => 'Find current line',
        QuranAiTool.studyChat => 'Find study sources',
        QuranAiTool.quranQuiz => 'Create Quran quiz',
        QuranAiTool.flashcards => 'Create flashcards',
        QuranAiTool.revisionPlan => 'Create revision plan',
      };

  bool get expectsUserInput => switch (this) {
        QuranAiTool.explainer => false,
        QuranAiTool.smartSearch => true,
        QuranAiTool.hifzCoach => true,
        QuranAiTool.tafsirAssistant => true,
        QuranAiTool.studyNotes => false,
        QuranAiTool.translationSimplifier => false,
        QuranAiTool.askCurrentPage => true,
        QuranAiTool.tajweedTutor => true,
        QuranAiTool.dailyLesson => false,
        QuranAiTool.bookmarkAssistant => true,
        QuranAiTool.voiceQna => true,
        QuranAiTool.recitationFollow => true,
        QuranAiTool.studyChat => true,
        QuranAiTool.quranQuiz => false,
        QuranAiTool.flashcards => false,
        QuranAiTool.revisionPlan => false,
      };

  String get inputLabel => switch (this) {
        QuranAiTool.explainer => 'Optional focus',
        QuranAiTool.smartSearch => 'Theme or topic',
        QuranAiTool.hifzCoach => 'Paste remembered Arabic lines',
        QuranAiTool.tafsirAssistant => 'Ayah or context question',
        QuranAiTool.studyNotes => 'Optional notes focus',
        QuranAiTool.translationSimplifier => 'Optional target',
        QuranAiTool.askCurrentPage => 'Your question',
        QuranAiTool.tajweedTutor => 'Paste recitation text if available',
        QuranAiTool.dailyLesson => 'Optional daily focus',
        QuranAiTool.bookmarkAssistant => 'Optional bookmark purpose',
        QuranAiTool.voiceQna => 'Paste voice transcript or type question',
        QuranAiTool.recitationFollow => 'Paste heard phrase',
        QuranAiTool.studyChat => 'Study question or follow-up',
        QuranAiTool.quranQuiz => 'Optional quiz topic',
        QuranAiTool.flashcards => 'Optional flashcard topic',
        QuranAiTool.revisionPlan => 'Optional revision focus',
      };

  String get inputHint => switch (this) {
        QuranAiTool.explainer =>
          'Example: explain the faith theme on this page',
        QuranAiTool.smartSearch => 'Example: patience, prayer, Musa',
        QuranAiTool.hifzCoach =>
          'Example: اِنَّ الَّذِيۡنَ كَفَرُوۡا سَوَآءٌ عَلَيۡهِمۡ',
        QuranAiTool.tafsirAssistant =>
          'Example: what is the context of this page?',
        QuranAiTool.studyNotes => 'Example: class notes for students',
        QuranAiTool.translationSimplifier =>
          'Example: simple student-friendly wording',
        QuranAiTool.askCurrentPage =>
          'Example: which ayahs are important here?',
        QuranAiTool.tajweedTutor =>
          'Example: identify madd and ghunna in this line',
        QuranAiTool.dailyLesson => 'Example: a short reflection for today',
        QuranAiTool.bookmarkAssistant =>
          'Example: memorization review or dua folder',
        QuranAiTool.voiceQna => 'Example: what guidance is in this ayah?',
        QuranAiTool.recitationFollow => 'Example: والذين يؤمنون بما انزل اليك',
        QuranAiTool.studyChat => 'Example: patience and prayer, then ask about these Ayahs',
        QuranAiTool.quranQuiz => 'Example: prayer or forgiveness',
        QuranAiTool.flashcards => 'Example: gratitude or trust in Allah',
        QuranAiTool.revisionPlan => 'Example: review the selected Ayahs this week',
      };
}

class ReaderAiSettings {
  const ReaderAiSettings({
    required this.responseLanguage,
    required this.responseDepth,
  });

  const ReaderAiSettings.defaults()
      : responseLanguage = AiResponseLanguage.english,
        responseDepth = AiResponseDepth.fast;

  final AiResponseLanguage responseLanguage;
  final AiResponseDepth responseDepth;

  ReaderAiSettings copyWith({
    AiResponseLanguage? responseLanguage,
    AiResponseDepth? responseDepth,
  }) {
    return ReaderAiSettings(
      responseLanguage: responseLanguage ?? this.responseLanguage,
      responseDepth: responseDepth ?? this.responseDepth,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ReaderAiSettings &&
        other.responseLanguage == responseLanguage &&
        other.responseDepth == responseDepth;
  }

  @override
  int get hashCode => Object.hash(responseLanguage, responseDepth);
}

class QuranAiArabicLine {
  const QuranAiArabicLine({
    required this.lineNumber,
    required this.text,
  });

  final int lineNumber;
  final String text;
}

class QuranAiPageContext {
  const QuranAiPageContext({
    required this.pageNumber,
    required this.standardPageNumber,
    required this.pageReference,
    required this.mushafEditionLabel,
    required this.chapterName,
    required this.chapterSummary,
    required this.chapterInfo,
    required this.tafsirExcerpt,
    required this.translationUr,
    required this.translationEn,
    required this.arabicLines,
    required this.verseKeys,
    required this.notes,
    required this.dailyProgressSummary,
  });

  final int pageNumber;
  final int standardPageNumber;
  final String pageReference;
  final String mushafEditionLabel;
  final String? chapterName;
  final String chapterSummary;
  final String chapterInfo;
  final String tafsirExcerpt;
  final String translationUr;
  final String translationEn;
  final List<QuranAiArabicLine> arabicLines;
  final List<String> verseKeys;
  final String notes;
  final String dailyProgressSummary;

  String toPromptBlock() {
    final buffer = StringBuffer()
      ..writeln('Current page context:')
      ..writeln('- Reader page: $pageNumber')
      ..writeln('- Standard page: $standardPageNumber')
      ..writeln('- Reference: $pageReference')
      ..writeln('- Edition: $mushafEditionLabel');

    if (chapterName != null && chapterName!.trim().isNotEmpty) {
      buffer.writeln('- Surah: $chapterName');
    }
    if (verseKeys.isNotEmpty) {
      buffer.writeln('- Verse keys: ${verseKeys.take(4).join(', ')}');
    }
    if (dailyProgressSummary.trim().isNotEmpty) {
      buffer.writeln('- Reading progress: $dailyProgressSummary');
    }
    if (chapterSummary.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Chapter summary:')
        ..writeln(_trimForAi(chapterSummary, 180));
    }
    if (translationUr.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Urdu translation excerpt:')
        ..writeln(_trimForAi(translationUr, 320));
    }
    if (translationEn.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('English translation excerpt:')
        ..writeln(_trimForAi(translationEn, 220));
    }
    if (arabicLines.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Arabic lines from the page:')
        ..writeln(
          arabicLines
              .take(6)
              .map((line) => 'Line ${line.lineNumber}: ${line.text}')
              .join('\n'),
        );
    }
    if (chapterInfo.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Chapter info:')
        ..writeln(_trimForAi(chapterInfo, 260));
    }
    if (tafsirExcerpt.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Tafsir excerpt:')
        ..writeln(_trimForAi(tafsirExcerpt, 260));
    }
    if (notes.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Saved note for this page:')
        ..writeln(_trimForAi(notes, 120));
    }
    return buffer.toString().trim();
  }

  String _trimForAi(String value, int maxChars) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars).trim()}...';
  }
}

class QuranAiBookmarkSuggestion {
  const QuranAiBookmarkSuggestion({
    required this.folder,
    required this.label,
    required this.reason,
  });

  final String folder;
  final String label;
  final String reason;
}

class QuranAiToolResult {
  const QuranAiToolResult({
    required this.tool,
    required this.output,
    required this.sourceLabel,
    required this.usedOnlineModel,
    this.searchResults = const <QuranSearchResult>[],
    this.bookmarkSuggestion,
    this.matchedLineNumber,
    this.matchedLineText,
    this.canonicalVerses = const <QuranAiCanonicalVerse>[],
    this.quizQuestions = const <QuranAiQuizQuestion>[],
    this.revisionDays = const <QuranAiRevisionDay>[],
    this.textComparison,
    this.selectionLabel = '',
    this.sourceNotes = const <String>[],
    this.contextPageNumber,
    this.contextScopeKey,
  });

  final QuranAiTool tool;
  final String output;
  final String sourceLabel;
  final bool usedOnlineModel;
  final List<QuranSearchResult> searchResults;
  final QuranAiBookmarkSuggestion? bookmarkSuggestion;
  final int? matchedLineNumber;
  final String? matchedLineText;
  final List<QuranAiCanonicalVerse> canonicalVerses;
  final List<QuranAiQuizQuestion> quizQuestions;
  final List<QuranAiRevisionDay> revisionDays;
  final QuranAiTextComparison? textComparison;
  final String selectionLabel;
  final List<String> sourceNotes;
  final int? contextPageNumber;
  final String? contextScopeKey;

  bool get hasSearchResults => searchResults.isNotEmpty;
  bool get hasBookmarkSuggestion => bookmarkSuggestion != null;
  bool get hasMatchedLine =>
      matchedLineNumber != null &&
      (matchedLineText?.trim().isNotEmpty ?? false);
}

class QuranAiCanonicalVerse {
  const QuranAiCanonicalVerse({required this.verseKey, required this.chapterName,
    required this.arabic, required this.translationEn, required this.translationUr});
  final String verseKey;
  final String chapterName;
  final String arabic;
  final String translationEn;
  final String translationUr;
  String translationFor(AiResponseLanguage language) => switch (language) {
    AiResponseLanguage.english => translationEn,
    AiResponseLanguage.urdu => translationUr,
    AiResponseLanguage.bilingual => '$translationEn\n\n$translationUr',
  };
}

class QuranAiStudyMaterial {
  const QuranAiStudyMaterial({required this.selectionLabel, required this.candidates,
    this.searchResults = const <QuranSearchResult>[], this.textComparison});
  final String selectionLabel;
  final List<QuranAiCanonicalVerse> candidates;
  final List<QuranSearchResult> searchResults;
  final QuranAiTextComparison? textComparison;
}

class QuranAiQuizOption {
  const QuranAiQuizOption({required this.verseKey, required this.translation});
  final String verseKey;
  final String translation;
}

class QuranAiQuizQuestion {
  const QuranAiQuizQuestion({required this.verseKey, required this.arabic,
    required this.options, required this.correctOptionIndex});
  final String verseKey;
  final String arabic;
  final List<QuranAiQuizOption> options;
  final int correctOptionIndex;
}

class QuranAiRevisionDay {
  const QuranAiRevisionDay({required this.day, required this.minutes,
    required this.learnReferences, required this.reviewReferences});
  final int day;
  final int minutes;
  final List<String> learnReferences;
  final List<String> reviewReferences;
}

class QuranAiTextComparison {
  const QuranAiTextComparison({required this.verseKey, required this.expected,
    required this.recalled, required this.missingWords, required this.extraWords,
    required this.matchedWordCount, required this.expectedWordCount,
    this.verseKeys = const <String>[]});
  final String verseKey;
  final List<String> verseKeys;
  final String expected;
  final String recalled;
  final List<String> missingWords;
  final List<String> extraWords;
  final int matchedWordCount;
  final int expectedWordCount;
}
