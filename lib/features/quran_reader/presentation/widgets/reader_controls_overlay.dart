import 'package:flutter/material.dart';

class ReaderControlsOverlay extends StatelessWidget {
  const ReaderControlsOverlay({
    super.key,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 280 || constraints.maxWidth < 520;
          final ultraCompact = constraints.maxHeight < 220;
          final buttonBottom = ultraCompact ? 64.0 : (compact ? 82.0 : 98.0);
          final edgeInset = compact ? 12.0 : 18.0;
          final hintBottom = ultraCompact ? 10.0 : 22.0;

          return Stack(
            children: [
              Positioned(
                left: edgeInset,
                bottom: buttonBottom,
                child: _ReaderEdgeButton(
                  label: 'Next',
                  helper: 'Move forward',
                  icon: Icons.arrow_back_rounded,
                  enabled: canGoNext,
                  onPressed: onNext,
                  compact: compact,
                ),
              ),
              Positioned(
                right: edgeInset,
                bottom: buttonBottom,
                child: _ReaderEdgeButton(
                  label: 'Previous',
                  helper: 'Go back',
                  icon: Icons.arrow_forward_rounded,
                  enabled: canGoPrevious,
                  onPressed: onPrevious,
                  compact: compact,
                ),
              ),
              if (!ultraCompact)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: hintBottom,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: 0.66),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .shadow
                                .withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 13 : 18,
                          vertical: compact ? 8 : 10,
                        ),
                        child: Text(
                          'Tap anywhere to focus on reading',
                          style: compact
                              ? Theme.of(context).textTheme.labelMedium
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReaderEdgeButton extends StatelessWidget {
  const _ReaderEdgeButton({
    required this.label,
    required this.helper,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    required this.compact,
  });

  final String label;
  final String helper;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface.withValues(alpha: 0.94),
              theme.colorScheme.surfaceContainer.withValues(alpha: 0.86),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.52),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 8 : 10,
          ),
          child: FilledButton.tonalIcon(
            onPressed: enabled ? onPressed : null,
            icon: Icon(icon, size: compact ? 20 : null),
            label: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (!compact)
                  Text(
                    helper,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            style: FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.34),
              foregroundColor: theme.colorScheme.onSurface,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 15 : 18,
                vertical: compact ? 11 : 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(compact ? 16 : 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
