import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/services/reader_browser_reminder_service.dart';

class ReaderBrowserReminderSettings extends StatefulWidget {
  const ReaderBrowserReminderSettings({super.key, required this.baseUrl,
    required this.hour, required this.minute});
  final String baseUrl;
  final int hour;
  final int minute;
  @override
  State<ReaderBrowserReminderSettings> createState() => _ReaderBrowserReminderSettingsState();
}

class _ReaderBrowserReminderSettingsState extends State<ReaderBrowserReminderSettings> {
  ReaderBrowserReminderService? _service;
  @override
  void initState() {
    super.initState(); _bind();
    ReaderLocalization.instance.addListener(_updateLanguage);
  }

  void _updateLanguage() {
    unawaited(_service?.updateTime(hour: widget.hour, minute: widget.minute,
      language: ReaderLocalization.instance.language.name));
  }

  void _bind() {
    _service?.removeListener(_refresh);
    try {
      _service = ReaderBrowserReminderService.forBaseUrl(widget.baseUrl);
      _service!.addListener(_refresh);
      unawaited(_service!.initialize());
    } on FormatException { _service = null; }
  }

  void _refresh() { if (mounted) setState(() {}); }
  @override
  void didUpdateWidget(covariant ReaderBrowserReminderSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baseUrl != widget.baseUrl) { _bind(); return; }
    if (oldWidget.hour != widget.hour || oldWidget.minute != widget.minute) {
      unawaited(_service?.updateTime(hour: widget.hour, minute: widget.minute,
        language: ReaderLocalization.instance.language.name));
    }
  }

  @override
  void dispose() {
    ReaderLocalization.instance.removeListener(_updateLanguage);
    _service?.removeListener(_refresh); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = _service;
    if (service == null || !service.supported) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 28),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(tr(context, 'Background notifications')),
        subtitle: Text(tr(context, 'Use the same reminder time when this tab is closed.')),
        value: service.enabled,
        onChanged: service.busy || (!service.enabled && !service.configured) ? null : (value) => service.setEnabled(value,
          hour: widget.hour, minute: widget.minute, language: ReaderLocalization.instance.language.name),
      ),
      Text(tr(context, service.error ?? (service.configured
          ? 'Requires notification permission and an internet connection. Chrome must be allowed to run in the background.'
          : 'Background reminders are not configured on this server.')),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: service.error == null ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.error)),
      if (service.busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      if (!service.busy && (service.error != null || !service.configured))
        TextButton.icon(onPressed: service.refresh, icon: const Icon(Icons.refresh_rounded),
          label: Text(tr(context, 'Check again'))),
    ]);
  }
}
