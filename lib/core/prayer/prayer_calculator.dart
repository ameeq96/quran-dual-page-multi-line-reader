import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_models.dart';

class PrayerCalculator {
  static bool _ready = false;
  static void initialize() {
    if (_ready) return;
    time_zone_data.initializeTimeZones();
    _ready = true;
  }

  static tz.Location zone(PrayerSettings settings) {
    initialize();
    return tz.getLocation(settings.location?.zone ?? 'UTC');
  }

  static DateTime dateInZone(DateTime instant, PrayerSettings settings) {
    final local = tz.TZDateTime.from(instant, zone(settings));
    return DateTime.utc(local.year, local.month, local.day);
  }

  static String dayKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime wallTime(tz.Location location, DateTime day, int minutes) {
    final candidate = tz.TZDateTime(location, day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
    var earliest = candidate.toUtc();
    for (var adjustment = -180; adjustment <= 180; adjustment += 15) {
      final possible = candidate.toUtc().add(Duration(minutes: adjustment));
      final local = tz.TZDateTime.from(possible, location);
      if (local.year == day.year && local.month == day.month && local.day == day.day &&
          local.hour * 60 + local.minute == minutes && possible.isBefore(earliest)) earliest = possible;
    }
    return earliest;
  }

  static adhan.CalculationParameters parameters(PrayerSettings settings) {
    final params = switch (settings.method) {
      'karachi' => adhan.CalculationMethodParameters.karachi(),
      'ummAlQura' => adhan.CalculationMethodParameters.ummAlQura(),
      'egyptian' => adhan.CalculationMethodParameters.egyptian(),
      'northAmerica' => adhan.CalculationMethodParameters.northAmerica(),
      'dubai' => adhan.CalculationMethodParameters.dubai(),
      _ => adhan.CalculationMethodParameters.muslimWorldLeague(),
    };
    params.madhab = settings.madhab == 'hanafi' ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    params.highLatitudeRule = switch (settings.highLatitudeRule) {
      'middleOfNight' => adhan.HighLatitudeRule.middleOfTheNight,
      'seventhOfNight' => adhan.HighLatitudeRule.seventhOfTheNight,
      'twilightAngle' => adhan.HighLatitudeRule.twilightAngle,
      _ => (settings.location?.latitude.abs() ?? 0) >= 48
          ? adhan.HighLatitudeRule.seventhOfTheNight : adhan.HighLatitudeRule.middleOfTheNight,
    };
    return params;
  }

  static Map<PrayerId, DateTime> timesForDate(PrayerSettings settings, DateTime day) {
    final place = settings.location;
    if (place == null) return {};
    final location = zone(settings);
    final solar = <PrayerId, DateTime>{};
    if (PrayerId.values.any((id) => settings.rule(id).manualMinutes == null)) {
      try {
        final times = adhan.PrayerTimes(date: DateTime.utc(day.year, day.month, day.day),
          coordinates: adhan.Coordinates(place.latitude, place.longitude), calculationParameters: parameters(settings));
        solar.addAll({PrayerId.fajr: times.fajr, PrayerId.dhuhr: times.dhuhr, PrayerId.asr: times.asr,
          PrayerId.maghrib: times.maghrib, PrayerId.isha: times.isha});
      } catch (_) {
        // A user-supplied local timetable remains usable when solar times are unavailable.
      }
    }
    final result = <PrayerId, DateTime>{};
    for (final id in PrayerId.values) {
      final rule = settings.rule(id);
      final base = rule.manualMinutes == null ? solar[id] : wallTime(location, day, rule.manualMinutes!);
      if (base != null) result[id] = base.toUtc().add(Duration(minutes: rule.offsetMinutes));
    }
    return result;
  }

  static List<PrayerEvent> eventsForDate(PrayerSettings settings, DateTime day) {
    if (settings.location == null) return [];
    final location = zone(settings);
    final key = dayKey(day);
    final times = timesForDate(settings, day);
    final events = <PrayerEvent>[];
    for (final id in PrayerId.values) {
      final rule = settings.rule(id);
      final at = times[id];
      if (!rule.enabled || at == null) continue;
      events.add(PrayerEvent(id: '$key:${id.name}:adhan', atUtc: at, kind: 'adhan', sound: rule.sound, prayer: id));
      if (settings.preReminderMinutes > 0) events.add(PrayerEvent(id: '$key:${id.name}:before',
        atUtc: at.subtract(Duration(minutes: settings.preReminderMinutes)), kind: 'before',
        sound: rule.sound == 'silent' ? 'silent' : 'tone', prayer: id));
      if (rule.jamaatMinutes != null) {
        final jamaatDay = day.add(Duration(days: id == PrayerId.isha && rule.jamaatMinutes! < 720 ? 1 : 0));
        events.add(PrayerEvent(id: '$key:${id.name}:jamaat', atUtc: wallTime(location, jamaatDay, rule.jamaatMinutes!),
          kind: 'jamaat', sound: rule.sound == 'silent' ? 'silent' : 'tone', prayer: id));
      }
    }
    for (final custom in settings.customReminders) {
      if (custom.enabled && custom.weekdays.contains(day.weekday)) events.add(PrayerEvent(
        id: '$key:custom:${custom.id}', atUtc: wallTime(location, day, custom.minutes),
        kind: 'custom', sound: custom.sound, customLabel: custom.label));
    }
    events.sort((a, b) => a.atUtc.compareTo(b.atUtc));
    return events;
  }

  static List<PrayerEvent> eventsAround(PrayerSettings settings, DateTime instant, {int forwardDays = 2}) {
    final day = dateInZone(instant, settings);
    final events = [for (var offset = -1; offset <= forwardDays; offset++)
      ...eventsForDate(settings, day.add(Duration(days: offset)))];
    events.sort((a, b) => a.atUtc.compareTo(b.atUtc));
    return events;
  }
}
