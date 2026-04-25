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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final referencePage =
            spread.rightPage.usesImage ? spread.rightPage : spread.leftPage;
        final pageAspectRatio = QuranConstants.pageAspectRatio(
          usesImage: referencePage.usesImage,
          assetPath: referencePage.assetPath,
        );
        final availableWidth = math.max(0.0, constraints.maxWidth);
        final availableHeight = math.max(0.0, constraints.maxHeight);
        final fullscreen = settings.fullscreenReading;
        final gutterWidth = math.max(
          fullscreen ? 10.0 : 12.0,
          math.min(fullscreen ? 18.0 : 22.0, availableWidth * 0.018),
        );
        final spreadHeight = math.min(
          availableHeight,
          (availableWidth - gutterWidth) / (pageAspectRatio * 2),
        );
        final pageWidth = spreadHeight * pageAspectRatio;
        final spreadCanvasWidth = (pageWidth * 2) + gutterWidth;
        final theme = Theme.of(context);

        return SizedBox.expand(
          child: RepaintBoundary(
            child: Center(
              child: SizedBox(
                width: spreadCanvasWidth,
                height: spreadHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: fullscreen
                          ? const SizedBox.shrink()
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    theme.colorScheme.surface
                                        .withValues(alpha: 0.16),
                                    theme.colorScheme.surface
                                        .withValues(alpha: 0.08),
                                    theme.colorScheme.surface
                                        .withValues(alpha: 0.16),
                                  ],
                                ),
                                border: Border.all(
                                  color: theme.dividerColor
                                      .withValues(alpha: 0.16),
                                ),
                                boxShadow: settings.lowMemoryMode
                                    ? const []
                                    : [
                                        BoxShadow(
                                          color: theme.colorScheme.shadow
                                              .withValues(alpha: 0.04),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                              ),
                            ),
                    ),
                    if (!fullscreen)
                      Positioned(
                        left: 44,
                        right: 44,
                        bottom: 8,
                        child: IgnorePointer(
                          child: Container(
                            height: 20,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  theme.colorScheme.shadow
                                      .withValues(alpha: 0.08),
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
                              turnAmount: 0,
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
                              turnAmount: 0,
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
        );
      },
    );
  }
}
