import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prayer/prayer_calculator.dart';
import '../prayer/prayer_models.dart';
import '../storage/reader_profile_store.dart';

const worshipSchools = ['hanafi', 'shafii', 'maliki', 'hanbali'];
const diaryPrayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'witr'];
const diaryStatuses = ['unrecorded', 'prayed', 'missed', 'excused'];

class WorshipStore extends ChangeNotifier {
  WorshipStore({required this.profileId, SharedPreferences? preferences})
    : _injected = preferences;
  final String profileId;
  final SharedPreferences? _injected;
  Map<String, dynamic> _data = {};
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  bool loaded = false;
  bool _disposed = false;
  String? get fiqh => _data['fiqh'] as String?;
  bool get includeWitr => _data['includeWitr'] == true;
  List<String> get trackedPrayers =>
      diaryPrayers.take(includeWitr ? 6 : 5).toList();
  Map<String, dynamic> get _diary =>
      Map<String, dynamic>.from(_data['diary'] as Map? ?? {});
  Map<String, int> _counts(String key) =>
      Map<String, int>.from(_data[key] as Map? ?? {});
  Map<String, int> get tasbeehCounts => Map.unmodifiable(_counts('tasbeeh'));
  Set<String> get completedLessons =>
      Set.unmodifiable(List<String>.from(_data['lessons'] as List? ?? []));
  Map<String, dynamic>? get ramadan => _data['ramadan'] == null
      ? null
      : Map<String, dynamic>.unmodifiable(_data['ramadan'] as Map);
  Map<String, dynamic>? get masjid => _data['masjid'] == null
      ? null
      : Map<String, dynamic>.unmodifiable(_data['masjid'] as Map);
  String get storageKey =>
      ReaderProfileStore.keyFor('reader.worship.v1', profileId);
  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<void> load() => _loading ??= _load().catchError((Object error) {
    _loading = null;
    throw error;
  });

