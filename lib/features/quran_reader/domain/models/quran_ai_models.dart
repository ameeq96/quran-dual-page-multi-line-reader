import 'quran_search_result.dart';

enum AiResponseLanguage {
  urdu,
  english,
  bilingual,
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
      };

  String get inputHint => switch (this) {
        QuranAiTool.explainer =>
          'Example: explain the faith theme on this page',
        QuranAiTool.smartSearch =>
          'Example: patience, prayer, Musa',
        QuranAiTool.hifzCoach =>
          'Example: اِنَّ الَّذِيۡنَ كَفَرُوۡا سَوَآءٌ عَلَيۡهِمۡ',
        QuranAiTool.tafsirAssistant =>
          'Example: what is the context of this page?',
        QuranAiTool.studyNotes =>
          'Example: class notes for students',
        QuranAiTool.translationSimplifier =>
          'Example: simple student-friendly wording',
        QuranAiTool.askCurrentPage =>
          'Example: which ayahs are important here?',
        QuranAiTool.tajweedTutor =>
          'Example: identify madd and ghunna in this line',
        QuranAiTool.dailyLesson =>
          'Example: a short reflection for today',
        QuranAiTool.bookmarkAssistant =>
          'Example: memorization review or dua folder',
        QuranAiTool.voiceQna =>
          'Example: what guidance is in this ayah?',
        QuranAiTool.recitationFollow =>
          'Example: والذين يؤمنون بما انزل اليك',
      };
}

class ReaderAiSettings {
  const ReaderAiSettings({
    required this.ollamaEnabled,
    required this.ollamaBaseUrl,
    required this.ollamaModel,
    required this.responseLanguage,
  });

  const ReaderAiSettings.defaults()
      : ollamaEnabled = false,
        ollamaBaseUrl = 'http://127.0.0.1:11434',
        ollamaModel = 'qwen2.5:1.5b-instruct',
        responseLanguage = AiResponseLanguage.english;

  final bool ollamaEnabled;
  final String ollamaBaseUrl;
  final String ollamaModel;
  final AiResponseLanguage responseLanguage;

  String get normalizedOllamaBaseUrl {
    final trimmed = ollamaBaseUrl.trim();
    if (trimmed.isEmpty) {
      return 'http://127.0.0.1:11434';
    }
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  bool get canUseOllama =>
      ollamaEnabled &&
      normalizedOllamaBaseUrl.isNotEmpty &&
      ollamaModel.trim().isNotEmpty;

  ReaderAiSettings copyWith({
    bool? ollamaEnabled,
    String? ollamaBaseUrl,
    String? ollamaModel,
    AiResponseLanguage? responseLanguage,
  }) {
    return ReaderAiSettings(
      ollamaEnabled: ollamaEnabled ?? this.ollamaEnabled,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      responseLanguage: responseLanguage ?? this.responseLanguage,
    );
  }
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
  });

  final QuranAiTool tool;
  final String output;
  final String sourceLabel;
  final bool usedOnlineModel;
  final List<QuranSearchResult> searchResults;
  final QuranAiBookmarkSuggestion? bookmarkSuggestion;
  final int? matchedLineNumber;
  final String? matchedLineText;

  bool get hasSearchResults => searchResults.isNotEmpty;
  bool get hasBookmarkSuggestion => bookmarkSuggestion != null;
  bool get hasMatchedLine =>
      matchedLineNumber != null && (matchedLineText?.trim().isNotEmpty ?? false);
}
