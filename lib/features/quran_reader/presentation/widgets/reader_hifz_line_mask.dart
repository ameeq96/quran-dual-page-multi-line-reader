import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/quran_page.dart';
import '../../domain/models/reader_settings.dart';

class ReaderHifzLineMask extends StatelessWidget {
  const ReaderHifzLineMask({
    super.key,
    required this.page,
    required this.edition,
    required this.lineCount,
    required this.hiddenLines,
    this.maskColor = const Color(0xFF111111),
    this.maskOpacity = 0.84,
    this.coverHeightFactorOverride,
  });

  final QuranPage page;
  final MushafEdition edition;
  final int lineCount;
  final Set<int> hiddenLines;
  final Color maskColor;
  final double maskOpacity;
  final double? coverHeightFactorOverride;

  static int resolveLineCount({
    required QuranPage page,
    required MushafEdition edition,
  }) {
    final lineNumbers = page.lines
        .map((line) => line.lineNumber)
        .where((lineNumber) => lineNumber > 0)
        .toList(growable: false);
    if (lineNumbers.isNotEmpty) {
      return lineNumbers.reduce(math.max);
    }
    return edition.lineCount ?? 16;
  }

  static Set<int> trailingHiddenLines({
    required int lineCount,
    required double coverageFactor,
  }) {
    final normalizedLineCount = lineCount.clamp(1, 32);
    final requestedHiddenCount =
        (normalizedLineCount * coverageFactor.clamp(0.12, 0.92)).round();
    final hiddenCount = requestedHiddenCount.clamp(1, normalizedLineCount);
    final startIndex = normalizedLineCount - hiddenCount;
    return <int>{
      for (var index = startIndex; index < normalizedLineCount; index += 1)
        index,
    };
  }

  static int manualPlateCount(double coverageFactor) {
    final normalized = ((coverageFactor - 0.18) / (0.7 - 0.18)).clamp(0.0, 1.0);
    return (4 + (normalized * 3)).round().clamp(4, 7);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLineCount = lineCount.clamp(1, 32);
    final effectiveHiddenLines = hiddenLines
        .where((lineIndex) => lineIndex >= 0 && lineIndex < effectiveLineCount)
        .toList(growable: false)
      ..sort();

    if (effectiveHiddenLines.isEmpty) {
      return const SizedBox.shrink();
    }

    final geometry = ReaderHifzMaskGeometry.forEdition(
      edition,
      isImagePage: page.usesImage,
    );

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
          lineSlotHeight *
              (coverHeightFactorOverride ?? geometry.coverHeightFactor),
        );

