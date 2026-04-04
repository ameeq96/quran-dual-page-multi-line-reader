import 'package:flutter/material.dart';

import '../controllers/quran_reader_controller.dart';
import 'reader_sheet_frame.dart';

Future<void> showReaderBookmarksSheet(
  BuildContext context, {
  required QuranReaderController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.88,
        child: ReaderSheetFrame(
          child: ReaderBookmarksContent(
            controller: controller,
            showHandle: true,
          ),
        ),
      );
    },
  );
}

class ReaderBookmarksContent extends StatelessWidget {
  const ReaderBookmarksContent({
    super.key,
    required this.controller,
    this.showHandle = false,
    this.onSelectPage,
  });

  final QuranReaderController controller;
  final bool showHandle;
  final Future<void> Function(int pageNumber)? onSelectPage;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.contentListenable,
      builder: (context, _) {
        final theme = Theme.of(context);
        final bookmarksByFolder = controller.bookmarksByFolder;
        final visibleFolders = bookmarksByFolder.entries
            .where((entry) => entry.value.isNotEmpty)
            .toList(growable: false);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: ListView(
              children: [
                Center(
                  child: showHandle
                      ? Container(
                          width: 54,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(height: showHandle ? 20 : 4),
                Text(
                  'Bookmarks',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Open your saved pages directly from here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (visibleFolders.isEmpty && controller.favoritePages.isEmpty)
                  _BookmarksCard(
                    child: Text(
                      'No bookmarks saved yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (controller.favoritePages.isNotEmpty) ...[
                  _BookmarksCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favorites',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: controller.favoritePages.map((pageNumber) {
                            return ActionChip(
                              label: Text('Page $pageNumber'),
                              onPressed: () async {
                                if (onSelectPage != null) {
                                  await onSelectPage!(pageNumber);
                                } else {
                                  Navigator.of(context).pop();
                                  await controller.jumpToPage(pageNumber);
                                }
                              },
                            );
                          }).toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                ...visibleFolders.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _BookmarksCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: entry.value.map((bookmark) {
                              return ActionChip(
                              label: Text(bookmark.label),
                              onPressed: () async {
                                if (onSelectPage != null) {
                                  await onSelectPage!(bookmark.pageNumber);
                                } else {
                                  Navigator.of(context).pop();
                                  await controller.jumpToPage(
                                    bookmark.pageNumber,
                                  );
                                }
                              },
                            );
                          }).toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookmarksCard extends StatelessWidget {
  const _BookmarksCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}
