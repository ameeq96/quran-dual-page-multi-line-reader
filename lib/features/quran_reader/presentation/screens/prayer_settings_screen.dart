import '../../../../app/app_theme.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../app/prayer_translations.dart';
import '../../../../app/reader_localization.dart';
import '../../../../core/prayer/prayer_calculator.dart';
import '../../../../core/prayer/prayer_models.dart';
import '../../../../core/prayer/prayer_reminder_service.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final _service = PrayerReminderService.instance;
  Timer? _clock;
  double? _volumeDraft;

  @override
  void initState() {
    super.initState();
    unawaited(_service.initialize(baseUrl: widget.baseUrl));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _t(String text, {Map<String, Object?> args = const {}}) =>
      prayerText(context, text, args: args);

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _report(Future<bool> operation) async {
    final success = await operation;
    if (!success && mounted) {
      _message(
        _service.error ??
            _service.backgroundError ??
            _t('Unable to save. Please try again.'),
      );
    }
  }

  Future<void> _save(PrayerSettings settings) =>
      _report(_service.updateSettings(settings));

  String _time(DateTime? value) {
    if (value == null) return _t('Not available');
    final wall = tz.TZDateTime.from(
      value,
      PrayerCalculator.zone(_service.settings),
    );
    return TimeOfDay.fromDateTime(wall).format(context);
  }

  String _eventLabel(PrayerEvent event) {
    if (event.customLabel != null) return event.customLabel!;
    final prayer = _t(event.prayer?.label ?? 'Prayer reminder');
    return switch (event.kind) {
      'before' => _t('Before {prayer}', args: {'prayer': prayer}),
      'jamaat' => _t('{prayer} jamaat', args: {'prayer': prayer}),
      _ => prayer,
    };
  }

  String _countdown(DateTime value) {
    final remaining = value.difference(DateTime.now().toUtc());
    final seconds = remaining.isNegative ? 0 : remaining.inSeconds;
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_service, ReaderLocalization.instance]),
      builder: (context, _) {
        final theme = Theme.of(context);
        return Directionality(
          textDirection: ReaderLocalization.instance.textDirection,
          child: Scaffold(
            appBar: AppBar(
              title: Text(_t('Namaz & Azan')),
              actions: [
                IconButton(
                  tooltip: _t('Refresh'),
                  onPressed: _service.busy ? null : _service.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            body: !_service.loaded
                ? const Center(child: CircularProgressIndicator())
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 840),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          _masterCard(theme),
                          if (_service.busy || _service.backgroundBusy)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          if (!_service.supported)
                            _notice(
                              _t(
                                'This platform does not support prayer alerts.',
                              ),
                            ),
                          if (_service.error != null)
                            _notice(_service.error!, error: true),
                          _locationCard(),
                          if (_service.settings.location != null)
                            _timesCard(theme),
                          _audioCard(),
                          _customCard(),
                          if (_service.isAndroid) _permissionsCard(),
                          if (_service.isWeb) _backgroundCard(),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _masterCard(ThemeData theme) {
    final settings = _service.settings;
    final decor = AppDecor.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: decor.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: decor.gold.withValues(alpha: .22)),
        boxShadow: decor.floatShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: decor.gold.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: decor.gold.withValues(alpha: .3)),
            ),
            child: Icon(Icons.mosque_outlined, color: decor.gold, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            _t('Prayer times, your way'),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: decor.onHero,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Choose your location, check the times, then turn reminders on.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: decor.onHero.withValues(alpha: .82),
            ),
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            activeThumbColor: decor.onGold,
            activeTrackColor: decor.gold,
            title: Text(
              _t('Prayer reminders'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: decor.onHero,
              ),
            ),
            subtitle: Text(
              _t(settings.enabled ? 'Reminders are on' : 'Reminders are off'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: decor.onHero.withValues(alpha: .76),
              ),
            ),
            value: settings.enabled,
            onChanged: _service.busy || !_service.supported
                ? null
                : (value) {
                    if (value && settings.location == null) {
                      _message(_t('Choose a location first.'));
                      return;
                    }
                    _report(_service.setEnabled(value));
                  },
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .7)),
        boxShadow: AppDecor.of(context).cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_t(title), style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    ),
  );

  Widget _notice(String text, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? colors.errorContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? colors.onErrorContainer : colors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    String Function(String) text,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label:$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: _t(label)),
        items: [
          for (final item in values)
            DropdownMenuItem(
              value: item,
              child: Text(text(item), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _service.busy
            ? null
            : (value) {
                if (value != null) onChanged(value);
              },
      ),
    );
  }

  Widget _locationCard() {
    final settings = _service.settings;
    final place = settings.location;
    final index = prayerCities.indexWhere(
      (city) =>
          place != null &&
          city.latitude == place.latitude &&
          city.longitude == place.longitude &&
          city.zone == place.zone,
    );
    return _section('Location & calculation', Icons.place_outlined, [
      DropdownButtonFormField<int>(
        key: ValueKey('city:${place?.label}:$index'),
        initialValue: index >= 0 ? index : (place == null ? null : -1),
        isExpanded: true,
        decoration: InputDecoration(
          labelText: _t('City'),
          hintText: _t('Choose a city'),
        ),
        items: [
          if (place != null && index < 0)
            DropdownMenuItem(
              value: -1,
              child: Text(_t(place.label), overflow: TextOverflow.ellipsis),
            ),
          for (var i = 0; i < prayerCities.length; i++)
            DropdownMenuItem(value: i, child: Text(_t(prayerCities[i].label))),
        ],
        onChanged: _service.busy
            ? null
            : (value) {
                if (value != null && value >= 0) {
                  _save(
                    _service.settings.copyWith(location: prayerCities[value]),
                  );
                }
              },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: _service.busy ? null : _manualLocation,
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: Text(_t('Manual location')),
          ),
          OutlinedButton.icon(
            onPressed: _service.busy || !_service.supported
                ? null
                : () => _report(_service.useLocation()),
            icon: const Icon(Icons.my_location_rounded),
            label: Text(_t('Use current location')),
          ),
        ],
      ),
      _note(_t('Location is requested only when you tap this button.')),
      if (place != null) ...[
        Directionality(
          textDirection: TextDirection.ltr,
          child: _note(
            '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)} · ${place.zone}',
          ),
        ),
      ],
      const SizedBox(height: 12),
      _dropdown(
        'Calculation method',
        settings.method,
        prayerMethods,
        _methodLabel,
        (value) => _save(_service.settings.copyWith(method: value)),
      ),
      _dropdown(
        'Asr calculation',
        settings.madhab,
        ['hanafi', 'shafi'],
        (value) => _t(value == 'hanafi' ? 'Hanafi' : 'Shafi / standard'),
        (value) => _save(_service.settings.copyWith(madhab: value)),
      ),
      _dropdown(
        'High latitude rule',
        settings.highLatitudeRule,
        prayerHighLatitudeRules,
        _highLatitudeLabel,
        (value) => _save(_service.settings.copyWith(highLatitudeRule: value)),
      ),
      _note(
        _t(
          'Calculated times may differ from your local mosque. Check its timetable and use manual times or offsets when needed.',
        ),
      ),
      if (settings.method == 'ummAlQura')
        _note(
          _t(
            'For Umm al-Qura, check the local Ramadan Isha timetable and adjust it manually if needed.',
          ),
        ),
    ]);
  }

  String _methodLabel(String value) => _t(switch (value) {
    'karachi' => 'Karachi (Pakistan)',
    'ummAlQura' => 'Umm al-Qura (Makkah)',
    'egyptian' => 'Egyptian General Authority',
    'northAmerica' => 'North America (ISNA)',
    'dubai' => 'Dubai',
    _ => 'Muslim World League',
  });

  String _highLatitudeLabel(String value) => _t(switch (value) {
    'middleOfNight' => 'Middle of the night',
    'seventhOfNight' => 'Seventh of the night',
    'twilightAngle' => 'Twilight angle',
    _ => 'Recommended',
  });

  Future<void> _manualLocation() async {
    final location = await showDialog<PrayerLocation>(
      context: context,
      builder: (_) => _LocationDialog(initial: _service.settings.location),
    );
    if (location != null && mounted) {
      await _save(_service.settings.copyWith(location: location));
    }
  }

  Widget _timesCard(ThemeData theme) {
    final next = _service.nextEvent;
    final settings = _service.settings;
    final now = tz.TZDateTime.from(
      DateTime.now(),
      PrayerCalculator.zone(settings),
    );
    return _section('Today’s prayer times', Icons.schedule_rounded, [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('Next reminder'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              next == null
                  ? _t('No upcoming reminder')
                  : '${_eventLabel(next)} · ${_time(next.atUtc)}',
              style: theme.textTheme.titleLarge,
            ),
            if (next != null) ...[
              const SizedBox(height: 6),
              Text(
                _t('In {time}', args: {'time': _countdown(next.atUtc)}),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
      Text(
        MaterialLocalizations.of(context).formatFullDate(now),
        style: theme.textTheme.bodyMedium,
      ),
      _note(_t('Times use {zone}.', args: {'zone': settings.location!.zone})),
      const SizedBox(height: 8),
      for (final id in PrayerId.values) _prayerRow(id),
    ]);
  }

  Widget _prayerRow(PrayerId id) {
    final theme = Theme.of(context);
    final rule = _service.settings.rule(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_t(id.label), style: theme.textTheme.titleMedium),
              ),
              Text(
                _time(_service.todayTimes[id]),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: rule.enabled,
                onChanged: _service.busy
                    ? null
                    : (value) => _saveRule(id, rule.copyWith(enabled: value)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _sourceBadge(
                _t(rule.manualMinutes == null ? 'Automatic' : 'Manual'),
              ),
              if (rule.offsetMinutes != 0)
                _sourceBadge(
                  _t(
                    '{minutes} min',
                    args: {
                      'minutes': rule.offsetMinutes > 0
                          ? '+${rule.offsetMinutes}'
                          : rule.offsetMinutes,
                    },
                  ),
                ),
              if (rule.jamaatMinutes != null)
                _sourceBadge(
                  '${_t('Jamaat time')}: ${_clockLabel(context, rule.jamaatMinutes!)}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('${id.name}:${rule.sound}'),
                  initialValue: rule.sound,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _t('Sound'),
                    isDense: true,
                  ),
                  items: [
                    for (final sound in ['azan', 'tone', 'silent'])
                      DropdownMenuItem(
                        value: sound,
                        child: Text(_soundLabel(context, sound)),
                      ),
                  ],
                  onChanged: _service.busy
                      ? null
                      : (value) {
                          if (value != null)
                            _saveRule(id, rule.copyWith(sound: value));
                        },
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _service.busy ? null : () => _editPrayer(id),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(_t('Edit')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sourceBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: Theme.of(context).textTheme.labelSmall),
  );

  Future<void> _saveRule(PrayerId id, PrayerRule rule) => _save(
    _service.settings.copyWith(
      prayers: {..._service.settings.prayers, id: rule},
    ),
  );

  Future<void> _editPrayer(PrayerId id) async {
    final rule = await showDialog<PrayerRule>(
      context: context,
      builder: (_) => _PrayerRuleDialog(
        id: id,
        initial: _service.settings.rule(id),
        calculated: _service.todayTimes[id] == null
            ? null
            : tz.TZDateTime.from(
                _service.todayTimes[id]!.subtract(
                  Duration(minutes: _service.settings.rule(id).offsetMinutes),
                ),
                PrayerCalculator.zone(_service.settings),
              ),
      ),
    );
    if (rule != null && mounted) await _saveRule(id, rule);
  }

  Widget _audioCard() {
    final settings = _service.settings;
    return _section('Alerts & audio', Icons.volume_up_outlined, [
      _dropdown(
        'Advance reminder',
        settings.preReminderMinutes.toString(),
        [for (final minutes in prayerLeadMinutes) '$minutes'],
        (value) => value == '0'
            ? _t('No advance reminder')
            : _t('{minutes} minutes before', args: {'minutes': value}),
        (value) => _save(
          _service.settings.copyWith(preReminderMinutes: int.parse(value)),
        ),
      ),
      _note(
        _t(
          'An advance reminder uses a short tone; Azan stays at the prayer time.',
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: Text(_t('Azan volume'))),
          Text('${((_volumeDraft ?? settings.volume) * 100).round()}%'),
        ],
      ),
      Slider(
        value: _volumeDraft ?? settings.volume,
        divisions: 20,
        label: '${((_volumeDraft ?? settings.volume) * 100).round()}%',
        onChanged: _service.busy
            ? null
            : (value) => setState(() => _volumeDraft = value),
        onChangeEnd: _service.busy
            ? null
            : (value) async {
                await _save(_service.settings.copyWith(volume: value));
                if (mounted) setState(() => _volumeDraft = null);
              },
      ),
      if (_service.isAndroid) ...[
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(_t('Respect silent mode')),
          value: settings.respectSilent,
          onChanged: _service.busy
              ? null
              : (value) =>
                    _save(_service.settings.copyWith(respectSilent: value)),
        ),
        _note(_t('Silent mode and Do Not Disturb may silence alerts.')),
      ],
      if (_service.isWeb) ...[
        if (!_service.audioEnabled)
          FilledButton.icon(
            onPressed: _service.busy
                ? null
                : () => _report(_service.enableAudio()),
            icon: const Icon(Icons.volume_up_rounded),
            label: Text(_t('Enable Azan audio')),
          )
        else
          _note(_t('Audio enabled for this browser session')),
        _note(
          _t(
            'Keep this page open for automatic Azan. Your browser may pause background tabs.',
          ),
        ),
        if (!_service.notificationsAllowed)
          OutlinedButton.icon(
            onPressed: _service.busy
                ? null
                : () => _report(_service.requestNotifications()),
            icon: const Icon(Icons.notifications_outlined),
            label: Text(_t('Allow notifications')),
          ),
      ],
      const SizedBox(height: 12),
      Text(_t('Listen to Azan'), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: _service.busy || !_service.supported
                ? null
                : () => _report(_service.preview()),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_t('General Azan')),
          ),
          OutlinedButton.icon(
            onPressed: _service.busy || !_service.supported
                ? null
                : () => _report(_service.preview(fajr: true)),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(_t('Fajr Azan')),
          ),
          if (_service.playing)
            FilledButton.tonalIcon(
              onPressed: _service.stop,
              icon: const Icon(Icons.stop_rounded),
              label: Text(_t('Stop')),
            ),
        ],
      ),
      TextButton.icon(
        onPressed: _credits,
        icon: const Icon(Icons.info_outline_rounded, size: 18),
        label: Text(_t('Recording credits')),
      ),
    ]);
  }

  Widget _customCard() {
    final reminders = _service.settings.customReminders;
    return _section('Custom reminders', Icons.add_alarm_rounded, [
      _note(
        _t(
          'Add up to 10 daily or weekly reminders in your selected time zone.',
        ),
      ),
      if (reminders.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(_t('No custom reminders yet')),
        ),
      for (final item in reminders)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Switch.adaptive(
                    value: item.enabled,
                    onChanged: _service.busy
                        ? null
                        : (value) => _saveCustom(item.copyWith(enabled: value)),
                  ),
                ],
              ),
              Text(
                '${_clockLabel(context, item.minutes)} · ${_soundLabel(context, item.sound)}',
              ),
              Row(
                children: [
                  Expanded(child: _note(_daysLabel(context, item.weekdays))),
                  IconButton(
                    tooltip: _t('Edit'),
                    onPressed: _service.busy ? null : () => _editCustom(item),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: _t('Delete'),
                    onPressed: _service.busy ? null : () => _deleteCustom(item),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      OutlinedButton.icon(
        onPressed: _service.busy || reminders.length >= 10
            ? null
            : () => _editCustom(null),
        icon: const Icon(Icons.add_rounded),
        label: Text('${_t('Add reminder')} (${reminders.length}/10)'),
      ),
    ]);
  }

  Future<void> _saveCustom(CustomPrayerReminder item) {
    final reminders = [..._service.settings.customReminders];
    final index = reminders.indexWhere((existing) => existing.id == item.id);
    if (index < 0) {
      if (reminders.length >= 10) return Future.value();
      reminders.add(item);
    } else {
      reminders[index] = item;
    }
    return _save(_service.settings.copyWith(customReminders: reminders));
  }

  Future<void> _editCustom(CustomPrayerReminder? initial) async {
    final result = await showDialog<CustomPrayerReminder>(
      context: context,
      builder: (_) => _CustomReminderDialog(initial: initial),
    );
    if (result != null && mounted) await _saveCustom(result);
  }

  Future<void> _deleteCustom(CustomPrayerReminder item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Delete reminder?')),
        content: Text(
          _t(
            'Remove “{name}” from your reminders? You can add it again.',
            args: {'name': item.label},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _save(
        _service.settings.copyWith(
          customReminders: [
            for (final reminder in _service.settings.customReminders)
              if (reminder.id != item.id) reminder,
          ],
        ),
      );
    }
  }

  Widget _permissionsCard() => _section(
    'Device permissions',
    Icons.verified_user_outlined,
    [
      _permissionStatus('Notifications', _service.notificationsAllowed),
      _permissionStatus('Exact alarms', _service.exactAlarmAllowed),
      _note(
        _t(
          'For timely Android reminders, allow notifications and exact alarms. Battery restrictions and device settings can affect delivery.',
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (!_service.notificationsAllowed)
            OutlinedButton(
              onPressed: _service.busy
                  ? null
                  : () => _report(_service.requestNotifications()),
              child: Text(_t('Allow notifications')),
            ),
          if (!_service.exactAlarmAllowed)
            OutlinedButton(
              onPressed: _service.busy
                  ? null
                  : () => _report(_service.requestExactAlarm()),
              child: Text(_t('Allow exact alarms')),
            ),
          TextButton(
            onPressed: _service.busy ? null : _service.refresh,
            child: Text(_t('Check permissions')),
          ),
        ],
      ),
    ],
  );

  Widget _permissionStatus(String label, bool allowed) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(
          allowed
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(_t(label))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _t(allowed ? 'Allowed' : 'Permission needed'),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );

  Widget _backgroundCard() => _section(
    'Closed-tab notifications',
    Icons.notifications_outlined,
    [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(_t('Optional background notifications')),
        value: _service.backgroundEnabled,
        onChanged:
            _service.busy ||
                _service.backgroundBusy ||
                (!_service.backgroundEnabled &&
                    (!_service.backgroundSupported ||
                        !_service.backgroundConfigured))
            ? null
            : _toggleBackground,
      ),
      _note(
        _t(
          'A closed browser cannot play the full Azan automatically. Push notifications need internet and may arrive late.',
        ),
      ),
      if (!_service.backgroundSupported)
        _note(_t('Background notifications are not supported in this browser.'))
      else if (!_service.backgroundConfigured)
        _note(
          _t(
            'This server has not enabled background prayer notifications yet.',
          ),
        ),
      if (_service.backgroundError != null)
        _notice(_service.backgroundError!, error: true),
    ],
  );

  Future<void> _toggleBackground(bool enabled) async {
    if (!enabled) {
      await _report(_service.setBackgroundEnabled(false));
      return;
    }
    final settings = _service.settings;
    final location = settings.location;
    if (location == null) {
      _message(_t('Choose a location first.'));
      return;
    }
    if (!settings.enabled) {
      _message(_t('Turn prayer reminders on first.'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(_t('Enable background notifications?')),
        content: Text(
          _t(
            'Your selected location ({location}), coordinates, time zone ({zone}), prayer settings and browser push subscription will be sent to your Quran server ({server}) to schedule notifications. Changes to these settings will also be sent while this is enabled. You can turn it off here.',
            args: {
              'location': _t(location.label),
              'zone': location.zone,
              'server':
                  Uri.tryParse(_service.baseUrl)?.host ?? _service.baseUrl,
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Allow background notifications')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _report(_service.setBackgroundEnabled(true, locationConsent: true));
    }
  }

  Future<void> _credits() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/prayer_audio/ATTRIBUTION.json',
      );
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final recordings = data['recordings'] as List<dynamic>;
      final text = [
        for (final recording in recordings) ...[
          recording['attribution'] as String,
          recording['sourceUrl'] as String,
          recording['licenseUrl'] as String,
          recording['modifications'] as String,
          '',
        ],
        data['licenseNotice'] as String,
      ].join('\n\n');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(_t('Recording credits')),
          content: Directionality(
            textDirection: TextDirection.ltr,
            child: SelectableText(text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Close')),
            ),
          ],
        ),
      );
    } catch (_) {
      _message(_t('Recording credits could not be loaded.'));
    }
  }
}

