import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/reader_recording_library.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/services/reader_voice_capture.dart';
import '../../data/services/quran_admin_ai_proxy_service.dart';
import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/quran_search_result.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/reader_skeleton.dart';

class QuranAiStudioScreen extends StatefulWidget {
  const QuranAiStudioScreen({
    super.key,
    required this.controller,
    this.initialTool = QuranAiTool.explainer,
  });

  final QuranReaderController controller;
  final QuranAiTool initialTool;

  @override
  State<QuranAiStudioScreen> createState() => _QuranAiStudioScreenState();
}

class _QuranAiStudioScreenState extends State<QuranAiStudioScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _inputController;
  late final TextEditingController _referenceController;
  late final ReaderVoiceCapture _voiceCapture;
  String _voiceLanguage = 'ar-SA';
  bool _voiceInputSession = false;
  String _voiceBaseInput = '';
  String _lastVoiceTranscript = '';
  QuranAiTool _selectedTool = QuranAiTool.explainer;
  QuranAiToolResult? _result;
  List<_AiOutputBlock> _formattedResultBlocks = const <_AiOutputBlock>[];
  bool _isRunning = false;
  String? _aiErrorMessage;
  int _quizCount = 5;
  int _revisionDays = 7;
  int _minutesPerDay = 10;
  bool _isSaving = false;
  final List<_StudyChatTurn> _chatTurns = [];

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _referenceController = TextEditingController();
    _voiceCapture = ReaderVoiceCapture()..addListener(_onVoiceChanged);
    WidgetsBinding.instance.addObserver(this);
    _selectedTool = widget.initialTool;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceCapture.removeListener(_onVoiceChanged);
    _voiceCapture.dispose();
    _inputController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    if (_voiceCapture.phase == ReaderVoiceCapturePhase.recording) {
      unawaited(_voiceCapture.stop());
    } else if (_voiceCapture.phase == ReaderVoiceCapturePhase.requesting) {
      _cancelVoiceCapture();
    }
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    if (_voiceInputSession) {
      final transcript = _voiceCapture.transcript;
      if (transcript != _lastVoiceTranscript) {
        _lastVoiceTranscript = transcript;
        final input = [_voiceBaseInput, transcript]
            .where((text) => text.isNotEmpty)
            .join('\n');
        _inputController.value = TextEditingValue(
          text: input,
          selection: TextSelection.collapsed(offset: input.length),
        );
      }
      if (!_voiceCapture.isBusy) _voiceInputSession = false;
    }
    setState(() {});
  }

  Future<void> _startVoiceCapture() async {
    if (_isRunning || _voiceCapture.isBusy) return;
    _voiceBaseInput = _inputController.text.trimRight();
    _lastVoiceTranscript = '';
    _voiceInputSession = true;
    await _voiceCapture.start(
      language: _voiceLanguage,
      transcribe: false,
    );
  }

  void _cancelVoiceCapture() {
    if (_voiceInputSession && _voiceCapture.isBusy) {
      _inputController.value = TextEditingValue(
        text: _voiceBaseInput,
        selection: TextSelection.collapsed(offset: _voiceBaseInput.length),
      );
    }
    _voiceInputSession = false;
    _voiceCapture.cancel();
  }

  Future<void> _runTool() async {
    if (_isRunning || _voiceCapture.isBusy) {
      return;
    }
    if (_inputController.text.length > 4000 || _referenceController.text.length > 128) {
      setState(() => _aiErrorMessage = _suiteTr(context,
          'Use at most 4000 input characters and 128 reference characters.'));
      return;
    }
    if (_selectedTool == QuranAiTool.smartSearch &&
        _inputController.text.trim().isEmpty) {
      setState(() {
        _result = null;
        _formattedResultBlocks = const <_AiOutputBlock>[];
        _aiErrorMessage = switch (ReaderLocalization.instance.language) {
          ReaderLanguage.urdu => 'تلاش کے لیے کوئی موضوع، لفظ یا سورہ:آیت نمبر لکھیں۔',
          ReaderLanguage.romanUrdu =>
            'Search ke liye koi topic, lafz ya Surah:Ayah number likhein.',
          ReaderLanguage.arabic => 'اكتب موضوعًا أو كلمة أو رقم السورة:الآية للبحث.',
          ReaderLanguage.english =>
            'Enter a topic, word, or Surah:Ayah reference to search.',
        };
      });
      return;
    }
    if ((_selectedTool == QuranAiTool.hifzCoach ||
            _selectedTool == QuranAiTool.recitationFollow) &&
        _referenceController.text.trim().isEmpty) {
      setState(() => _aiErrorMessage = _suiteTr(context,
          'Enter an Ayah reference or range for text comparison.'));
      return;
    }
    if (_selectedTool == QuranAiTool.studyChat &&
        _inputController.text.trim().isEmpty) {
      setState(() => _aiErrorMessage = _suiteTr(context, 'Write a study question first.'));
      return;
    }

    final requestedTool = _selectedTool;
    final question = _inputController.text.trim();
    final historyReferences = requestedTool == QuranAiTool.studyChat
        ? _chatTurns.reversed.expand((turn) => turn.references).toSet().take(12).toList()
        : const <String>[];
    QuranAiToolResult? nextResult;
    String? nextError;
    List<_AiOutputBlock> nextFormattedResultBlocks = const <_AiOutputBlock>[];
    setState(() {
      _isRunning = true;
      _aiErrorMessage = null;
      _result = null;
      _formattedResultBlocks = const <_AiOutputBlock>[];
    });
    try {
      nextResult = await widget.controller.runAiTool(
        requestedTool,
        userInput: question,
        referenceSelection: _referenceController.text.trim(),
        historyReferences: historyReferences,
        quizCount: _quizCount,
        revisionDays: _revisionDays,
        minutesPerDay: _minutesPerDay,
      );
      nextFormattedResultBlocks = _AiOutputFormatter.parse(nextResult.output);
      if (!mounted) {
        return;
      }
    } on FormatException catch (error) {
      nextError = _suiteTr(context, error.message.isEmpty
          ? 'Check your Ayah references and input, then try again.' : error.message);
    } on QuranAdminAiException catch (error) {
      nextError = _suiteTr(context, error.message);
    } catch (_) {
      nextError = switch (ReaderLocalization.instance.language) {
        ReaderLanguage.urdu =>
          'اولاما جواب نہیں دے سکا یا درخواست کا وقت ختم ہو گیا۔ دوبارہ کوشش کریں۔ کوئی دوسرا AI فراہم کنندہ استعمال نہیں ہوا۔',
        ReaderLanguage.romanUrdu =>
          'Ollama jawab nahi de saka ya request ka waqt khatam ho gaya. Dobara koshish karein. Koi doosra AI provider istemal nahi hua.',
        ReaderLanguage.arabic =>
          'تعذر الحصول على إجابة من Ollama أو انتهت مهلة الطلب. حاول مجددًا. لم يُستخدم أي مزود ذكاء اصطناعي آخر.',
        ReaderLanguage.english =>
          'Ollama could not answer or the request timed out. Try again. No other AI provider was used.',
      };
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
          _aiErrorMessage = nextError;
          if (nextResult != null) {
            _result = nextResult;
            _formattedResultBlocks = nextFormattedResultBlocks;
            if (requestedTool == QuranAiTool.studyChat) {
              _chatTurns.add(_StudyChatTurn(question, nextResult.output,
                  nextResult.canonicalVerses.map((verse) => verse.verseKey).toList()));
              if (_chatTurns.length > 6) _chatTurns.removeAt(0);
              _inputController.clear();
            }
          }
        });
      }
    }
  }

  Future<void> _copyStudyResult(QuranAiToolResult result) async {
    final text = <String>[
      if (result.selectionLabel.isNotEmpty) result.selectionLabel,
      result.output,
      for (final verse in result.canonicalVerses)
        '${verse.verseKey} · ${verse.chapterName}\n${verse.arabic}\n'
            '${verse.translationFor(widget.controller.aiSettings.responseLanguage)}',
      for (final day in result.revisionDays)
        '${_suiteTr(context, 'Day')} ${day.day} · ${day.minutes} ${_suiteTr(context, 'minutes')}\n'
            '${_suiteTr(context, 'Learn')}: ${day.learnReferences.join(', ')}\n'
            '${_suiteTr(context, 'Review')}: ${day.reviewReferences.join(', ')}',
      result.sourceLabel,
      ...result.sourceNotes,
    ].join('\n\n');
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_suiteTr(context, 'Copied with sources.'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_suiteTr(context, 'Copy failed. Please try again.'))));
      }
    }
  }

  Future<void> _saveStudyResult(QuranAiToolResult result) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.controller.saveAiStudyResultAsNote(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_suiteTr(context, 'Added to your existing page note.'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
            _suiteTr(context, 'The note could not be saved. Return to the original reading page and try again.'))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openStudyReference(QuranAiToolResult result, String key) async {
    final targets = result.searchResults.where((hit) => hit.verseKey == key);
    if (targets.isNotEmpty) await _openSearchResult(targets.first);
  }

  Future<void> _openCurrentPageInReader() async {
    final pageNumber = widget.controller.currentPageNumber;
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(pageNumber);
  }

  Future<void> _openSearchResult(QuranSearchResult result) async {
    await widget.controller.jumpToPage(result.pageNumber);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(result.pageNumber);
  }

  Future<void> _applyBookmark(QuranAiBookmarkSuggestion suggestion) async {
    await widget.controller.applyAiBookmarkSuggestion(suggestion);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(context, 'Saved to ${suggestion.folder}')),
      ),
    );
  }

  String _editionLabel(MushafEdition edition) {
    return switch (edition) {
      MushafEdition.lines10 => '10 lines',
      MushafEdition.lines13 => '13 lines',
      MushafEdition.lines14 => '14 lines',
      MushafEdition.lines15 => '15 lines',
      MushafEdition.lines16 => '16 lines',
      MushafEdition.lines17 => '17 lines',
      MushafEdition.kanzulIman => 'Kanzul Iman',
      _ => edition.label,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller.aiSettingsListenable,
        widget.controller.settingsListenable,
        widget.controller.experienceListenable,
      ]),
      builder: (context, _) {
        final readerSettings = widget.controller.settings;
        final aiSettings = widget.controller.aiSettings;
        final experience = widget.controller.experienceSettings;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final contentInset = screenWidth > 920
            ? (screenWidth - 920) / 2 + 28
            : screenWidth < 600 ? 18.0 : 28.0;
        final themeData = readerSettings.nightMode
            ? AppTheme.dark(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              )
            : AppTheme.light(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              );

        return Theme(
          data: themeData,
          child: Scaffold(
            backgroundColor: themeData.scaffoldBackgroundColor,
            appBar: AppBar(
              title: Text(tr(context, 'AI Studio')),
              centerTitle: false,
            ),
            body: ListView(
              padding: EdgeInsets.fromLTRB(contentInset, 12, contentInset, 32),
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: widget.controller.pageListenable,
                  builder: (context, _, __) {
                    return _OverviewCard(
                      pageReference:
                          widget.controller.buildCurrentPageReference(),
                      editionLabel: _editionLabel(readerSettings.mushafEdition),
                      languageLabel: aiSettings.responseLanguage.label,
                      depthLabel: aiSettings.responseDepth.label,
                      providerLabel: widget.controller.adminAiProviderLabel,
                      modelLabel: widget.controller.adminAiModelLabel,
                      statusLabel: widget.controller.adminAiStatusLabel,
                      endpointLabel: widget.controller.adminAiEndpointLabel,
                    );
                  },
                ),
                const SizedBox(height: 14),
                _ToolPicker(
                  selectedTool: _selectedTool,
                  enabled: !_isRunning && !_voiceCapture.isBusy,
                  aiSettings: aiSettings,
                  languageLocked: widget.controller.isAiLanguageManagedByAdmin,
                  depthLocked: widget.controller.isAiDepthManagedByAdmin,
                  hasAdminAiConfiguration:
                      widget.controller.hasAdminAiConfiguration,
                  onSelectLanguage: widget.controller.setAiResponseLanguage,
                  onSelectDepth: widget.controller.setAiResponseDepth,
                  onSelected: (tool) {
                    _cancelVoiceCapture();
                    setState(() {
                      _selectedTool = tool;
                      _result = null;
                      _aiErrorMessage = null;
                      _formattedResultBlocks = const <_AiOutputBlock>[];
                    });
                  },
                ),
                const SizedBox(height: 14),
                if (_selectedTool != QuranAiTool.smartSearch) ...[
                  _StudySelectionCard(
                    tool: _selectedTool, controller: _referenceController,
                    enabled: !_isRunning && !_voiceCapture.isBusy,
                    quizCount: _quizCount, revisionDays: _revisionDays,
                    minutesPerDay: _minutesPerDay,
                    onQuizCount: (value) => setState(() => _quizCount = value),
                    onRevisionDays: (value) => setState(() => _revisionDays = value),
                    onMinutes: (value) => setState(() => _minutesPerDay = value)),
                  const SizedBox(height: 14),
                ],
                _InputCard(
                  tool: _selectedTool,
                  controller: _inputController,
                  readOnly: _isRunning || _voiceCapture.isBusy,
                ),
                if (_selectedTool == QuranAiTool.voiceQna ||
                    _selectedTool == QuranAiTool.recitationFollow ||
                    _selectedTool == QuranAiTool.hifzCoach ||
                    _selectedTool == QuranAiTool.tajweedTutor) ...[
                  const SizedBox(height: 14),
                  _VoiceInputCard(
                    capture: _voiceCapture,
                    language: _voiceLanguage,
                    onlineRecognition: false,
                    enabled: !_isRunning,
                    onLanguageChanged: (language) {
                      setState(() => _voiceLanguage = language);
                    },
                    onOnlineRecognitionChanged: (_) {},
                    onStart: _startVoiceCapture,
                    onStop: _voiceCapture.stop,
                    onCancel: _cancelVoiceCapture,
                  ),
                  const SizedBox(height: 10),
                  ReaderRecordingSaveControls(capture: _voiceCapture,
                    chapterId: widget.controller.currentChapterSummary?.id,
                    chapterName: widget.controller.currentChapterSummary?.nameSimple),
                ],
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: FilledButton.icon(
                    onPressed: _isRunning || _voiceCapture.isBusy ? null : _runTool,
                    icon: _isRunning
                        ? const ReaderSkeletonBlock(
                            width: 18,
                            height: 18,
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          )
                        : Icon(_toolIcon(_selectedTool)),
                    label: Text(_suiteTr(context, _selectedTool.actionLabel)),
                  ),
                ),
                const SizedBox(height: 14),
                if (_aiErrorMessage != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(_aiErrorMessage!,
                      style: TextStyle(color: themeData.colorScheme.error)),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_selectedTool == QuranAiTool.studyChat && _chatTurns.isNotEmpty) ...[
                  _StudyChatCard(turns: _chatTurns, onClear: _isRunning ? null : () {
                    setState(() {
                      _chatTurns.clear(); _result = null;
                      _formattedResultBlocks = const [];
                    });
                  }),
                  const SizedBox(height: 14),
                ],
                if (_isRunning) ...[
                  const _AiStudioSkeletonCard(),
                ] else if (_result != null) ...[
                  if (_result!.tool != QuranAiTool.studyChat) ValueListenableBuilder<int>(
                    valueListenable: widget.controller.pageListenable,
                    builder: (context, _, __) {
                      return _ResultCard(
                        result: _result!,
                        blocks: _formattedResultBlocks,
                        pageReference:
                            widget.controller.buildCurrentPageReference(),
                        currentPageNumber: widget.controller.currentPageNumber,
                        onOpenCurrentPage: _openCurrentPageInReader,
                      );
                    },
                  ),
                  if (_result!.selectionLabel.isNotEmpty || _result!.sourceNotes.isNotEmpty) ...[
                    const SizedBox(height: 12), _StudySourcesCard(result: _result!),
                  ],
                  if (_result!.quizQuestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _StudyQuizCard(key: ValueKey(_result), result: _result!,
                        onOpen: (key) => _openStudyReference(_result!, key)),
                  ],
                  if (_result!.tool == QuranAiTool.flashcards && _result!.canonicalVerses.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _StudyFlashcards(key: ValueKey(_result), result: _result!,
                        language: aiSettings.responseLanguage,
                        onOpen: (key) => _openStudyReference(_result!, key)),
                  ],
                  if (_result!.revisionDays.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _StudyRevisionCard(result: _result!,
                        onOpen: (key) => _openStudyReference(_result!, key)),
                  ],
                  if (_result!.textComparison != null) ...[
                    const SizedBox(height: 12),
                    _StudyTextComparisonCard(comparison: _result!.textComparison!),
                  ],
                  if (_result!.canonicalVerses.isNotEmpty &&
                      _result!.tool != QuranAiTool.quranQuiz &&
                      _result!.tool != QuranAiTool.flashcards) ...[
                    const SizedBox(height: 12),
                    _StudyVersesCard(result: _result!, language: aiSettings.responseLanguage,
                        onOpen: (key) => _openStudyReference(_result!, key)),
                  ],
                  const SizedBox(height: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: widget.controller.pageListenable,
                    builder: (context, page, _) => Wrap(spacing: 10, runSpacing: 10, children: [
                      if (_result!.tool != QuranAiTool.quranQuiz && _result!.tool != QuranAiTool.flashcards)
                        OutlinedButton.icon(onPressed: () => _copyStudyResult(_result!),
                            icon: const Icon(Icons.copy_rounded), label: Text(_suiteTr(context, 'Copy with sources'))),
                      if (const {QuranAiTool.studyNotes, QuranAiTool.dailyLesson,
                          QuranAiTool.revisionPlan}.contains(_result!.tool))
                        FilledButton.tonalIcon(
                          onPressed: _isSaving || _result!.contextPageNumber != page
                              ? null : () => _saveStudyResult(_result!),
                          icon: const Icon(Icons.note_add_outlined),
                          label: Text(_suiteTr(context, _isSaving ? 'Saving…' : 'Add to page note'))),
                    ]),
                  ),
                  if (_result!.hasMatchedLine) ...[
                    const SizedBox(height: 12),
                    _MatchedLineCard(result: _result!),
                  ],
                  if (_result!.hasBookmarkSuggestion) ...[
                    const SizedBox(height: 12),
                    _BookmarkSuggestionCard(
                      suggestion: _result!.bookmarkSuggestion!,
                      onApply: _applyBookmark,
                    ),
                  ],
                  if (_result!.hasSearchResults && _result!.canonicalVerses.isEmpty) ...[
                    const SizedBox(height: 12),
                    _SearchResultsCard(
                      results: _result!.searchResults,
                      onOpen: _openSearchResult,
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AiStudioSkeletonCard extends StatelessWidget {
  const _AiStudioSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReaderSkeletonBlock(
            width: 140,
            height: 18,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          SizedBox(height: 14),
          ReaderSkeletonLines(
            lineCount: 6,
            lineHeight: 14,
            spacing: 10,
            lastLineWidthFactor: 0.72,
          ),
        ],
      ),
    );
  }
}

IconData _toolIcon(QuranAiTool tool) {
  switch (tool) {
    case QuranAiTool.explainer:
      return Icons.auto_awesome_rounded;
    case QuranAiTool.smartSearch:
      return Icons.travel_explore_rounded;
    case QuranAiTool.hifzCoach:
      return Icons.school_rounded;
    case QuranAiTool.tafsirAssistant:
      return Icons.menu_book_rounded;
    case QuranAiTool.studyNotes:
      return Icons.note_alt_outlined;
    case QuranAiTool.translationSimplifier:
      return Icons.translate_rounded;
    case QuranAiTool.askCurrentPage:
      return Icons.question_answer_outlined;
    case QuranAiTool.tajweedTutor:
      return Icons.graphic_eq_rounded;
    case QuranAiTool.dailyLesson:
      return Icons.wb_sunny_outlined;
    case QuranAiTool.bookmarkAssistant:
      return Icons.bookmark_add_outlined;
    case QuranAiTool.voiceQna:
      return Icons.mic_none_rounded;
    case QuranAiTool.recitationFollow:
      return Icons.hearing_rounded;
    case QuranAiTool.studyChat:
      return Icons.forum_outlined;
    case QuranAiTool.quranQuiz:
      return Icons.quiz_outlined;
    case QuranAiTool.flashcards:
      return Icons.style_outlined;
    case QuranAiTool.revisionPlan:
      return Icons.event_note_outlined;
  }
}

String _suiteTr(BuildContext context, String label) {
  const labels = <String, (String, String, String)>{
    'AI study chat': ('AI mutala guftagu', 'AI مطالعہ گفتگو', 'محادثة الدراسة'),
    'Quran quiz': ('Quran sawalat', 'قرآن سوالات', 'اختبار القرآن'),
    'Quran flashcards': ('Quran yaaddasht cards', 'قرآن یادداشت کارڈز', 'بطاقات القرآن'),
    'AI revision plan': ('AI dohrayi mansuba', 'AI دہرائی منصوبہ', 'خطة المراجعة'),
    'Ask follow-up questions using verified Ayah sources.': ('Mustanad Ayat par mazeed sawal poochhein.', 'مستند آیات پر مزید سوال پوچھیں۔', 'اطرح أسئلة متابعة باستخدام مصادر الآيات الموثقة.'),
    'Test your understanding with verified Quran text and translations.': ('Mustanad Quran aur tarjume se apni samajh jaanchein.', 'مستند قرآن اور ترجمے سے اپنی سمجھ جانچیں۔', 'اختبر فهمك بالنص القرآني والترجمات الموثقة.'),
    'Review original Arabic with verified translations.': ('Asal Arabi aur mustanad tarjume ki dohrayi karein.', 'اصل عربی اور مستند ترجمے کی دہرائی کریں۔', 'راجع النص العربي مع الترجمات الموثقة.'),
    'Build a revision schedule for selected Ayahs.': ('Muntakhib Ayat ka dohrayi jadwal banayein.', 'منتخب آیات کا دہرائی جدول بنائیں۔', 'أنشئ جدول مراجعة للآيات المختارة.'),
    'Find study sources': ('Mutala ke hawale dhoondein', 'مطالعے کے حوالے ڈھونڈیں', 'ابحث عن مصادر الدراسة'),
    'Create Quran quiz': ('Quran sawalat banayein', 'قرآن سوالات بنائیں', 'أنشئ اختبار القرآن'),
    'Create flashcards': ('Yaaddasht cards banayein', 'یادداشت کارڈز بنائیں', 'أنشئ البطاقات'),
    'Create revision plan': ('Dohrayi mansuba banayein', 'دہرائی منصوبہ بنائیں', 'أنشئ خطة مراجعة'),
    'Study question or follow-up': ('Mutala ka sawal ya mazeed sawal', 'مطالعے کا سوال یا مزید سوال', 'سؤال دراسة أو متابعة'),
    'Optional quiz topic': ('Sawalat ka mauzu, ikhtiyari', 'سوالات کا موضوع، اختیاری', 'موضوع الاختبار، اختياري'),
    'Optional flashcard topic': ('Cards ka mauzu, ikhtiyari', 'کارڈز کا موضوع، اختیاری', 'موضوع البطاقات، اختياري'),
    'Optional revision focus': ('Dohrayi ka mauzu, ikhtiyari', 'دہرائی کا موضوع، اختیاری', 'محور المراجعة، اختياري'),
    'Example: patience and prayer, then ask about these Ayahs': ('Misal: sabr aur namaz, phir in Ayat par sawal', 'مثال: صبر اور نماز، پھر ان آیات پر سوال', 'مثال: الصبر والصلاة، ثم اسأل عن هذه الآيات'),
    'Example: prayer or forgiveness': ('Misal: namaz ya maghfirat', 'مثال: نماز یا مغفرت', 'مثال: الصلاة أو المغفرة'),
    'Example: gratitude or trust in Allah': ('Misal: shukr ya Allah par tawakkul', 'مثال: شکر یا اللہ پر توکل', 'مثال: الشكر أو التوكل على الله'),
    'Example: review the selected Ayahs this week': ('Misal: is haftay muntakhib Ayat ki dohrayi', 'مثال: اس ہفتے منتخب آیات کی دہرائی', 'مثال: راجع الآيات المختارة هذا الأسبوع'),
    'Ayah sources': ('Ayat ke hawale', 'آیات کے حوالے', 'مصادر الآيات'),
    'Surah:Ayah or range': ('Surah:Ayah ya had', 'سورہ:آیت یا حد', 'السورة:الآية أو نطاق'),
    'Blank: current Surah excerpt. This is not exact scan-page alignment.': ('Khali: mojooda Surah ka iqtibas. Yeh scan safhay ki exact Ayah mapping nahin.', 'خالی: موجودہ سورہ کا اقتباس۔ یہ اسکین صفحے کی عین آیت میپنگ نہیں۔', 'فارغ: مقتطف من السورة الحالية، وليس مطابقة دقيقة لصفحة المصحف المصورة.'),
    'Enter an Ayah reference or range for text comparison.': ('Matn milane ke liye Ayah ka hawala ya had likhein.', 'متن ملانے کے لیے آیت کا حوالہ یا حد لکھیں۔', 'أدخل مرجع آية أو نطاقًا للمقارنة النصية.'),
    'Write a study question first.': ('Pehle mutala ka sawal likhein.', 'پہلے مطالعے کا سوال لکھیں۔', 'اكتب سؤال الدراسة أولًا.'),
    'Check your Ayah references and input, then try again.': ('Ayat ke hawale aur matn jaanch kar dobara koshish karein.', 'آیات کے حوالے اور متن جانچ کر دوبارہ کوشش کریں۔', 'تحقق من مراجع الآيات والمدخلات ثم حاول مجددًا.'),
    'Use at most 4000 input characters and 128 reference characters.': ('Matn 4000 aur hawalay 128 huroof tak rakhein.', 'متن ۴۰۰۰ اور حوالے ۱۲۸ حروف تک رکھیں۔', 'استخدم ٤٠٠٠ حرف للإدخال و١٢٨ حرفًا للمراجع كحد أقصى.'),
    'Use at most 4000 characters.': ('Zyada se zyada 4000 huroof likhein.', 'زیادہ سے زیادہ ۴۰۰۰ حروف لکھیں۔', 'استخدم ٤٠٠٠ حرف كحد أقصى.'),
    'Select an explicit Ayah or range for written-text practice.': ('Likhe matn ki mashq ke liye wazeh Ayah ya had chunein.', 'لکھے متن کی مشق کے لیے واضح آیت یا حد چنیں۔', 'اختر آية أو نطاقًا محددًا للتدريب النصي.'),
    'Select an Ayah or enter a study topic.': ('Ayah chunein ya mutala ka mauzu likhein.', 'آیت چنیں یا مطالعے کا موضوع لکھیں۔', 'اختر آية أو أدخل موضوع الدراسة.'),
    'Paste the Arabic text you want to compare.': ('Muqablay ke liye Arabi matn paste karein.', 'مقابلے کے لیے عربی متن پیسٹ کریں۔', 'ألصق النص العربي الذي تريد مقارنته.'),
    'Use 1–8 quiz questions, 1–30 days, and 5–120 minutes.': ('1–8 sawal, 1–30 din aur 5–120 minute chunein.', '۱–۸ سوال، ۱–۳۰ دن اور ۵–۱۲۰ منٹ چنیں۔', 'اختر ١–٨ أسئلة و١–٣٠ يومًا و٥–١٢٠ دقيقة.'),
    'Choose unique references from the supplied verified sources.': ('Diye gaye mustanad hawalon mein se mukhtalif hawale chunein.', 'دیے گئے مستند حوالوں میں سے مختلف حوالے چنیں۔', 'اختر مراجع غير مكررة من المصادر الموثقة المقدمة.'),
    'Select at most 12 Ayahs.': ('Zyada se zyada 12 Ayat chunein.', 'زیادہ سے زیادہ ۱۲ آیات چنیں۔', 'اختر ١٢ آية كحد أقصى.'),
    'History and defaults require single Ayah references.': ('Pichhlay hawalon aur default ke liye alag Ayah number chahiye.', 'پچھلے حوالوں اور ڈیفالٹ کے لیے الگ آیت نمبر چاہیے۔', 'يتطلب السجل والقيم الافتراضية مراجع آيات منفردة.'),
    'Use a reference such as 2:255 or a same-Surah range such as 112:1-4.': ('2:255 jaisa hawala ya isi Surah ki had 112:1-4 likhein.', '۲:۲۵۵ جیسا حوالہ یا اسی سورہ کی حد ۱۱۲:۱–۴ لکھیں۔', 'استخدم مرجعًا مثل 2:255 أو نطاقًا في سورة واحدة مثل 112:1-4.'),
    'Use an ordered range of at most 12 Ayahs within one Surah.': ('Aik Surah ki zyada se zyada 12 Ayat tarteeb se chunein.', 'ایک سورہ کی زیادہ سے زیادہ ۱۲ آیات ترتیب سے چنیں۔', 'استخدم نطاقًا مرتبًا لا يتجاوز ١٢ آية في سورة واحدة.'),
    'The selection contains an invalid Quran reference.': ('Intikhab mein Quran ka ghalat hawala hai.', 'انتخاب میں قرآن کا غلط حوالہ ہے۔', 'يتضمن الاختيار مرجعًا قرآنيًا غير صالح.'),
    'Questions': ('Sawalat', 'سوالات', 'الأسئلة'),
    'Days': ('Din', 'دن', 'الأيام'),
    'Minutes per day': ('Rozana minute', 'روزانہ منٹ', 'الدقائق يوميًا'),
    'Follow-ups reuse only the cited Ayahs from this session. The last 12 messages stay here until you leave.': ('Mazeed sawal isi session ki hawala shuda Ayat istemal karte hain. Aakhri 12 paigham yahan se nikalne tak rehte hain.', 'مزید سوال اسی سیشن کی حوالہ شدہ آیات استعمال کرتے ہیں۔ آخری ۱۲ پیغام یہاں سے نکلنے تک رہتے ہیں۔', 'تستخدم المتابعة الآيات المستشهد بها في هذه الجلسة فقط. تبقى آخر ١٢ رسالة حتى مغادرتك.'),
    'Study conversation': ('Mutala guftagu', 'مطالعہ گفتگو', 'محادثة الدراسة'),
    'Clear conversation': ('Guftagu saaf karein', 'گفتگو صاف کریں', 'امسح المحادثة'),
    'Your question': ('Aap ka sawal', 'آپ کا سوال', 'سؤالك'),
    'Source-based study reply': ('Hawalon par mabni jawab', 'حوالوں پر مبنی جواب', 'إجابة دراسية مستندة إلى المصادر'),
    'Sources and limits': ('Hawale aur hudood', 'حوالے اور حدود', 'المصادر والحدود'),
    'Verified Quran text and translation': ('Mustanad Quran matn aur tarjuma', 'مستند قرآن متن اور ترجمہ', 'نص القرآن والترجمة الموثقان'),
    'Open source page': ('Hawalay ka safha kholein', 'حوالے کا صفحہ کھولیں', 'افتح صفحة المصدر'),
    'Question': ('Sawal', 'سوال', 'السؤال'),
    'Score': ('Nateeja', 'نتیجہ', 'النتيجة'),
    'Choose the matching verified translation.': ('Milta hua mustanad tarjuma chunein.', 'ملتا ہوا مستند ترجمہ چنیں۔', 'اختر الترجمة الموثقة المطابقة.'),
    'Correct.': ('Durust.', 'درست۔', 'صحيح.'),
    'Review the correct answer.': ('Durust jawab parhein.', 'درست جواب پڑھیں۔', 'راجع الإجابة الصحيحة.'),
    'Check answer': ('Jawab jaanchein', 'جواب جانچیں', 'تحقق من الإجابة'),
    'Next question': ('Agla sawal', 'اگلا سوال', 'السؤال التالي'),
    'Restart quiz': ('Sawalat dobara shuru karein', 'سوالات دوبارہ شروع کریں', 'أعد الاختبار'),
    'The study exercise is unavailable. Please create it again.': ('Mashq dastiyab nahin. Dobara banayein.', 'مشق دستیاب نہیں۔ دوبارہ بنائیں۔', 'التمرين غير متاح. أنشئه مجددًا.'),
    'Card': ('Card', 'کارڈ', 'البطاقة'),
    'Reveal translation': ('Tarjuma dikhayein', 'ترجمہ دکھائیں', 'أظهر الترجمة'),
    'Hide translation': ('Tarjuma chhupayein', 'ترجمہ چھپائیں', 'أخفِ الترجمة'),
    'Previous card': ('Pichhla card', 'پچھلا کارڈ', 'البطاقة السابقة'),
    'Next card': ('Agla card', 'اگلا کارڈ', 'البطاقة التالية'),
    'Revision schedule': ('Dohrayi ka jadwal', 'دہرائی کا جدول', 'جدول المراجعة'),
    'Day': ('Din', 'دن', 'اليوم'),
    'minutes': ('minute', 'منٹ', 'دقيقة'),
    'Learn': ('Yaad karein', 'یاد کریں', 'احفظ'),
    'Review': ('Dohrayein', 'دہرائیں', 'راجع'),
    'None scheduled.': ('Kuch muqarrar nahin.', 'کچھ مقرر نہیں۔', 'لا شيء مقرر.'),
    'Typed-text comparison': ('Likhe matn ka muqabla', 'لکھے متن کا مقابلہ', 'مقارنة النص المكتوب'),
    'Text comparison only. This does not assess pronunciation or audio.': ('Sirf matn ka muqabla hai. Talaffuz ya audio ki jaanch nahin hoti.', 'صرف متن کا مقابلہ ہے۔ تلفظ یا آڈیو کی جانچ نہیں ہوتی۔', 'مقارنة نصية فقط، ولا تُقيّم النطق أو الصوت.'),
    'Verified Arabic': ('Mustanad Arabi', 'مستند عربی', 'النص العربي الموثق'),
    'Your recalled text': ('Aap ka yaad se likha matn', 'آپ کا یاد سے لکھا متن', 'النص الذي استذكرته'),
    'Matched words': ('Milne wale alfaaz', 'ملنے والے الفاظ', 'الكلمات المطابقة'),
    'Missing words': ('Chhootay hue alfaaz', 'چھوٹے ہوئے الفاظ', 'الكلمات الناقصة'),
    'Extra words': ('Zaid alfaaz', 'زائد الفاظ', 'الكلمات الزائدة'),
    'Copy with sources': ('Hawalon samet copy', 'حوالوں سمیت کاپی', 'انسخ مع المصادر'),
    'Copied with sources.': ('Hawalon samet copy ho gaya.', 'حوالوں سمیت کاپی ہو گیا۔', 'نُسخ مع المصادر.'),
    'Copy failed. Please try again.': ('Copy nahin hua. Dobara koshish karein.', 'کاپی نہیں ہوا۔ دوبارہ کوشش کریں۔', 'تعذر النسخ. حاول مجددًا.'),
    'Add to page note': ('Safhay ki note mein jorein', 'صفحے کی نوٹ میں جوڑیں', 'أضف إلى ملاحظة الصفحة'),
    'Added to your existing page note.': ('Aap ki mojooda note mein jor diya gaya.', 'آپ کی موجودہ نوٹ میں جوڑ دیا گیا۔', 'أُضيف إلى ملاحظة صفحتك الحالية.'),
    'Saving…': ('Mehfooz ho raha hai…', 'محفوظ ہو رہا ہے…', 'جارٍ الحفظ…'),
    'The note could not be saved. Return to the original reading page and try again.': ('Note mehfooz nahin hua. Asal parhne wale safhay par laut kar dobara koshish karein.', 'نوٹ محفوظ نہیں ہوا۔ اصل پڑھنے والے صفحے پر لوٹ کر دوبارہ کوشش کریں۔', 'تعذر حفظ الملاحظة. عُد إلى صفحة القراءة الأصلية وحاول مجددًا.'),
    'Bookmark the current reading page': ('Mojooda parhne wala safha bookmark karein', 'موجودہ پڑھنے والا صفحہ بک مارک کریں', 'أضف علامة لصفحة القراءة الحالية'),
    'This saves the current reading page, not an exact Ayah location.': ('Yeh mojooda parhne wala safha mehfooz karta hai, Ayah ki exact jagah nahin.', 'یہ موجودہ پڑھنے والا صفحہ محفوظ کرتا ہے، آیت کی عین جگہ نہیں۔', 'يحفظ هذا صفحة القراءة الحالية، وليس موضع آية دقيقًا.'),
  };
  final translated = labels[label];
  if (translated == null) return tr(context, label);
  return switch (ReaderLocalization.instance.language) {
    ReaderLanguage.english => label,
    ReaderLanguage.romanUrdu => translated.$1,
    ReaderLanguage.urdu => translated.$2,
    ReaderLanguage.arabic => translated.$3,
  };
}

class _StudyChatTurn {
  const _StudyChatTurn(this.question, this.answer, this.references);
  final String question;
  final String answer;
  final List<String> references;
}

class _StudyPanel extends StatelessWidget {
  const _StudyPanel({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).dividerColor)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
}

class _StudySelectionCard extends StatelessWidget {
  const _StudySelectionCard({required this.tool, required this.controller, required this.enabled,
    required this.quizCount, required this.revisionDays, required this.minutesPerDay,
    required this.onQuizCount, required this.onRevisionDays, required this.onMinutes});
  final QuranAiTool tool;
  final TextEditingController controller;
  final bool enabled;
  final int quizCount, revisionDays, minutesPerDay;
  final ValueChanged<int> onQuizCount, onRevisionDays, onMinutes;

  @override
  Widget build(BuildContext context) {
    Widget choice(String label, int value, List<int> values, ValueChanged<int> changed) =>
        SizedBox(width: 180, child: DropdownButtonFormField<int>(
          key: ValueKey('$label:$value'), initialValue: value, isExpanded: true,
          decoration: InputDecoration(labelText: _suiteTr(context, label)),
          items: values.map((number) => DropdownMenuItem(value: number, child: Text('$number'))).toList(),
          onChanged: !enabled ? null : (number) { if (number != null) changed(number); }));
    return _StudyPanel(children: [
      Text(_suiteTr(context, 'Ayah sources'), style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      TextField(key: const ValueKey('ai-reference-selection'), controller: controller,
        readOnly: !enabled, maxLength: 128, textDirection: TextDirection.ltr,
        decoration: InputDecoration(labelText: _suiteTr(context, 'Surah:Ayah or range'),
          hintText: '1:1-7, 2:255', helperMaxLines: 3,
          helperText: _suiteTr(context, tool == QuranAiTool.hifzCoach || tool == QuranAiTool.recitationFollow
              ? 'Enter an Ayah reference or range for text comparison.'
              : 'Blank: current Surah excerpt. This is not exact scan-page alignment.'))),
      if (tool == QuranAiTool.quranQuiz || tool == QuranAiTool.revisionPlan) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 12, runSpacing: 12, children: [
          if (tool == QuranAiTool.quranQuiz) choice('Questions', quizCount, const [3, 5, 8], onQuizCount),
          if (tool == QuranAiTool.revisionPlan) ...[
            choice('Days', revisionDays, const [3, 7, 14], onRevisionDays),
            choice('Minutes per day', minutesPerDay, const [5, 10, 15, 20], onMinutes),
          ],
        ]),
      ],
      if (tool == QuranAiTool.studyChat) ...[
        const SizedBox(height: 10), Text(_suiteTr(context,
            'Follow-ups reuse only the cited Ayahs from this session. The last 12 messages stay here until you leave.')),
      ],
    ]);
  }
}

class _StudyChatCard extends StatelessWidget {
  const _StudyChatCard({required this.turns, required this.onClear});
  final List<_StudyChatTurn> turns;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => _StudyPanel(children: [
    Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text(_suiteTr(context, 'Study conversation'), style: Theme.of(context).textTheme.titleMedium),
      TextButton.icon(onPressed: onClear, icon: const Icon(Icons.clear_all_rounded),
          label: Text(_suiteTr(context, 'Clear conversation'))),
    ]),
    for (final turn in turns) ...[
      const Divider(height: 24),
      Text(_suiteTr(context, 'Your question'), style: Theme.of(context).textTheme.labelLarge),
      SelectableText(turn.question), const SizedBox(height: 10),
      Text(_suiteTr(context, 'Source-based study reply'), style: Theme.of(context).textTheme.labelLarge),
      SelectableText(turn.answer),
      if (turn.references.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text('${_suiteTr(context, 'Ayah sources')}: ${turn.references.join(', ')}')),
    ],
  ]);
}

