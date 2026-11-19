import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';

class ReaderSkeletonBlock extends StatelessWidget {
  const ReaderSkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.sm)),
    this.alignment = AlignmentDirectional.centerStart,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Opaque container tones, so a block reads the same on a card, on the
    // sheet background and on the page placeholder.
    final base = theme.colorScheme.surfaceContainerHigh;
    final edge = theme.colorScheme.surfaceContainerLow;

    return Align(
      alignment: alignment,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: <Color>[
              base,
              edge,
              base,
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderSkeletonLines extends StatelessWidget {
  const ReaderSkeletonLines({
    super.key,
    this.lineCount = 4,
    this.lineHeight = 12,
    this.spacing = 10,
    this.lastLineWidthFactor = 0.6,
  });

  final int lineCount;
  final double lineHeight;
  final double spacing;
  final double lastLineWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List<Widget>.generate(lineCount, (index) {
        final isLast = index == lineCount - 1;
        return Padding(
          padding:
              EdgeInsets.only(bottom: index == lineCount - 1 ? 0 : spacing),
          child: ReaderSkeletonBlock(
            height: lineHeight,
            width: isLast ? 220 * lastLineWidthFactor : double.infinity,
            alignment: isLast
                ? AlignmentDirectional.centerStart
                : Alignment.center,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class ReaderSkeletonResultList extends StatelessWidget {
  const ReaderSkeletonResultList({
    super.key,
    this.itemCount = 5,
    this.compact = false,
  });

  final int itemCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tilePadding = compact ? 12.0 : 16.0;

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final theme = Theme.of(context);
        return Container(
          padding: EdgeInsets.all(tilePadding),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg - 2),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.7),
            ),
            boxShadow: AppDecor.of(context).cardShadow,
          ),
          child: Row(
            children: [
              const ReaderSkeletonBlock(
                width: 44,
                height: 44,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReaderSkeletonBlock(
                      height: 16,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    SizedBox(height: 10),
                    ReaderSkeletonBlock(
                      height: 12,
                      width: 180,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ReaderSkeletonBlock(
                width: compact ? 54 : 68,
                height: compact ? 12 : 14,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ReaderSkeletonPage extends StatelessWidget {
  const ReaderSkeletonPage({
    super.key,
    this.showLines = true,
  });

  final bool showLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerLowest,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          children: [
            const ReaderSkeletonBlock(
              width: 160,
              height: 16,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: showLines
                  ? const ReaderSkeletonLines(
                      lineCount: 12,
                      lineHeight: 12,
                      spacing: 12,
                    )
                  : const SizedBox.expand(),
            ),
          ],
        ),
      ),
    );
  }
}
