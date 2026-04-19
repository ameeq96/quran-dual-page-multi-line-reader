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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pageAspectRatio = QuranConstants.pageAspectRatio(
          usesImage: page.usesImage,
          assetPath: page.assetPath,
        );
        final fullscreen = settings.fullscreenReading;
        final horizontalPadding =
            fullscreen ? 0.0 : math.max(2.0, constraints.maxWidth * 0.0045);
        final verticalPadding =
            fullscreen ? 0.0 : math.max(2.0, constraints.maxHeight * 0.003);
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
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Align(
            alignment: Alignment.center,
            child: RepaintBoundary(
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
                  turnAmount: 0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