class _StudySourcesCard extends StatelessWidget {
  const _StudySourcesCard({required this.result});
  final QuranAiToolResult result;
  @override
  Widget build(BuildContext context) => _StudyPanel(children: [
    Text(_suiteTr(context, 'Sources and limits'), style: Theme.of(context).textTheme.titleMedium),
    if (result.selectionLabel.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
        child: SelectableText(result.selectionLabel)),
    for (final note in result.sourceNotes) Padding(padding: const EdgeInsets.only(top: 8),
        child: SelectableText(note)),
  ]);
}

class _StudyVersesCard extends StatelessWidget {
  const _StudyVersesCard({required this.result, required this.language, required this.onOpen});
  final QuranAiToolResult result;
  final AiResponseLanguage language;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => _StudyPanel(children: [
    Text(_suiteTr(context, 'Verified Quran text and translation'), style: Theme.of(context).textTheme.titleMedium),
    for (final verse in result.canonicalVerses) ...[
      const Divider(height: 28),
      Text('${verse.verseKey} · ${verse.chapterName}', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 10),
      SelectableText(verse.arabic, textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 24, height: 1.8)),
      const SizedBox(height: 10),
      SelectableText(verse.translationFor(language),
          textDirection: language == AiResponseLanguage.urdu ? TextDirection.rtl : TextDirection.ltr),
      if (result.searchResults.any((hit) => hit.verseKey == verse.verseKey))
        TextButton.icon(onPressed: () => onOpen(verse.verseKey), icon: const Icon(Icons.menu_book_outlined),
            label: Text(_suiteTr(context, 'Open source page'))),
    ],
  ]);
}

