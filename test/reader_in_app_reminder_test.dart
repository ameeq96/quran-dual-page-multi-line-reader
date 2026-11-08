import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/services/reader_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'foreground reminder appears once per local day across restart',
    () async {
      var now = DateTime(2026, 11, 7, 7);
      final first = ReaderReminderService.forTesting(now: () => now);
      addTearDown(first.dispose);
      await first.initialize();
      await first.setTime(hour: 8, minute: 0);
      await first.setEnabled(true);
      expect(first.inAppReminderDue, isFalse);
      now = DateTime(2026, 11, 7, 8);
      await first.refreshSchedule();
      expect(first.inAppReminderDue, isTrue);
      first.dismissInAppReminder();
      await first.refreshSchedule();
      expect(first.inAppReminderDue, isFalse);
      final restarted = ReaderReminderService.forTesting(now: () => now);
      addTearDown(restarted.dispose);
      await restarted.initialize();
      expect(restarted.inAppReminderDue, isFalse);
      now = DateTime(2026, 11, 8, 8);
      await restarted.refreshSchedule();
      expect(restarted.inAppReminderDue, isTrue);
    },
  );

  test('enabling or changing a past time starts the following day', () async {
    var now = DateTime(2026, 11, 7, 10);
    final service = ReaderReminderService.forTesting(now: () => now);
    addTearDown(service.dispose);
    await service.initialize();
    await service.setTime(hour: 8, minute: 0);
    await service.setEnabled(true);
    await service.refreshSchedule();
    expect(service.inAppReminderDue, isFalse);
    await service.setTime(hour: 9, minute: 0);
    expect(service.inAppReminderDue, isFalse);
    now = DateTime(2026, 11, 8, 9);
    await service.refreshSchedule();
    expect(service.inAppReminderDue, isTrue);
  });

  test('previously enabled reminder catches up on active app resume', () async {
    SharedPreferences.setMockInitialValues({
      'reader.dailyReminder.v1':
          '{"enabled":true,"hour":8,"minute":0,"lastDeliveredDate":"2026-11-06"}',
    });
    final service = ReaderReminderService.forTesting(
      now: () => DateTime(2026, 11, 7, 10),
    );
    addTearDown(service.dispose);
    await service.setAppActive(false);
    await service.initialize();
    await service.refreshSchedule();
    expect(service.inAppReminderDue, isFalse);
    await service.setAppActive(true);
    expect(service.inAppReminderDue, isTrue);
    await service.setEnabled(false);
    expect(service.inAppReminderDue, isFalse);
    await service.refreshSchedule();
    expect(service.inAppReminderDue, isFalse);
  });

  test(
    'disabled reminder never fires and clock rollback cannot duplicate a day',
    () async {
      SharedPreferences.setMockInitialValues({
        'reader.dailyReminder.v1':
            '{"enabled":false,"hour":8,"minute":0,"lastDeliveredDate":"2026-11-07"}',
      });
      var now = DateTime(2026, 11, 8, 10);
      final service = ReaderReminderService.forTesting(now: () => now);
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.inAppReminderDue, isFalse);
      now = DateTime(2026, 11, 7, 7);
      await service.setEnabled(true);
      now = DateTime(2026, 11, 7, 10);
      await service.refreshSchedule();
      expect(service.inAppReminderDue, isFalse);
      now = DateTime(2026, 11, 6, 10);
      await service.refreshSchedule();
      expect(service.inAppReminderDue, isFalse);
    },
  );
}
