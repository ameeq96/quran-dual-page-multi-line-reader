import 'package:flutter/material.dart';

class BookGutter extends StatelessWidget {
  const BookGutter({
    super.key,
    required this.width,
    this.lowMemoryMode = false,
  });

  final double width;
  final bool lowMemoryMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              theme.colorScheme.shadow
                  .withValues(alpha: lowMemoryMode ? 0.05 : 0.08),
              theme.colorScheme.shadow
                  .withValues(alpha: lowMemoryMode ? 0.14 : 0.24),
              theme.colorScheme.shadow
                  .withValues(alpha: lowMemoryMode ? 0.05 : 0.08),
            ],
          ),
          boxShadow: lowMemoryMode
              ? const []
              : [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
      ),
    );
  }
}