class _StudyQuizCard extends StatefulWidget {
  const _StudyQuizCard({super.key, required this.result, required this.onOpen});
  final QuranAiToolResult result;
  final ValueChanged<String> onOpen;
  @override State<_StudyQuizCard> createState() => _StudyQuizCardState();
}

class _StudyQuizCardState extends State<_StudyQuizCard> {
  int _index = 0;
  int? _selected;
  final Map<int, bool> _checked = {};
  @override
  Widget build(BuildContext context) {
    final questions = widget.result.quizQuestions;
    final question = questions[_index];
    final checked = _checked.containsKey(_index);
    final correct = question.correctOptionIndex;
    if (correct < 0 || correct >= question.options.length) {
      return _StudyPanel(children: [Text(_suiteTr(context, 'The study exercise is unavailable. Please create it again.'))]);
    }
    return _StudyPanel(children: [
      Text('${_suiteTr(context, 'Question')} ${_index + 1} / ${questions.length}',
          style: Theme.of(context).textTheme.titleMedium),
      Text('${_suiteTr(context, 'Score')}: ${_checked.values.where((value) => value).length} / ${questions.length}'),
      const SizedBox(height: 14),
      SelectableText(question.arabic, textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 24, height: 1.8)),
      const SizedBox(height: 10),
      Text(_suiteTr(context, 'Choose the matching verified translation.')),
      for (var option = 0; option < question.options.length; option++) Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton(
          key: ValueKey('quiz-option-$_index-$option'),
          style: OutlinedButton.styleFrom(alignment: AlignmentDirectional.centerStart,
              side: BorderSide(color: _selected == option ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor), padding: const EdgeInsets.all(14)),
          onPressed: checked ? null : () => setState(() => _selected = option),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_selected == option ? Icons.radio_button_checked : Icons.radio_button_off, size: 20),
            const SizedBox(width: 10), Expanded(child: Text(question.options[option].translation)),
          ])),
      ),
      if (checked) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_suiteTr(context, _checked[_index]! ? 'Correct.' : 'Review the correct answer.'),
              style: Theme.of(context).textTheme.titleSmall),
          SelectableText('${question.verseKey}\n${question.options[correct].translation}'),
        ])),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        if (!checked) FilledButton(onPressed: _selected == null ? null : () {
          setState(() => _checked[_index] = _selected == correct);
        }, child: Text(_suiteTr(context, 'Check answer'))),
        if (checked && _index < questions.length - 1) FilledButton(onPressed: () {
          setState(() { _index++; _selected = null; });
        }, child: Text(_suiteTr(context, 'Next question'))),
        if (checked && _index == questions.length - 1) TextButton(onPressed: () {
          setState(() { _index = 0; _selected = null; _checked.clear(); });
        }, child: Text(_suiteTr(context, 'Restart quiz'))),
        if (checked && widget.result.searchResults.any((hit) => hit.verseKey == question.verseKey))
          TextButton(onPressed: () => widget.onOpen(question.verseKey),
              child: Text(_suiteTr(context, 'Open source page'))),
      ]),
    ]);
  }
}