String _clockLabel(BuildContext context, int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

String _soundLabel(BuildContext context, String sound) =>
    prayerText(context, switch (sound) {
      'azan' => 'Azan',
      'tone' => 'Tone',
      _ => 'Silent',
    });

const _weekdayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _daysLabel(BuildContext context, List<int> weekdays) =>
    weekdays.length == 7
    ? prayerText(context, 'Every day')
    : ([...weekdays]..sort())
          .map((day) => prayerText(context, _weekdayKeys[day - 1]))
          .join(' · ');

class _LocationDialog extends StatefulWidget {
  const _LocationDialog({this.initial});
  final PrayerLocation? initial;
  @override
  State<_LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends State<_LocationDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.label ?? '');
  late final _latitude = TextEditingController(
    text: widget.initial?.latitude.toString() ?? '',
  );
  late final _longitude = TextEditingController(
    text: widget.initial?.longitude.toString() ?? '',
  );
  late final _zone = TextEditingController(text: widget.initial?.zone ?? '');

  @override
  void dispose() {
    _name.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _zone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String text) => prayerText(context, text);
    return AlertDialog(
      scrollable: true,
      title: Text(t('Manual location')),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: InputDecoration(labelText: t('Location name')),
                validator: (value) => _validName(value)
                    ? null
                    : t('Enter a name (1–80 characters).'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _latitude,
                textDirection: TextDirection.ltr,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: t('Latitude')),
                validator: (value) => _validCoordinate(value, 89)
                    ? null
                    : t('Enter latitude from -89 to 89.'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _longitude,
                textDirection: TextDirection.ltr,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: t('Longitude')),
                validator: (value) => _validCoordinate(value, 180)
                    ? null
                    : t('Enter longitude from -180 to 180.'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _zone,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: t('IANA time zone'),
                  helperText: t('For example: Asia/Karachi'),
                ),
                validator: (value) {
                  try {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty ||
                        name.length > 100 ||
                        !RegExp(r'^[A-Za-z0-9_+./-]+$').hasMatch(name)) {
                      return t('Enter a valid IANA time zone.');
                    }
                    PrayerCalculator.initialize();
                    tz.getLocation(name);
                    return null;
                  } catch (_) {
                    return t('Enter a valid IANA time zone.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              PrayerLocation(
                label: _name.text.trim(),
                latitude: double.parse(_latitude.text.trim()),
                longitude: double.parse(_longitude.text.trim()),
                zone: _zone.text.trim(),
              ),
            );
          },
          child: Text(t('Save')),
        ),
      ],
    );
  }

  bool _validCoordinate(String? value, double limit) {
    final number = double.tryParse(value?.trim() ?? '');
    return number != null && number.isFinite && number.abs() <= limit;
  }
}

