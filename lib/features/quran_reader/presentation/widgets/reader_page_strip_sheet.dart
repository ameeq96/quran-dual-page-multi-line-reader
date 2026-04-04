import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'reader_sheet_frame.dart';

Future<void> showReaderPageStripSheet(
  BuildContext context, {
  required QuranReaderController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.9,
        child: ReaderSheetFrame(
          child: ReaderPageStripContent(
            controller: controller,
            showHandle: true,
          ),
        ),
      );
    },
  );
}

class QuranPageStripScreen extends StatelessWidget {
  const QuranPageStripScreen({
    super.key,
    required this.controller,
    this.onSelectPage,
  });

  final QuranReaderController controller;
  final Future<void> Function(int pageNumber)? onSelectPage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderSettings>(
      valueListenable: controller.settingsListenable,
      builder: (context, settings, _) {
        return Theme(
          data: settings.nightMode ? AppTheme.dark() : AppTheme.light(),
          child: Scaffold(
            body: SafeArea(
              child: ReaderPageStripContent(
                controller: controller,
                showHandle: false,
                onSelectPage: onSelectPage ??
                    (pageNumber) async {
                      Navigator.of(context).pop(pageNumber);
                    },
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReaderPageStripContent extends StatelessWidget {
  const ReaderPageStripContent({
    super.key,
    required this.controller,
    this.showHandle = true,
    this.onSelectPage,
  });

  final QuranReaderController controller;
  final bool showHandle;
  final Future<void> Function(int pageNumber)? onSelectPage;

  Future<void> _handlePageOpen(BuildContext context, int pageNumber) async {
    if (onSelectPage != null) {
      await onSelectPage!(pageNumber);
      return;
    }
    Navigator.of(context).pop();
    await controller.jumpToPage(pageNumber);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final columns = size.width > 900
        ? 5
        : size.width > 700
            ? 4
            : 3;
    final tileLogicalWidth =
        ((size.width - 40 - (12 * (columns - 1))) / columns)
            .clamp(120.0, 260.0);
    final thumbnailCacheWidth =
        (MediaQuery.of(context).devicePixelRatio * tileLogicalWidth)
            .round()
            .clamp(180, 420)
            .toInt();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHandle) ...[
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(
              'Page thumbnails',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Jump quickly by previewing the nearby Mushaf pages.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                cacheExtent: size.height * 1.1,
                itemCount: controller.totalPages,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                itemBuilder: (context, index) {
                  final pageNumber = index + 1;
                  final page = controller.pageForNumber(pageNumber);
                  final selected = pageNumber == controller.currentPageNumber;

                  return RepaintBoundary(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _handlePageOpen(context, pageNumber),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.dividerColor.withOpacity(0.5),
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: page.assetPath == null
                                      ? DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme
                                                .surfaceContainerHighest
                                                .withOpacity(0.35),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Page\n$pageNumber',
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.titleSmall,
                                            ),
                                          ),
                                        )
                                      : Image.asset(
                                          page.assetPath!,
                                          fit: BoxFit.cover,
                                          cacheWidth: thumbnailCacheWidth,
                                          filterQuality: FilterQuality.none,
                                        ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              child: Text(
                                'Page $pageNumber',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
