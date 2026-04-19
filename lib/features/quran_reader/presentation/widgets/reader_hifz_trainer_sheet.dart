import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'mushaf_page_widget.dart';
import 'reader_hifz_line_mask.dart';

Future<void> showReaderHifzTrainerSheet(
  BuildContext context, {
  required QuranReaderController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.94,
        child: _ReaderHifzTrainerSheet(controller: controller),
      );
    },
  );
}

class _ReaderHifzTrainerSheet extends StatefulWidget {
  const _ReaderHifzTrainerSheet({
    required this.controller,
  });

  final QuranReaderController controller;

  @override
  State<_ReaderHifzTrainerSheet> createState() =>
      _ReaderHifzTrainerSheetState();
}

class _ReaderHifzTrainerSheetState extends State<_ReaderHifzTrainerSheet> {
  List<double> _maskAnchors = const <double>[];
  bool _linesHidden = true;

  MushafEdition get _edition => widget.controller.primaryStudyEdition;

  int get _standardPage => widget.controller.currentStandardPageNumber;

  QuranPage get _page => widget.controller.pageForCurrentReferenceInEdition(
        _edition,
      );

  int get _lineCount => ReaderHifzLineMask.resolveLineCount(
        page: _page,
        edition: _edition,
      );

  @override
  void initState() {
    super.initState();
    _resetAnchors();
  }

  List<double> _buildDefaultAnchors() {
    final lineCount = _lineCount;
    final maskCount = math.min(6, math.max(5, lineCount ~/ 2));
    final anchors = <double>[];
    for (var index = 0; index < maskCount; index += 1) {
      final lineIndex =
          (((index + 1) * lineCount) / (maskCount + 1)).round().clamp(
                0,
                lineCount - 1,
              );
      anchors.add((lineIndex + 0.5) / lineCount);
    }
    return anchors;
  }

  void _syncChallenge() {
    widget.controller.applySmartHifzManualChallenge(
      standardPageNumber: _standardPage,
      maskAnchors: _maskAnchors,
      edition: _edition,
      lineCount: _lineCount,
      revealed: !_linesHidden,
    );
  }

  void _resetAnchors() {
    _maskAnchors = _buildDefaultAnchors();
    _syncChallenge();
  }

  void _updateAnchor(int index, double nextAnchor) {
    final nextAnchors = List<double>.from(_maskAnchors);
    nextAnchors[index] = nextAnchor.clamp(0.0, 1.0).toDouble();
    setState(() {
      _maskAnchors = nextAnchors;
    });
    _syncChallenge();
  }

