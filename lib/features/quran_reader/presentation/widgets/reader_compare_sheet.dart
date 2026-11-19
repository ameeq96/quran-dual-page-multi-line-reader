import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'app_motion.dart';
import 'mushaf_page_widget.dart';
import 'reader_app_bar.dart';

class QuranCompareScreen extends StatefulWidget {
  const QuranCompareScreen({
    super.key,
    required this.controller,
  });

  final QuranReaderController controller;

  @override
  State<QuranCompareScreen> createState() => _QuranCompareScreenState();
}

class _QuranCompareScreenState extends State<QuranCompareScreen> {
  Future<void> _useEdition(MushafEdition edition) async {
    if (edition == widget.controller.settings.mushafEdition) {
      Navigator.of(context).maybePop();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    await widget.controller.selectMushafEdition(edition);
    if (!mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(tr(context, '${edition.label} is now active in the reader.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller.pageListenable,
        widget.controller.settingsListenable,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final size = MediaQuery.of(context).size;
        final compact = size.width < 420 || size.height < 760;
        final activeEdition = widget.controller.settings.mushafEdition;
        final previewSettings = widget.controller.settings.copyWith(
          hifzFocusMode: false,
          pageReflectionEnabled: false,
          pageOverlayEnabled: false,
          pagePresetEnabled: false,
          customBrightnessEnabled: false,
          lowMemoryMode: true,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'Compare Editions')),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                compact ? 10 : 14,
                16,
                24,
              ),
              children: [
                AppStagger(
                  index: 0,
                  child: _CompareHeader(
                    activeEdition: activeEdition,
                    currentPageNumber: widget.controller.currentPageNumber,
                  ),
                ),
                const SizedBox(height: 14),
                ...widget.controller.compareEditions.indexed.map((entry) {
                  final (index, edition) = entry;
                  final page =
                      widget.controller.pageForCurrentReferenceInEdition(
                    edition,
                  );
                  final navigationPage = widget.controller
                      .navigationPageForCurrentReferenceInEdition(edition);
                  final card = _CompareEditionCard(
                    edition: edition,
                    page: page,
                    navigationPage: navigationPage,
                    settings: previewSettings.copyWith(mushafEdition: edition),
                    isActive: edition == activeEdition,
                    onUseEdition: () => _useEdition(edition),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    // Only the cards visible on entry are staggered.
                    child: index < 2
                        ? AppStagger(index: index + 1, child: card)
                        : card,
                  );
                }),
                Text(
                  tr(context, 'Compare uses each edition\'s own navigation JSON, so surah and sipara mapping stays aligned with the selected scan.'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _CompareHeader extends StatelessWidget {
  const _CompareHeader({
    required this.activeEdition,
    required this.currentPageNumber,
  });

  final MushafEdition activeEdition;
  final int currentPageNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ReaderSheetCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReaderAccentBadge(icon: Icons.compare_rounded, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Same reference across all editions'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(context, 'Current reader page $currentPageNumber in ${activeEdition.label}. Switch edition directly from any card below.'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareEditionCard extends StatelessWidget {
  const _CompareEditionCard({
    required this.edition,
    required this.page,
    required this.navigationPage,
    required this.settings,
    required this.isActive,
    required this.onUseEdition,
  });

  final MushafEdition edition;
  final QuranPage page;
  final int navigationPage;
  final ReaderSettings settings;
  final bool isActive;
  final VoidCallback onUseEdition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final compact = size.width < 420 || size.height < 760;
    final pageAspectRatio = QuranConstants.pageAspectRatio(
      usesImage: page.usesImage,
      assetPath: page.assetPath,
    );
    final previewWidth = compact ? 210.0 : 250.0;
    final previewHeight = previewWidth / pageAspectRatio;

    return ReaderSheetCard(
      highlighted: isActive,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, edition.label),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(context, '${edition.companyLabel} - Reader page $navigationPage'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      tr(context, isActive ? 'Active' : 'Available'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Center(
                child: RepaintBoundary(
                  child: SizedBox(
                    width: previewWidth,
                    height: previewHeight,
                    child: MushafPageWidget(
                      page: page,
                      settings: settings,
                      showPageNumbers: false,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ReaderInfoPill(
                  icon: Icons.menu_book_rounded,
                  label: tr(context, 'Page ${page.number}'),
                ),
                ReaderInfoPill(
                  icon: Icons.layers_outlined,
                  label: tr(context, edition.bestUseLabel),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              tr(context, edition.historySummary),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: isActive
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: onUseEdition,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(tr(context, 'Back to reader')),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: onUseEdition,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text(tr(context, 'Use ${edition.label}')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