bool _validName(String? value) =>
    value != null &&
    value.trim().isNotEmpty &&
    value.length <= 80 &&
    !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);

class _PrayerRuleDialog extends StatefulWidget {
  const _PrayerRuleDialog({
    required this.id,
    required this.initial,
    this.calculated,
  });
  final PrayerId id;
  final PrayerRule initial;
  final DateTime? calculated;
  @override
  State<_PrayerRuleDialog> createState() => _PrayerRuleDialogState();
}

class _PrayerRuleDialogState extends State<_PrayerRuleDialog> {
  late bool _manual = widget.initial.manualMinutes != null;
  late int _minutes =
      widget.initial.manualMinutes ??
      (widget.calculated == null
          ? 720
          : widget.calculated!.hour * 60 + widget.calculated!.minute);
  late int _offset = widget.initial.offsetMinutes;
  late bool _jamaat = widget.initial.jamaatMinutes != null;
  late int _jamaatMinutes =
      widget.initial.jamaatMinutes ?? (_minutes + 15) % 1440;

  Future<void> _pick(bool jamaat) async {
    final minutes = jamaat ? _jamaatMinutes : _minutes;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (result != null && mounted)
      setState(() {
        if (jamaat) {
          _jamaatMinutes = result.hour * 60 + result.minute;
        } else {
          _minutes = result.hour * 60 + result.minute;
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    String t(String text) => prayerText(context, text);
    return AlertDialog(
      scrollable: true,
      title: Text(t(widget.id.label)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<bool>(
              initialValue: _manual,
              isExpanded: true,
              decoration: InputDecoration(labelText: t('Time source')),
              items: [
                DropdownMenuItem(value: false, child: Text(t('Automatic'))),
                DropdownMenuItem(value: true, child: Text(t('Manual'))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _manual = value);
              },
            ),
            if (_manual) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _pick(false),
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  '${t('Prayer time')}: ${_clockLabel(context, _minutes)}',
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              t('Minute adjustment'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              prayerText(
                context,
                '{minutes} min',
                args: {'minutes': _offset > 0 ? '+$_offset' : _offset},
              ),
            ),
            Slider(
              value: _offset.toDouble(),
              min: -60,
              max: 60,
              divisions: 120,
              label: '$_offset',
              onChanged: (value) => setState(() => _offset = value.round()),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t('Jamaat reminder')),
              value: _jamaat,
              onChanged: (value) => setState(() => _jamaat = value),
            ),
            if (_jamaat)
              OutlinedButton.icon(
                onPressed: () => _pick(true),
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  '${t('Jamaat time')}: ${_clockLabel(context, _jamaatMinutes)}',
                ),
              ),
            const SizedBox(height: 10),
            Text(
              t(
                'Jamaat uses a short tone. For Isha, a jamaat time before noon belongs to the following day.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.initial.copyWith(
              offsetMinutes: _offset,
              manualMinutes: _manual ? _minutes : null,
              clearManual: !_manual,
              jamaatMinutes: _jamaat ? _jamaatMinutes : null,
              clearJamaat: !_jamaat,
            ),
          ),
          child: Text(t('Save')),
        ),
      ],
    );
  }
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog({this.initial});
  final CustomPrayerReminder? initial;
  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.label ?? '');
  late int _minutes = widget.initial?.minutes ?? 480;
  late final _days = {
    ...?widget.initial?.weekdays,
    if (widget.initial == null) ...[1, 2, 3, 4, 5, 6, 7],
  };
  late String _sound = widget.initial?.sound ?? 'tone';
  bool _dayError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60),
    );
    if (result != null && mounted)
      setState(() => _minutes = result.hour * 60 + result.minute);
  }

  @override
  Widget build(BuildContext context) {
    String t(String text) => prayerText(context, text);
    return AlertDialog(
      scrollable: true,
      title: Text(t(widget.initial == null ? 'Add reminder' : 'Edit')),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 80,
                decoration: InputDecoration(labelText: t('Reminder name')),
                validator: (value) => _validName(value)
                    ? null
                    : t('Enter a name (1–80 characters).'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  '${t('Reminder time')}: ${_clockLabel(context, _minutes)}',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('Repeat on'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(t(_weekdayKeys[day - 1])),
                      selected: _days.contains(day),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _days.add(day);
                        } else {
                          _days.remove(day);
                        }
                        _dayError = _days.isEmpty;
                      }),
                    ),
                ],
              ),
              if (_dayError)
                Text(
                  t('Select at least one day.'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _sound,
                isExpanded: true,
                decoration: InputDecoration(labelText: t('Sound')),
                items: [
                  for (final sound in ['tone', 'silent'])
                    DropdownMenuItem(
                      value: sound,
                      child: Text(_soundLabel(context, sound)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _sound = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            final valid = _form.currentState!.validate();
            setState(() => _dayError = _days.isEmpty);
            if (!valid || _days.isEmpty) return;
            Navigator.pop(
              context,
              CustomPrayerReminder(
                id: widget.initial?.id ?? PrayerReminderService.newCustomId(),
                label: _name.text.trim(),
                minutes: _minutes,
                weekdays: _days.toList()..sort(),
                enabled: widget.initial?.enabled ?? true,
                sound: _sound,
              ),
            );
          },
          child: Text(t('Save')),
        ),
      ],
    );
  }
}
