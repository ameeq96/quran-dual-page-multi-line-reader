import 'package:flutter/material.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'mushaf_page_widget.dart';

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
        content: Text('${edition.label} is now active in the reader.'),
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
            title: const Text('Compare Editions'),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 16,
                compact ? 10 : 14,
                compact ? 12 : 16,
                24,
              ),
              children: [
                _CompareHeader(
                  activeEdition: activeEdition,
                  currentPageNumber: widget.controller.currentPageNumber,
                ),
                const SizedBox(height: 14),
                ...widget.controller.compareEditions.map((edition) {
                  final page =
                      widget.controller.pageForCurrentReferenceInEdition(
                    edition,
                  );
                  final navigationPage = widget.controller
                      .navigationPageForCurrentReferenceInEdition(edition);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _CompareEditionCard(
                      edition: edition,
                      page: page,
                      navigationPage: navigationPage,
                      settings: previewSettings,
                      isActive: edition == activeEdition,
                      onUseEdition: () => _useEdition(edition),
                    ),
                  );
                }),
                Text(
                  'Compare uses each edition\'s own navigation JSON, so surah and sipara mapping stays aligned with the selected scan.',
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.36)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Same reference across all editions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Current reader page $currentPageNumber in ${activeEdition.label}. Switch edition directly from any card below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.38)
              : theme.dividerColor.withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                        edition.label,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${edition.companyLabel} - Reader page $navigationPage',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.14)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      isActive ? 'Active' : 'Available',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? theme.colorScheme.primary
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
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
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
                _CompareChip(
                  icon: Icons.menu_book_rounded,
                  label: 'Page ${page.number}',
                ),
                _CompareChip(
                  icon: Icons.layers_outlined,
                  label: edition.bestUseLabel,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              edition.historySummary,
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
                      onPressed: onUseEdition,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Back to reader'),
                    )
                  : FilledButton.icon(
                      onPressed: onUseEdition,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: Text('Use ${edition.label}'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareChip extends StatelessWidget {
  const _CompareChip({
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
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
