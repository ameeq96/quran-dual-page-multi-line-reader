import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'mushaf_page_widget.dart';
import 'reader_sheet_frame.dart';

Future<void> showReaderCompareSheet(
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
          child: ReaderCompareContent(
            controller: controller,
            showHandle: true,
          ),
        ),
      );
    },
  );
}

class QuranCompareScreen extends StatelessWidget {
  const QuranCompareScreen({
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
              child: ReaderCompareContent(
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

class ReaderCompareContent extends StatefulWidget {
  const ReaderCompareContent({
    super.key,
    required this.controller,
    this.showHandle = true,
  });

  final QuranReaderController controller;
  final bool showHandle;

  @override
  State<ReaderCompareContent> createState() => _ReaderCompareContentState();
}

class _ReaderCompareContentState extends State<ReaderCompareContent> {
  late MushafEdition _morphEdition;

  @override
  void initState() {
    super.initState();
    final editions = widget.controller.compareEditions;
    _morphEdition = editions.contains(widget.controller.primaryStudyEdition)
        ? widget.controller.primaryStudyEdition
        : editions.first;
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
        final editions = widget.controller.compareEditions;
        final previewSettings = widget.controller.settings.copyWith(
          hifzFocusMode: false,
          pageReflectionEnabled: false,
          pageOverlayEnabled: false,
          pagePresetEnabled: false,
          customBrightnessEnabled: false,
          lowMemoryMode: true,
        );
        if (!editions.contains(_morphEdition)) {
          _morphEdition = editions.first;
        }

        final morphIndex = editions.indexOf(_morphEdition).toDouble();
        final selectedPage = widget.controller.pageForStandardPageInEdition(
          standardPage,
          edition: _morphEdition,
        );
        final mappedPage =
            widget.controller.navigationPageForStandardPageInEdition(
          standardPage,
          edition: _morphEdition,
        );

        return SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 20,
              18,
              compact ? 16 : 20,
              24,
            ),
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
                const SizedBox(height: 18),
              ],
              _CompareCard(
                compact: compact,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-edition compare',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'See the same reference page across 13, 15, 16, 17 line scans and Kanzul Iman.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.menu_book_rounded,
                          label: 'Standard page $standardPage',
                        ),
                        _MetaChip(
                          icon: Icons.auto_stories_outlined,
                          label: widget.controller.currentChapterSummary
                                  ?.nameSimple ??
                              'Current Surah',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CompareCard(
                compact: compact,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edition morph mode',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Slide through different print styles while staying on the same reference page.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: editions.map((edition) {
                        return ChoiceChip(
                          label: Text(edition.label),
                          selected: edition == _morphEdition,
                          onSelected: (_) {
                            setState(() {
                              _morphEdition = edition;
                            });
                          },
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: morphIndex,
                      min: 0,
                      max: (editions.length - 1).toDouble(),
                      divisions: editions.length - 1,
                      label: _morphEdition.label,
                      onChanged: (value) {
                        setState(() {
                          _morphEdition = editions[value.round()];
                        });
                      },
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _morphEdition.historySummary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await widget.controller
                            .selectMushafEdition(_morphEdition);
                        if (!mounted) {
                          return;
                        }
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Reader switched to ${_morphEdition.label}.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Use this edition'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: compact ? 320 : 380,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _EditionPreviewCard(
                          key: ValueKey<MushafEdition>(_morphEdition),
                          title: _morphEdition.label,
                          subtitle:
                              '${_morphEdition.companyLabel} - Page $mappedPage',
                          page: selectedPage,
                          settings: previewSettings,
                          compact: compact,
                          footer: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(
                                icon: Icons.location_on_outlined,
                                label: _morphEdition.commonRegionLabel,
                              ),
                              _MetaChip(
                                icon: Icons.tips_and_updates_outlined,
                                label: _morphEdition.bestUseLabel,
                              ),
                              _MetaChip(
                                icon: Icons.view_agenda_outlined,
                                label: _morphEdition.lineCount == null
                                    ? 'Study edition'
                                    : '${_morphEdition.lineCount} lines',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _CompareCard(
                compact: compact,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Same page across editions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Useful for huffaz, teachers, and researchers comparing print density and study editions.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: compact ? 360 : 420,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: editions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final edition = editions[index];
                          final page =
                              widget.controller.pageForStandardPageInEdition(
                            standardPage,
                            edition: edition,
                          );
                          final pageNumber = widget.controller
                              .navigationPageForStandardPageInEdition(
                            standardPage,
                            edition: edition,
                          );
                          return SizedBox(
                            width: compact ? 248 : 286,
                            child: _EditionPreviewCard(
                              title: edition.label,
                              subtitle:
                                  '${edition.companyLabel} - Page $pageNumber',
                              page: page,
                              settings: previewSettings,
                              compact: compact,
                              footer: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    edition.historySummary,
                                    maxLines: compact ? 3 : 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  FilledButton.tonalIcon(
                                    onPressed: () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      await widget.controller
                                          .selectMushafEdition(edition);
                                      if (!mounted) {
                                        return;
                                      }
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${edition.label} is now active in the reader.',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.compare_arrows_rounded,
                                    ),
                                    label: const Text('Switch reader'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.child,
    required this.compact,
  });

  final Widget child;
  final bool compact;

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
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        border: Border.all(color: theme.dividerColor.withOpacity(0.42)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.06),
            blurRadius: compact ? 18 : 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: child,
      ),
    );
  }
}

class _EditionPreviewCard extends StatelessWidget {
  const _EditionPreviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.page,
    required this.settings,
    required this.compact,
    required this.footer,
  });

  final String title;
  final String subtitle;
  final QuranPage page;
  final ReaderSettings settings;
  final bool compact;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.42)),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 14),
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
            SizedBox(height: compact ? 10 : 12),
            Expanded(
              child: _PreviewCanvas(
                page: page,
                settings: settings,
                compact: compact,
              ),
            ),
            const SizedBox(height: 12),
            footer,
          ],
        ),
      ),
    );
  }
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.page,
    required this.settings,
    required this.compact,
  });

  final QuranPage page;
  final ReaderSettings settings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = QuranConstants.pageAspectRatio(
      usesImage: page.usesImage,
      assetPath: page.assetPath,
    );
    final previewWidth = compact ? 220.0 : 260.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: RepaintBoundary(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: previewWidth,
              height: previewWidth / aspectRatio,
              child: MushafPageWidget(
                page: page,
                settings: settings,
                showPageNumbers: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withOpacity(0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
