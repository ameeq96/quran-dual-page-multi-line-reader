import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import 'reader_sheet_frame.dart';

Future<void> showReaderDashboardSheet(
  BuildContext context, {
  required QuranReaderController controller,
  required VoidCallback onOpenSearch,
  required VoidCallback onOpenInsights,
  required VoidCallback onOpenAudio,
  required VoidCallback onOpenAiStudio,
  required VoidCallback onOpenPageStrip,
  required VoidCallback onOpenCompare,
  required VoidCallback onOpenKanzulStudy,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: ReaderSheetFrame(
          child: ReaderDashboardContent(
            controller: controller,
            onOpenSearch: onOpenSearch,
            onOpenInsights: onOpenInsights,
            onOpenAudio: onOpenAudio,
            onOpenAiStudio: onOpenAiStudio,
            onOpenPageStrip: onOpenPageStrip,
            onOpenCompare: onOpenCompare,
            onOpenKanzulStudy: onOpenKanzulStudy,
            showHandle: true,
            closeOnAction: true,
          ),
        ),
      );
    },
  );
}

class QuranDashboardScreen extends StatelessWidget {
  const QuranDashboardScreen({
    super.key,
    required this.controller,
    required this.onOpenSearch,
    required this.onOpenInsights,
    required this.onOpenAudio,
    required this.onOpenAiStudio,
    required this.onOpenPageStrip,
    required this.onOpenCompare,
    required this.onOpenKanzulStudy,
    this.onSelectPage,
  });