class _StudyFlashcards extends StatefulWidget {
  const _StudyFlashcards({super.key, required this.result, required this.language, required this.onOpen});
  final QuranAiToolResult result;
  final AiResponseLanguage language;
  final ValueChanged<String> onOpen;
  @override State<_StudyFlashcards> createState() => _StudyFlashcardsState();
}

class _StudyFlashcardsState extends State<_StudyFlashcards> {
  int _index = 0;
  bool _revealed = false;
  @override
  Widget build(BuildContext context) {
    final verses = widget.result.canonicalVerses;
    final verse = verses[_index];
    return _StudyPanel(children: [
      Text('${_suiteTr(context, 'Card')} ${_index + 1} / ${verses.length}', style: Theme.of(context).textTheme.titleMedium),
      Text('${verse.verseKey} · ${verse.chapterName}'), const SizedBox(height: 18),
      SelectableText(verse.arabic, textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 26, height: 1.8)),
      const SizedBox(height: 18),
      if (_revealed) SelectableText(verse.translationFor(widget.language),
          textDirection: widget.language == AiResponseLanguage.urdu ? TextDirection.rtl : TextDirection.ltr),
      FilledButton.tonalIcon(onPressed: () => setState(() => _revealed = !_revealed),
          icon: const Icon(Icons.flip_rounded), label: Text(_suiteTr(context,
              _revealed ? 'Hide translation' : 'Reveal translation'))),
      const SizedBox(height: 12),
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton(onPressed: _index == 0 ? null : () => setState(() { _index--; _revealed = false; }),
            child: Text(_suiteTr(context, 'Previous card'))),
        OutlinedButton(onPressed: _index == verses.length - 1 ? null : () => setState(() { _index++; _revealed = false; }),
            child: Text(_suiteTr(context, 'Next card'))),
        if (widget.result.searchResults.any((hit) => hit.verseKey == verse.verseKey))
          TextButton(onPressed: () => widget.onOpen(verse.verseKey), child: Text(_suiteTr(context, 'Open source page'))),
      ]),
    ]);
  }
}

