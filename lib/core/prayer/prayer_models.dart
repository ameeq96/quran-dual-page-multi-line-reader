enum PrayerId { fajr, dhuhr, asr, maghrib, isha }

extension PrayerIdName on PrayerId {
  String get label => const ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'][index];
}

const prayerMethods = ['karachi', 'mwl', 'ummAlQura', 'egyptian', 'northAmerica', 'dubai'];
const prayerHighLatitudeRules = ['recommended', 'middleOfNight', 'seventhOfNight', 'twilightAngle'];
const prayerLeadMinutes = [0, 5, 10, 15, 30];

class PrayerLocation {
  const PrayerLocation({required this.label, required this.latitude, required this.longitude, required this.zone});
  final String label;
  final double latitude;
  final double longitude;
  final String zone;

  Map<String, dynamic> toJson() => {'label': label, 'latitude': latitude, 'longitude': longitude, 'zone': zone};
  factory PrayerLocation.fromJson(Map<String, dynamic> json) {
    final label = _text(json['label'], 80);
    final lat = json['latitude'];
    final lon = json['longitude'];
    final zone = _text(json['zone'], 100);
    if (lat is! num || lon is! num || !lat.isFinite || !lon.isFinite || lat.abs() > 89 || lon.abs() > 180 ||
        !RegExp(r'^[A-Za-z0-9_+./-]+$').hasMatch(zone)) throw const FormatException('Invalid prayer location.');
    return PrayerLocation(label: label, latitude: lat.toDouble(), longitude: lon.toDouble(), zone: zone);
  }
}

class PrayerRule {
  const PrayerRule({this.enabled = true, this.sound = 'azan', this.offsetMinutes = 0, this.manualMinutes, this.jamaatMinutes});
  final bool enabled;
  final String sound;
  final int offsetMinutes;
  final int? manualMinutes;
  final int? jamaatMinutes;

  PrayerRule copyWith({bool? enabled, String? sound, int? offsetMinutes, int? manualMinutes, bool clearManual = false,
    int? jamaatMinutes, bool clearJamaat = false}) => PrayerRule(
    enabled: enabled ?? this.enabled, sound: sound ?? this.sound, offsetMinutes: offsetMinutes ?? this.offsetMinutes,
    manualMinutes: clearManual ? null : manualMinutes ?? this.manualMinutes,
    jamaatMinutes: clearJamaat ? null : jamaatMinutes ?? this.jamaatMinutes);
  Map<String, dynamic> toJson() => {'enabled': enabled, 'sound': sound, 'offsetMinutes': offsetMinutes,
    'manualMinutes': manualMinutes, 'jamaatMinutes': jamaatMinutes};
  factory PrayerRule.fromJson(Map<String, dynamic> json) {
    final sound = json['sound'];
    if (json['enabled'] is! bool || !['azan', 'tone', 'silent'].contains(sound)) {
      throw const FormatException('Invalid prayer sound.');
    }
    return PrayerRule(enabled: json['enabled'] as bool, sound: sound as String,
      offsetMinutes: _integer(json['offsetMinutes'], -60, 60),
      manualMinutes: _clock(json['manualMinutes']), jamaatMinutes: _clock(json['jamaatMinutes']));
  }
}

class CustomPrayerReminder {
  const CustomPrayerReminder({required this.id, required this.label, required this.minutes,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7], this.enabled = true, this.sound = 'tone'});
  final String id;
  final String label;
  final int minutes;
  final List<int> weekdays;
  final bool enabled;
  final String sound;

  CustomPrayerReminder copyWith({String? label, int? minutes, List<int>? weekdays, bool? enabled, String? sound}) =>
    CustomPrayerReminder(id: id, label: label ?? this.label, minutes: minutes ?? this.minutes,
      weekdays: weekdays ?? this.weekdays, enabled: enabled ?? this.enabled, sound: sound ?? this.sound);
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'minutes': minutes, 'weekdays': weekdays, 'enabled': enabled, 'sound': sound};
  factory CustomPrayerReminder.fromJson(Map<String, dynamic> json) {
    final id = _text(json['id'], 48);
    final days = json['weekdays'];
    if (!RegExp(r'^[A-Za-z0-9_-]{6,48}$').hasMatch(id) || days is! List || days.isEmpty || days.length > 7 ||
        days.any((v) => v is! int || v < 1 || v > 7) || days.toSet().length != days.length ||
        json['enabled'] is! bool || !['tone', 'silent'].contains(json['sound'])) {
      throw const FormatException('Invalid custom reminder.');
    }
    return CustomPrayerReminder(id: id, label: _text(json['label'], 80), minutes: _integer(json['minutes'], 0, 1439),
      weekdays: List<int>.unmodifiable(days.cast<int>()), enabled: json['enabled'] as bool, sound: json['sound'] as String);
  }
}

