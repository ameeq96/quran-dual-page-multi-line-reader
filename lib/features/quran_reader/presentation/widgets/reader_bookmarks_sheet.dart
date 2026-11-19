import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../controllers/quran_reader_controller.dart';
import 'app_motion.dart';
import 'app_page_header.dart';
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
    this.eyebrow,
    this.onBack,
  });

  final QuranReaderController controller;
  final bool showHandle;

  /// Optional label shown above the header title (already localized).
  final String? eyebrow;

  /// Shows a back button in the header when non-null.
  final VoidCallback? onBack;
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
                            color: theme.dividerColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                SizedBox(height: showHandle ? 20 : 4),
                AppPageHeader(
                  eyebrow: eyebrow,
                  title: tr(context, 'Bookmarks'),
                  subtitle: tr(
                    context,
                    'Open your saved pages directly from here.',
                  ),
                  icon: Icons.bookmarks_rounded,
                  compact: showHandle,
                  onBack: onBack,
                ),
                const SizedBox(height: 18),
                if (visibleFolders.isEmpty && controller.favoritePages.isEmpty)
                  AppStagger(
                    index: 0,
                    child: _BookmarksCard(
                      child: Text(
                        tr(context, 'No bookmarks saved yet.'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                if (controller.favoritePages.isNotEmpty) ...[
                  AppStagger(
                    index: 0,
                    child: _BookmarksCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'Favorites'),
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
                              label: Text(tr(context, 'Page $pageNumber')),
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
                                // Long labels end in an ellipsis instead of
                                // being cut at the chip edge.
                                label: Text(
                                  bookmark.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
