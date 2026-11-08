import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';
import '../../../../core/services/reader_file_export.dart';
import '../../domain/models/reader_growth_models.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/reader_reminder_settings.dart';
import '../widgets/reader_account_settings.dart';
import '../widgets/reader_local_data_settings.dart';
import 'quran_study_screen.dart';

class QuranGrowthHubScreen extends StatelessWidget {
  const QuranGrowthHubScreen({
    super.key,
    required this.controller,
    this.onSelectPage,
  });

  final QuranReaderController controller;
  final Future<void> Function(int pageNumber)? onSelectPage;

  Future<void> _openPage(BuildContext context, int pageNumber) async {
    if (onSelectPage != null) {
      await onSelectPage!(pageNumber);
      return;
    }
    Navigator.of(context).pop(pageNumber);
  }

  Future<void> _openRevision(
    BuildContext context,
    ReaderHifzReviewEntry entry,
  ) async {
    try {
      await controller.openHifzReviewEntry(entry);
      if (context.mounted) await _openPage(context, entry.pageNumber);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'Unable to open revision: {error}', args: {'error': error}))),
        );
      }
    }
  }

  String _revisionDueLabel(
    BuildContext context,
    ReaderHifzReviewEntry entry,
    DateTime now,
  ) {
    final days = entry.daysUntilReview(now: now);
    if (days < 0) {
      return tr(context, days == -1 ? '{days} day overdue' : '{days} days overdue',
          args: {'days': -days});
    }
    if (days == 0) return tr(context, 'Due today');
    if (days == 1) return tr(context, 'Due tomorrow');
    return tr(context, 'Due in {days} days', args: {'days': days});
  }

  Future<void> _shareBackup(BuildContext context) async {
    try {
      await exportReaderFile(
        fileName: 'quran_dual_page_backup.json',
        contents: controller.buildStateBackupJson(),
        mimeType: 'application/json',
        subject: tr(context, 'Quran Reader backup'),
        text: tr(context, 'Bookmarks, notes, reading plans and hifz tracking.'),
      );
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'Backup export failed: $error'))));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final input = TextEditingController();
    String? error;
    bool busy = false;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setState) => AlertDialog(
        title: Text(tr(context, 'Restore reader backup')),
        content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(context, 'Paste your exported backup JSON. Restoring replaces your reader data. Export a backup first if you want to keep the current data.')),
          const SizedBox(height: 16),
          TextField(controller: input, minLines: 5, maxLines: 10, enabled: !busy, decoration: InputDecoration(labelText: tr(context, 'Backup JSON'), alignLabelWithHint: true, errorText: error == null ? null : tr(context, error!))),
        ]))),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.of(dialogContext).pop(), child: Text(tr(context, 'Cancel'))),
          FilledButton(onPressed: busy ? null : () async {
            setState(() { busy = true; error = null; });
            try {
              await controller.restoreStateBackupJson(input.text);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'Reader backup restored.'))));
            } catch (failure) {
              if (dialogContext.mounted) setState(() { busy = false; error = failure.toString().replaceFirst('FormatException: ', ''); });
            }
          }, child: Text(tr(context, busy ? 'Restoring…' : 'Restore backup'))),
        ],
      )));
    } finally { input.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller.settingsListenable,
        controller.aiSettingsListenable,
        controller.experienceListenable,
        controller.pageListenable,
        controller.contentListenable,
      ]),
      builder: (context, _) {
        final settings = controller.settings;
        final experience = controller.experienceSettings;
        final themeData = settings.nightMode
            ? AppTheme.dark(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              )
            : AppTheme.light(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              );
        final now = DateTime.now();
        final revisionQueue = controller.hifzRevisionQueue;
        final overdueCount = revisionQueue
            .where((entry) => entry.daysUntilReview(now: now) < 0).length;
        final dueTodayCount = revisionQueue
            .where((entry) => entry.daysUntilReview(now: now) == 0).length;
        final upcomingCount = revisionQueue.length - overdueCount - dueTodayCount;
        final pageReference = controller.buildCurrentPageReference();
        final plan = controller.readingPlan;
        final planPagesPerDay = plan.pagesPerDay(
          remainingPages: controller.remainingPages,
          fallbackDailyTarget: controller.dailyTargetPages,
        );
        final targetDays = plan.effectiveTargetDays(
          fallbackDailyTarget: controller.dailyTargetPages,
        );

        return Theme(
          data: themeData,
          child: Scaffold(
            backgroundColor: themeData.scaffoldBackgroundColor,
            appBar: AppBar(
              title: Text(tr(context, 'Plans & Hifz')),
              actions: [IconButton(tooltip: tr(context, 'Profiles & restore history'), icon: const Icon(Icons.people_outline),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(tr(context, 'Profiles & restore history'))),
                  body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20), child: ReaderLocalDataSettings(controller: controller)))))))),
                IconButton(tooltip: tr(context, 'Word study & collections'), icon: const Icon(Icons.auto_stories_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const QuranStudyScreen())))],
              centerTitle: true,
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'YOUR READING JOURNEY'),
                        style: themeData.textTheme.labelSmall?.copyWith(
                          color: themeData.colorScheme.secondary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, 'A steady practice.'),
                        style: themeData.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, 'Set a comfortable pace, strengthen your memorization, and keep your reading close.'),
                        style: themeData.textTheme.bodyMedium?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            icon: Icons.menu_book_rounded,
                            label: pageReference,
                          ),
                          _Pill(
                            icon: Icons.flag_circle_outlined,
                            label:
                                tr(context, '{plan} · {pages}/day', args: {'plan': tr(context, plan.preset.label), 'pages': planPagesPerDay}),
                          ),
                          _Pill(
                            icon: Icons.school_outlined,
                            label:
                                tr(context, '${controller.hifzReviewEntries.length} hifz pages'),
                          ),
                          _Pill(
                            icon: Icons.sync_outlined,
                            label: experience.syncMode.label,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'Reading plan'),
                        style: themeData.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, 'Choose a reading goal and keep a clear daily pace.'),
                        style: themeData.textTheme.bodyMedium?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ReadingGoalPreset.values.map((preset) {
                          return ChoiceChip(
                            label: Text(tr(context, preset.label)),
                            selected: plan.preset == preset,
                            onSelected: (_) {
                              controller.setReadingPlanPreset(preset);
                            },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 12),
                      _MetricGrid(
                        metrics: [
                          _MetricItem(
                              label: tr(context, 'Target'), value: plan.preset.label),
                          _MetricItem(label: tr(context, 'Days'), value: '$targetDays'),
                          _MetricItem(
                              label: tr(context, 'Pages/day'), value: '$planPagesPerDay'),
                          _MetricItem(
                            label: tr(context, 'Remaining'),
                            value: '${controller.remainingPages}',
                          ),
                        ],
                      ),
                      if (plan.preset == ReadingGoalPreset.custom) ...[
                        const SizedBox(height: 14),
                        Text(
                          tr(context, 'Custom target days'),
                          style: themeData.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: plan.targetDays.toDouble(),
                          min: 7,
                          max: 120,
                          divisions: 113,
                          label: tr(context, '${plan.targetDays.round()} days'),
                          onChanged: (value) {
                            controller.setCustomReadingPlan(
                              targetDays: value.round(),
                            );
                          },
                        ),
                        Text(
                          tr(context, 'Custom pages per day'),
                          style: themeData.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: plan.customPagesPerDay.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          label: tr(context, '${plan.customPagesPerDay.round()} pages'),
                          onChanged: (value) {
                            controller.setCustomReadingPlan(
                              pagesPerDay: value.round(),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'Hifz planner'),
                        style: themeData.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, 'Track weak pages, schedule revision, and jump back into review quickly.'),
                        style: themeData.textTheme.bodyMedium?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () {
                              controller.markCurrentPageForHifz(
                                HifzPageStrength.weak,
                              );
                            },
                            child: Text(tr(context, 'Mark current as weak')),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              controller.markCurrentPageForHifz(
                                HifzPageStrength.steady,
                              );
                            },
                            child: Text(tr(context, 'Mark current as steady')),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              controller.markCurrentPageForHifz(
                                HifzPageStrength.strong,
                              );
                            },
                            child: Text(tr(context, 'Mark current as strong')),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              controller.clearHifzReviewEntry(
                                controller.currentPageNumber,
                              );
                            },
                            child: Text(tr(context, 'Clear current')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr(context, 'Revision reminders'),
                        style: themeData.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, 'Weak pages return after 1 day, steady after 3, strong after 7. After reading, mark the page again to schedule its next review. Reminders appear here while you use the app.'),
                        style: themeData.textTheme.bodySmall?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(icon: Icons.history_rounded,
                              label: tr(context, '{count} overdue', args: {'count': overdueCount})),
                          _Pill(icon: Icons.today_rounded,
                              label: tr(context, '{count} due today', args: {'count': dueTodayCount})),
                          _Pill(icon: Icons.event_outlined,
                              label: tr(context, '{count} upcoming', args: {'count': upcomingCount})),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (revisionQueue.isEmpty)
                        Text(
                          tr(context, 'Mark a page above to start your revision queue.'),
                          style: themeData.textTheme.bodyMedium?.copyWith(
                            color: themeData.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 420),
                          child: ListView.separated(
                            shrinkWrap: true,
                            primary: false,
                            itemCount: revisionQueue.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final entry = revisionQueue[index];
                              final days = entry.daysUntilReview(now: now);
                              final color = days < 0
                                  ? themeData.colorScheme.error
                                  : days == 0
                                      ? themeData.colorScheme.primary
                                      : themeData.colorScheme.onSurfaceVariant;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  days <= 0
                                      ? Icons.auto_stories_outlined
                                      : Icons.event_outlined,
                                  color: color,
                                ),
                                title: Text(
                                  tr(context, 'Page {page} · {edition}', args: {'page': entry.pageNumber, 'edition': tr(context, entry.edition.label)}),
                                ),
                                subtitle: Text(
                                  '${_revisionDueLabel(context, entry, now)} · ${tr(context, entry.strength.label)}',
                                  style: TextStyle(color: color),
                                ),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => _openRevision(context, entry),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _HubCard(child: ReaderReminderSettings(baseUrl: controller.adminSyncBaseUrl)),
                const SizedBox(height: 18),
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'Accessibility & sync'),
                        style: themeData.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.largerTextMode,
                        onChanged: controller.setLargerTextMode,
                        title: Text(tr(context, 'Larger text mode')),
                        subtitle:
                            Text(tr(context, 'Increase app text size slightly.')),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.highContrastMode,
                        onChanged: controller.setHighContrastMode,
                        title: Text(tr(context, 'High contrast mode')),
                        subtitle: Text(
                            tr(context, 'Stronger borders and clearer contrast.')),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.reducedMotion,
                        onChanged: controller.setReducedMotion,
                        title: Text(tr(context, 'Reduced motion')),
                        subtitle: Text(
                            tr(context, 'Prepare the app for lighter transitions.')),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.tajweedMode,
                        onChanged: controller.setTajweedMode,
                        title: Text(tr(context, 'Tajweed mode')),
                        subtitle: Text(
                            tr(context, 'Keep tajweed-ready reading mode enabled.')),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.recitationSyncEnabled,
                        onChanged: controller.setRecitationSyncEnabled,
                        title: Text(tr(context, 'Recitation sync')),
                        subtitle: Text(
                            tr(context, 'Follow timed ayahs during recitation when timing data is available.')),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ReaderSyncMode.values.map((mode) {
                          return ChoiceChip(
                            label: Text(tr(context, mode.label)),
                            selected: experience.syncMode == mode,
                            onSelected: (_) {
                              controller.setSyncMode(mode);
                            },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        tr(context, experience.syncMode.subtitle),
                        style: themeData.textTheme.bodyMedium?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, controller.readerSyncStatusLabel),
                        style: themeData.textTheme.bodySmall?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ExpansionTile(tilePadding: EdgeInsets.zero,
                        leading: const Icon(Icons.people_outline), title: Text(tr(context, 'Profiles & restore history')),
                        children: [ReaderLocalDataSettings(controller: controller), const SizedBox(height: 20)]),
                      const SizedBox(height: 12),
                      ReaderAccountSettings(controller: controller),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          _shareBackup(context);
                        },
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(tr(context, 'Export backup JSON')),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(onPressed: () => _restoreBackup(context), icon: const Icon(Icons.restore_rounded), label: Text(tr(context, 'Restore backup JSON'))),
                    ],
                  ),
                ),
              ],
            ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map((metric) {
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: width,
                    maxWidth: width,
                    minHeight: 108,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, metric.label),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(context, metric.value),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.secondary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tr(context, label),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
