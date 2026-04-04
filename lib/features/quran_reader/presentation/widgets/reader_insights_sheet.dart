import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_bookmark.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'reader_sheet_frame.dart';

enum _TranslationPane {
  english('English'),
  urdu('Urdu');

  const _TranslationPane(this.label);

  final String label;
}

Future<void> showReaderInsightsSheet(
  BuildContext context, {
  required QuranReaderController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.94,
        child: ReaderSheetFrame(
          child: ReaderInsightsContent(
            controller: controller,
            showHandle: true,
          ),
        ),
      );
    },
  );
}

class QuranInsightsScreen extends StatelessWidget {
  const QuranInsightsScreen({
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
              child: ReaderInsightsContent(
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

class ReaderInsightsContent extends StatefulWidget {
  const ReaderInsightsContent({
    super.key,
    required this.controller,
    this.showHandle = true,
    this.onSelectPage,
  });

  final QuranReaderController controller;
  final bool showHandle;
  final Future<void> Function(int pageNumber)? onSelectPage;

  @override
  State<ReaderInsightsContent> createState() => _ReaderInsightsContentState();
}

class _ReaderInsightsContentState extends State<ReaderInsightsContent> {
  late Future<String?> _chapterInfoFuture;
  late Future<String?> _tafsirFuture;
  late final TextEditingController _noteController;
  late double _dailyTargetDraft;
  String _selectedBookmarkFolder = 'General';
  _TranslationPane _pane = _TranslationPane.english;

  @override
  void initState() {
    super.initState();
    _chapterInfoFuture = widget.controller.loadCurrentChapterInfo();
    _tafsirFuture = widget.controller.loadCurrentTafsirExcerpt();
    _noteController = TextEditingController(
      text:
          widget.controller.noteForPage(widget.controller.currentPageNumber) ??
              '',
    );
    _dailyTargetDraft = widget.controller.dailyTargetPages.toDouble();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller.pageListenable,
        widget.controller.audioListenable,
        widget.controller.contentListenable,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final size = MediaQuery.of(context).size;
        final compact = size.width < 420 || size.height < 760;
        final pagePadding = compact ? 10.0 : 12.0;
        final sectionGap = compact ? 10.0 : 12.0;
        final controller = widget.controller;
        final insight = controller.currentPageInsight;
        final chapter = controller.currentChapterSummary;
        final currentBookmark =
            controller.bookmarkForPage(controller.currentPageNumber);
        final translation = _pane == _TranslationPane.english
            ? insight?.translationEn ?? ''
            : insight?.translationUr ?? '';

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: pagePadding,
              right: pagePadding,
              top: widget.showHandle ? (compact ? 10 : 12) : 4,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  (compact ? 12 : 14),
            ),
            child: ListView(
              children: [
                if (widget.showHandle) ...[
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
                  SizedBox(height: sectionGap),
                ],
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter?.nameSimple ?? 'Reading insights',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        chapter == null
                            ? 'Page ${controller.currentPageNumber}'
                            : '${chapter.nameArabic} | Page ${controller.currentPageNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _StatPill(
                            label: 'Khatam',
                            value:
                                '${(controller.khatamProgress * 100).round()}%',
                          ),
                          _StatPill(
                            label: 'Daily',
                            value: controller.dailyProgressSummaryLabel,
                          ),
                          _StatPill(
                            label: 'Streak',
                            value: '${controller.readingStreakCount} days',
                          ),
                          _StatPill(
                            label: 'Remaining',
                            value: '${controller.remainingPages} pages',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        controller.dailyProgressStatusLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: controller.isDailyTargetComplete
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current page actions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () {
                              controller.toggleFavoritePage();
                            },
                            icon: Icon(
                              controller.isCurrentPageFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                            ),
                            label: Text(
                              controller.isCurrentPageFavorite
                                  ? 'Favorited page'
                                  : 'Favorite page',
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              controller.toggleBookmarkCurrentPage(
                                _selectedBookmarkFolder,
                              );
                            },
                            icon: Icon(
                              controller.isCurrentPageBookmarked
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_add_outlined,
                            ),
                            label: Text(
                              controller.isCurrentPageBookmarked
                                  ? 'Bookmarked page'
                                  : 'Bookmark page',
                            ),
                          ),
                          if (controller.hasActiveAudioSelection)
                            Chip(
                              avatar: const Icon(
                                Icons.headphones_rounded,
                                size: 18,
                              ),
                              label: Text(
                                controller.hasAudioResumePoint
                                    ? 'Resume audio at ${_formatMillis(controller.audioResumePositionMillis)}'
                                    : 'Audio ready for this recitation',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentBookmark == null
                            ? 'Bookmark shelf'
                            : 'Saved in ${currentBookmark.folder}',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controller.bookmarkFolders.map((folder) {
                          return ChoiceChip(
                            label: Text(folder),
                            selected: _selectedBookmarkFolder == folder,
                            onSelected: (_) {
                              setState(() {
                                _selectedBookmarkFolder = folder;
                              });
                            },
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily reading target',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set your target, then use the khatam plans below to pace your reading.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Slider(
                        value: _dailyTargetDraft.clamp(1, 40),
                        min: 1,
                        max: 40,
                        divisions: 39,
                        label: '${_dailyTargetDraft.round()} pages',
                        onChanged: (value) {
                          setState(() {
                            _dailyTargetDraft = value;
                          });
                        },
                        onChangeEnd: (value) {
                          widget.controller.setDailyTargetPages(value.round());
                        },
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [7, 15, 30, 60].map((days) {
                          return _PlanChip(
                            days: days,
                            pagesPerDay: controller.plannedPagesPerDay(days),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                if (insight != null)
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mushaf markers',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...insight.juzNumbers.map(
                              (value) => _MarkerChip(label: 'Juz $value'),
                            ),
                            ...insight.hizbNumbers.map(
                              (value) => _MarkerChip(label: 'Hizb $value'),
                            ),
                            ...insight.rubElHizbNumbers.map(
                              (value) => _MarkerChip(label: 'Rub $value'),
                            ),
                            ...insight.rukuNumbers.map(
                              (value) => _MarkerChip(label: 'Ruku $value'),
                            ),
                            ...insight.manzilNumbers.map(
                              (value) => _MarkerChip(label: 'Manzil $value'),
                            ),
                            if (insight.hasSajdah)
                              const _MarkerChip(label: 'Sajdah ayah'),
                          ],
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: sectionGap),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved pages',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bookmarks and favorite pages stay available across sessions.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SavedGroup(
                        title: 'Bookmarks',
                        emptyLabel: 'No bookmarks added yet.',
                        children: controller.bookmarksByFolder.entries
                            .where((entry) => entry.value.isNotEmpty)
                            .map((entry) {
                          return _FolderBookmarkGroup(
                            folder: entry.key,
                            bookmarks: entry.value,
                            onOpenPage: _openPage,
                            onDelete: controller.removeBookmark,
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      _SavedGroup(
                        title: 'Favorites',
                        emptyLabel: 'No favorite pages yet.',
                        children: controller.favoritePages.map((pageNumber) {
                          return InputChip(
                            label: Text('Page $pageNumber'),
                            onPressed: () => _openPage(pageNumber),
                            onDeleted: () {
                              controller.toggleFavoritePage(pageNumber);
                            },
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Translation',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<_TranslationPane>(
                        segments: _TranslationPane.values
                            .map(
                              (value) => ButtonSegment<_TranslationPane>(
                                value: value,
                                label: Text(value.label),
                              ),
                            )
                            .toList(growable: false),
                        selected: <_TranslationPane>{_pane},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _pane = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        translation.isEmpty
                            ? 'Translation is unavailable for this page.'
                            : translation,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _FutureTextSection(
                  title: 'Surah overview',
                  future: _chapterInfoFuture,
                ),
                SizedBox(height: sectionGap),
                _FutureTextSection(
                  title: 'Tafsir excerpt',
                  future: _tafsirFuture,
                ),
                SizedBox(height: sectionGap),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page note',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Add a personal note for this page',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () {
                            widget.controller
                                .saveNoteForCurrentPage(_noteController.text);
                          },
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Save note'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent pages',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controller.readingHistory.map((entry) {
                          return ActionChip(
                            label: Text('Page ${entry.pageNumber}'),
                            onPressed: () => _openPage(entry.pageNumber),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPage(int pageNumber) async {
    if (widget.onSelectPage != null) {
      await widget.onSelectPage!(pageNumber);
      return;
    }
    Navigator.of(context).pop();
    await widget.controller.jumpToPage(pageNumber);
  }

  String _formatMillis(int millis) {
    final duration = Duration(milliseconds: millis);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
    required this.days,
    required this.pagesPerDay,
  });

  final int days;
  final int pagesPerDay;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        '$days-day plan: $pagesPerDay pages/day',
      ),
    );
  }
}

class _SavedGroup extends StatelessWidget {
  const _SavedGroup({
    required this.title,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(
            emptyLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
      ],
    );
  }
}

class _FolderBookmarkGroup extends StatelessWidget {
  const _FolderBookmarkGroup({
    required this.folder,
    required this.bookmarks,
    required this.onOpenPage,
    required this.onDelete,
  });

  final String folder;
  final List<ReaderBookmark> bookmarks;
  final Future<void> Function(int pageNumber) onOpenPage;
  final Future<void> Function(int pageNumber) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              folder,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: bookmarks.map((bookmark) {
                return InputChip(
                  label: Text(bookmark.label),
                  onPressed: () {
                    onOpenPage(bookmark.pageNumber);
                  },
                  onDeleted: () {
                    onDelete(bookmark.pageNumber);
                  },
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureTextSection extends StatelessWidget {
  const _FutureTextSection({
    required this.title,
    required this.future,
  });

  final String title;
  final Future<String?> future;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<String?>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator(minHeight: 3);
              }
              final text = snapshot.data;
              if (text == null || text.trim().isEmpty) {
                return Text(
                  'No additional content is available right now.',
                  style: theme.textTheme.bodyMedium,
                );
              }
              return SelectableText(
                text,
                style: theme.textTheme.bodyMedium,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerChip extends StatelessWidget {
  const _MarkerChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