  final QuranReaderController controller;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenInsights;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenAiStudio;
  final VoidCallback onOpenPageStrip;
  final VoidCallback onOpenCompare;
  final VoidCallback onOpenKanzulStudy;
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
              child: ReaderDashboardContent(
                controller: controller,
                onOpenSearch: onOpenSearch,
                onOpenInsights: onOpenInsights,
                onOpenAudio: onOpenAudio,
                onOpenAiStudio: onOpenAiStudio,
                onOpenPageStrip: onOpenPageStrip,
                onOpenCompare: onOpenCompare,
                onOpenKanzulStudy: onOpenKanzulStudy,
                showHandle: false,
                closeOnAction: false,
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

class ReaderDashboardContent extends StatelessWidget {
  const ReaderDashboardContent({
    super.key,
    required this.controller,
    required this.onOpenSearch,
    required this.onOpenInsights,
    required this.onOpenAudio,
    required this.onOpenAiStudio,
    required this.onOpenPageStrip,
    required this.onOpenCompare,
    required this.onOpenKanzulStudy,
    this.showHandle = true,
    this.closeOnAction = true,
    this.onSelectPage,
  });

  final QuranReaderController controller;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenInsights;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenAiStudio;
  final VoidCallback onOpenPageStrip;
  final VoidCallback onOpenCompare;
  final VoidCallback onOpenKanzulStudy;
  final bool showHandle;
  final bool closeOnAction;
  final Future<void> Function(int pageNumber)? onSelectPage;

  Future<void> _handleAction(BuildContext context, VoidCallback action) async {
    if (closeOnAction) {
      Navigator.of(context).pop();
    }
    action();
  }

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
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller.pageListenable,
        controller.audioListenable,
        controller.contentListenable,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final size = MediaQuery.of(context).size;
        final compact = size.width < 420 || size.height < 760;
        final pagePadding = compact ? 10.0 : 12.0;
        final sectionGap = compact ? 10.0 : 12.0;
        final chapter = controller.currentChapterSummary;
        final bookmarksByFolder = controller.bookmarksByFolder;
        final nonEmptyBookmarkFolders = bookmarksByFolder.entries
            .where((entry) => entry.value.isNotEmpty)
            .toList(growable: false);
        final activityKeys = controller.recentActivityDateKeys;
        final activityCounts = controller.readingActivityCounts;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              pagePadding,
              showHandle ? (compact ? 10 : 12) : 4,
              pagePadding,
              compact ? 12 : 14,
            ),
            child: ListView(
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
                  SizedBox(height: sectionGap),
                ],
                _DashboardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reader dashboard',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        chapter == null
                            ? 'Continue from page ${controller.currentPageNumber}.'
                            : 'Continue from ${chapter.nameSimple} - Page ${controller.currentPageNumber}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _QuickActionButton(
                            icon: Icons.search_rounded,
                            label: 'Search',
                            onPressed: () =>
                                _handleAction(context, onOpenSearch),
                          ),
                          _QuickActionButton(
                            icon: Icons.auto_stories_outlined,
                            label: 'Insights',
                            onPressed: () =>
                                _handleAction(context, onOpenInsights),
                          ),
                          _QuickActionButton(
                            icon: Icons.headphones_rounded,
                            label: 'Audio',
                            onPressed: () =>
                                _handleAction(context, onOpenAudio),
                          ),
                          _QuickActionButton(
                            icon: Icons.auto_awesome_rounded,
                            label: 'AI Studio',
                            onPressed: () =>
                                _handleAction(context, onOpenAiStudio),
                          ),
                          _QuickActionButton(
                            icon: Icons.photo_library_outlined,
                            label: 'Pages',
                            onPressed: () =>
                                _handleAction(context, onOpenPageStrip),
                          ),
                          _QuickActionButton(
                            icon: Icons.compare_rounded,
                            label: 'Compare',
                            onPressed: () =>
                                _handleAction(context, onOpenCompare),
                          ),
                          _QuickActionButton(
                            icon: Icons.translate_rounded,
                            label: 'Kanzul study',
                            onPressed: () =>
                                _handleAction(context, onOpenKanzulStudy),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _DashboardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading rhythm',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _InfoPill(
                            label: 'Streak',
                            value: '${controller.readingStreakCount} days',
                          ),
                          _InfoPill(
                            label: 'Today',
                            value: controller.dailyProgressSummaryLabel,
                          ),
                          _InfoPill(
                            label: 'Favorites',
                            value: '${controller.favoritePages.length}',
                          ),
                          _InfoPill(
                            label: 'Bookmarks',
                            value: '${controller.bookmarks.length}',
                          ),
                          _InfoPill(
                            label: 'Offline audio',
                            value: '${controller.downloadedAudioCount}',
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
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List<Widget>.generate(7, (index) {
                          final date = DateTime.now().subtract(
                            Duration(days: 6 - index),
                          );
                          final key = _dateKey(date);
                          return _DayDot(
                            label: _shortDay(date.weekday),
                            active: activityKeys.contains(key),
                            today: index == 6,
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      _MonthHeatmap(activityCounts: activityCounts),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _DashboardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khatam plans',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [7, 15, 30, 60].map((days) {
                          return Chip(
                            label: Text(
                              '$days days: ${controller.plannedPagesPerDay(days)} pages/day',
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _DashboardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved places',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (nonEmptyBookmarkFolders.isEmpty)
                        Text(
                          'No bookmarked pages yet.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ...nonEmptyBookmarkFolders.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FolderSection(
                              title: entry.key,
                              emptyLabel: 'No pages in this folder yet.',
                              children: entry.value.map((bookmark) {
                                return ActionChip(
                                  label: Text(bookmark.label),
                                  onPressed: () => _handlePageOpen(
                                    context,
                                    bookmark.pageNumber,
                                  ),
                                );
                              }).toList(growable: false),
                            ),
                          );
                        }),
                      _FolderSection(
                        title: 'Favorites',
                        emptyLabel: 'No favorite pages yet.',
                        children: controller.favoritePages.map((pageNumber) {
                          return ActionChip(
                            label: Text('Page $pageNumber'),
                            onPressed: () =>
                                _handlePageOpen(context, pageNumber),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _DashboardCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export',
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
                              _copyToClipboard(
                                context,
                                controller.buildCurrentPageReference(),
                                'Current page reference copied.',
                              );
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copy page ref'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              _copyToClipboard(
                                context,
                                controller.buildReadingSummary(),
                                'Reading summary copied.',
                              );
                            },
                            icon: const Icon(Icons.summarize_outlined),
                            label: const Text('Copy summary'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              _shareText(
                                context,
                                controller.buildReadingSummary(),
                                subject: 'Mushaf Reader summary',
                              );
                            },
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share summary'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              _shareNotesExport(context);
                            },
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Export notes'),
                          ),
                        ],
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

  Future<void> _shareText(
    BuildContext context,
    String text, {
    required String subject,
  }) async {
    await Share.share(
      text,
      subject: subject,
    );
  }

  Future<void> _shareNotesExport(BuildContext context) async {
    final notes = controller.pageNotes.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final bookmarks = controller.bookmarks;
    final buffer = StringBuffer()
      ..writeln('Mushaf Reader Export')
      ..writeln()
      ..writeln(controller.buildReadingSummary())
      ..writeln()
      ..writeln('Bookmarks');

    if (bookmarks.isEmpty) {
      buffer.writeln('None');
    } else {
      for (final bookmark in bookmarks) {
        buffer.writeln(
          '- [${bookmark.folder}] ${bookmark.label} (Page ${bookmark.pageNumber})',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('Notes');

    if (notes.isEmpty) {
      buffer.writeln('None');
    } else {
      for (final entry in notes) {
        buffer
          ..writeln('Page ${entry.key}')
          ..writeln(entry.value)
          ..writeln();
      }
    }

    final tempDirectory = await getTemporaryDirectory();
    final file = File(
        '${tempDirectory.path}${Platform.pathSeparator}mushaf_reader_export.txt');
    await file.writeAsString(buffer.toString(), flush: true);
    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      subject: 'Mushaf Reader export',
    );
  }

  void _copyToClipboard(
    BuildContext context,
    String text,
    String confirmation,
  ) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(confirmation)),
    );
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _shortDay(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'M',
      DateTime.tuesday => 'T',
      DateTime.wednesday => 'W',
      DateTime.thursday => 'T',
      DateTime.friday => 'F',
      DateTime.saturday => 'S',
      DateTime.sunday => 'S',
      _ => '-',
    };
  }
}

class _MonthHeatmap extends StatelessWidget {
  const _MonthHeatmap({
    required this.activityCounts,
  });

  final Map<String, int> activityCounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final cells = List<DateTime>.generate(
      28,
      (index) => today.subtract(Duration(days: 27 - index)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 28 days',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: cells.map((date) {
            final key = _dateKeyForCell(date);
            final count = activityCounts[key] ?? 0;
            final active = count > 0;
            return Tooltip(
              message: '${date.day}/${date.month}: $count reading event(s)',
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? theme.colorScheme.primary.withOpacity(
                          count >= 3 ? 1 : (count == 2 ? 0.72 : 0.42),
                        )
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${date.day}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: active
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  String _dateKeyForCell(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
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
          color: theme.dividerColor.withOpacity(0.52),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.active,
    required this.today,
  });

  final String label;
  final bool active;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: today ? theme.colorScheme.primary : null,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: today ? 20 : 16,
          height: today ? 20 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: today
                ? Border.all(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection({
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
