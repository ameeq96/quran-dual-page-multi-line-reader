import 'package:flutter/material.dart';

class ReaderSkeletonBlock extends StatelessWidget {
  const ReaderSkeletonBlock({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.alignment = Alignment.centerLeft,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.34 : 0.62,
    );
    final edge = theme.colorScheme.outlineVariant.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.18 : 0.18,
    );

    return Align(
      alignment: alignment,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
            alignment: isLast ? Alignment.centerLeft : Alignment.center,
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
    final tilePadding = compact ? 12.0 : 14.0;

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.all(tilePadding),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const ReaderSkeletonBlock(
                width: 42,
                height: 42,
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
            theme.colorScheme.surface.withValues(alpha: 0.98),
            theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.98),
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
