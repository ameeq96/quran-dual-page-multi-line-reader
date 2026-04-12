import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/app_theme.dart';
import '../../domain/models/quran_ai_models.dart';
import '../../domain/models/reader_growth_models.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';

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

  Future<void> _shareBackup(BuildContext context) async {
    final tempDirectory = await getTemporaryDirectory();
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}quran_dual_page_backup.json',
    );
    await file.writeAsString(controller.buildStateBackupJson(), flush: true);
    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      subject: 'Quran Dual Page & Multi-Line Reader backup',
      text:
          'Reader backup export with bookmarks, notes, plan, and hifz tracking.',
    );
  }

  Future<void> _downloadOfflinePack(
    BuildContext context,
    MushafEdition edition,
  ) async {
    try {
      await controller.downloadOfflineEditionPack(edition);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${edition.label} is now available offline.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download ${edition.label}: $error')),
      );
    }
  }

  Future<void> _removeOfflinePack(
    BuildContext context,
    MushafEdition edition,
  ) async {
    try {
      await controller.removeOfflineEditionPack(edition);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${edition.label} offline pack removed.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove ${edition.label}: $error')),
      );
    }
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
        final aiSettings = controller.aiSettings;
        final themeData = settings.nightMode
            ? AppTheme.dark(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              )
            : AppTheme.light(
                highContrast: experience.highContrastMode,
                largerText: experience.largerTextMode,
              );
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
              title: const Text('Plans & Packs'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              children: [
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Growth hub',
                        style: themeData.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage reading plans, hifz revision, AI depth, offline edition packs, accessibility, and backup-ready sync settings from one place.',
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
                                '${plan.preset.label} · $planPagesPerDay/day',
                          ),
                          _Pill(
                            icon: Icons.school_outlined,
                            label:
                                '${controller.hifzReviewEntries.length} hifz pages',
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
                const SizedBox(height: 14),
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading plan',
                        style: themeData.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a reading goal and keep a clear daily pace.',
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
                            label: Text(preset.label),
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
                              label: 'Target', value: plan.preset.label),
                          _MetricItem(label: 'Days', value: '$targetDays'),
                          _MetricItem(
                              label: 'Pages/day', value: '$planPagesPerDay'),
                          _MetricItem(
                            label: 'Remaining',
                            value: '${controller.remainingPages}',
                          ),
                        ],
                      ),
                      if (plan.preset == ReadingGoalPreset.custom) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Custom target days',
                          style: themeData.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Slider(
                          value: plan.targetDays.toDouble(),
                          min: 7,
                          max: 120,
                          divisions: 113,
                          label: '${plan.targetDays.round()} days',
                          onChanged: (value) {
                            controller.setCustomReadingPlan(
                              targetDays: value.round(),
                            );
                          },
                        ),
                        Text(
                          'Custom pages per day',
                          style: themeData.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Slider(
                          value: plan.customPagesPerDay.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          label: '${plan.customPagesPerDay.round()} pages',
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
                const SizedBox(height: 14),
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hifz planner',
                        style: themeData.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track weak pages, schedule revision, and jump back into review quickly.',
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
                            child: const Text('Mark current as weak'),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              controller.markCurrentPageForHifz(
                                HifzPageStrength.steady,
                              );
                            },
                            child: const Text('Mark current as steady'),
                          ),
                          FilledButton.tonal(
                            onPressed: () {
                              controller.markCurrentPageForHifz(
                                HifzPageStrength.strong,
                              );
                            },
                            child: const Text('Mark current as strong'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              controller.clearHifzReviewEntry(
                                controller.currentPageNumber,
                              );
                            },
                            child: const Text('Clear current'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (controller.prioritizedHifzReviewEntries.isEmpty)
                        Text(
                          'No hifz pages tracked yet. Mark weak or strong pages to build a revision queue.',
                          style: themeData.textTheme.bodyMedium?.copyWith(
                            color: themeData.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: controller.prioritizedHifzReviewEntries
                              .take(12)
                              .map((entry) {
                            return ActionChip(
                              label: Text(
                                'Page ${entry.pageNumber} · ${entry.strength.label}',
                              ),
                              onPressed: () {
                                _openPage(context, entry.pageNumber);
                              },
                            );
                          }).toList(growable: false),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline edition packs',
                        style: themeData.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Download the exact Quran scan packs you use online so the same editions keep working offline.',
                        style: themeData.textTheme.bodyMedium?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...controller.offlineEditionPacks.map((pack) {
                        final remotePack =
                            controller.remoteAssetPackForEdition(pack.edition);
                        final isDownloading =
                            controller.isOfflinePackDownloading(pack.edition);
                        final isDownloaded =
                            controller.isOfflinePackDownloaded(pack.edition);
                        final isBundled =
                            controller.isBundledPackForEdition(pack.edition);
                        final canDownload = remotePack != null &&
                            !isDownloading &&
                            !isDownloaded &&
                            !isBundled;
                        final canRemove =
                            isDownloaded && !isDownloading && !isBundled;
                        final progress =
                            controller.offlinePackProgressForEdition(
                          pack.edition,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  themeData.colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: themeData
                                            .colorScheme.primary
                                            .withOpacity(0.12),
                                        child: Text(
                                          pack.edition.shortLabel,
                                          style: themeData.textTheme.labelLarge
                                              ?.copyWith(
                                            color:
                                                themeData.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pack.title,
                                              style: themeData
                                                  .textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              controller
                                                  .adminPackSubtitleForEdition(
                                                pack.edition,
                                              ),
                                              style: themeData
                                                  .textTheme.bodySmall
                                                  ?.copyWith(
                                                color: themeData.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _StatusChip(
                                        label: controller
                                            .adminPackStatusForEdition(
                                          pack.edition,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isDownloading) ...[
                                    const SizedBox(height: 12),
                                    LinearProgressIndicator(
                                      value: progress <= 0 || progress >= 1
                                          ? null
                                          : progress,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      FilledButton.tonal(
                                        onPressed: canDownload
                                            ? () => _downloadOfflinePack(
                                                  context,
                                                  pack.edition,
                                                )
                                            : null,
                                        child: Text(
                                          isBundled
                                              ? 'Built-in'
                                              : isDownloaded
                                                  ? 'Downloaded'
                                                  : isDownloading
                                                      ? 'Downloading...'
                                                      : 'Download offline',
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed: canRemove
                                            ? () => _removeOfflinePack(
                                                  context,
                                                  pack.edition,
                                                )
                                            : null,
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accessibility & sync',
                        style: themeData.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.largerTextMode,
                        onChanged: controller.setLargerTextMode,
                        title: const Text('Larger text mode'),
                        subtitle:
                            const Text('Increase app text size slightly.'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.highContrastMode,
                        onChanged: controller.setHighContrastMode,
                        title: const Text('High contrast mode'),
                        subtitle: const Text(
                            'Stronger borders and clearer contrast.'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.reducedMotion,
                        onChanged: controller.setReducedMotion,
                        title: const Text('Reduced motion'),
                        subtitle: const Text(
                            'Prepare the app for lighter transitions.'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.tajweedMode,
                        onChanged: controller.setTajweedMode,
                        title: const Text('Tajweed mode'),
                        subtitle: const Text(
                            'Keep tajweed-ready reading mode enabled.'),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: experience.recitationSyncEnabled,
                        onChanged: controller.setRecitationSyncEnabled,
                        title: const Text('Recitation sync'),
                        subtitle: const Text(
                            'Keep audio follow mode ready for page sync.'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ReaderSyncMode.values.map((mode) {
                          return ChoiceChip(
                            label: Text(mode.label),
                            selected: experience.syncMode == mode,
                            onSelected: (_) {
                              controller.setSyncMode(mode);
                            },
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        experience.syncMode.subtitle,
                        style: themeData.textTheme.bodyMedium?.copyWith(
                          color: themeData.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          _shareBackup(context);
                        },
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Export backup JSON'),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.metrics,
  });

  final List<_MetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics.map((metric) {
        return SizedBox(
          width: 150,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
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
  const _Pill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
