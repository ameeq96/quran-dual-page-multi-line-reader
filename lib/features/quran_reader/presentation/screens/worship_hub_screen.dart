import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app/app_theme.dart';
import '../../../../app/reader_localization.dart';
import '../../../../app/prayer_translations.dart';
import '../../../../core/prayer/prayer_calculator.dart';
import '../../../../core/prayer/prayer_models.dart';
import '../../../../core/prayer/prayer_reminder_service.dart';
import '../../../../core/storage/reader_profile_store.dart';
import '../../../../core/services/reader_web_surah_navigation.dart';
import '../../../../core/worship/worship_store.dart';
import '../controllers/quran_reader_controller.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_page_header.dart';
import 'ayah_audio_follow_screen.dart';
import 'quran_reader_screen.dart';
import 'worship_learning_screen.dart';

class WorshipHubScreen extends StatefulWidget {
  const WorshipHubScreen({super.key, required this.controller});
  final QuranReaderController controller;
  @override
  State<WorshipHubScreen> createState() => _WorshipHubScreenState();
}

class _WorshipHubScreenState extends State<WorshipHubScreen> {
  late final WorshipStore _store;
  final _prayer = PrayerReminderService.instance;
  final _masjidName = TextEditingController();
  final _masjidSource = TextEditingController();
  final _jamaat = <String, int>{};
  String _section = 'overview';
  String? _error;
  bool _working = false, _ready = false;
  DateTime _diaryDate = DateTime.now();
  DateTime? _ramadanStart;
  int _ramadanDays = 30, _sehriLead = 15, _iftarLead = 0;
  bool _ramadanEnabled = false, _masjidEnabled = false, _verified = false;
  bool _masjidLocationChanged = false;
  late DateTime _validFrom, _validUntil;
  Timer? _clock;

  String _t(String en, String ur, String ar) =>
      switch (ReaderLocalization.instance.language) {
        ReaderLanguage.urdu => ur,
        ReaderLanguage.arabic => ar,
        _ => en,
      };

  String _s(String source, {Map<String, Object?> args = const {}}) {
    final translation = _hubTranslations[source];
    final text = translation == null
        ? prayerText(context, source, args: args)
        : _t(source, translation.$1, translation.$2);
    return text.replaceAllMapped(
      RegExp(r'\{([^{}]+)\}'),
      (match) => args.containsKey(match[1]) ? '${args[match[1]]}' : match[0]!,
    );
  }

  String _prayerName(String prayer) =>
      _s(prayer[0].toUpperCase() + prayer.substring(1));

