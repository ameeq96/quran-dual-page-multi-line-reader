import 'package:flutter/material.dart';

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';
import '../../../../core/services/reader_file_export.dart';
import '../../data/services/quran_study_data_source.dart';
import '../../domain/models/reader_growth_models.dart';
import '../../domain/models/reader_settings.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_page_header.dart';
import '../widgets/reader_reminder_settings.dart';
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
            // Zero-height bar: keeps the status bar styling and top inset
            // while the hero header in the body carries title and actions.
            appBar: AppBar(toolbarHeight: 0, automaticallyImplyLeading: false),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                AppPageHeader(
                  eyebrow: tr(context, 'YOUR READING JOURNEY'),
                  title: tr(context, 'Plans & Hifz'),
                  icon: Icons.insights_outlined,
                  compact: true,
                  onBack: AppPageHeader.popAction(context),
                  actions: [IconButton(tooltip: tr(context, 'Profiles & restore history'), icon: const Icon(Icons.people_outline),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(tr(context, 'Profiles & restore history'))),
                  body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20), child: ReaderLocalDataSettings(controller: controller)))))))),
                IconButton(tooltip: tr(context, 'Word study & collections'), icon: const Icon(Icons.auto_stories_outlined),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const QuranStudyScreen())))],
                ),
                const SizedBox(height: 16),
                AppStagger(index: 0, child: _HubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                )),
                const SizedBox(height: 18),
                AppStagger(index: 1, child: _HubCard(
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
                              label: tr(context, 'Target'), value: tr(context, plan.preset.label)),
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
                          min: 1,
                          max: 365,
                          divisions: 364,
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
                          max: 40,
                          divisions: 39,
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
                )),
                const SizedBox(height: 18),
                AppStagger(index: 2, child: _HubCard(
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
                      const SizedBox(height: 14),
                      // On phones the planner actions share one full-width
                      // column instead of a ragged stack of mixed widths.
                      LayoutBuilder(builder: (context, hifzBox) {
                      final stackActions = hifzBox.maxWidth < 480;
                      Widget action(Widget button) => stackActions
                          ? SizedBox(width: hifzBox.maxWidth, child: button)
                          : button;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      action(OutlinedButton.icon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => Theme(
                            data: themeData,
                            child: const FractionallySizedBox(
                              heightFactor: 0.94,
                              child: _RandomHifzSession(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.quiz_outlined),
                        label: Text(_hifzText(context, 'Random Hifz test', 'حفظ کا اتفاقی امتحان', 'اختبار حفظ عشوائي')),
                      )),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          action(FilledButton.tonal(
                            onPressed: () {
                              controller.markCurrentPageForHifz(
                                HifzPageStrength.weak,
                              );
                            },
                            child: Text(tr(context, 'Mark current as weak')),
                          )),
                          action(FilledButton.tonal(
                            onPressed: () {
                              controller.markCurrentPageForHifz(
                                HifzPageStrength.steady,
                              );
                            },
                            child: Text(tr(context, 'Mark current as steady')),
                          )),
                          action(FilledButton.tonal(
                            onPressed: () {
                              controller.markCurrentPageForHifz(
                                HifzPageStrength.strong,
                              );
                            },
                            child: Text(tr(context, 'Mark current as strong')),
                          )),
                          action(OutlinedButton(
                            onPressed: () {
                              controller.clearHifzReviewEntry(
                                controller.currentPageNumber,
                              );
                            },
                            child: Text(tr(context, 'Clear current')),
                          )),
                        ],
                      ),
                        ],
                      );
                      }),
                      const SizedBox(height: 18),
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
                )),
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

String _hifzText(BuildContext context, String english, String urdu, String arabic) =>
    switch (ReaderLocalizationScope.of(context).language) {
      ReaderLanguage.urdu => urdu,
      ReaderLanguage.arabic => arabic,
      _ => english,
    };

class _RandomHifzSession extends StatefulWidget {
  const _RandomHifzSession();

  @override
  State<_RandomHifzSession> createState() => _RandomHifzSessionState();
}

class _RandomHifzSessionState extends State<_RandomHifzSession> {
  final _source = QuranStudyDataSource();
  bool _loading = true;
  bool _loadFailed = false;
  bool _useJuz = false;
  int _chapter = 1;
  int _juz = 1;
  List<String> _remaining = [];
  String? _reference;
  int _total = 0;
  int _remembered = 0;
  final _needsReview = <String>[];
  bool _revealed = false;
  bool _marked = false;
  bool _finished = false;