  void _toggleLinesVisibility() {
    setState(() {
      _linesHidden = !_linesHidden;
    });
    _syncChallenge();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final compact = size.width < 420 || size.height < 760;
    final page = _page;

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
          _TrainerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart hifz trainer',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Six hide bars are ready. Drag any bar to the exact line you want to cover. The same bars also appear on the live reader page.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TrainerChip(
                      icon: Icons.menu_book_rounded,
                      label: '${_edition.label} - Page ${page.number}',
                    ),
                    _TrainerChip(
                      icon: Icons.drag_indicator_rounded,
                      label: '${_maskAnchors.length} movable bars',
                    ),
                    _TrainerChip(
                      icon: _linesHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      label: _linesHidden ? 'Lines hidden' : 'Lines visible',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _toggleLinesVisibility,
                      icon: Icon(
                        _linesHidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      label: Text(
                        _linesHidden ? 'Show lines' : 'Hide lines',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(_resetAnchors);
                      },
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reset bars'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _TrainerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: compact ? 360 : 440,
                  child: _ManualHifzPreview(
                    page: page,
                    edition: _edition,
                    settings: widget.controller.settings.copyWith(
                      hifzFocusMode: false,
                    ),
                    lineCount: _lineCount,
                    maskAnchors: _maskAnchors,
                    linesHidden: _linesHidden,
                    onAnchorChanged: _updateAnchor,
                    onReset: () {
                      setState(_resetAnchors);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _linesHidden
                      ? 'Drag any bar vertically to place it on the exact line you want to cover. Double tap the preview to reset.'
                      : 'Lines are visible right now. Tap Hide lines to apply the same bars on the preview and the live reader page.',
                  style: theme.textTheme.bodySmall?.copyWith(
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

class _ManualHifzPreview extends StatelessWidget {
  const _ManualHifzPreview({
    required this.page,
    required this.edition,
    required this.settings,
    required this.lineCount,
    required this.maskAnchors,
    required this.linesHidden,
    required this.onAnchorChanged,
    required this.onReset,
  });

  final QuranPage page;
  final MushafEdition edition;
  final ReaderSettings settings;
  final int lineCount;
  final List<double> maskAnchors;
  final bool linesHidden;
  final void Function(int index, double nextAnchor) onAnchorChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aspectRatio = QuranConstants.pageAspectRatio(
      usesImage: page.usesImage,
      assetPath: page.assetPath,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 280,
            height: 280 / aspectRatio,
            child: GestureDetector(
              onDoubleTap: onReset,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MushafPageWidget(
                      page: page,
                      settings: settings,
                      showPageNumbers: false,
                    ),
                  ),
                  Positioned.fill(
                    child: _ManualMaskEditor(
                      page: page,
                      edition: edition,
                      lineCount: lineCount,
                      maskAnchors: maskAnchors,
                      linesHidden: linesHidden,
                      onAnchorChanged: onAnchorChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualMaskEditor extends StatelessWidget {
  const _ManualMaskEditor({
    required this.page,
    required this.edition,
    required this.lineCount,
    required this.maskAnchors,
    required this.linesHidden,
    required this.onAnchorChanged,
  });

  final QuranPage page;
  final MushafEdition edition;
  final int lineCount;
  final List<double> maskAnchors;
  final bool linesHidden;
  final void Function(int index, double nextAnchor) onAnchorChanged;

  @override
  Widget build(BuildContext context) {
    final geometry = ReaderHifzMaskGeometry.forEdition(
      edition,
      isImagePage: page.usesImage,
    );
    final effectiveLineCount = lineCount.clamp(1, 32);

    return LayoutBuilder(
      builder: (context, constraints) {
        final topInset = constraints.maxHeight * geometry.topInsetFactor;
        final bottomInset = constraints.maxHeight * geometry.bottomInsetFactor;
        final usableHeight = math.max(
          0.0,
          constraints.maxHeight - topInset - bottomInset,
        );
        final lineSlotHeight = usableHeight / effectiveLineCount;
        final barHeight = math.max(
          12.0,
          lineSlotHeight * geometry.coverHeightFactor,
        );

        return Stack(
          children: List.generate(maskAnchors.length, (index) {
            final anchor = maskAnchors[index].clamp(0.0, 1.0).toDouble();
            final top = (topInset + (usableHeight * anchor) - (barHeight / 2))
                .clamp(
                  topInset,
                  constraints.maxHeight - bottomInset - barHeight,
                )
                .toDouble();

            return Positioned(
              left: constraints.maxWidth * geometry.sideInsetFactor,
              right: constraints.maxWidth * geometry.sideInsetFactor,
              top: top,
              height: barHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (usableHeight <= 0) {
                    return;
                  }
                  final nextAnchor = anchor + (details.delta.dy / usableHeight);
                  onAnchorChanged(index, nextAnchor);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: linesHidden
                        ? const Color(0xFF090909).withOpacity(0.92)
                        : const Color(0xFF111111).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: linesHidden
                          ? Colors.white.withOpacity(0.08)
                          : Colors.white.withOpacity(0.24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          linesHidden ? 0.24 : 0.08,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(
                          linesHidden ? 0.32 : 0.6,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _TrainerCard extends StatelessWidget {
  const _TrainerCard({
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
        border: Border.all(color: theme.dividerColor.withOpacity(0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _TrainerChip extends StatelessWidget {
  const _TrainerChip({
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
        border: Border.all(color: theme.dividerColor.withOpacity(0.36)),
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