  @override
  void initState() {
    super.initState();
    _store = WorshipStore(profileId: ReaderProfileStore.instance.activeId);
    _validFrom = DateTime.now();
    _validUntil = _validFrom.add(const Duration(days: 7));
    unawaited(_load());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _ready = false;
        _error = null;
      });
    try {
      await _store.load();
      await _prayer.initialize(baseUrl: widget.controller.adminSyncBaseUrl);
      if (!mounted) return;
      final ramadan = _store.ramadan;
      if (ramadan != null) {
        _ramadanStart = DateTime.parse(ramadan['startDate'] as String);
        _ramadanDays = ramadan['days'] as int;
        _sehriLead = ramadan['sehriLeadMinutes'] as int;
        _iftarLead = ramadan['iftarLeadMinutes'] as int;
        _ramadanEnabled = ramadan['enabled'] == true;
      }
      final masjid = _store.masjid;
      if (masjid != null) {
        _masjidName.text = masjid['name'] as String;
        _masjidSource.text = masjid['source'] as String;
        _validFrom = DateTime.parse(masjid['validFrom'] as String);
        _validUntil = DateTime.parse(masjid['validUntil'] as String);
        _jamaat.addAll(Map<String, int>.from(masjid['times'] as Map));
        final place = _prayer.settings.location;
        final latitude = masjid['latitude'];
        final longitude = masjid['longitude'];
        final sameLocation =
            place != null &&
            masjid['zone'] == place.zone &&
            latitude is num &&
            longitude is num &&
            (latitude - place.latitude).abs() < .02 &&
            (longitude - place.longitude).abs() < .02;
        _masjidLocationChanged = !sameLocation;
        _verified = masjid['verified'] == true && sameLocation;
        _masjidEnabled = masjid['enabled'] == true && sameLocation;
      }
      setState(() => _ready = true);
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Saved worship records could not be loaded. Your records have not been replaced.',
        );
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _masjidName.dispose();
    _masjidSource.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function() work, {
    bool reminders = false,
  }) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await work();
      if (reminders && !await _prayer.refreshWorship()) {
        throw StateError(
          _prayer.error ??
              'Saved, but reminders could not be scheduled. Retry saving after checking permissions.',
        );
      }
    } catch (e) {
      if (mounted)
        _error = e is ArgumentError
            ? '${e.message}'
            : e is FormatException
            ? e.message
            : e is StateError
            ? '${e.message}'
            : '$e';
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  Future<DateTime?> _date(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(2200),
  );
  String _day(DateTime value) => PrayerCalculator.dayKey(value);
  String _time(DateTime? value) => value == null
      ? '—'
      : TimeOfDay.fromDateTime(
          tz.TZDateTime.from(value, PrayerCalculator.zone(_prayer.settings)),
        ).format(context);
  String _clockTime(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
  String _countdown(DateTime at) {
    final total = at.difference(DateTime.now().toUtc()).inSeconds;
    if (total <= 0) return '00:00:00';
    final days = total ~/ 86400 > 0
        ? _s('{days}d ', args: {'days': total ~/ 86400})
        : '';
    return '$days${(total ~/ 3600 % 24).toString().padLeft(2, '0')}:${(total ~/ 60 % 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Widget _card(String title, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_s(title), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
  Widget _feature(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(_s(title)),
      subtitle: Text(_s(subtitle)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(_s(text), style: Theme.of(context).textTheme.bodyMedium),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ReaderLocalization.instance,
    builder: (context, _) {
      final title = switch (_section) {
        'diary' => _t(
          'Namaz & Qaza diary',
          'نماز اور قضا ڈائری',
          'سجل الصلاة والقضاء',
        ),
        'ramadan' => _t('Ramadan', 'رمضان', 'رمضان'),
        'masjid' => _t('My Masjid', 'میری مسجد', 'مسجدي'),
        _ => _t('Worship companions', 'عبادت کے ساتھی', 'رفقاء العبادة'),
      };
      final overview = _section == 'overview';
      return Directionality(
        textDirection: ReaderLocalization.instance.textDirection,
        child: Builder(
          builder: (context) {
            // Built under the Directionality above so it mirrors in RTL.
            final header = AppPageHeader(
              title: title,
              eyebrow: overview
                  ? _s(
                      _t(
                        'A little worship, every day',
                        'روزانہ تھوڑی عبادت',
                        'عبادة يسيرة كل يوم',
                      ),
                    )
                  : null,
              subtitle: overview
                  ? _t(
                      'Your diary, counters and lessons stay on this device, in this reader profile.',
                      'آپ کی ڈائری، گنتی اور اسباق اسی آلے اور پروفائل میں محفوظ ہیں۔',
                      'يبقى سجلك وعدادك ودروسك على هذا الجهاز وفي ملفك المحلي.',
                    )
                  : null,
              icon: switch (_section) {
                'diary' => Icons.checklist_rounded,
                'ramadan' => Icons.nights_stay_outlined,
                'masjid' => Icons.mosque_outlined,
                _ => Icons.spa_outlined,
              },
              compact: !overview,
              onBack: overview
                  ? AppPageHeader.popAction(context)
                  : () => setState(() => _section = 'overview'),
            );
            return Scaffold(
          // Zero-height bar: keeps the status bar styling and top inset while
          // the hero header in the body carries title and back.
          appBar: AppBar(toolbarHeight: 0, automaticallyImplyLeading: false),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: !_ready && _error == null
                  ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: header,
                        ),
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        header,
                        const SizedBox(height: 16),
                        if (_working) const LinearProgressIndicator(),
                        if (_error != null) _notice(_error!),
                        if (!_ready && _error != null)
                          OutlinedButton(
                            onPressed: () => unawaited(_load()),
                            child: Text(_s('Retry')),
                          ),
                        if (_ready)
                          ...switch (_section) {
                            'diary' => _diary(),
                            'ramadan' => _ramadan(),
                            'masjid' => _masjid(),
                            // Only the first rows animate in; the rest of
                            // the list appears immediately.
                            _ => [
                              for (final (index, item) in _overview().indexed)
                                index < 6
                                    ? AppStagger(index: index, child: item)
                                    : item,
                            ],
                          },
                      ],
                    ),
            ),
          ),
            );
          },
        ),
      );
    },
  );

  List<Widget> _overview() => [
    _feature(
      Icons.checklist_rounded,
      _t('Namaz & Qaza diary', 'نماز اور قضا ڈائری', 'سجل الصلاة والقضاء'),
      'Daily prayer record and your own Qaza balance.',
      () => setState(() => _section = 'diary'),
    ),
    _feature(
      Icons.nights_stay_outlined,
      _t('Ramadan mode', 'رمضان موڈ', 'وضع رمضان'),
      'Sehri, Iftar, countdowns and date-limited reminders.',
      () => setState(() => _section = 'ramadan'),
    ),
    _feature(
      Icons.mosque_outlined,
      _t('My Masjid', 'میری مسجد', 'مسجدي'),
      'Save and confirm your local Jamaat timetable.',
      () => setState(() => _section = 'masjid'),
    ),
    for (final (tab, icon, title, subtitle) in [
      (
        0,
        Icons.spa_outlined,
        _t('Azkar & Tasbeeh', 'اذکار اور تسبیح', 'الأذكار والتسبيح'),
        'Morning, evening and daily remembrance with references.',
      ),
      (
        1,
        Icons.school_outlined,
        _t('Children’s learning', 'بچوں کی تعلیم', 'تعليم الأطفال'),
        'Arabic letters, short Surahs and small lessons.',
      ),
      (
        2,
        Icons.menu_book_outlined,
        _t(
          'Wuzu & Namaz guide',
          'وضو اور نماز کی رہنمائی',
          'دليل الوضوء والصلاة',
        ),
        'Learn the foundations with sources and your school selection.',
      ),
    ])
      _feature(
        icon,
        title,
        subtitle,
        () => _open(
          WorshipLearningScreen(
            store: _store,
            initialTab: tab,
            onPlaySurah: widget.controller.isAudioEnabled ? _playSurah : null,
            onReadSurah: _readSurah,
            onStopAudio: widget.controller.pauseAudio,
          ),
        ),
      ),
    _feature(
      Icons.hearing_outlined,
      _t('Ayah audio follow', 'آیت کے ساتھ تلاوت', 'متابعة تلاوة الآيات'),
      'Follow the currently recited Ayah and its translation.',
      () => _open(AyahAudioFollowScreen(controller: widget.controller)),
    ),
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      _feature(
        Icons.widgets_outlined,
        _t(
          'Prayer home-screen widget',
          'نماز کا ہوم اسکرین ویجٹ',
          'أداة الصلاة للشاشة الرئيسية',
        ),
        'Next prayer and timetable on your phone’s home screen.',
        _pinWidget,
      ),
    _notice(
      _t(
        'Reminder sounds on the web need an open browser and enabled audio. Android background alarms need notification and alarm permissions.',
        'ویب پر آواز کے لیے براؤزر کھلا اور آڈیو فعال ہونا ضروری ہے۔ اینڈرائیڈ الارم کے لیے متعلقہ اجازتیں دیں۔',
        'تتطلب أصوات الويب متصفحًا مفتوحًا وصوتًا مفعّلًا. تحتاج تنبيهات أندرويد إلى الأذونات المناسبة.',
      ),
    ),
    if (_prayer.isWeb && !_prayer.audioEnabled)
      FilledButton.tonal(
        onPressed: () async {
          await _prayer.enableAudio();
          if (mounted) setState(() {});
        },
        child: Text(_s('Enable reminder audio')),
      ),
  ];

  Future<void> _playSurah(int id) async {
    final matches = widget.controller.chapters
        .where((chapter) => chapter.id == id)
        .toList();
    if (matches.length != 1)
      throw StateError('This recitation is unavailable.');
    await widget.controller.selectAudioChapter(matches.single);
    await widget.controller.playSelectedSurah();
    if (widget.controller.audioState.errorMessage != null)
      throw StateError(widget.controller.audioState.errorMessage!);
  }

  Future<void> _readSurah(int id) async {
    final controller = widget.controller;
    await controller.pendingMushafEditionChange;
    final entries = controller.surahEntries
        .where((entry) => entry.id == id)
        .toList();
    if (entries.length != 1 ||
        !controller.isMushafEditionReady(controller.settings.mushafEdition)) {
      throw StateError('This Surah is unavailable in the selected Mushaf.');
    }
    if (!controller.settings.preferImageMode)
      await controller.togglePreferImageMode(true);
    await controller.jumpToSurah(entries.single);
    if (mounted)
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: readerWebSurahRouteSettings,
          builder: (_) => QuranReaderScreen(controller: controller),
        ),
      );
  }

  Future<void> _pinWidget() async {
    await _run(() async {
      if (_prayer.settings.location == null)
        throw ArgumentError('Choose a location in Namaz & Azan first.');
      if (!await _prayer.refreshWorship())
        throw StateError(_prayer.error ?? 'Unable to prepare widget.');
      const channel = MethodChannel('com.opplexify.quran/prayer_reminders');
      final status = await channel.invokeMapMethod<String, dynamic>(
        'widgetStatus',
      );
      if (status?['pinSupported'] != true)
        throw StateError(
          'Add the Prayer widget from your launcher’s Widgets menu.',
        );
      final result = await channel.invokeMapMethod<String, dynamic>(
        'pinWidget',
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _s(
                result?['requested'] == true
                    ? 'Confirm the widget on your home screen.'
                    : 'Open your launcher’s Widgets menu to add the Prayer widget.',
              ),
            ),
          ),
        );
    });
  }

  List<Widget> _diary() => [
    _card(_t('Your school and record', 'آپ کا مسلک اور ریکارڈ', 'مذهبك وسجلك'), [
      DropdownButtonFormField<String>(
        initialValue: _store.fiqh,
        isExpanded: true,
        decoration: InputDecoration(labelText: _s('Choose your fiqh school')),
        items: [
          for (final school in worshipSchools)
            DropdownMenuItem(
              value: school,
              child: Text(_s(school[0].toUpperCase() + school.substring(1))),
            ),
        ],
        onChanged: _working
            ? null
            : (value) {
                if (value != null) _run(() => _store.setFiqh(value));
              },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _store.includeWitr,
        onChanged: _working
            ? null
            : (value) => _run(() => _store.setIncludeWitr(value)),
        title: Text(_s('Include Witr in my record')),
      ),
      Text(
        _s(
          'Only prayers you mark “Missed” enter the balance. “Unrecorded” and “Excused” do not. This is your record, not a ruling on what you owe.',
        ),
      ),
    ]),
    _card(_t('Daily record', 'روزانہ کا ریکارڈ', 'السجل اليومي'), [
      OutlinedButton.icon(
        icon: const Icon(Icons.calendar_month),
        label: Text(_day(_diaryDate)),
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _diaryDate,
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (date != null && mounted) setState(() => _diaryDate = date);
        },
      ),
      const SizedBox(height: 8),
      for (final prayer in _store.trackedPrayers) _diaryPrayerRow(prayer),
    ]),
    _card(_t('Qaza balance', 'قضا کا حساب', 'رصيد القضاء'), [
      for (final (index, prayer) in _store.trackedPrayers.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const Divider(height: 20),
              Text(
                _s(
                  '{prayer} · {count} remaining',
                  args: {
                    'prayer': _prayerName(prayer),
                    'count': _store.qazaBalance(prayer),
                  },
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                _s(
                  'Starting {opening} + marked missed {missed} − completed {completed}',
                  args: {
                    'opening': _store.openingBalance(prayer),
                    'missed': _store.missedCount(prayer),
                    'completed': _store.completedQaza(prayer),
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _working ? null : () => _editOpening(prayer),
                    child: Text(_s('Starting balance')),
                  ),
                  FilledButton.tonal(
                    onPressed: _working || _store.qazaBalance(prayer) == 0
                        ? null
                        : () => _run(() => _store.recordQaza(prayer, 1)),
                    child: Text(_s('Completed one')),
                  ),
                  TextButton(
                    onPressed: _working || _store.completedQaza(prayer) == 0
                        ? null
                        : () => _run(() => _store.recordQaza(prayer, -1)),
                    child: Text(_s('Undo')),
                  ),
                ],
              ),
            ],
          ),
        ),
    ]),
  ];

  Widget _diaryPrayerRow(String prayer) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final choice = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
            child: DropdownButton<String>(
          value: _store.status(_day(_diaryDate), prayer),
          isExpanded: true,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          items: [
            for (final status in diaryStatuses)
              DropdownMenuItem(
                value: status,
                child: Text(_s(status[0].toUpperCase() + status.substring(1))),
              ),
          ],
          onChanged: _working
              ? null
              : (value) {
                  if (value != null) {
                    _run(
                      () => _store.setStatus(_day(_diaryDate), prayer, value),
                    );
                  }
                },
            ),
          ),
        );
        final name = Text(
          _prayerName(prayer),
          style: Theme.of(context).textTheme.titleMedium,
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 18) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [name, const SizedBox(height: 6), choice],
          );
        }
        return Row(
          children: [
            Expanded(child: name),
            const SizedBox(width: 16),
            SizedBox(
              width: constraints.maxWidth < 480 ? 184 : 220,
              child: choice,
            ),
          ],
        );
      },
    ),
  );

  Future<void> _editOpening(String prayer) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _OpeningBalanceDialog(
        initialCount: _store.openingBalance(prayer),
        title: _s(
          '{prayer} starting balance',
          args: {'prayer': _prayerName(prayer)},
        ),
        helperText: _s('Enter prayers owed before this diary.'),
        cancelLabel: _s('Cancel'),
        saveLabel: _s('Save'),
      ),
    );
    if (value != null && mounted)
      await _run(() => _store.setOpeningBalance(prayer, value));
  }

  List<Widget> _ramadan() {
    final place = _prayer.settings.location;
    final start = _ramadanStart;
    final today = PrayerCalculator.dateInZone(DateTime.now(), _prayer.settings);
    final now = DateTime.now().toUtc();
    DateTime? fastDay;
    if (start != null) {
      final startDay = DateTime.utc(start.year, start.month, start.day);
      final last = startDay.add(Duration(days: _ramadanDays - 1));
      if (!today.isAfter(last)) {
        fastDay = today.isBefore(startDay) ? startDay : today;
        final maghrib = PrayerCalculator.timesForDate(
          _prayer.settings,
          fastDay,
        )[PrayerId.maghrib];
        if (maghrib != null && !maghrib.isAfter(now))
          fastDay = fastDay.add(const Duration(days: 1));
        if (fastDay.isAfter(last)) fastDay = null;
      }
    }
    final times = fastDay == null
        ? <PrayerId, DateTime>{}
        : PrayerCalculator.timesForDate(_prayer.settings, fastDay);
    return [
      _card(
        _t(
          'Your local Ramadan calendar',
          'آپ کا مقامی رمضان کیلنڈر',
          'تقويم رمضان المحلي',
        ),
        [
          Text(
            _s(
              'Confirm the first fasting day and 29/30 days with your local moon-sighting authority. Fajr ends Sehri; Maghrib begins Iftar. Advance reminders are not the time to start Iftar.',
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(
              start == null ? _s('Choose first fasting day') : _day(start),
            ),
            onPressed: () async {
              final date = await _date(start ?? DateTime.now());
              if (date != null && mounted) setState(() => _ramadanStart = date);
            },
          ),
          DropdownButtonFormField<int>(
            initialValue: _ramadanDays,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _s('Confirmed number of days'),
            ),
            items: [
              for (final d in [29, 30])
                DropdownMenuItem(
                  value: d,
                  child: Text(_s('{days} days', args: {'days': d})),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _ramadanDays = v);
            },
          ),
          if (place != null) _notice('${_s(place.label)} · ${place.zone}'),
          if (fastDay != null)
            _notice(_s('Fasting day: {date}', args: {'date': _day(fastDay)})),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_s('Sehri ends / Fajr')),
            trailing: Text(_time(times[PrayerId.fajr])),
          ),
          if (times[PrayerId.fajr]?.isAfter(now) == true)
            _notice(_countdown(times[PrayerId.fajr]!)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_s('Iftar / Maghrib')),
            trailing: Text(_time(times[PrayerId.maghrib])),
          ),
          if (times[PrayerId.maghrib]?.isAfter(now) == true)
            _notice(_countdown(times[PrayerId.maghrib]!)),
          if (start != null && fastDay == null)
            _notice('This Ramadan calendar has ended.'),
          if (place == null)
            _notice('Choose your city in Namaz & Azan to calculate times.'),
        ],
      ),
      _card(_t('Ramadan reminders', 'رمضان کی یاددہانیاں', 'تنبيهات رمضان'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_s('Sehri and Iftar reminder tones')),
          value: _ramadanEnabled,
          onChanged: (v) => setState(() => _ramadanEnabled = v),
        ),
        _leadPicker(
          'Minutes before Sehri ends',
          _sehriLead,
          [0, 5, 10, 15, 30, 60],
          (v) => setState(() => _sehriLead = v),
        ),
        _leadPicker('Minutes before Iftar', _iftarLead, [
          0,
          5,
          10,
          15,
          30,
        ], (v) => setState(() => _iftarLead = v)),
        _reminderNotice(),
        FilledButton(
          onPressed: _working
              ? null
              : () => _run(() async {
                  if (start == null)
                    throw ArgumentError('Choose the first fasting day.');
                  if (_ramadanEnabled && place == null)
                    throw ArgumentError('Choose your prayer location first.');
                  await _store.saveRamadan({
                    'startDate': _day(start),
                    'days': _ramadanDays,
                    'enabled': _ramadanEnabled,
                    'sehriLeadMinutes': _sehriLead,
                    'iftarLeadMinutes': _iftarLead,
                  });
                }, reminders: true),
          child: Text(_s('Save Ramadan plan')),
        ),
      ]),
    ];
  }

  Widget _leadPicker(
    String title,
    int value,
    List<int> values,
    ValueChanged<int> change,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: _s(title)),
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v,
            child: Text(_s('{minutes} min', args: {'minutes': v})),
          ),
      ],
      onChanged: (v) {
        if (v != null) change(v);
      },
    ),
  );
  Widget _reminderNotice() => _notice(
    _prayer.isWeb
        ? 'Keep this browser open and enable reminder audio in Worship companions. These local timetable reminders are not delivered by web push.'
        : 'Enable notification and exact-alarm permissions in Namaz & Azan. Your main prayer reminder switch is independent.',
  );

  List<Widget> _masjid() => [
    _card(
      _t(
        'Your confirmed timetable',
        'آپ کا تصدیق شدہ ٹائم ٹیبل',
        'جدولك المؤكد',
      ),
      [
        Text(
          _s(
            'Enter times from your Masjid’s current poster or Imam. “Confirmed by me” records your own check; it is not an independently verified public listing.',
          ),
        ),
        Text(
          _s(
            'An Isha time before noon is scheduled after midnight following that timetable date.',
          ),
        ),
        if (_store.masjid?['zone'] is String)
          _notice(
            _s(
              'Timetable time zone: {zone}',
              args: {'zone': _store.masjid!['zone']},
            ),
          ),
        if (_masjidLocationChanged)
          _notice(
            'Location changed. Reconfirm this Masjid timetable before enabling reminders.',
          ),
        TextField(
          controller: _masjidName,
          maxLength: 80,
          decoration: InputDecoration(labelText: _s('Masjid name')),
          onChanged: (_) => setState(() => _verified = false),
        ),
        TextField(
          controller: _masjidSource,
          maxLength: 160,
          decoration: InputDecoration(
            labelText: _s('Source / who confirmed these times'),
          ),
          onChanged: (_) => setState(() => _verified = false),
        ),
        for (final id in PrayerId.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_s(id.label)),
            subtitle: Text(
              _jamaat[id.name] == null
                  ? _s('Not set')
                  : _clockTime(_jamaat[id.name]!),
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: _s(
                    'Set {prayer} Jamaat',
                    args: {'prayer': _s(id.label)},
                  ),
                  icon: const Icon(Icons.schedule),
                  onPressed: () async {
                    final value = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: (_jamaat[id.name] ?? 720) ~/ 60,
                        minute: (_jamaat[id.name] ?? 720) % 60,
                      ),
                    );
                    if (value != null && mounted)
                      setState(() {
                        _jamaat[id.name] = value.hour * 60 + value.minute;
                        _verified = false;
                      });
                  },
                ),
                if (_jamaat.containsKey(id.name))
                  IconButton(
                    tooltip: _s(
                      'Clear {prayer}',
                      args: {'prayer': _s(id.label)},
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _jamaat.remove(id.name);
                      _verified = false;
                    }),
                  ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () async {
                final d = await _date(_validFrom);
                if (d != null && mounted)
                  setState(() {
                    _validFrom = d;
                    _verified = false;
                  });
              },
              child: Text(_s('From {date}', args: {'date': _day(_validFrom)})),
            ),
            OutlinedButton(
              onPressed: () async {
                final d = await _date(_validUntil);
                if (d != null && mounted)
                  setState(() {
                    _validUntil = d;
                    _verified = false;
                  });
              },
              child: Text(
                _s('Until {date}', args: {'date': _day(_validUntil)}),
              ),
            ),
          ],
        ),
        if (_day(_validUntil).compareTo(
              _day(
                PrayerCalculator.dateInZone(DateTime.now(), _prayer.settings),
              ),
            ) <
            0)
          _notice('This timetable has expired. Confirm new dates and times.'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _verified,
          title: Text(_s('Confirmed by me with my Masjid')),
          onChanged: (v) => setState(() => _verified = v ?? false),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _masjidEnabled,
          title: Text(_s('Jamaat reminder tones during these dates')),
          onChanged: _masjidLocationChanged && !_verified
              ? null
              : (v) => setState(() => _masjidEnabled = v),
        ),
        _reminderNotice(),
        FilledButton(
          onPressed: _working
              ? null
              : () => _run(() async {
                  final place = _prayer.settings.location;
                  if (place == null)
                    throw ArgumentError(
                      'Choose your city and time zone in Namaz & Azan first.',
                    );
                  await _store.saveMasjid({
                    'name': _masjidName.text.trim(),
                    'source': _masjidSource.text.trim(),
                    'verified': _verified,
                    'enabled': _masjidEnabled,
                    'validFrom': _day(_validFrom),
                    'validUntil': _day(_validUntil),
                    'times': Map<String, int>.from(_jamaat),
                    'zone': place.zone,
                    'latitude': place.latitude,
                    'longitude': place.longitude,
                  });
                  _masjidLocationChanged = false;
                }, reminders: true),
          child: Text(_s('Save Masjid timetable')),
        ),
      ],
    ),
  ];
}