class _StudyRevisionCard extends StatelessWidget {
  const _StudyRevisionCard({required this.result, required this.onOpen});
  final QuranAiToolResult result;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    Widget references(List<String> values) => values.isEmpty ? Text(_suiteTr(context, 'None scheduled.'))
        : Wrap(spacing: 8, runSpacing: 8, children: values.map((reference) => ActionChip(
            label: Text(reference), onPressed: result.searchResults.any((hit) => hit.verseKey == reference)
                ? () => onOpen(reference) : null)).toList());
    return _StudyPanel(children: [
      Text(_suiteTr(context, 'Revision schedule'), style: Theme.of(context).textTheme.titleMedium),
      for (final day in result.revisionDays) ...[
        const Divider(height: 24),
        Text('${_suiteTr(context, 'Day')} ${day.day} · ${day.minutes} ${_suiteTr(context, 'minutes')}',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8), Text(_suiteTr(context, 'Learn')), references(day.learnReferences),
        const SizedBox(height: 8), Text(_suiteTr(context, 'Review')), references(day.reviewReferences),
      ],
    ]);
  }
}

class _StudyTextComparisonCard extends StatelessWidget {
  const _StudyTextComparisonCard({required this.comparison});
  final QuranAiTextComparison comparison;
  @override
  Widget build(BuildContext context) => _StudyPanel(children: [
    Text(_suiteTr(context, 'Typed-text comparison'), style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    Text(_suiteTr(context, 'Text comparison only. This does not assess pronunciation or audio.')),
    const SizedBox(height: 12), Text(_suiteTr(context, 'Verified Arabic')),
    SelectableText(comparison.expected, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 22, height: 1.8)),
    const SizedBox(height: 12), Text(_suiteTr(context, 'Your recalled text')),
    SelectableText(comparison.recalled, textDirection: TextDirection.rtl),
    const SizedBox(height: 12),
    Text('${_suiteTr(context, 'Matched words')}: ${comparison.matchedWordCount} / ${comparison.expectedWordCount}'),
    if (comparison.missingWords.isNotEmpty) ...[
      const SizedBox(height: 8), Text(_suiteTr(context, 'Missing words')),
      SelectableText(comparison.missingWords.join(' '), textDirection: TextDirection.rtl),
    ],
    if (comparison.extraWords.isNotEmpty) ...[
      const SizedBox(height: 8), Text(_suiteTr(context, 'Extra words')),
      SelectableText(comparison.extraWords.join(' '), textDirection: TextDirection.rtl),
    ],
  ]);
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.pageReference,
    required this.editionLabel,
    required this.languageLabel,
    required this.depthLabel,
    required this.providerLabel,
    required this.modelLabel,
    required this.statusLabel,
    required this.endpointLabel,
  });

  final String pageReference;
  final String editionLabel;
  final String languageLabel;
  final String depthLabel;
  final String providerLabel;
  final String modelLabel;
  final String statusLabel;
  final String endpointLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.primary,
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: foreground.withValues(alpha: 0.18)),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  color: foreground,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'STUDY COMPANION'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground.withValues(alpha: 0.78),
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(context, 'Study & reflect'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            tr(context, 'Explore meaning, strengthen memorization, and make room for thoughtful reflection.'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground.withValues(alpha: 0.88),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                label: tr(context, pageReference),
                icon: Icons.menu_book_outlined,
                inverse: true,
              ),
              _Pill(
                label: tr(context, editionLabel),
                icon: Icons.layers_outlined,
                inverse: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolPicker extends StatelessWidget {
  const _ToolPicker({
    required this.selectedTool,
    this.enabled = true,
    required this.aiSettings,
    required this.languageLocked,
    required this.depthLocked,
    required this.hasAdminAiConfiguration,
    required this.onSelectLanguage,
    required this.onSelectDepth,
    required this.onSelected,
  });

  final QuranAiTool selectedTool;
  final bool enabled;
  final ReaderAiSettings aiSettings;
  final bool languageLocked;
  final bool depthLocked;
  final bool hasAdminAiConfiguration;
  final Future<void> Function(AiResponseLanguage language) onSelectLanguage;
  final Future<void> Function(AiResponseDepth depth) onSelectDepth;
  final ValueChanged<QuranAiTool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageOptions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'Response language'),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              const <AiResponseLanguage>[
                    AiResponseLanguage.english,
                    AiResponseLanguage.urdu,
                    AiResponseLanguage.bilingual,
                  ]
                  .map(
                    (language) => ChoiceChip(
                      label: Text(tr(context, language.label)),
                      selected: aiSettings.responseLanguage == language,
                      onSelected: languageLocked || !enabled
                          ? null
                          : (_) {
                              onSelectLanguage(language);
                            },
                    ),
                  )
                  .toList(growable: false),
        ),
      ],
    );
    final depthOptions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'Response depth'),
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AiResponseDepth.values
              .map(
                (depth) => ChoiceChip(
                  label: Text(tr(context, depth.label)),
                  selected: aiSettings.responseDepth == depth,
                  onSelected: depthLocked || !enabled
                      ? null
                      : (_) {
                          onSelectDepth(depth);
                        },
                ),
              )
              .toList(growable: false),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'How would you like to study?'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<QuranAiTool>(
            key: ValueKey<QuranAiTool>(selectedTool),
            initialValue: selectedTool,
            isExpanded: true,
            menuMaxHeight: 420,
            borderRadius: BorderRadius.circular(18),
            dropdownColor: theme.colorScheme.surface,
            icon: Icon(
              Icons.expand_more_rounded,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              labelText: tr(context, 'Study tool'),
              prefixIcon: Icon(_toolIcon(selectedTool), size: 21),
            ),
            items: QuranAiTool.values
                .map(
                  (tool) => DropdownMenuItem<QuranAiTool>(
                    value: tool,
                    child: Text(
                      _suiteTr(context, tool.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: !enabled ? null : (tool) {
              if (tool != null) onSelected(tool);
            },
          ),
          const SizedBox(height: 12),
          Text(
            _suiteTr(context, selectedTool.subtitle),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 620) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: languageOptions),
                    const SizedBox(width: 24),
                    Expanded(child: depthOptions),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  languageOptions,
                  const SizedBox(height: 20),
                  depthOptions,
                ],
              );
            },
          ),
          if (hasAdminAiConfiguration && (languageLocked || depthLocked)) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    tr(context, 'Your response preferences are set by the administrator.'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.tool,
    required this.controller,
    this.readOnly = false,
  });

  final QuranAiTool tool;
  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _suiteTr(context, tool.inputLabel),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            readOnly: readOnly,
            minLines: tool.expectsUserInput ? 4 : 2,
            maxLines: tool.expectsUserInput ? 6 : 3,
            decoration: InputDecoration(
              hintText: _suiteTr(context, tool.inputHint),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceInputCard extends StatelessWidget {
  const _VoiceInputCard({
    required this.capture,
    required this.language,
    required this.onlineRecognition,
    required this.enabled,
    required this.onLanguageChanged,
    required this.onOnlineRecognitionChanged,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  final ReaderVoiceCapture capture;
  final String language;
  final bool onlineRecognition;
  final bool enabled;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<bool> onOnlineRecognitionChanged;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = capture.isBusy;
    final status = switch (capture.phase) {
      ReaderVoiceCapturePhase.requesting => 'Waiting for microphone permission',
      ReaderVoiceCapturePhase.recording => 'Recording',
      ReaderVoiceCapturePhase.stopping => 'Finishing recording',
      ReaderVoiceCapturePhase.ready => capture.isTranscribing
          ? 'Finishing transcript'
          : 'Recording ready',
      ReaderVoiceCapturePhase.idle => 'Ready to record',
    };
    final seconds = capture.elapsed.inSeconds.clamp(0, 60);
    final time = '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')} / 01:00';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(context, 'Voice input'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(time, textDirection: TextDirection.ltr),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr(context,
              'Record up to 60 seconds. Save to your local library or download a copy before leaving this screen.')),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr(context, 'Use online speech recognition')),
            value: false,
            onChanged: null,
          ),
          Text(
            switch (ReaderLocalization.instance.language) {
              ReaderLanguage.urdu =>
                'اولاما صرف متن استعمال کرتا ہے۔ ریکارڈنگ اس آلے پر رہتی ہے؛ اپنا متن خود لکھیں یا پیسٹ کریں۔',
              ReaderLanguage.romanUrdu =>
                'Ollama sirf matn istemal karta hai. Recording isi device par rehti hai; apna transcript likhein ya paste karein.',
              ReaderLanguage.arabic =>
                'يستخدم Ollama النص فقط. يبقى التسجيل على هذا الجهاز؛ اكتب النص أو الصقه بنفسك.',
              ReaderLanguage.english =>
                'Ollama uses text only. Recordings stay on this device; type or paste your transcript.',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (onlineRecognition) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: language,
              decoration: InputDecoration(
                labelText: tr(context, 'Spoken language'),
              ),
              items: [
                DropdownMenuItem(value: 'ar-SA', child: Text(tr(context, 'Arabic'))),
                DropdownMenuItem(value: 'ur-PK', child: Text(tr(context, 'Urdu'))),
                DropdownMenuItem(value: 'en-US', child: Text(tr(context, 'English'))),
              ],
              onChanged: enabled && !busy
                  ? (value) {
                      if (value != null) onLanguageChanged(value);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            Text(tr(context, 'The transcript is added to the input above.')),
          ],
          const SizedBox(height: 12),
          Text(
            tr(context, 'Tajweed guidance does not assess recorded pronunciation.'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(tr(context, status)),
          if (capture.phase == ReaderVoiceCapturePhase.recording) ...[
            const SizedBox(height: 8),
            Semantics(
              container: true,
              child: LinearProgressIndicator(value: seconds / 60),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!busy)
                FilledButton.icon(
                  onPressed: enabled && capture.supported ? onStart : null,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(tr(context,
                      onlineRecognition ? 'Record and transcribe' : 'Record audio')),
                ),
              if (capture.phase == ReaderVoiceCapturePhase.recording)
                FilledButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_rounded),
                  label: Text(tr(context, 'Stop recording')),
                ),
              if (busy || capture.hasRecording)
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(tr(context,
                      busy ? 'Cancel recording' : 'Discard recording')),
                ),
              if (capture.hasRecording && !busy) ...[
                OutlinedButton.icon(
                  onPressed: capture.togglePlayback,
                  icon: Icon(capture.isPlaying
                      ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(tr(context,
                      capture.isPlaying ? 'Pause playback' : 'Play recording')),
                ),
                OutlinedButton.icon(
                  onPressed: capture.download,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(tr(context, 'Download recording')),
                ),
              ],
            ],
          ),
          if (!capture.supported || capture.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              tr(context, capture.errorMessage ??
                  'Voice recording is available in Chrome on HTTPS or localhost.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.blocks,
    required this.pageReference,
    required this.currentPageNumber,
    required this.onOpenCurrentPage,
  });

  final QuranAiToolResult result;
  final List<_AiOutputBlock> blocks;
  final String pageReference;
  final int currentPageNumber;
  final Future<void> Function() onOpenCurrentPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 420;
              final sourcePill = _Pill(
                label: tr(context, result.sourceLabel),
                icon: result.usedOnlineModel
                    ? Icons.memory_rounded
                    : Icons.offline_bolt_outlined,
              );

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _suiteTr(context, result.tool.title),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    sourcePill,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                        _suiteTr(context, result.tool.title),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  sourcePill,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (result.tool != QuranAiTool.smartSearch && result.selectionLabel.isEmpty) Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surfaceContainerLow,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactActions = constraints.maxWidth < 430;
                final pageInfo = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Current page'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(context, pageReference),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                );
                final openPageButton = FilledButton.tonalIcon(
                  onPressed: () {
                    onOpenCurrentPage();
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(tr(context, 'Open page $currentPageNumber')),
                );

                if (compactActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      pageInfo,
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: openPageButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: pageInfo),
                    const SizedBox(width: 12),
                    openPageButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            switch (ReaderLocalization.instance.language) {
              ReaderLanguage.urdu =>
                'AI کی مطالعاتی مدد میں غلطیاں ہو سکتی ہیں۔ قرآنی اقتباسات اصل مصحف اور مستند ترجمے سے ضرور ملائیں۔',
              ReaderLanguage.romanUrdu =>
                'AI ki study help mein ghaltiyan ho sakti hain. Quran ke quotes ko asal Mushaf aur mustanad tarjume se zaroor milayein.',
              ReaderLanguage.arabic =>
                'قد تحتوي المساعدة الدراسية بالذكاء الاصطناعي على أخطاء. راجع الاقتباسات القرآنية في المصحف الأصلي وترجمة موثوقة.',
              ReaderLanguage.english =>
                'AI study help can contain errors. Check Quran quotations against the original Mushaf and a verified translation.',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final block in blocks) ...[
                  block.build(context),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchedLineCard extends StatelessWidget {
  const _MatchedLineCard({
    required this.result,
  });

  final QuranAiToolResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'Matched line'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _Pill(
            label: tr(context, 'Line ${result.matchedLineNumber}'),
            icon: Icons.hearing_rounded,
          ),
          const SizedBox(height: 10),
          Text(
            result.matchedLineText ?? '',
            textAlign: TextAlign.right,
            style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _BookmarkSuggestionCard extends StatelessWidget {
  const _BookmarkSuggestionCard({
    required this.suggestion,
    required this.onApply,
  });

  final QuranAiBookmarkSuggestion suggestion;
  final Future<void> Function(QuranAiBookmarkSuggestion suggestion) onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'Bookmark suggestion'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: suggestion.folder, icon: Icons.folder_open_outlined),
              _Pill(label: suggestion.label, icon: Icons.label_outline_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            suggestion.reason,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(_suiteTr(context, 'This saves the current reading page, not an exact Ayah location.')),
          FilledButton.tonalIcon(
            onPressed: () {
              onApply(suggestion);
            },
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(_suiteTr(context, 'Bookmark the current reading page')),
          ),
        ],
      ),
    );
  }
}

class _SearchResultsCard extends StatelessWidget {
  const _SearchResultsCard({
    required this.results,
    required this.onOpen,
  });

  final List<QuranSearchResult> results;
  final Future<void> Function(QuranSearchResult result) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'Relevant results'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...results.map((result) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: theme.colorScheme.surfaceContainerLow,
              ),
              child: ListTile(
                onTap: () {
                  onOpen(result);
                },
                title: Text(
                  result.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (result.navigationNote != null) ...[
                      const SizedBox(height: 6),
                      Text(tr(context, result.navigationNote!), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                    ],
                  ],
                ),
                trailing: Text(tr(context, 'P${result.pageNumber}')),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, this.inverse = false});
  final String label;
  final IconData icon;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = inverse
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: inverse
            ? foreground.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: inverse
              ? foreground.withValues(alpha: 0.16)
              : theme.dividerColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: inverse ? foreground : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AiOutputBlockType {
  heading,
  bullet,
  paragraph,
}

class _AiOutputBlock {
  const _AiOutputBlock({
    required this.type,
    required this.text,
  });

  final _AiOutputBlockType type;
  final String text;

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (type) {
      case _AiOutputBlockType.heading:
        return Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        );
      case _AiOutputBlockType.bullet:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
            ),
          ],
        );
      case _AiOutputBlockType.paragraph:
        return Text(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        );
    }
  }
}

