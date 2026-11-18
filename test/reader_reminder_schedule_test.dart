import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as tz;

import '../lib/core/services/reader_reminder_service.dart';

void main() {
  setUpAll(time_zone_data.initializeTimeZones);

  test('daily reminder uses the next chosen local calendar time', () {
    final location = tz.getLocation('Asia/Karachi');
    final before = tz.TZDateTime(location, 2026, 11, 7, 19, 59);
    final at = tz.TZDateTime(location, 2026, 11, 7, 20);
    expect(ReaderReminderService.nextDailyTime(before, 20, 0), at);
    expect(
      ReaderReminderService.nextDailyTime(at, 20, 0),
      tz.TZDateTime(location, 2026, 11, 8, 20),
    );
  });

  test('calendar scheduling keeps local time across daylight saving', () {
    final location = tz.getLocation('America/New_York');
    final beforeGap = tz.TZDateTime(location, 2026, 3, 8, 1);
    final next = ReaderReminderService.nextDailyTime(beforeGap, 2, 30);
    expect(next, tz.TZDateTime(location, 2026, 3, 9, 2, 30));
    expect(next.hour, 2);
    final beforeFall = tz.TZDateTime(location, 2026, 10, 31, 21);
    expect(
      ReaderReminderService.nextDailyTime(beforeFall, 20, 0),
      tz.TZDateTime(location, 2026, 11, 1, 20),
    );
  });

  test('invalid reminder time cannot produce a schedule', () {
    final now = tz.TZDateTime(tz.getLocation('Asia/Karachi'), 2026, 11, 7);
    for (final (hour, minute) in [(-1, 0), (24, 0), (12, -1), (12, 60)]) {
      expect(
        () => ReaderReminderService.nextDailyTime(now, hour, minute),
        throwsArgumentError,
      );
    }
  });
}