class PrayerSettings {
  const PrayerSettings({this.enabled = false, this.location, this.method = 'karachi', this.madhab = 'hanafi',
    this.highLatitudeRule = 'recommended', this.preReminderMinutes = 0, this.volume = .7, this.respectSilent = true,
    this.language = 'en', this.prayers = const {}, this.customReminders = const []});
  final bool enabled;
  final PrayerLocation? location;
  final String method;
  final String madhab;
  final String highLatitudeRule;
  final int preReminderMinutes;
  final double volume;
  final bool respectSilent;
  final String language;
  final Map<PrayerId, PrayerRule> prayers;
  final List<CustomPrayerReminder> customReminders;
  PrayerRule rule(PrayerId id) => prayers[id] ?? const PrayerRule();

  PrayerSettings copyWith({bool? enabled, PrayerLocation? location, bool clearLocation = false, String? method,
    String? madhab, String? highLatitudeRule, int? preReminderMinutes, double? volume, bool? respectSilent,
    String? language, Map<PrayerId, PrayerRule>? prayers, List<CustomPrayerReminder>? customReminders}) => PrayerSettings(
      enabled: enabled ?? this.enabled, location: clearLocation ? null : location ?? this.location,
      method: method ?? this.method, madhab: madhab ?? this.madhab, highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      preReminderMinutes: preReminderMinutes ?? this.preReminderMinutes, volume: volume ?? this.volume,
      respectSilent: respectSilent ?? this.respectSilent, language: language ?? this.language,
      prayers: Map.unmodifiable(prayers ?? this.prayers), customReminders: List.unmodifiable(customReminders ?? this.customReminders));

  Map<String, dynamic> toJson() => {'version': 1, 'enabled': enabled, 'location': location?.toJson(), 'method': method,
    'madhab': madhab, 'highLatitudeRule': highLatitudeRule, 'preReminderMinutes': preReminderMinutes, 'volume': volume,
    'respectSilent': respectSilent, 'language': language,
    'prayers': {for (final id in PrayerId.values) id.name: rule(id).toJson()},
    'customReminders': [for (final item in customReminders) item.toJson()]};

  factory PrayerSettings.fromJson(Map<String, dynamic> json) {
    final rawRules = json['prayers'];
    final rawCustom = json['customReminders'];
    final volume = json['volume'];
    if (json['version'] != 1 || json['enabled'] is! bool || json['respectSilent'] is! bool ||
        !prayerMethods.contains(json['method']) || !['hanafi', 'shafi'].contains(json['madhab']) ||
        !prayerHighLatitudeRules.contains(json['highLatitudeRule']) || !prayerLeadMinutes.contains(json['preReminderMinutes']) ||
        !['en', 'ur', 'ar'].contains(json['language']) || volume is! num || !volume.isFinite || volume < 0 || volume > 1 ||
        rawRules is! Map || rawCustom is! List || rawCustom.length > 10) throw const FormatException('Invalid prayer settings.');
    final rules = <PrayerId, PrayerRule>{};
    for (final id in PrayerId.values) {
      final value = rawRules[id.name];
      if (value is! Map) throw const FormatException('Missing prayer settings.');
      rules[id] = PrayerRule.fromJson(Map<String, dynamic>.from(value));
    }
    final custom = [for (final item in rawCustom) CustomPrayerReminder.fromJson(Map<String, dynamic>.from(item as Map))];
    if (custom.map((v) => v.id).toSet().length != custom.length) throw const FormatException('Duplicate custom reminders.');
    final rawLocation = json['location'];
    final location = rawLocation == null ? null : PrayerLocation.fromJson(Map<String, dynamic>.from(rawLocation as Map));
    if (json['enabled'] == true && location == null) throw const FormatException('Choose a location first.');
    return PrayerSettings(enabled: json['enabled'] as bool, location: location, method: json['method'] as String,
      madhab: json['madhab'] as String, highLatitudeRule: json['highLatitudeRule'] as String,
      preReminderMinutes: json['preReminderMinutes'] as int, volume: volume.toDouble(), respectSilent: json['respectSilent'] as bool,
      language: json['language'] as String, prayers: Map.unmodifiable(rules), customReminders: List.unmodifiable(custom));
  }
}

