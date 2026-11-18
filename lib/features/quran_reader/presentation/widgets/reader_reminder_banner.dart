import 'package:flutter/material.dart';

import '../../../../app/reader_localization.dart';
import '../../../../core/services/reader_reminder_service.dart';

class ReaderReminderBanner extends StatelessWidget {
  const ReaderReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReaderReminderService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (!service.inAppReminderDue) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return SafeArea(
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(context, 'Time for Quran'),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tr(
                                    context,
                                    'Read a few pages and revisit your Hifz revision queue.',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: service.dismissInAppReminder,
                            tooltip: tr(context, 'Dismiss reminder'),
                            color: theme.colorScheme.onPrimaryContainer,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
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
}
