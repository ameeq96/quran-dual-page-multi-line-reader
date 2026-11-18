import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../domain/models/quran_page.dart';
import '../models/reader_page_appearance.dart';

class ReaderOfflineActions extends InheritedWidget {
  const ReaderOfflineActions({
    super.key,
    required this.onOpenDownloads,
    required this.onReadBundledEdition,
    required super.child,
  });

  final VoidCallback onOpenDownloads;
  final VoidCallback? onReadBundledEdition;

  static ReaderOfflineActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReaderOfflineActions>();

  @override
  bool updateShouldNotify(ReaderOfflineActions oldWidget) =>
      onOpenDownloads != oldWidget.onOpenDownloads ||
      onReadBundledEdition != oldWidget.onReadBundledEdition;
}

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
    final offlineActions = ReaderOfflineActions.maybeOf(context);
    final guidance = offlineActions?.onReadBundledEdition != null &&
            (page.usesRemoteImage || page.contentType == QuranPageContentType.placeholder)
        ? '16-line Quran is ready offline. Download other editions once to read without internet.'
        : message ?? 'Connect to the internet, or download this Quran edition from Asset Packs for offline reading.';
    final sideInset = page.isLeftPage
        ? const EdgeInsets.fromLTRB(10, 10, 6, 10)
        : const EdgeInsets.fromLTRB(6, 10, 10, 10);
    return Padding(
      padding: sideInset,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: SingleChildScrollView(child: Padding(
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
                  tr(context, page.usesRemoteImage && offlineActions != null
                      ? 'Internet or server unavailable'
                      : title ?? 'Page is not available offline'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, guidance),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (offlineActions != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: offlineActions.onOpenDownloads,
                        icon: const Icon(Icons.download_for_offline_outlined),
                        label: Text(tr(context, 'Open downloads')),
                      ),
                      if (offlineActions.onReadBundledEdition != null)
                        OutlinedButton.icon(
                          onPressed: offlineActions.onReadBundledEdition,
                          icon: const Icon(Icons.menu_book_rounded),
                          label: Text(tr(context, 'Read 16-line Quran')),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          )),
        ),
      ),
    );
  }
}