class PrayerEvent {
  const PrayerEvent({required this.id, required this.atUtc, required this.kind, required this.sound,
    this.prayer, this.customLabel});
  final String id;
  final DateTime atUtc;
  final String kind;
  final String sound;
  final PrayerId? prayer;
  final String? customLabel;
  String get label => customLabel ?? prayer?.label ?? 'Prayer reminder';
  String get recording => prayer == PrayerId.fajr ? 'fajr' : 'general';
}

const prayerCities = <PrayerLocation>[
  PrayerLocation(label: 'Karachi', latitude: 24.8607, longitude: 67.0011, zone: 'Asia/Karachi'),
  PrayerLocation(label: 'Lahore', latitude: 31.5204, longitude: 74.3587, zone: 'Asia/Karachi'),
  PrayerLocation(label: 'Islamabad', latitude: 33.6844, longitude: 73.0479, zone: 'Asia/Karachi'),
  PrayerLocation(label: 'Makkah', latitude: 21.4225, longitude: 39.8262, zone: 'Asia/Riyadh'),
  PrayerLocation(label: 'Madinah', latitude: 24.4672, longitude: 39.6111, zone: 'Asia/Riyadh'),
  PrayerLocation(label: 'Riyadh', latitude: 24.7136, longitude: 46.6753, zone: 'Asia/Riyadh'),
  PrayerLocation(label: 'Dubai', latitude: 25.2048, longitude: 55.2708, zone: 'Asia/Dubai'),
  PrayerLocation(label: 'London', latitude: 51.5074, longitude: -.1278, zone: 'Europe/London'),
  PrayerLocation(label: 'New York', latitude: 40.7128, longitude: -74.006, zone: 'America/New_York'),
  PrayerLocation(label: 'Toronto', latitude: 43.6532, longitude: -79.3832, zone: 'America/Toronto'),
  PrayerLocation(label: 'Delhi', latitude: 28.6139, longitude: 77.2090, zone: 'Asia/Kolkata'),
  PrayerLocation(label: 'Dhaka', latitude: 23.8103, longitude: 90.4125, zone: 'Asia/Dhaka'),
  PrayerLocation(label: 'Jakarta', latitude: -6.2088, longitude: 106.8456, zone: 'Asia/Jakarta'),
  PrayerLocation(label: 'Kuala Lumpur', latitude: 3.1390, longitude: 101.6869, zone: 'Asia/Kuala_Lumpur'),
  PrayerLocation(label: 'Istanbul', latitude: 41.0082, longitude: 28.9784, zone: 'Europe/Istanbul'),
  PrayerLocation(label: 'Cairo', latitude: 30.0444, longitude: 31.2357, zone: 'Africa/Cairo'),
  PrayerLocation(label: 'Paris', latitude: 48.8566, longitude: 2.3522, zone: 'Europe/Paris'),
  PrayerLocation(label: 'Sydney', latitude: -33.8688, longitude: 151.2093, zone: 'Australia/Sydney'),
];

int _integer(Object? value, int min, int max) {
  if (value is! int || value < min || value > max) throw const FormatException('Invalid prayer time.');
  return value;
}
int? _clock(Object? value) => value == null ? null : _integer(value, 0, 1439);
String _text(Object? value, int max) {
  if (value is! String || value.trim().isEmpty || value.length > max || RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid prayer text.');
  }
  return value.trim();
}
