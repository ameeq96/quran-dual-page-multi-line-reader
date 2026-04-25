import 'package:flutter/material.dart';

import '../../domain/models/quran_page.dart';
import '../models/reader_page_appearance.dart';

class PlaceholderQuranPage extends StatelessWidget {
  const PlaceholderQuranPage({
    super.key,
    required this.page,
    required this.appearance,
    this.title,
    this.message,
    this.icon = Icons.cloud_off_rounded,
  });

  final QuranPage page;
  final ReaderPageAppearance appearance;
  final String? title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sideInset = page.isLeftPage
        ? const EdgeInsets.fromLTRB(10, 10, 6, 10)
        : const EdgeInsets.fromLTRB(6, 10, 10, 10);
    return Padding(
      padding: sideInset,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appearance.baseColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: appearance.borderColor),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 42,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  title ?? 'Page is not available offline',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message ??
                      'Connect to the internet, or download this Quran edition from Asset Packs for offline reading.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
