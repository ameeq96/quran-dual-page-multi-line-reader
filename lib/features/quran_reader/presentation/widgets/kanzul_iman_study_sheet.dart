import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'mushaf_page_widget.dart';
import 'reader_sheet_frame.dart';

Future<void> showKanzulImanStudySheet(
  BuildContext context, {
  required QuranReaderController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.95,
        child: ReaderSheetFrame(
          child: KanzulImanStudyContent(
            controller: controller,
            showHandle: true,
          ),
        ),
      );
    },
  );
}

enum _StudyMode {
  quranOnly('Quran only'),
  kanzulOnly('Kanzul Iman'),
  combined('Combined');

  const _StudyMode(this.label);

  final String label;
}

class QuranKanzulImanStudyScreen extends StatelessWidget {
  const QuranKanzulImanStudyScreen({
    super.key,
    required this.controller,
  });

  final QuranReaderController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderSettings>(
      valueListenable: controller.settingsListenable,
      builder: (context, settings, _) {
        return Theme(
          data: settings.nightMode ? AppTheme.dark() : AppTheme.light(),
          child: Scaffold(
            body: SafeArea(
              child: KanzulImanStudyContent(
                controller: controller,
                showHandle: false,
              ),
            ),
          ),
        );
      },
    );
  }
}

class KanzulImanStudyContent extends StatefulWidget {
  const KanzulImanStudyContent({
    super.key,
    required this.controller,
    this.showHandle = true,
  });

  final QuranReaderController controller;
  final bool showHandle;

  @override
  State<KanzulImanStudyContent> createState() =>
      _KanzulImanStudyContentState();
}

class _KanzulImanStudyContentState extends State<KanzulImanStudyContent> {
  _StudyMode _mode = _StudyMode.combined;
  late MushafEdition _studyEdition;

  @override
  void initState() {
    super.initState();
    _studyEdition = widget.controller.primaryStudyEdition;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final compact = size.width < 420 || size.height < 760;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller.pageListenable,
        widget.controller.settingsListenable,
      ]),
      builder: (context, _) {
        final standardPage = widget.controller.currentStandardPageNumber;
        final quranPage = widget.controller.pageForStandardPageInEdition(
          standardPage,
          edition: _studyEdition,
        );
        final kanzulPage = widget.controller.pageForStandardPageInEdition(
          standardPage,
          edition: MushafEdition.kanzulIman,
        );
        final currentInsight = widget.controller.currentPageInsight;
        final dualWide = size.width > 780;
        final combined = _mode == _StudyMode.combined;
        final showQuran = _mode != _StudyMode.kanzulOnly;
        final showKanzul = _mode != _StudyMode.quranOnly;
        final readerSettings = widget.controller.settings.copyWith(
          hifzFocusMode: false,
          pageReflectionEnabled: false,
          pageOverlayEnabled: false,
          pagePresetEnabled: false,
          customBrightnessEnabled: false,
          lowMemoryMode: true,
        );

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 16,
              widget.showHandle ? 18 : 6,
              compact ? 12 : 16,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.showHandle) ...[
                  Center(
                    child: Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _StudyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kanzul Iman study mode',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Read the Quran scan alongside Kanzul Iman translation and tafsir presentation.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _StudyMode.values.map((mode) {
                          return ChoiceChip(
                            label: Text(mode.label),
                            selected: _mode == mode,
                            onSelected: (_) {
                              setState(() {
                                _mode = mode;
                              });
                            },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      if (_mode != _StudyMode.kanzulOnly)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...widget.controller.compareEditions
                                .where(
                                  (edition) =>
                                      edition != MushafEdition.kanzulIman,
                                )
                                .map((edition) {
                              return ChoiceChip(
                                label: Text(edition.label),
                                selected: edition == _studyEdition,
                                onSelected: (_) {
                                  setState(() {
                                    _studyEdition = edition;
                                  });
                                },
                              );
                            }),
                            ActionChip(
                              avatar: const Icon(Icons.compare_arrows_rounded),
                              label: const Text('Use in reader'),
                              onPressed: () async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                await widget.controller
                                    .selectMushafEdition(_studyEdition);
                                if (!mounted) {
                                  return;
                                }
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${_studyEdition.label} is now active in the reader.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (combined && dualWide) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showQuran)
                        Expanded(
                          child: _StudyPagePanel(
                            title: _studyEdition.label,
                            subtitle:
                                '${_studyEdition.companyLabel} • Page ${quranPage.number}',
                            page: quranPage,
                            settings: readerSettings,
                          ),
                        ),
                      if (showQuran && showKanzul)
                        const SizedBox(width: 14),
                      if (showKanzul)
                        Expanded(
                          child: _StudyPagePanel(
                            title: 'Kanzul Iman',
                            subtitle:
                                'Translation and tafsir • Page ${kanzulPage.number}',
                            page: kanzulPage,
                            settings: readerSettings,
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  if (showQuran)
                    _StudyPagePanel(
                      title: _studyEdition.label,
                      subtitle:
                          '${_studyEdition.companyLabel} • Page ${quranPage.number}',
                      page: quranPage,
                      settings: readerSettings,
                    ),
                  if (showQuran && showKanzul)
                    const SizedBox(height: 14),
                  if (showKanzul)
                    _StudyPagePanel(
                      title: 'Kanzul Iman',
                      subtitle:
                          'Translation and tafsir • Page ${kanzulPage.number}',
                      page: kanzulPage,
                      settings: readerSettings,
                    ),
                ],
                const SizedBox(height: 14),
                _StudyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study notes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentInsight?.translationUr.isNotEmpty == true
                            ? currentInsight!.translationUr
                            : 'Bundled Urdu translation for this page is not available yet, but the scanned Kanzul Iman page above remains available for study.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudyPagePanel extends StatelessWidget {
  const _StudyPagePanel({
    required this.title,
    required this.subtitle,
    required this.page,
    required this.settings,
  });

  final String title;
  final String subtitle;
  final QuranPage page;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final compact = size.width < 420 || size.height < 760;

    return _StudyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          SizedBox(
            height: compact ? 340 : 440,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: RepaintBoundary(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: compact ? 230 : 280,
                      height: (compact ? 230 : 280) /
                          QuranConstants.pageAspectRatio(
                            usesImage: page.usesImage,
                            assetPath: page.assetPath,
                          ),
                      child: MushafPageWidget(
                        page: page,
                        settings: settings,
                        showPageNumbers: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface.withOpacity(0.97),
            theme.colorScheme.surfaceContainer.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}
