import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:my_flutter_app/core/prayer/prayer_calculator.dart';
import 'package:my_flutter_app/core/prayer/prayer_models.dart';
import 'package:my_flutter_app/core/worship/qibla_service.dart';
import 'package:my_flutter_app/core/worship/worship_store.dart';

class _Preferences extends Fake implements SharedPreferences {
  final values = <String, String>{};
  bool failWrites = false;
  @override
  String? getString(String key) => values[key];
  @override
  Future<bool> setString(String key, String value) async {
    if (failWrites) return false;
    values[key] = value;
    return true;
  }
}

void main() {
  setUpAll(PrayerCalculator.initialize);
  const otherProfile = 'p_000000000000000000000001';

  test(
    'profiles persist independently and never receive a default fiqh school',
    () async {
      final prefs = _Preferences();
      final first = WorshipStore(profileId: 'default', preferences: prefs);
      final other = WorshipStore(profileId: otherProfile, preferences: prefs);
      await Future.wait([first.load(), other.load()]);
      expect(first.fiqh, isNull);
      expect(other.fiqh, isNull);
      expect(first.includeWitr, isFalse);
      await first.setFiqh('hanafi');
      await first.setIncludeWitr(true);
      await first.setTasbeeh('morning_ikhlas', 2);
      await first.setLessonComplete('letters_1', true);
      await other.setFiqh('shafii');
      expect(other.tasbeehCounts, isEmpty);
      expect(other.completedLessons, isEmpty);
      expect(other.includeWitr, isFalse);
      final restored = WorshipStore(profileId: 'default', preferences: prefs);
      await restored.load();
      expect(restored.fiqh, 'hanafi');
      expect(restored.trackedPrayers, contains('witr'));
      expect(restored.tasbeehCounts['morning_ikhlas'], 2);
      expect(restored.completedLessons, contains('letters_1'));
      expect(prefs.values.keys.toSet().length, 2);
    },
  );

  test(
    'Qaza counts only explicit missed records; completion undo and past-edit guard are consistent',
    () async {
      final store = WorshipStore(
        profileId: 'default',
        preferences: _Preferences(),
      );
      await store.load();
      await store.setStatus('2020-01-01', 'fajr', 'missed');
      await store.setStatus('2020-01-02', 'fajr', 'excused');
      await store.setStatus('2020-01-03', 'fajr', 'unrecorded');
      await store.setStatus('2020-01-04', 'fajr', 'prayed');
      expect(store.qazaBalance('fajr'), 1);
      await store.recordQaza('fajr', 1);
      expect(store.qazaBalance('fajr'), 0);
      await expectLater(
        store.setStatus('2020-01-01', 'fajr', 'prayed'),
        throwsArgumentError,
      );
      expect(store.status('2020-01-01', 'fajr'), 'missed');
      expect(store.completedQaza('fajr'), 1);
      await expectLater(store.recordQaza('fajr', 1), throwsArgumentError);
      await store.recordQaza('fajr', -1);
      expect(store.qazaBalance('fajr'), 1);
      await store.setStatus('2020-01-01', 'fajr', 'prayed');
      expect(store.qazaBalance('fajr'), 0);
      await store.setOpeningBalance('fajr', 3);
      await store.recordQaza('fajr', 1);
      await expectLater(
        store.setOpeningBalance('fajr', 0),
        throwsArgumentError,
      );
      expect(store.qazaBalance('fajr'), 2);
    },
  );

  test(
    'failed writes preserve last saved in-memory and on-disk records; subsequent writes recover',
    () async {
      final prefs = _Preferences();
      final store = WorshipStore(profileId: 'default', preferences: prefs);
      await store.load();
      await store.setTasbeeh('counter', 4);
      final saved = prefs.values[store.storageKey];
      prefs.failWrites = true;
      await expectLater(store.setTasbeeh('counter', 5), throwsStateError);
      expect(store.tasbeehCounts['counter'], 4);
      expect(prefs.values[store.storageKey], saved);
      prefs.failWrites = false;
      await store.setTasbeeh('counter', 6);
      expect(store.tasbeehCounts['counter'], 6);
      await store.setLessonComplete('letters_1', true);
      await store.setLessonComplete('letters_1', false);
      expect(store.completedLessons, isEmpty);
    },
  );

  test(
    'future, invalid civil dates and malformed or negative-balance saved data fail closed',
    () async {
      final prefs = _Preferences();
      final store = WorshipStore(profileId: 'default', preferences: prefs);
      await store.load();
      final tomorrow = PrayerCalculator.dayKey(
        DateTime.now().add(const Duration(days: 2)),
      );
      await expectLater(
        store.setStatus(tomorrow, 'fajr', 'missed'),
        throwsArgumentError,
      );
      await expectLater(
        store.setStatus('2026-02-30', 'fajr', 'missed'),
        throwsFormatException,
      );
      await expectLater(store.setFiqh('unknown'), throwsFormatException);
      for (final raw in [
        '{',
        jsonEncode({'version': 1, 'fiqh': 'invented'}),
        jsonEncode({
          'version': 1,
          'qazaDone': {'fajr': 1},
          'opening': {'fajr': 0},
        }),
        jsonEncode({
          'version': 1,
          'tasbeeh': {'counter': -1},
        }),
      ]) {
        final corruptPrefs = _Preferences()..values[store.storageKey] = raw;
        final corrupt = WorshipStore(
          profileId: 'default',
          preferences: corruptPrefs,
        );
        await expectLater(corrupt.load(), throwsFormatException);
        expect(corrupt.loaded, isFalse);
        expect(corruptPrefs.values[store.storageKey], raw);
      }
    },
  );

  const newYork = PrayerLocation(
    label: 'New York',
    latitude: 40.7128,
    longitude: -74.006,
    zone: 'America/New_York',
  );
  final settings = PrayerSettings(
    location: newYork,
    prayers: {
      for (final id in PrayerId.values)
        id: PrayerRule(manualMinutes: id == PrayerId.fajr ? 300 : 1080),
    },
  );
  Map<String, dynamic> ramadan(int days) => {
    'startDate': '2035-11-01',
    'days': days,
    'enabled': true,
    'sehriLeadMinutes': 15,
    'iftarLeadMinutes': 0,
  };

  for (final days in [29, 30]) {
    test(
      'Ramadan includes exactly$days selected civil dates across New York DST and expires afterward',
      () {
        final start = DateTime.utc(2035, 11, 1);
        var count = 0;
        for (var offset = -1; offset <= days; offset++) {
          final day = start.add(Duration(days: offset));
          final events = WorshipSchedule.eventsForDate(
            settings,
            day,
            ramadan: ramadan(days),
          );
          if (offset < 0 || offset == days) {
            expect(events, isEmpty);
          } else {
            expect(events.length, 2);
            expect(
              events.every(
                (event) => event.atUtc.isUtc && event.sound == 'tone',
              ),
              isTrue,
            );
            final fajr = events.singleWhere(
              (event) => event.id.endsWith(':fajr'),
            );
            final iftar = events.singleWhere(
              (event) => event.id.endsWith(':maghrib'),
            );
            final localFajr = tz.TZDateTime.from(
              fajr.atUtc,
              PrayerCalculator.zone(settings),
            );
            final localIftar = tz.TZDateTime.from(
              iftar.atUtc,
              PrayerCalculator.zone(settings),
            );
            expect(localFajr.hour * 60 + localFajr.minute, 285);
            expect(localIftar.hour * 60 + localIftar.minute, 1080);
            expect(
              PrayerCalculator.dayKey(localFajr),
              PrayerCalculator.dayKey(day),
            );
            count++;
          }
        }
        expect(count, days);
        final beforeDst = WorshipSchedule.eventsForDate(
          settings,
          DateTime.utc(2035, 11, 1),
          ramadan: ramadan(days),
        ).first.atUtc;
        final afterDst = WorshipSchedule.eventsForDate(
          settings,
          DateTime.utc(2035, 11, 10),
          ramadan: ramadan(days),
        ).first.atUtc;
        expect(afterDst.hour, beforeDst.hour + 1);
      },
    );
  }

  Map<String, dynamic> masjid({bool verified = true}) => {
    'name': 'Test Masjid',
    'source': 'Confirmed poster',
    'zone': newYork.zone,
    'latitude': newYork.latitude,
    'longitude': newYork.longitude,
    'verified': verified,
    'enabled': true,
    'validFrom': '2035-11-01',
    'validUntil': '2035-11-03',
    'times': {'fajr': 330, 'isha': 30},
  };

  test(
    'Masjid requires confirmation, expires by owner date and assigns after-midnight Isha to following day',
    () async {
      final store = WorshipStore(
        profileId: 'default',
        preferences: _Preferences(),
      );
      await store.load();
      await expectLater(
        store.saveMasjid(masjid(verified: false)),
        throwsFormatException,
      );
      await store.saveMasjid(masjid());
      expect(
        WorshipSchedule.eventsForDate(
          settings,
          DateTime.utc(2035, 10, 31),
          masjid: store.masjid,
        ),
        isEmpty,
      );
      final events = WorshipSchedule.eventsForDate(
        settings,
        DateTime.utc(2035, 11, 3),
        masjid: store.masjid,
      );
      expect(events.length, 2);
      final isha = events.singleWhere((event) => event.id.endsWith(':isha'));
      final wall = tz.TZDateTime.from(
        isha.atUtc,
        PrayerCalculator.zone(settings),
      );
      expect(PrayerCalculator.dayKey(wall), '2035-11-04');
      expect(wall.hour * 60 + wall.minute, 30);
      expect(
        WorshipSchedule.eventsForDate(
          settings,
          DateTime.utc(2035, 11, 4),
          masjid: store.masjid,
        ),
        isEmpty,
      );
    },
  );

  test(
    'a confirmed Masjid timetable is suppressed after city or zone changes',
    () {
      final day = DateTime.utc(2035, 11, 2);
      expect(
        WorshipSchedule.eventsForDate(settings, day, masjid: masjid()),
        isNotEmpty,
      );
      expect(
        WorshipSchedule.eventsForDate(
          settings.copyWith(location: prayerCities.first),
          day,
          masjid: masjid(),
        ),
        isEmpty,
      );
      final wrongZone = {...masjid(), 'zone': 'America/Toronto'};
      expect(
        WorshipSchedule.eventsForDate(settings, day, masjid: wrongZone),
        isEmpty,
      );
      final shiftedCity = {...masjid(), 'latitude': newYork.latitude + .03};
      expect(
        WorshipSchedule.eventsForDate(settings, day, masjid: shiftedCity),
        isEmpty,
      );
    },
  );

  test(
    'Qibla bearings agree with independent city reference ranges and reject invalid coordinates',
    () {
      expect(QiblaService.bearingFor(24.8607, 67.0011), closeTo(268, 1));
      expect(QiblaService.bearingFor(51.5074, -.1278), closeTo(119, 1));
      expect(QiblaService.bearingFor(40.7128, -74.006), closeTo(58.5, 1));
      expect(QiblaService.bearingFor(-33.8688, 151.2093), closeTo(277.5, 1));
      expect(
        () => QiblaService.bearingFor(double.nan, 0),
        throwsFormatException,
      );
      expect(() => QiblaService.bearingFor(91, 0), throwsFormatException);
      expect(() => QiblaService.bearingFor(0, 181), throwsFormatException);
    },
  );
}
