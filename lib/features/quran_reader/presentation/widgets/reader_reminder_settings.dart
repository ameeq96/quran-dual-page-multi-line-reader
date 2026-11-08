import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/services/reader_reminder_service.dart';
import 'reader_browser_reminder_settings.dart';

class ReaderReminderSettings extends StatefulWidget {
  const ReaderReminderSettings({super.key, this.baseUrl});

  final String? baseUrl;

  @override
  State<ReaderReminderSettings> createState() => _ReaderReminderSettingsState();
}

class _ReaderReminderSettingsState extends State<ReaderReminderSettings> {
  final _service = ReaderReminderService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_service.initialize());
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _service.hour, minute: _service.minute),
    );
    if (selected != null && mounted) {
      await _service.setTime(hour: selected.hour, minute: selected.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final theme = Theme.of(context);
        final time = TimeOfDay(
          hour: _service.hour,
          minute: _service.minute,
        ).format(context);
        final error = _service.errorMessage;
        final String status;
        if (!_service.supported) {
          status = tr(
            context,
            'Daily notifications are available in the Android and iOS app. In Chrome, use the revision queue while the app is open.',
          );
        } else if (error != null) {
          status = tr(context, error);
        } else if (_service.enabled && _service.usesInAppReminders) {
          status = tr(
            context,
            'Only while this app is open. Daily around {time}.',
            args: {'time': time},
          );
        } else if (_service.enabled && _service.scheduled) {
          status = tr(
            context,
            'Daily around {time} ({zone}).',
            args: {'time': time, 'zone': _service.timeZoneName ?? ''},
          );
        } else if (_service.enabled) {
          status = tr(context, 'Reminder is not scheduled. Try again.');
        } else {
          status = tr(context, 'Off. Your reminder stays on this device.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _service.supported && _service.enabled,
              onChanged: _service.busy || !_service.supported
                  ? null
                  : _service.setEnabled,
              title: Text(tr(context, 'Daily reminder')),
              subtitle: Text(
                tr(context, 'A gentle daily reminder to read and revise.'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(tr(context, time), style: theme.textTheme.titleMedium),
                OutlinedButton.icon(
                  onPressed: _service.busy || !_service.supported
                      ? null
                      : _chooseTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(tr(context, 'Change time')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_service.busy)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(tr(context, 'Updating reminder…'))),
                ],
              )
            else
              Text(
                tr(context, status),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: error != null && _service.supported
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (_service.usesInAppReminders) ...[
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  widget.baseUrl == null
                      ? 'Chrome cannot remind you after this app is closed.'
                      : 'This reminder appears while the app is open. Enable background notifications separately.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (!_service.usesInAppReminders &&
                _service.supported &&
                _service.scheduled &&
                error == null) ...[
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  'Delivery may be delayed by battery or notification settings.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_service.supported && error != null)
              TextButton.icon(
                onPressed: _service.busy ? null : _service.refreshSchedule,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr(context, 'Check again')),
              ),
            if (widget.baseUrl != null)
              ReaderBrowserReminderSettings(baseUrl: widget.baseUrl!,
                hour: _service.hour, minute: _service.minute),
          ],
        );
      },
    );
  }
}
