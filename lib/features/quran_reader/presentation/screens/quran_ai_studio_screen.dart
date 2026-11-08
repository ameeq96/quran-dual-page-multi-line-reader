import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/services/reader_voice_capture.dart';
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
  late final ReaderVoiceCapture _voiceCapture;
  String _voiceLanguage = 'ar-SA';
  bool _useOnlineRecognition = false;
  bool _voiceInputSession = false;
  String _voiceBaseInput = '';
  String _lastVoiceTranscript = '';
  QuranAiTool _selectedTool = QuranAiTool.explainer;
  QuranAiToolResult? _result;
  List<_AiOutputBlock> _formattedResultBlocks = const <_AiOutputBlock>[];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
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
      transcribe: _useOnlineRecognition,
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

    QuranAiToolResult? nextResult;
    List<_AiOutputBlock> nextFormattedResultBlocks = const <_AiOutputBlock>[];
    setState(() => _isRunning = true);
    try {
      nextResult = await widget.controller.runAiTool(
        _selectedTool,
        userInput: _inputController.text,
      );
      nextFormattedResultBlocks = _AiOutputFormatter.parse(nextResult.output);
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
          if (nextResult != null) {
            _result = nextResult;
            _formattedResultBlocks = nextFormattedResultBlocks;
          }
        });
      }
    }
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
                      _formattedResultBlocks = const <_AiOutputBlock>[];
                    });
                  },
                ),
                const SizedBox(height: 14),
                _InputCard(
                  tool: _selectedTool,
                  controller: _inputController,
                  readOnly: _voiceCapture.isBusy,
                ),
                if (_selectedTool == QuranAiTool.voiceQna ||
                    _selectedTool == QuranAiTool.recitationFollow ||
                    _selectedTool == QuranAiTool.hifzCoach ||
                    _selectedTool == QuranAiTool.tajweedTutor) ...[
                  const SizedBox(height: 14),
                  _VoiceInputCard(
                    capture: _voiceCapture,
                    language: _voiceLanguage,
                    onlineRecognition: _useOnlineRecognition,
                    enabled: !_isRunning,
                    onLanguageChanged: (language) {
                      setState(() => _voiceLanguage = language);
                    },
                    onOnlineRecognitionChanged: (enabled) {
                      setState(() => _useOnlineRecognition = enabled);
                    },
                    onStart: _startVoiceCapture,
                    onStop: _voiceCapture.stop,
                    onCancel: _cancelVoiceCapture,
                  ),
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
                    label: Text(tr(context, _selectedTool.actionLabel)),
                  ),
                ),
                const SizedBox(height: 14),
                if (_isRunning) ...[
                  const _AiStudioSkeletonCard(),
                ] else if (_result != null) ...[
                  ValueListenableBuilder<int>(
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
                  if (_result!.hasSearchResults) ...[
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
  }
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
    required this.aiSettings,
    required this.languageLocked,
    required this.depthLocked,
    required this.hasAdminAiConfiguration,
    required this.onSelectLanguage,
    required this.onSelectDepth,
    required this.onSelected,
  });

  final QuranAiTool selectedTool;
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
                      onSelected: languageLocked
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
                  onSelected: depthLocked
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
                      tr(context, tool.title),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (tool) {
              if (tool != null) onSelected(tool);
            },
          ),
          const SizedBox(height: 12),
          Text(
            tr(context, selectedTool.subtitle),
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
            tr(context, tool.inputLabel),
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
              hintText: tr(context, tool.inputHint),
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
              'Record up to 60 seconds. Audio stays in memory; download a copy before leaving this screen.')),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr(context, 'Use online speech recognition')),
            value: onlineRecognition,
            onChanged: enabled && !busy && capture.speechSupported
                ? (value) => onOnlineRecognitionChanged(value ?? false)
                : null,
          ),
          Text(
            tr(context,
                'Online recognition sends microphone audio to your browser\'s speech provider. Review the transcript before using it.'),
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
            LinearProgressIndicator(value: seconds / 60),
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
                      tr(context, result.tool.title),
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
                      tr(context, result.tool.title),
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
          Container(
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
          FilledButton.tonalIcon(
            onPressed: () {
              onApply(suggestion);
            },
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(tr(context, 'Apply bookmark')),
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
