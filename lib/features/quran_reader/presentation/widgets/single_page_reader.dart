import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_page.dart';
import '../../domain/models/reader_settings.dart';
import 'mushaf_page_widget.dart';

class SinglePageReader extends StatelessWidget {
  const SinglePageReader({
    super.key,
    required this.page,
    required this.settings,
    this.smartHifzHiddenLines = const <int>{},
    this.smartHifzManualMaskAnchors = const <double>[],
    this.onSmartHifzManualMaskAnchorChanged,
    this.smartHifzRevealed = false,
    this.smartHifzEdition,
    this.smartHifzLineCount,
    this.pageOffset = 0,
  });

  final QuranPage page;
  final ReaderSettings settings;
  final Set<int> smartHifzHiddenLines;
  final List<double> smartHifzManualMaskAnchors;
  final void Function(int index, double nextAnchor)?
      onSmartHifzManualMaskAnchorChanged;
  final bool smartHifzRevealed;
  final MushafEdition? smartHifzEdition;
  final int? smartHifzLineCount;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageAspectRatio =
            page.usesImage ? QuranConstants.scannedPageAspectRatio : 0.72;
        final horizontalPadding = math.max(4.0, constraints.maxWidth * 0.012);
        final verticalPadding = math.max(4.0, constraints.maxHeight * 0.006);
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - (horizontalPadding * 2),
        );
        final availableHeight = math.max(
          0.0,
          constraints.maxHeight - (verticalPadding * 2),
        );
        final widthFitHeight = availableWidth / pageAspectRatio;
        final pageHeight = math.min(availableHeight, widthFitHeight);
        final pageWidth = pageHeight * pageAspectRatio;
        final clampedOffset = pageOffset.clamp(-1.0, 1.0);
        final pageTransform =
            settings.lowMemoryMode || clampedOffset.abs() < 0.001
                ? Matrix4.identity()
                : (Matrix4.identity()
                  ..setEntry(3, 2, 0.0011)
                  ..translate(clampedOffset * constraints.maxWidth * 0.012)
                  ..scale(1 - (clampedOffset.abs() * 0.014)));

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Align(
            alignment: Alignment.center,
            child: RepaintBoundary(
              child: Transform(
                alignment: Alignment.center,
                transform: pageTransform,
                child: SizedBox(
                  width: pageWidth,
                  height: pageHeight,
                  child: MushafPageWidget(
                    page: page,
                    settings: settings,
                    showPageNumbers: settings.showPageNumbers,
                    smartHifzHiddenLines: smartHifzHiddenLines,
                    smartHifzManualMaskAnchors: smartHifzManualMaskAnchors,
                    onSmartHifzManualMaskAnchorChanged:
                        onSmartHifzManualMaskAnchorChanged,
                    smartHifzRevealed: smartHifzRevealed,
                    smartHifzEdition: smartHifzEdition,
                    smartHifzLineCount: smartHifzLineCount,
                    alignment: Alignment.center,
                    turnAmount:
                        settings.lowMemoryMode ? 0 : clampedOffset * 0.1,
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
