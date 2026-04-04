import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_spread.dart';
import '../../domain/models/reader_settings.dart';
import 'book_gutter.dart';
import 'mushaf_page_widget.dart';

class DualPageSpread extends StatelessWidget {
  const DualPageSpread({
    super.key,
    required this.spread,
    required this.settings,
    this.leftSmartHifzHiddenLines = const <int>{},
    this.rightSmartHifzHiddenLines = const <int>{},
    this.leftSmartHifzManualMaskAnchors = const <double>[],
    this.rightSmartHifzManualMaskAnchors = const <double>[],
    this.onLeftSmartHifzManualMaskAnchorChanged,
    this.onRightSmartHifzManualMaskAnchorChanged,
    this.leftSmartHifzRevealed = false,
    this.rightSmartHifzRevealed = false,
    this.leftSmartHifzEdition,
    this.rightSmartHifzEdition,
    this.leftSmartHifzLineCount,
    this.rightSmartHifzLineCount,
    this.spreadOffset = 0,
  });

  final QuranSpread spread;
  final ReaderSettings settings;
  final Set<int> leftSmartHifzHiddenLines;
  final Set<int> rightSmartHifzHiddenLines;
  final List<double> leftSmartHifzManualMaskAnchors;
  final List<double> rightSmartHifzManualMaskAnchors;
  final void Function(int index, double nextAnchor)?
      onLeftSmartHifzManualMaskAnchorChanged;
  final void Function(int index, double nextAnchor)?
      onRightSmartHifzManualMaskAnchorChanged;
  final bool leftSmartHifzRevealed;
  final bool rightSmartHifzRevealed;
  final MushafEdition? leftSmartHifzEdition;
  final MushafEdition? rightSmartHifzEdition;
  final int? leftSmartHifzLineCount;
  final int? rightSmartHifzLineCount;
  final double spreadOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final usesScannedPages =
            spread.leftPage.usesImage || spread.rightPage.usesImage;
        final pageAspectRatio =
            usesScannedPages ? QuranConstants.scannedPageAspectRatio : 0.72;
        final availableWidth = math.max(0.0, constraints.maxWidth);
        final availableHeight = math.max(0.0, constraints.maxHeight);
        final gutterWidth = math.max(
          18.0,
          math.min(30.0, availableWidth * 0.026),
        );
        final spreadHeight = math.min(
          availableHeight,
          (availableWidth - gutterWidth) / (pageAspectRatio * 2),
        );
        final pageWidth = spreadHeight * pageAspectRatio;
        final spreadCanvasWidth = (pageWidth * 2) + gutterWidth;
        final clampedOffset = spreadOffset.clamp(-1.0, 1.0);
        final effectiveOffset = settings.lowMemoryMode ? 0.0 : clampedOffset;
        final theme = Theme.of(context);
        final spreadTransform =
            settings.lowMemoryMode || effectiveOffset.abs() < 0.001
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..translate(effectiveOffset * constraints.maxWidth * 0.05)
                  ..scale(1 - (effectiveOffset.abs() * 0.024))
                  ..rotateY(effectiveOffset * -0.1));

        return SizedBox.expand(
          child: RepaintBoundary(
            child: Transform(
              alignment: Alignment.center,
              transform: spreadTransform,
              child: Center(
                child: SizedBox(
                  width: spreadCanvasWidth,
                  height: spreadHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                theme.colorScheme.surface.withOpacity(0.28),
                                theme.colorScheme.surface.withOpacity(0.12),
                                theme.colorScheme.surface.withOpacity(0.28),
                              ],
                            ),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.24),
                            ),
                            boxShadow: settings.lowMemoryMode
                                ? const []
                                : [
                                    BoxShadow(
                                      color: theme.colorScheme.shadow
                                          .withOpacity(0.06),
                                      blurRadius: 22,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 44,
                        right: 44,
                        bottom: 8,
                        child: IgnorePointer(
                          child: Container(
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  theme.colorScheme.shadow.withOpacity(0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: pageWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 0.5),
                              child: MushafPageWidget(
                                page: spread.leftPage,
                                settings: settings,
                                showPageNumbers: settings.showPageNumbers,
                                smartHifzHiddenLines: leftSmartHifzHiddenLines,
                                smartHifzManualMaskAnchors:
                                    leftSmartHifzManualMaskAnchors,
                                onSmartHifzManualMaskAnchorChanged:
                                    onLeftSmartHifzManualMaskAnchorChanged,
                                smartHifzRevealed: leftSmartHifzRevealed,
                                smartHifzEdition: leftSmartHifzEdition,
                                smartHifzLineCount: leftSmartHifzLineCount,
                                alignment: Alignment.centerRight,
                                turnAmount: effectiveOffset * 0.7,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: pageWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 0.5),
                              child: MushafPageWidget(
                                page: spread.rightPage,
                                settings: settings,
                                showPageNumbers: settings.showPageNumbers,
                                smartHifzHiddenLines: rightSmartHifzHiddenLines,
                                smartHifzManualMaskAnchors:
                                    rightSmartHifzManualMaskAnchors,
                                onSmartHifzManualMaskAnchorChanged:
                                    onRightSmartHifzManualMaskAnchorChanged,
                                smartHifzRevealed: rightSmartHifzRevealed,
                                smartHifzEdition: rightSmartHifzEdition,
                                smartHifzLineCount: rightSmartHifzLineCount,
                                alignment: Alignment.centerLeft,
                                turnAmount: effectiveOffset * 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      IgnorePointer(
                        child: SizedBox(
                          height: double.infinity,
                          child: BookGutter(
                            width: gutterWidth,
                            lowMemoryMode: settings.lowMemoryMode,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