class _AiOutputFormatter {
  static List<_AiOutputBlock> parse(String raw) {
    final normalized =
        raw.replaceAll('\r\n', '\n').replaceAll('```', '').trim();
    if (normalized.isEmpty) {
      return const <_AiOutputBlock>[];
    }

    final blocks = <_AiOutputBlock>[];
    for (final originalLine in normalized.split('\n')) {
      final line = _stripMarkdown(originalLine);
      if (line.isEmpty) {
        continue;
      }

      if (_isHeading(originalLine, line)) {
        blocks.add(
          _AiOutputBlock(
            type: _AiOutputBlockType.heading,
            text: line,
          ),
        );
        continue;
      }

      if (_isBullet(originalLine)) {
        blocks.add(
          _AiOutputBlock(
            type: _AiOutputBlockType.bullet,
            text: _stripBulletPrefix(line),
          ),
        );
        continue;
      }

      blocks.add(
        _AiOutputBlock(
          type: _AiOutputBlockType.paragraph,
          text: line,
        ),
      );
    }
    return blocks;
  }

  static bool _isHeading(String originalLine, String cleanedLine) {
    final trimmedOriginal = originalLine.trimLeft();
    if (trimmedOriginal.startsWith('#')) {
      return true;
    }
    if (RegExp(r'^\d+\.\s+').hasMatch(trimmedOriginal)) {
      return true;
    }
    return cleanedLine.endsWith(':') && cleanedLine.length < 72;
  }

  static bool _isBullet(String originalLine) {
    final trimmed = originalLine.trimLeft();
    return trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('• ');
  }

  static String _stripMarkdown(String line) {
    var value = line.trim();
    value = value.replaceFirst(RegExp(r'^#{1,6}\s*'), '');
    value = value.replaceAll('**', '');
    value = value.replaceAll('__', '');
    value = value.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceFirst(RegExp(r'^\d+\.\s+'), '');
    value = value.replaceFirst(RegExp(r'^>\s*'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  static String _stripBulletPrefix(String line) {
    return line.replaceFirst(RegExp(r'^[-*•]\s*'), '').trim();
  }
}