class _OpeningBalanceDialog extends StatefulWidget {
  const _OpeningBalanceDialog({
    required this.initialCount,
    required this.title,
    required this.helperText,
    required this.cancelLabel,
    required this.saveLabel,
  });

  final int initialCount;
  final String title, helperText, cancelLabel, saveLabel;

  @override
  State<_OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<_OpeningBalanceDialog> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: '${widget.initialCount}');
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _field,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 7,
      decoration: InputDecoration(helperText: widget.helperText),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(
        onPressed: () {
          final count = int.tryParse(_field.text);
          if (count != null) Navigator.pop(context, count);
        },
        child: Text(widget.saveLabel),
      ),
    ],
  );
}

const _hubTranslations = <String, (String, String)>{
  'Timetable time zone: {zone}': (
    'اوقات نامے کا ٹائم زون: {zone}',
    'المنطقة الزمنية للجدول: {zone}',
  ),
  'Location changed. Reconfirm this Masjid timetable before enabling reminders.': (
    'مقام تبدیل ہو گیا ہے۔ یاددہانیاں فعال کرنے سے پہلے مسجد کے اوقات دوبارہ تصدیق کریں۔',
    'تغيّر الموقع. أعد تأكيد جدول المسجد قبل تفعيل التنبيهات.',
  ),
  'Compass or a north-referenced direction for your location.': (
    'آپ کے مقام کے لیے کمپاس یا شمال کے مطابق سمت۔',
    'بوصلة أو اتجاه مرجعي للشمال بحسب موقعك.',
  ),
  'Daily prayer record and your own Qaza balance.': (
    'روزانہ کی نمازوں کا ریکارڈ اور آپ کا قضا حساب۔',
    'سجل الصلاة اليومي ورصيد القضاء الخاص بك.',
  ),
  'Sehri, Iftar, countdowns and date-limited reminders.': (
    'سحری، افطار، باقی وقت اور مقررہ تاریخوں کی یاددہانیاں۔',
    'السحور والإفطار والوقت المتبقي وتنبيهات ضمن تواريخ محددة.',
  ),
  'Save and confirm your local Jamaat timetable.': (
    'اپنی مسجد کے جماعت کے اوقات محفوظ اور تصدیق کریں۔',
    'احفظ مواعيد الجماعة المحلية وأكّدها.',
  ),
  'Morning, evening and daily remembrance with references.': (
    'صبح، شام اور روزانہ کے اذکار حوالوں کے ساتھ۔',
    'أذكار الصباح والمساء والأذكار اليومية مع مصادرها.',
  ),
  'Arabic letters, short Surahs and small lessons.': (
    'عربی حروف، چھوٹی سورتیں اور مختصر اسباق۔',
    'الحروف العربية والسور القصيرة والدروس المبسطة.',
  ),
  'Learn the foundations with sources and your school selection.': (
    'اپنے منتخب مسلک کے مطابق بنیادی باتیں حوالوں کے ساتھ سیکھیں۔',
    'تعلّم الأساسيات مع المصادر والمذهب الذي تختاره.',
  ),
  'Follow the currently recited Ayah and its translation.': (
    'جاری تلاوت کی آیت اور اس کا ترجمہ ساتھ دیکھیں۔',
    'تابع الآية المتلوّة وترجمتها.',
  ),
  'Next prayer and timetable on your phone’s home screen.': (
    'اگلی نماز اور اوقات فون کی ہوم اسکرین پر۔',
    'الصلاة القادمة ومواعيد الصلاة على الشاشة الرئيسية للهاتف.',
  ),
  'Enable reminder audio': (
    'یاددہانی کی آواز فعال کریں',
    'تفعيل صوت التنبيهات',
  ),
  'Retry': ('دوبارہ کوشش کریں', 'إعادة المحاولة'),
  'Choose your fiqh school': ('اپنا فقہی مسلک منتخب کریں', 'اختر مذهبك الفقهي'),
  'Shafii': ('شافعی', 'شافعي'),
  'Maliki': ('مالکی', 'مالكي'),
  'Hanbali': ('حنبلی', 'حنبلي'),
  'Witr': ('وتر', 'الوتر'),
  'Unrecorded': ('درج نہیں', 'غير مسجّلة'),
  'Prayed': ('ادا کی', 'أُدّيت'),
  'Missed': ('رہ گئی', 'فائتة'),
  'Excused': ('شرعی عذر', 'معذور'),
  'Include Witr in my record': (
    'میرے ریکارڈ میں وتر بھی شامل کریں',
    'إدراج الوتر في سجلي',
  ),
  'Only prayers you mark “Missed” enter the balance. “Unrecorded” and “Excused” do not. This is your record, not a ruling on what you owe.': (
    'صرف وہ نمازیں قضا کے حساب میں آتی ہیں جنہیں آپ «رہ گئی» درج کریں۔ «درج نہیں» اور «شرعی عذر» شامل نہیں ہوتے۔ یہ آپ کا ذاتی ریکارڈ ہے، واجب قضا کا شرعی فتویٰ نہیں۔',
    'تُضاف إلى الرصيد الصلوات التي تسجلها «فائتة» فقط. لا تُضاف «غير مسجّلة» و«معذور». هذا سجلك الشخصي وليس فتوى بشأن ما يجب عليك قضاؤه.',
  ),
  '{prayer} · {count} remaining': (
    '{prayer} · باقی {count}',
    '{prayer} · المتبقي {count}',
  ),
  'Starting {opening} + marked missed {missed} − completed {completed}': (
    'ابتدائی {opening} + رہ گئی {missed} − ادا شدہ قضا {completed}',
    'الرصيد الأولي {opening} + الفائتة المسجّلة {missed} − المقضيّة {completed}',
  ),
  'Starting balance': ('ابتدائی حساب', 'الرصيد الأولي'),
  'Completed one': ('ایک قضا ادا کی', 'قضيت صلاة واحدة'),
  'Undo': ('واپس کریں', 'تراجع'),
  '{prayer} starting balance': (
    '{prayer} کا ابتدائی حساب',
    'الرصيد الأولي لصلاة {prayer}',
  ),
  'Enter prayers owed before this diary.': (
    'اس ڈائری سے پہلے کی قضا نمازوں کی تعداد درج کریں۔',
    'أدخل عدد الصلوات الفائتة قبل بدء هذا السجل.',
  ),
  'Confirm the first fasting day and 29/30 days with your local moon-sighting authority. Fajr ends Sehri; Maghrib begins Iftar. Advance reminders are not the time to start Iftar.': (
    'پہلے روزے کی تاریخ اور 29 یا 30 دن اپنے مقامی رویتِ ہلال ادارے سے تصدیق کریں۔ سحری فجر پر ختم اور افطار مغرب پر شروع ہوتا ہے۔ پہلے آنے والی یاددہانی افطار شروع کرنے کا وقت نہیں ہے۔',
    'أكّد تاريخ أول يوم صيام وعدد الأيام 29 أو 30 مع جهة تحرّي الهلال المحلية. ينتهي السحور عند الفجر ويبدأ الإفطار عند المغرب. التنبيه المبكر ليس موعد بدء الإفطار.',
  ),
  'Choose first fasting day': (
    'پہلے روزے کی تاریخ منتخب کریں',
    'اختر تاريخ أول يوم صيام',
  ),
  'Confirmed number of days': ('تصدیق شدہ دنوں کی تعداد', 'عدد الأيام المؤكّد'),
  '{days} days': ('{days} دن', '{days} يومًا'),
  '{days}d ': ('{days} دن ', '{days} يوم '),
  'Fasting day: {date}': ('روزے کی تاریخ: {date}', 'تاريخ الصيام: {date}'),
  'Sehri ends / Fajr': ('سحری ختم / فجر', 'نهاية السحور / الفجر'),
  'Iftar / Maghrib': ('افطار / مغرب', 'الإفطار / المغرب'),
  'This Ramadan calendar has ended.': (
    'اس رمضان کیلنڈر کی مدت ختم ہو گئی ہے۔',
    'انتهت فترة تقويم رمضان هذا.',
  ),
  'Choose your city in Namaz & Azan to calculate times.': (
    'اوقات معلوم کرنے کے لیے نماز اور اذان میں اپنا شہر منتخب کریں۔',
    'اختر مدينتك في الصلاة والأذان لحساب المواقيت.',
  ),
  'Sehri and Iftar reminder tones': (
    'سحری اور افطار کی یاددہانی کی آوازیں',
    'أصوات تنبيهات السحور والإفطار',
  ),
  'Minutes before Sehri ends': (
    'سحری ختم ہونے سے کتنے منٹ پہلے',
    'الدقائق قبل نهاية السحور',
  ),
  'Minutes before Iftar': ('افطار سے کتنے منٹ پہلے', 'الدقائق قبل الإفطار'),
  '{minutes} min': ('{minutes} منٹ', '{minutes} دقيقة'),
  'Save Ramadan plan': ('رمضان کا منصوبہ محفوظ کریں', 'حفظ خطة رمضان'),
  'Keep this browser open and enable reminder audio in Worship companions. These local timetable reminders are not delivered by web push.': (
    'یہ براؤزر کھلا رکھیں اور عبادت کے ساتھی میں یاددہانی کی آواز فعال کریں۔ ان مقامی اوقات کی یاددہانیاں ویب پش کے ذریعے نہیں آتیں۔',
    'أبقِ المتصفح مفتوحًا وفعّل صوت التنبيهات في رفقاء العبادة. لا تُرسل تنبيهات هذا الجدول المحلي عبر إشعارات الويب الفورية.',
  ),
  'Enable notification and exact-alarm permissions in Namaz & Azan. Your main prayer reminder switch is independent.': (
    'نماز اور اذان میں نوٹیفکیشن اور درست الارم کی اجازت دیں۔ نماز کی مرکزی یاددہانی کا سوئچ الگ ہے۔',
    'فعّل أذونات الإشعارات والمنبّهات الدقيقة في الصلاة والأذان. مفتاح تنبيهات الصلاة الرئيسي مستقل.',
  ),
  'Enter times from your Masjid’s current poster or Imam. “Confirmed by me” records your own check; it is not an independently verified public listing.': (
    'اپنی مسجد کے موجودہ اوقات نامے یا امام سے اوقات لے کر درج کریں۔ «میں نے تصدیق کی» آپ کی اپنی تصدیق کا ریکارڈ ہے، آزادانہ تصدیق شدہ عوامی فہرست نہیں۔',
    'أدخل الأوقات من إعلان مسجدك الحالي أو من الإمام. عبارة «أكّدتها بنفسي» تسجّل تحقّقك الشخصي، وليست قائمة عامة جرى التحقّق منها بشكل مستقل.',
  ),
  'An Isha time before noon is scheduled after midnight following that timetable date.': (
    'دوپہر سے پہلے درج عشاء کا وقت متعلقہ تاریخ کے بعد آدھی رات گزرنے پر مقرر ہوتا ہے۔',
    'يُجدول وقت العشاء المدخل قبل الظهر بعد منتصف الليل التالي لتاريخ الجدول.',
  ),
  'Masjid name': ('مسجد کا نام', 'اسم المسجد'),
  'Source / who confirmed these times': (
    'ماخذ / اوقات کی تصدیق کس نے کی',
    'المصدر / من أكّد هذه الأوقات',
  ),
  'Not set': ('مقرر نہیں', 'غير محدّد'),
  'Set {prayer} Jamaat': (
    '{prayer} کی جماعت مقرر کریں',
    'تحديد جماعة {prayer}',
  ),
  'Clear {prayer}': ('{prayer} کا وقت ہٹائیں', 'مسح وقت {prayer}'),
  'From {date}': ('{date} سے', 'من {date}'),
  'Until {date}': ('{date} تک', 'حتى {date}'),
  'This timetable has expired. Confirm new dates and times.': (
    'اس اوقات نامے کی مدت ختم ہو چکی ہے۔ نئی تاریخیں اور اوقات تصدیق کریں۔',
    'انتهت صلاحية هذا الجدول. أكّد التواريخ والأوقات الجديدة.',
  ),
  'Confirmed by me with my Masjid': (
    'میں نے اپنی مسجد سے تصدیق کی ہے',
    'أكّدت الأوقات بنفسي مع مسجدي',
  ),
  'Jamaat reminder tones during these dates': (
    'ان تاریخوں میں جماعت کی یاددہانی کی آوازیں',
    'أصوات تنبيهات الجماعة خلال هذه التواريخ',
  ),
  'Save Masjid timetable': ('مسجد کے اوقات محفوظ کریں', 'حفظ جدول المسجد'),
  'Confirm the widget on your home screen.': (
    'ہوم اسکرین پر ویجٹ کی تصدیق کریں۔',
    'أكّد إضافة الأداة على شاشتك الرئيسية.',
  ),
  'Open your launcher’s Widgets menu to add the Prayer widget.': (
    'نماز کا ویجٹ شامل کرنے کے لیے لانچر کا ویجٹس مینو کھولیں۔',
    'افتح قائمة الأدوات في مشغّل الهاتف لإضافة أداة الصلاة.',
  ),
  'Add the Prayer widget from your launcher’s Widgets menu.': (
    'لانچر کے ویجٹس مینو سے نماز کا ویجٹ شامل کریں۔',
    'أضف أداة الصلاة من قائمة الأدوات في مشغّل الهاتف.',
  ),
  'Saved worship records could not be loaded. Your records have not been replaced.': (
    'عبادت کا محفوظ ریکارڈ کھل نہیں سکا۔ آپ کے ریکارڈ کو تبدیل نہیں کیا گیا۔',
    'تعذّر تحميل سجلات العبادة المحفوظة. لم تُستبدل سجلاتك.',
  ),
  'Saved, but reminders could not be scheduled. Retry saving after checking permissions.': (
    'محفوظ ہو گیا، مگر یاددہانیاں مقرر نہیں ہو سکیں۔ اجازتیں دیکھ کر دوبارہ محفوظ کریں۔',
    'تم الحفظ، لكن تعذّرت جدولة التنبيهات. تحقّق من الأذونات ثم أعد الحفظ.',
  ),
  'Choose a location in Namaz & Azan first.': (
    'پہلے نماز اور اذان میں اپنا مقام منتخب کریں۔',
    'اختر موقعًا في الصلاة والأذان أولًا.',
  ),
  'Unable to prepare widget.': (
    'ویجٹ تیار نہیں ہو سکا۔',
    'تعذّر تجهيز الأداة.',
  ),
  'Choose the first fasting day.': (
    'پہلے روزے کی تاریخ منتخب کریں۔',
    'اختر تاريخ أول يوم صيام.',
  ),
  'Choose your prayer location first.': (
    'پہلے نماز کے لیے اپنا مقام منتخب کریں۔',
    'اختر موقع الصلاة أولًا.',
  ),
  'Choose your city and time zone in Namaz & Azan first.': (
    'پہلے نماز اور اذان میں اپنا شہر اور ٹائم زون منتخب کریں۔',
    'اختر مدينتك ومنطقتك الزمنية في الصلاة والأذان أولًا.',
  ),
  'Future prayers cannot be recorded.': (
    'آنے والی نمازوں کا ریکارڈ درج نہیں کیا جا سکتا۔',
    'لا يمكن تسجيل صلوات مستقبلية.',
  ),
  'Invalid prayer record.': (
    'نماز کا ریکارڈ درست نہیں۔',
    'سجل الصلاة غير صالح.',
  ),
  'This change would remove an already completed Qaza. Adjust the starting balance first.': (
    'اس تبدیلی سے ادا شدہ قضا کا حساب کم ہو گا۔ پہلے ابتدائی حساب درست کریں۔',
    'سيزيل هذا التغيير قضاءً سجّلته بالفعل. عدّل الرصيد الأولي أولًا.',
  ),
  'Use a count from 0 to 1,000,000.': (
    'تعداد 0 سے 1,000,000 کے درمیان درج کریں۔',
    'أدخل عددًا بين 0 و1,000,000.',
  ),
  'Starting balance cannot be less than completed Qaza.': (
    'ابتدائی حساب ادا شدہ قضا سے کم نہیں ہو سکتا۔',
    'لا يمكن أن يكون الرصيد الأولي أقل من القضاء المنجَز.',
  ),
  'Invalid Qaza adjustment.': (
    'قضا کے حساب کی تبدیلی درست نہیں۔',
    'تعديل رصيد القضاء غير صالح.',
  ),
  'No Qaza is available for this action.': (
    'اس عمل کے لیے قضا کا حساب دستیاب نہیں۔',
    'لا يوجد رصيد قضاء لهذا الإجراء.',
  ),
  'Choose a valid date.': ('درست تاریخ منتخب کریں۔', 'اختر تاريخًا صحيحًا.'),
  'Invalid Ramadan plan.': (
    'رمضان کا منصوبہ درست نہیں۔',
    'خطة رمضان غير صالحة.',
  ),
  'Invalid Masjid timetable.': (
    'مسجد کا اوقات نامہ درست نہیں۔',
    'جدول المسجد غير صالح.',
  ),
  'Timetable end precedes start.': (
    'اختتامی تاریخ ابتدائی تاریخ سے پہلے ہے۔',
    'تاريخ نهاية الجدول يسبق بدايته.',
  ),
  'Invalid Jamaat time.': ('جماعت کا وقت درست نہیں۔', 'وقت الجماعة غير صالح.'),
  'Confirm your timetable before enabling reminders.': (
    'یاددہانیاں فعال کرنے سے پہلے اوقات کی تصدیق کریں۔',
    'أكّد الجدول قبل تفعيل التنبيهات.',
  ),
};
