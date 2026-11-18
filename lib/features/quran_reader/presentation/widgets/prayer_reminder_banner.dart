import 'package:flutter/material.dart';

import '../../../../app/prayer_translations.dart';
import '../../../../app/reader_localization.dart';
import '../../../../core/prayer/prayer_models.dart';
import '../../../../core/prayer/prayer_reminder_service.dart';

class PrayerReminderBanner extends StatelessWidget {
  const PrayerReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PrayerReminderService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([service, ReaderLocalization.instance]),
      builder: (context, _) {
        if (service.currentEvent == null && !service.playing) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Directionality(
          textDirection: ReaderLocalization.instance.textDirection,
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Semantics(
                    liveRegion: true,
                    child: Material(
                      elevation: 8,
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        child: Row(
                          children: [
                            Icon(
                              service.playing
                                  ? Icons.volume_up_rounded
                                  : Icons.notifications_active_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _label(context, service.currentEvent),
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  Wrap(
                                    spacing: 4,
                                    children: [
                                      if (service.playing)
                                        TextButton.icon(
                                          onPressed: service.stop,
                                          icon: const Icon(
                                            Icons.stop_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            prayerText(context, 'Stop'),
                                          ),
                                        ),
                                      TextButton(
                                        onPressed: () {
                                          service.stop();
                                          service.dismissCurrentEvent();
                                        },
                                        child: Text(
                                          prayerText(context, 'Dismiss'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _label(BuildContext context, PrayerEvent? event) {
    if (event == null) return prayerText(context, 'Azan preview');
    if (event.customLabel != null) return event.customLabel!;
    final prayer = prayerText(
      context,
      event.prayer?.label ?? 'Prayer reminder',
    );
    return switch (event.kind) {
      'before' => prayerText(
        context,
        'Before {prayer}',
        args: {'prayer': prayer},
      ),
      'jamaat' => prayerText(
        context,
        '{prayer} jamaat',
        args: {'prayer': prayer},
      ),
      _ => prayer,
    };
  }
}