  Future<void> _load() async {
    final raw = (await _prefs).getString(storageKey);
    if (raw != null) {
      if (raw.length > 2000000)
        throw const FormatException('Worship record is too large.');
      final value = jsonDecode(raw);
      if (value is! Map || value['version'] != 1)
        throw const FormatException('Worship records could not be read.');
      _validate(Map<String, dynamic>.from(value));
      _data = Map<String, dynamic>.from(value);
    }
    loaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> _change(void Function(Map<String, dynamic>) edit) {
    final operation = _writes.then((_) async {
      await load();
      final next = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(_data)) as Map,
      );
      next['version'] = 1;
      edit(next);
      _validate(next);
      if (!await (await _prefs).setString(storageKey, jsonEncode(next))) {
        throw StateError('Unable to save. Please try again.');
      }
      _data = next;
      if (!_disposed) notifyListeners();
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> setFiqh(String school) =>
      _change((data) => data['fiqh'] = school);
  Future<void> setIncludeWitr(bool value) =>
      _change((data) => data['includeWitr'] = value);
  String status(String day, String prayer) =>
      (_diary[day] as Map?)?[prayer] as String? ?? 'unrecorded';
  int openingBalance(String prayer) => _counts('opening')[prayer] ?? 0;
  int completedQaza(String prayer) => _counts('qazaDone')[prayer] ?? 0;
  int missedCount(String prayer) => _diary.values
      .where((row) => row is Map && row[prayer] == 'missed')
      .length;
  int qazaBalance(String prayer) =>
      openingBalance(prayer) + missedCount(prayer) - completedQaza(prayer);

  Future<void> setStatus(String day, String prayer, String value) => _change((
    data,
  ) {
    _validDay(day);
    if (DateTime.parse(day).isAfter(DateTime.now()))
      throw ArgumentError('Future prayers cannot be recorded.');
    if (!diaryPrayers.contains(prayer) || !diaryStatuses.contains(value))
      throw ArgumentError('Invalid prayer record.');
    final rows = Map<String, dynamic>.from(data['diary'] as Map? ?? {});
    final row = Map<String, dynamic>.from(rows[day] as Map? ?? {});
    row[prayer] = value;
    rows[day] = row;
    data['diary'] = rows;
    final missed = rows.values
        .where((r) => r is Map && r[prayer] == 'missed')
        .length;
    final opening = (data['opening'] as Map?)?[prayer] as int? ?? 0;
    final paid = (data['qazaDone'] as Map?)?[prayer] as int? ?? 0;
    if (paid > opening + missed)
      throw ArgumentError(
        'This change would remove an already completed Qaza. Adjust the starting balance first.',
      );
  });

  Future<void> setOpeningBalance(String prayer, int value) => _change((data) {
    if (!diaryPrayers.contains(prayer) || value < 0 || value > 1000000)
      throw ArgumentError('Use a count from 0 to 1,000,000.');
    if (value + missedCount(prayer) < completedQaza(prayer))
      throw ArgumentError(
        'Starting balance cannot be less than completed Qaza.',
      );
    data['opening'] = {...?data['opening'] as Map?, prayer: value};
  });

  Future<void> recordQaza(String prayer, int adjustment) => _change((data) {
    if (!diaryPrayers.contains(prayer) || ![-1, 1].contains(adjustment))
      throw ArgumentError('Invalid Qaza adjustment.');
    final done = completedQaza(prayer) + adjustment;
    if (done < 0 || done > openingBalance(prayer) + missedCount(prayer))
      throw ArgumentError('No Qaza is available for this action.');
    data['qazaDone'] = {...?data['qazaDone'] as Map?, prayer: done};
  });

  Future<void> setTasbeeh(String key, int count) => _change((data) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(key) ||
        count < 0 ||
        count > 1000000)
      throw ArgumentError('Invalid counter.');
    data['tasbeeh'] = {...?data['tasbeeh'] as Map?, key: count};
  });
  Future<void> setLessonComplete(String id, bool complete) => _change((data) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id))
      throw ArgumentError('Invalid lesson.');
    final lessons = Set<String>.from(data['lessons'] as List? ?? []);
    if (complete) {
      lessons.add(id);
    } else {
      lessons.remove(id);
    }
    data['lessons'] = lessons.toList();
  });
  Future<void> saveRamadan(Map<String, dynamic> plan) =>
      _change((data) => data['ramadan'] = Map<String, dynamic>.from(plan));
  Future<void> saveMasjid(Map<String, dynamic> plan) =>
      _change((data) => data['masjid'] = Map<String, dynamic>.from(plan));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static void _validDay(String day) {
    final parsed = DateTime.tryParse(day);
    if (parsed == null ||
        PrayerCalculator.dayKey(parsed) != day ||
        parsed.year < 1900 ||
        parsed.year > 2200) {
      throw const FormatException('Choose a valid date.');
    }
  }

  static void _validate(Map<String, dynamic> data) {
    if (data['fiqh'] != null && !worshipSchools.contains(data['fiqh']))
      throw const FormatException('Choose a school.');
    if (data['includeWitr'] != null && data['includeWitr'] is! bool)
      throw const FormatException('Invalid Witr setting.');
    for (final key in ['opening', 'qazaDone', 'tasbeeh']) {
      final values = data[key];
      if (values != null &&
          (values is! Map ||
              values.length > 200 ||
              values.entries.any(
                (e) =>
                    e.key is! String ||
                    e.value is! int ||
                    (e.value as int) < 0 ||
                    (e.value as int) > 1000000,
              ))) {
        throw const FormatException('Invalid worship count.');
      }
      if (key != 'tasbeeh' &&
          values is Map &&
          values.keys.any((key) => !diaryPrayers.contains(key))) {
        throw const FormatException('Invalid prayer balance.');
      }
    }
    final diary = data['diary'];
    for (final prayer in diaryPrayers) {
      final opening = (data['opening'] as Map?)?[prayer] as int? ?? 0;
      final done = (data['qazaDone'] as Map?)?[prayer] as int? ?? 0;
      final missed = diary is Map
          ? diary.values
                .where((row) => row is Map && row[prayer] == 'missed')
                .length
          : 0;
      if (done > opening + missed)
        throw const FormatException(
          'Completed Qaza exceeds the recorded balance.',
        );
    }
    if (diary != null) {
      if (diary is! Map || diary.length > 40000)
        throw const FormatException('Invalid diary.');
      for (final entry in diary.entries) {
        _validDay(entry.key as String);
        if (entry.value is! Map ||
            (entry.value as Map).entries.any(
              (e) =>
                  !diaryPrayers.contains(e.key) ||
                  !diaryStatuses.contains(e.value),
            ))
          throw const FormatException('Invalid diary record.');
      }
    }
    final lessons = data['lessons'];
    if (lessons != null &&
        (lessons is! List ||
            lessons.length > 200 ||
            lessons.any((e) => e is! String)))
      throw const FormatException('Invalid lesson progress.');
    final plan = data['ramadan'];
    if (plan != null) {
      if (plan is! Map ||
          plan['startDate'] is! String ||
          ![29, 30].contains(plan['days']) ||
          plan['enabled'] is! bool ||
          plan['sehriLeadMinutes'] is! int ||
          (plan['sehriLeadMinutes'] as int) < 0 ||
          (plan['sehriLeadMinutes'] as int) > 60 ||
          plan['iftarLeadMinutes'] is! int ||
          (plan['iftarLeadMinutes'] as int) < 0 ||
          (plan['iftarLeadMinutes'] as int) > 30)
        throw const FormatException('Invalid Ramadan plan.');
      _validDay(plan['startDate'] as String);
    }
    final masjid = data['masjid'];
    if (masjid != null) {
      if (masjid is! Map ||
          masjid['name'] is! String ||
          (masjid['name'] as String).trim().isEmpty ||
          (masjid['name'] as String).length > 80 ||
          masjid['source'] is! String ||
          (masjid['source'] as String).trim().isEmpty ||
          (masjid['source'] as String).length > 160 ||
          masjid['verified'] is! bool ||
          masjid['enabled'] is! bool ||
          masjid['validFrom'] is! String ||
          masjid['validUntil'] is! String ||
          masjid['zone'] is! String ||
          masjid['latitude'] is! num ||
          !(masjid['latitude'] as num).isFinite ||
          (masjid['latitude'] as num).abs() > 89 ||
          masjid['longitude'] is! num ||
          !(masjid['longitude'] as num).isFinite ||
          (masjid['longitude'] as num).abs() > 180 ||
          masjid['times'] is! Map)
        throw const FormatException('Invalid Masjid timetable.');
      try {
        PrayerCalculator.zone(
          PrayerSettings(
            location: PrayerLocation(
              label: 'Timetable',
              latitude: (masjid['latitude'] as num).toDouble(),
              longitude: (masjid['longitude'] as num).toDouble(),
              zone: masjid['zone'] as String,
            ),
          ),
        );
      } catch (_) {
        throw const FormatException('Invalid Masjid time zone.');
      }
      _validDay(masjid['validFrom'] as String);
      _validDay(masjid['validUntil'] as String);
      if ((masjid['validUntil'] as String).compareTo(
            masjid['validFrom'] as String,
          ) <
          0)
        throw const FormatException('Timetable end precedes start.');
      final times = masjid['times'] as Map;
      if (times.keys.any(
            (key) => !PrayerId.values.map((p) => p.name).contains(key),
          ) ||
          times.values.any((v) => v is! int || v < 0 || v > 1439))
        throw const FormatException('Invalid Jamaat time.');
      if (masjid['enabled'] == true &&
          (masjid['verified'] != true || times.isEmpty))
        throw const FormatException(
          'Confirm your timetable before enabling reminders.',
        );
    }
  }
}

