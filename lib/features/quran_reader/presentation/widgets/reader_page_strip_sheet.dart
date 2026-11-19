import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'quran_page_image_provider.dart';
import 'reader_app_bar.dart';
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
        ((size.width - 32 - (12 * (columns - 1))) / columns)
            .clamp(120.0, 260.0);
    final thumbnailCacheWidth =
        (MediaQuery.of(context).devicePixelRatio * tileLogicalWidth)
            .round()
            .clamp(140, 280)
            .toInt();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReaderSheetHeader(
              title: tr(context, 'Page thumbnails'),
              subtitle: tr(context, 'Jump quickly by previewing the nearby Mushaf pages.'),
              showHandle: showHandle,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 20),
                cacheExtent: size.height * 0.35,
                itemCount: controller.totalPages,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
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
                    child: Material(
                      color: selected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        side: BorderSide(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.dividerColor.withValues(alpha: 0.7),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _handlePageOpen(context, pageNumber),
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
                                                .withValues(alpha: 0.35),
                                          ),
                                          child: Center(
                                            child: Text(
                                              tr(context, 'Page\n$pageNumber'),
                                              textAlign: TextAlign.center,
                                              style: theme.textTheme.titleSmall,
                                            ),
                                          ),
                                        )
                                      : Image(
                                          image: buildQuranPageImageProvider(
                                            page,
                                            cacheWidth: thumbnailCacheWidth,
                                          ),
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.none,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              child: Text(
                                tr(context, 'Page $pageNumber'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurface,
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