        return Stack(
          children: effectiveHiddenLines.map((lineIndex) {
            final lineTop = topInset +
                (lineIndex * lineSlotHeight) +
                ((lineSlotHeight - barHeight) / 2) +
                (lineSlotHeight * geometry.verticalNudgeFactor);
            return Positioned(
              left: constraints.maxWidth * geometry.sideInsetFactor,
              right: constraints.maxWidth * geometry.sideInsetFactor,
              top: lineTop,
              height: barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: maskColor.withValues(alpha: maskOpacity),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: maskColor.computeLuminance() < 0.5
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: maskColor.withValues(
                        alpha: maskColor.computeLuminance() < 0.5 ? 0.18 : 0.08,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class ReaderHifzMaskGeometry {
  const ReaderHifzMaskGeometry({
    required this.topInsetFactor,
    required this.bottomInsetFactor,
    required this.sideInsetFactor,
    required this.coverHeightFactor,
    required this.verticalNudgeFactor,
  });

  final double topInsetFactor;
  final double bottomInsetFactor;
  final double sideInsetFactor;
  final double coverHeightFactor;
  final double verticalNudgeFactor;

  static const _fallback = ReaderHifzMaskGeometry(
    topInsetFactor: 0.152,
    bottomInsetFactor: 0.104,
    sideInsetFactor: 0.108,
    coverHeightFactor: 0.76,
    verticalNudgeFactor: 0,
  );

  static ReaderHifzMaskGeometry forEdition(
    MushafEdition edition, {
    required bool isImagePage,
  }) {
    if (!isImagePage) {
      return const ReaderHifzMaskGeometry(
        topInsetFactor: 0.148,
        bottomInsetFactor: 0.11,
        sideInsetFactor: 0.108,
        coverHeightFactor: 0.78,
        verticalNudgeFactor: 0,
      );
    }

    return switch (edition) {
      MushafEdition.lines10 => const ReaderHifzMaskGeometry(
          topInsetFactor: 0.182,
          bottomInsetFactor: 0.12,
          sideInsetFactor: 0.1,
          coverHeightFactor: 0.66,
          verticalNudgeFactor: 0,
        ),
      MushafEdition.lines13 => const ReaderHifzMaskGeometry(
          topInsetFactor: 0.172,
          bottomInsetFactor: 0.115,
          sideInsetFactor: 0.103,
          coverHeightFactor: 0.7,
          verticalNudgeFactor: 0,
        ),
      MushafEdition.lines14 => const ReaderHifzMaskGeometry(
          topInsetFactor: 0.166,
          bottomInsetFactor: 0.112,
          sideInsetFactor: 0.105,
          coverHeightFactor: 0.72,
          verticalNudgeFactor: 0,
        ),
      MushafEdition.lines15 => const ReaderHifzMaskGeometry(
          topInsetFactor: 0.158,
          bottomInsetFactor: 0.108,
          sideInsetFactor: 0.107,
          coverHeightFactor: 0.74,
          verticalNudgeFactor: 0,
        ),
      MushafEdition.lines16 => const ReaderHifzMaskGeometry(
          topInsetFactor: 0.151,
          bottomInsetFactor: 0.105,
          sideInsetFactor: 0.109,
          coverHeightFactor: 0.76,
          verticalNudgeFactor: 0,
        ),
      MushafEdition.lines17 => const ReaderHifzMaskGeometry(
          topInsetFactor: 0.146,
          bottomInsetFactor: 0.102,
          sideInsetFactor: 0.11,
          coverHeightFactor: 0.78,
          verticalNudgeFactor: 0,
        ),
      MushafEdition.kanzulIman => _fallback,
    };
  }
}

class ReaderHifzManualMask extends StatelessWidget {
  const ReaderHifzManualMask({
    super.key,
    required this.page,
    required this.edition,
    required this.lineCount,
    required this.maskAnchors,
    this.linesHidden = true,
    this.onAnchorChanged,
    this.maskColor = const Color(0xFF111111),
    this.maskOpacity = 0.84,
    this.coverHeightFactorOverride,
  });

  final QuranPage page;
  final MushafEdition edition;
  final int lineCount;
  final List<double> maskAnchors;
  final bool linesHidden;
  final void Function(int index, double nextAnchor)? onAnchorChanged;
  final Color maskColor;
  final double maskOpacity;
  final double? coverHeightFactorOverride;

  static double anchorForLineIndex(int lineIndex, int lineCount) {
    final normalizedLineCount = lineCount.clamp(1, 32);
    final normalizedIndex = lineIndex.clamp(0, normalizedLineCount - 1);
    return (normalizedIndex + 0.5) / normalizedLineCount;
  }

  static int lineIndexForAnchor(double anchor, int lineCount) {
    final normalizedLineCount = lineCount.clamp(1, 32);
    final normalizedAnchor = anchor.clamp(0.0, 0.999999).toDouble();
    return (normalizedAnchor * normalizedLineCount)
        .floor()
        .clamp(0, normalizedLineCount - 1);
  }

  static double snappedAnchorForLocalDy({
    required double localDy,
    required double topInset,
    required double usableHeight,
    required int lineCount,
  }) {
    if (usableHeight <= 0) {
      return anchorForLineIndex(0, lineCount);
    }
    final normalizedDy =
        ((localDy - topInset) / usableHeight).clamp(0.0, 0.999999).toDouble();
    final lineIndex = lineIndexForAnchor(normalizedDy, lineCount);
    return anchorForLineIndex(lineIndex, lineCount);
  }

  static double snappedAnchorForContinuousAnchor(
    double anchor,
    int lineCount,
  ) {
    final lineIndex = lineIndexForAnchor(anchor, lineCount);
    return anchorForLineIndex(lineIndex, lineCount);
  }

  static int nearestMaskIndexForDy({
    required double localDy,
    required List<double> anchors,
    required double topInset,
    required double usableHeight,
  }) {
    if (anchors.isEmpty) {
      return 0;
    }
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < anchors.length; index += 1) {
      final anchorDy =
          topInset + (usableHeight * anchors[index].clamp(0.0, 1.0));
      final distance = (anchorDy - localDy).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    return nearestIndex;
  }

  @override
  Widget build(BuildContext context) {
    if (maskAnchors.isEmpty) {
      return const SizedBox.shrink();
    }

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
          lineSlotHeight *
              (coverHeightFactorOverride ?? geometry.coverHeightFactor),
        );

        Widget content = Stack(
          children: List.generate(maskAnchors.length, (index) {
            final clampedAnchor = maskAnchors[index].clamp(0.0, 1.0).toDouble();
            final selectedLineNumber =
                lineIndexForAnchor(clampedAnchor, effectiveLineCount) + 1;
            final top =
                topInset + (usableHeight * clampedAnchor) - (barHeight / 2);
            Widget bar = DecoratedBox(
              decoration: BoxDecoration(
                color: maskColor.withValues(
                  alpha: linesHidden
                      ? maskOpacity
                      : math.max(maskOpacity * 0.3, 0.2),
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: maskColor.computeLuminance() < 0.5
                      ? Colors.white
                          .withValues(alpha: linesHidden ? 0.06 : 0.22)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        maskColor.withValues(alpha: linesHidden ? 0.2 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      constraints: const BoxConstraints(minWidth: 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: linesHidden ? 0.18 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: linesHidden ? 0.14 : 0.24,
                          ),
                        ),
                      ),
                      child: Text(
                        'L$selectedLineNumber',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(
                                alpha: linesHidden ? 0.92 : 0.76,
                              ),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 52,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: linesHidden ? 0.34 : 0.62,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 42,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: Colors.white.withValues(
                          alpha: linesHidden ? 0.8 : 0.7,
                        ),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (onAnchorChanged != null) {
              bar = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  final tappedAnchor = snappedAnchorForLocalDy(
                    localDy: top + details.localPosition.dy,
                    topInset: topInset,
                    usableHeight: usableHeight,
                    lineCount: effectiveLineCount,
                  );
                  onAnchorChanged!(index, tappedAnchor);
                },
                onVerticalDragUpdate: (details) {
                  if (usableHeight <= 0) {
                    return;
                  }
                  final nextAnchor = snappedAnchorForContinuousAnchor(
                    clampedAnchor + (details.delta.dy / usableHeight),
                    effectiveLineCount,
                  );
                  onAnchorChanged!(index, nextAnchor);
                },
                child: bar,
              );
            }

            return Positioned(
              left: constraints.maxWidth * geometry.sideInsetFactor,
              right: constraints.maxWidth * geometry.sideInsetFactor,
              top: top
                  .clamp(
                    topInset,
                    constraints.maxHeight - bottomInset - barHeight,
                  )
                  .toDouble(),
              height: barHeight,
              child: bar,
            );
          }),
        );

        if (onAnchorChanged != null) {
          content = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              final targetIndex = nearestMaskIndexForDy(
                localDy: details.localPosition.dy,
                anchors: maskAnchors,
                topInset: topInset,
                usableHeight: usableHeight,
              );
              final tappedAnchor = snappedAnchorForLocalDy(
                localDy: details.localPosition.dy,
                topInset: topInset,
                usableHeight: usableHeight,
                lineCount: effectiveLineCount,
              );
              onAnchorChanged!(targetIndex, tappedAnchor);
            },
            child: content,
          );
        }

        return content;
      },
    );
  }
}