class WorshipSchedule {
  static List<PrayerEvent> eventsForDate(
    PrayerSettings settings,
    DateTime day, {
    Map<String, dynamic>? ramadan,
    Map<String, dynamic>? masjid,
  }) {
    if (settings.location == null) return [];
    final key = PrayerCalculator.dayKey(day);
    final events = <PrayerEvent>[];
    if (ramadan?['enabled'] == true) {
      final parsedStart = DateTime.parse(ramadan!['startDate'] as String);
      final start = DateTime.utc(
        parsedStart.year,
        parsedStart.month,
        parsedStart.day,
      );
      final end = start.add(Duration(days: (ramadan['days'] as int) - 1));
      final date = DateTime.utc(day.year, day.month, day.day);
      if (!date.isBefore(start) && !date.isAfter(end)) {
        final times = PrayerCalculator.timesForDate(settings, day);
        for (final (id, label, lead) in [
          (PrayerId.fajr, 'Sehri reminder', ramadan['sehriLeadMinutes'] as int),
          (
            PrayerId.maghrib,
            'Iftar reminder',
            ramadan['iftarLeadMinutes'] as int,
          ),
        ]) {
          final at = times[id];
          if (at != null)
            events.add(
              PrayerEvent(
                id: '$key:worship:${id.name}',
                atUtc: at.subtract(Duration(minutes: lead)),
                kind: 'worship',
                sound: 'tone',
                customLabel: label,
              ),
            );
        }
      }
    }
    if (masjid?['enabled'] == true &&
        masjid?['verified'] == true &&
        masjid?['zone'] == settings.location!.zone &&
        ((masjid!['latitude'] as num).toDouble() - settings.location!.latitude)
                .abs() <
            .02 &&
        ((masjid['longitude'] as num).toDouble() - settings.location!.longitude)
                .abs() <
            .02 &&
        key.compareTo(masjid!['validFrom'] as String) >= 0 &&
        key.compareTo(masjid['validUntil'] as String) <= 0) {
      for (final entry in (masjid['times'] as Map).entries) {
        final jamaatDay = day.add(
          Duration(
            days: entry.key == 'isha' && (entry.value as int) < 720 ? 1 : 0,
          ),
        );
        events.add(
          PrayerEvent(
            id: '$key:worship:jamaat:${entry.key}',
            atUtc: PrayerCalculator.wallTime(
              PrayerCalculator.zone(settings),
              jamaatDay,
              entry.value as int,
            ),
            kind: 'worship',
            sound: 'tone',
            customLabel: '${masjid['name']} · ${entry.key} Jamaat',
          ),
        );
      }
    }
    events.sort((a, b) => a.atUtc.compareTo(b.atUtc));
    return events;
  }
}
