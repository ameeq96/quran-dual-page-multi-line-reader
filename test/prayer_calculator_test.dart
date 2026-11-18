import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:my_flutter_app/core/prayer/prayer_calculator.dart';
import 'package:my_flutter_app/core/prayer/prayer_models.dart';

void main() {
  setUpAll(PrayerCalculator.initialize);
  final karachi = prayerCities.first;
  const newYork = PrayerLocation(label: 'New York', latitude: 40.7128, longitude: -74.006, zone: 'America/New_York');

  test('new installs are off; invalid and duplicated reminder settings are rejected', () {
    const defaults = PrayerSettings();
    expect(PrayerSettings.fromJson(defaults.toJson()).enabled, isFalse);
    expect(() => PrayerSettings.fromJson(defaults.copyWith(enabled: true).toJson()), throwsFormatException);
    final custom = CustomPrayerReminder(id: 'custom_01', label: 'Mosque', minutes: 900);
    expect(() => PrayerSettings.fromJson(defaults.copyWith(customReminders: [custom, custom]).toJson()), throwsFormatException);
    expect(() => PrayerLocation.fromJson({'label': 'x', 'latitude': double.nan, 'longitude': 0, 'zone': 'UTC'}), throwsFormatException);
  });
  test('manual New York spring gap moves forward and autumn overlap fires once at earliest occurrence', () {
    final zone = tz.getLocation(newYork.zone);
    expect(PrayerCalculator.wallTime(zone, DateTime.utc(2026, 3, 8), 150), DateTime.utc(2026, 3, 8, 7, 30));
    expect(PrayerCalculator.wallTime(zone, DateTime.utc(2026, 11, 1), 90), DateTime.utc(2026, 11, 1, 5, 30));
  });
  test('offset/pre-reminder crossing midnight retains its prayer date; Isha jamaat belongs to next day', () {
    final settings = PrayerSettings(enabled: true, location: karachi, preReminderMinutes: 10, prayers: {
      for (final prayer in PrayerId.values) prayer: PrayerRule(enabled: prayer == PrayerId.fajr || prayer == PrayerId.isha,
        manualMinutes: prayer == PrayerId.fajr ? 5 : 1200, offsetMinutes: prayer == PrayerId.fajr ? -10 : 0,
        jamaatMinutes: prayer == PrayerId.isha ? 30 : null),
    });
    final events = PrayerCalculator.eventsForDate(settings, DateTime.utc(2026, 11, 11));
    final fajr = events.singleWhere((e) => e.id == '2026-11-11:fajr:adhan');
    expect(fajr.atUtc, DateTime.utc(2026, 11, 10, 18, 55));
    expect(events.singleWhere((e) => e.id == '2026-11-11:fajr:before').atUtc, DateTime.utc(2026, 11, 10, 18, 45));
    expect(events.singleWhere((e) => e.id == '2026-11-11:isha:jamaat').atUtc, DateTime.utc(2026, 11, 11, 19, 30));
    expect(events.any((e) => e.prayer == PrayerId.dhuhr), isFalse);
  });
  test('manual timetable remains usable in polar summer and custom weekdays respect city date', () {
    const polar = PrayerLocation(label: 'Tromso', latitude: 69.6492, longitude: 18.9553, zone: 'Europe/Oslo');
    final settings = PrayerSettings(enabled: true, location: polar, prayers: {
      for (final prayer in PrayerId.values) prayer: PrayerRule(manualMinutes: 300 + prayer.index * 180),
    }, customReminders: const [CustomPrayerReminder(id: 'friday_01', label: 'Friday', minutes: 720, weekdays: [5])]);
    expect(PrayerCalculator.timesForDate(settings, DateTime.utc(2026, 6, 19)).length, 5);
    expect(PrayerCalculator.eventsForDate(settings, DateTime.utc(2026, 6, 19)).where((e) => e.kind == 'custom').single.id,
      '2026-06-19:custom:friday_01');
    expect(PrayerCalculator.eventsForDate(settings, DateTime.utc(2026, 6, 20)).where((e) => e.kind == 'custom'), isEmpty);
  });
  test('Hanafi Asr is later; all prayer times stay UTC and chronologically valid', () {
    final settings = PrayerSettings(location: karachi);
    final day = DateTime.utc(2026, 11, 11);
    final hanafi = PrayerCalculator.timesForDate(settings, day);
    final shafi = PrayerCalculator.timesForDate(settings.copyWith(madhab: 'shafi'), day);
    expect(hanafi[PrayerId.asr]!.isAfter(shafi[PrayerId.asr]!), isTrue);
    expect(hanafi.values.every((v) => v.isUtc), isTrue);
    for (var i = 1; i < PrayerId.values.length; i++) {
      expect(hanafi[PrayerId.values[i]]!.isAfter(hanafi[PrayerId.values[i - 1]]!), isTrue);
    }
  });
  test('silent prayer also silences its advance and jamaat alerts', () {
    final settings = PrayerSettings(location: karachi, preReminderMinutes: 10, prayers: {
      for (final prayer in PrayerId.values) prayer: const PrayerRule(sound: 'silent', jamaatMinutes: 1200),
    });
    expect(PrayerCalculator.eventsForDate(settings, DateTime.utc(2026, 11, 11)).every((event) => event.sound == 'silent'), isTrue);
  });
  test('backend parity fixtures agree within one minute', () {
    const path = String.fromEnvironment('PRAYER_PARITY_FIXTURES');
    if (path.isEmpty) return;
    final fixtures = (jsonDecode(File(path).readAsStringSync()) as Map)['cases'] as List;
    for (final fixture in fixtures) {
      final settings = PrayerSettings.fromJson(Map<String, dynamic>.from(fixture['settings'] as Map));
      final times = PrayerCalculator.timesForDate(settings, DateTime.parse(fixture['day'] as String));
      final expected = fixture['times'] as Map;
      for (final prayer in PrayerId.values) {
        final value = expected[prayer.name];
        if (value != null) expect(times[prayer]!.difference(DateTime.parse(value as String)).inSeconds.abs(), lessThanOrEqualTo(60),
          reason: '${settings.location!.label}/${settings.method}/${settings.madhab}/${prayer.name}');
      }
    }
  });
}