  String _t(String english, String urdu, String arabic) =>
      _hifzText(context, english, urdu, arabic);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadFailed = false; });
    try {
      await _source.initialize();
      if (mounted) setState(() { _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _loadFailed = true; });
    }
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  void _clearSession() {
    _remaining = [];
    _reference = null;
    _total = 0;
    _remembered = 0;
    _needsReview.clear();
    _revealed = false;
    _marked = false;
    _finished = false;
  }

  void _nextQuestion() {
    _revealed = false;
    _marked = false;
    _reference = _remaining.isEmpty ? null : _remaining.removeLast();
    _finished = _reference == null;
  }

  void _start() {
    final references = _source.referencesForScope(
      chapterId: _useJuz ? null : _chapter,
      juzNumber: _useJuz ? _juz : null,
    );
    setState(() {
      _clearSession();
      _remaining = List<String>.of(references)..shuffle();
      _total = _remaining.length;
      _nextQuestion();
    });
  }

  void _mark(bool remembered) {
    if (_reference == null || !_revealed || _marked || _finished) return;
    setState(() {
      _marked = true;
      if (remembered) {
        _remembered++;
      } else {
        _needsReview.add(_reference!);
      }
    });
  }

  Future<void> _review(String reference) async {
    final verse = _source.verse(reference);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${verse.chapterName} · ${verse.reference}'),
        content: SingleChildScrollView(
          child: SelectableText(
            verse.arabic,
            textDirection: TextDirection.rtl,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.9),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_hifzText(context, 'Close', 'بند کریں', 'إغلاق')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verse = _reference == null ? null : _source.verse(_reference!);
    final completed = _remembered + _needsReview.length;
    final clue = verse == null || verse.words.length < 2
        ? ''
        : verse.words
            .take(verse.words.length > 3 ? 3 : verse.words.length - 1)
            .map((word) => word.arabic).join(' ');
    return Directionality(
      textDirection: ReaderLocalizationScope.of(context).textDirection,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 0),
            child: Row(
              children: [
                Expanded(child: Text(
                  _t('Random Hifz test', 'حفظ کا اتفاقی امتحان', 'اختبار حفظ عشوائي'),
                  style: theme.textTheme.titleLarge,
                )),
                IconButton(
                  tooltip: _t('Close', 'بند کریں', 'إغلاق'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  _t(
                    'Self-assessment only. Closing, resetting or changing the selection discards these session marks. Your page revision queue stays unchanged.',
                    'یہ صرف خود جائزہ لینے کے لیے ہے۔ بند کرنے، دوبارہ شروع کرنے یا انتخاب بدلنے سے اس نشست کے نتائج مٹ جائیں گے۔ صفحات کی دہرائی کی فہرست تبدیل نہیں ہوگی۔',
                    'للتقييم الذاتي فقط. تُحذف نتائج الجلسة عند الإغلاق أو إعادة الضبط أو تغيير الاختيار. لا تتغير قائمة مراجعة الصفحات.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  Center(child: Semantics(
                    label: _t('Loading Quran text', 'قرآن کا متن کھل رہا ہے', 'جارٍ تحميل النص القرآني'),
                    child: const CircularProgressIndicator(),
                  ))
                else if (_loadFailed) ...[
                  Text(_t(
                    'Quran text could not be opened. Please try again.',
                    'قرآن کا متن نہیں کھل سکا۔ دوبارہ کوشش کریں۔',
                    'تعذّر فتح النص القرآني. يُرجى المحاولة مجددًا.',
                  )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_t('Try again', 'دوبارہ کوشش کریں', 'حاول مجددًا')),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(_t('Surah', 'سورت', 'سورة')),
                        selected: !_useJuz,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() {
                            _useJuz = false;
                            _clearSession();
                          });
                        },
                      ),
                      ChoiceChip(
                        label: Text(_t('Juz', 'پارہ', 'جزء')),
                        selected: _useJuz,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() {
                            _useJuz = true;
                            _clearSession();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey('$_useJuz:$_chapter:$_juz'),
                    initialValue: _useJuz ? _juz : _chapter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _useJuz
                          ? _t('Choose Juz', 'پارہ منتخب کریں', 'اختر الجزء')
                          : _t('Choose Surah', 'سورت منتخب کریں', 'اختر السورة'),
                      border: const OutlineInputBorder(),
                    ),
                    items: List.generate(_useJuz ? 30 : 114, (index) =>
                      DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          _useJuz
                              ? '${_t('Juz', 'پارہ', 'جزء')} ${index + 1}'
                              : _source.chapterLabels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                    onChanged: (value) {
                      if (value == null || value == (_useJuz ? _juz : _chapter)) return;
                      setState(() {
                        if (_useJuz) { _juz = value; } else { _chapter = value; }
                        _clearSession();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _total == 0 || _finished ? _start : null,
                        icon: const Icon(Icons.shuffle),
                        label: Text(_t('Start test', 'امتحان شروع کریں', 'ابدأ الاختبار')),
                      ),
                      if (_total > 0)
                        OutlinedButton(
                          onPressed: () => setState(_clearSession),
                          child: Text(_t('Reset session', 'نشست دوبارہ شروع کریں', 'إعادة ضبط الجلسة')),
                        ),
                      if (_reference != null && !_finished)
                        TextButton(
                          onPressed: () => setState(() {
                            _reference = null;
                            _finished = true;
                            _remaining.clear();
                          }),
                          child: Text(_t('Finish session', 'نشست ختم کریں', 'إنهاء الجلسة')),
                        ),
                    ],
                  ),
                  if (_total > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${_t('This session', 'اس نشست میں', 'هذه الجلسة')}: '
                      '$completed / $_total',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: completed / _total),
                    const SizedBox(height: 10),
                    Text(
                      '${_t('Remembered', 'یاد تھا', 'تمّ الحفظ')}: $_remembered  ·  '
                      '${_t('Needs review', 'دہرائی درکار', 'بحاجة إلى مراجعة')}: ${_needsReview.length}',
                    ),
                  ],
                  if (verse != null && !_finished) ...[
                    const SizedBox(height: 20),
                    _HubCard(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${verse.chapterName} · ${verse.reference}',
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(_t(
                          'Recite this Ayah from memory, then reveal the answer.',
                          'یہ آیت زبانی پڑھیں، پھر جواب ظاہر کریں۔',
                          'اقرأ هذه الآية من حفظك، ثم أظهر الإجابة.',
                        )),
                        if (!_revealed && clue.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(_t('Starting words', 'ابتدائی الفاظ', 'بداية الآية'),
                            style: theme.textTheme.labelMedium),
                          const SizedBox(height: 6),
                          Text(
                            '$clue …',
                            textDirection: TextDirection.rtl,
                            style: theme.textTheme.headlineSmall?.copyWith(height: 1.9),
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (!_revealed)
                          FilledButton.tonal(
                            onPressed: () => setState(() { _revealed = true; }),
                            child: Text(_t('Reveal answer', 'جواب ظاہر کریں', 'إظهار الإجابة')),
                          )
                        else ...[
                          SelectableText(
                            verse.arabic,
                            textDirection: TextDirection.rtl,
                            style: theme.textTheme.headlineSmall?.copyWith(height: 1.9),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _marked ? null : () => _mark(true),
                                icon: const Icon(Icons.check),
                                label: Text(_t('I remembered', 'مجھے یاد تھا', 'حفظتها')),
                              ),
                              OutlinedButton.icon(
                                onPressed: _marked ? null : () => _mark(false),
                                icon: const Icon(Icons.replay),
                                label: Text(_t('Needs review', 'دہرائی درکار', 'بحاجة إلى مراجعة')),
                              ),
                            ],
                          ),
                          if (_marked) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => setState(() {
                                if (_marked) _nextQuestion();
                              }),
                              icon: const Icon(Icons.navigate_next),
                              label: Text(_remaining.isEmpty
                                  ? _t('Show results', 'نتائج دیکھیں', 'عرض النتائج')
                                  : _t('Next Ayah', 'اگلی آیت', 'الآية التالية')),
                            ),
                          ],
                        ],
                      ],
                    )),
                  ],
                  if (_finished) ...[
                    const SizedBox(height: 16),
                    Text(_t(
                      _total == 0 ? 'No Ayahs were found in this selection.' : 'Session finished. Results are kept here until you close, reset or start again.',
                      _total == 0 ? 'اس انتخاب میں کوئی آیت نہیں ملی۔' : 'نشست ختم ہوگئی۔ نتائج صرف بند کرنے، دوبارہ ترتیب دینے یا نیا امتحان شروع کرنے تک یہاں رہیں گے۔',
                      _total == 0 ? 'لم يُعثر على آيات ضمن هذا الاختيار.' : 'انتهت الجلسة. تبقى النتائج هنا حتى الإغلاق أو إعادة الضبط أو بدء اختبار جديد.',
                    )),
                  ],
                  if (_needsReview.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _t('Review these Ayahs', 'ان آیات کی دہرائی کریں', 'راجع هذه الآيات'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _needsReview.map((reference) => ActionChip(
                        label: Text(reference, textDirection: TextDirection.ltr),
                        tooltip: _t('Show answer', 'جواب دیکھیں', 'عرض الإجابة'),
                        onPressed: () => _review(reference),
                      )).toList(growable: false),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppDecor.of(context).cardShadow,
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
        final tiles = metrics
              .map((metric) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 84),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
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
                          const SizedBox(height: 6),
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
              .toList(growable: false);
        // Tiles in a row share the tallest height, so a value that wraps
        // (longer translations) does not leave its neighbour shorter.
        final rows = <Widget>[];
        for (var start = 0; start < tiles.length; start += columns) {
          if (rows.isNotEmpty) {
            rows.add(const SizedBox(height: 10));
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: 10),
                    Expanded(
                      child: i < tiles.length
                          ? tiles[i]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
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
