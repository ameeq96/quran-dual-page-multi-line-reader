import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';
import 'app_motion.dart';

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
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);

    // Mushaf pages always turn right-to-left, so "next" stays on the physical
    // left edge in every app language. The arrows are pinned to LTR so they
    // keep pointing outwards instead of mirroring under Urdu or Arabic.
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
                  label: tr(context, 'Next'),
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
                  label: tr(context, 'Previous'),
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: edgeInset),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.7),
                          ),
                          boxShadow: decor.cardShadow,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 14 : 18,
                            vertical: compact ? 8 : 10,
                          ),
                          child: Text(
                            tr(context, 'Tap anywhere to focus on reading'),
                            textAlign: TextAlign.center,
                            style: (compact
                                    ? theme.textTheme.labelMedium
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
      duration: AppMotion.release,
      opacity: enabled ? 1 : 0.6,
      child: AppPressable(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppDecor.of(context).floatShadow,
          ),
          child: Material(
            // Fully opaque so the label keeps its contrast over both the
            // light and the night page tones.
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              side: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.7),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FilledButton.tonalIcon(
                onPressed: enabled ? onPressed : null,
                icon: Icon(
                  icon,
                  size: compact ? 20 : 22,
                  textDirection: TextDirection.ltr,
                ),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, label)),
                    if (!compact)
                      Text(
                        tr(context, helper),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                style: FilledButton.styleFrom(
                  elevation: 0,
                  minimumSize: const Size(48, 48),
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  foregroundColor: theme.colorScheme.onSurface,
                  disabledBackgroundColor:
                      theme.colorScheme.surfaceContainerLow,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 14 : 18,
                    vertical: compact ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
