import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/quran_search_result.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/reader_skeleton.dart';

class QuranAiStudioScreen extends StatefulWidget {
  const QuranAiStudioScreen({
    super.key,
    required this.controller,
  });

  final QuranReaderController controller;

  @override
  State<QuranAiStudioScreen> createState() => _QuranAiStudioScreenState();
}

class _QuranAiStudioScreenState extends State<QuranAiStudioScreen> {
  late final TextEditingController _inputController;
  QuranAiTool _selectedTool = QuranAiTool.explainer;
  QuranAiToolResult? _result;
  List<_AiOutputBlock> _formattedResultBlocks = const <_AiOutputBlock>[];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _runTool() async {
    if (_isRunning) {
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
        content: Text('Saved to ${suggestion.folder}'),
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
              title: const Text('AI Studio'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
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
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isRunning ? null : _runTool,
                    icon: _isRunning
                        ? const ReaderSkeletonBlock(
                            width: 18,
                            height: 18,
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          )
                        : Icon(_toolIcon(_selectedTool)),
                    label: Text(_selectedTool.actionLabel),
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
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Quran tools',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask about the current page, generate study notes, search by meaning, review memorization, and get quick tafsir help.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: pageReference, icon: Icons.menu_book_rounded),
              _Pill(label: editionLabel, icon: Icons.layers_outlined),
              _Pill(label: languageLabel, icon: Icons.translate_rounded),
              _Pill(label: depthLabel, icon: Icons.speed_rounded),
              _Pill(label: providerLabel, icon: Icons.auto_awesome_rounded),
              _Pill(label: modelLabel, icon: Icons.memory_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            endpointLabel.isEmpty
                ? statusLabel
                : '$statusLabel\n$endpointLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose AI feature',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: QuranAiTool.values.map((tool) {
              return FilterChip(
                avatar: Icon(_toolIcon(tool), size: 18),
                label: Text(tool.title),
                selected: selectedTool == tool,
                onSelected: (_) => onSelected(tool),
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          Text(
            selectedTool.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <AiResponseLanguage>[
              AiResponseLanguage.english,
              AiResponseLanguage.urdu,
              AiResponseLanguage.bilingual,
            ].map((language) {
              return ChoiceChip(
                label: Text(language.label),
                selected: aiSettings.responseLanguage == language,
                onSelected: languageLocked
                    ? null
                    : (_) {
                        onSelectLanguage(language);
                      },
              );
            }).toList(growable: false),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AiResponseDepth.values.map((depth) {
              return ChoiceChip(
                label: Text(depth.label),
                selected: aiSettings.responseDepth == depth,
                onSelected: depthLocked
                    ? null
                    : (_) {
                        onSelectDepth(depth);
                      },
              );
            }).toList(growable: false),
          ),
          if (hasAdminAiConfiguration) ...[
            const SizedBox(height: 10),
            Text(
              languageLocked || depthLocked
                  ? 'AI defaults are currently managed by the admin dashboard.'
                  : 'AI provider details are managed by the admin dashboard.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
  });

  final QuranAiTool tool;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tool.inputLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: tool.expectsUserInput ? 4 : 2,
            maxLines: tool.expectsUserInput ? 6 : 3,
            decoration: InputDecoration(
              hintText: tool.inputHint,
              alignLabelWithHint: true,
            ),
          ),
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
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compactHeader = constraints.maxWidth < 420;
              final sourcePill = _Pill(
                label: result.sourceLabel,
                icon: result.usedOnlineModel
                    ? Icons.memory_rounded
                    : Icons.offline_bolt_outlined,
              );

              if (compactHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.tool.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
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
                      result.tool.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
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
                      'Current page',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pageReference,
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
                  label: Text('Open page $currentPageNumber'),
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
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matched line',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _Pill(
            label: 'Line ${result.matchedLineNumber}',
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
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bookmark suggestion',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
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
            label: const Text('Apply bookmark'),
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
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Relevant results',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
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
                subtitle: Text(
                  result.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text('P${result.pageNumber}'),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
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
            fontWeight: FontWeight.w900,
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
