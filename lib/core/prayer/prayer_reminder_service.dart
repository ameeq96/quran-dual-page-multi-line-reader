import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/reader_preferences.dart';
import '../storage/reader_profile_store.dart';
import '../worship/worship_store.dart';
import 'prayer_calculator.dart';
import 'prayer_models.dart';
import 'prayer_platform.dart';
import 'prayer_push_client.dart';

class PrayerReminderService extends ChangeNotifier {
  PrayerReminderService._() {
    _platform.messages.listen(_onPush);
    prayerSettingsBusy = () => busy;
  }
  static final instance = PrayerReminderService._();
  final _platform = PrayerPlatform();
  PrayerSettings settings = const PrayerSettings();
  bool busy = false, loaded = false;
  String? error;
  String _profileId = 'default';
  String baseUrl = '';
  Map<String, dynamic> _status = {};
  PrayerPushClient? _push;
  WorshipStore? _worship;
  Map<PrayerId, DateTime> todayTimes = {};
  PrayerEvent? nextEvent, currentEvent;
  Future<void> Function()? beforeAudio;
  Timer? _timer;
  bool _active = true, _ticking = false;
  DateTime _notBefore = DateTime.now().toUtc();
  final Set<String> _delivered = {};
  Future<void> _operations = Future.value();
  Future<void>? _initializing;
  Future<T> _serial<T>(Future<T> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
  String get _settingsKey => ReaderProfileStore.keyFor('reader.prayer.settings.v1', _profileId);
  String get _deliveryKey => ReaderProfileStore.keyFor('reader.prayer.delivered.v1', _profileId);
  bool get isAndroid => _platform.isAndroid;
  bool get isWeb => _platform.isWeb;
  bool get supported => _platform.supported;
  bool get audioEnabled => _platform.audioEnabled;
  bool get playing => isAndroid ? _status['playing'] == true || _status['playingEventId'] != null : _platform.playing;
  bool get exactAlarmAllowed => _status['exactAlarmAllowed'] == true;
  bool get notificationsAllowed => _status['notificationsAllowed'] == true;
  bool get armed => _anyReminders && nextEvent != null && (isAndroid ? _status['scheduled'] == true : isWeb && audioEnabled);
  bool get _anyReminders => settings.enabled || _worship?.ramadan?['enabled'] == true || _worship?.masjid?['enabled'] == true;
  bool get backgroundSupported => _platform.backgroundSupported;
  bool get backgroundEnabled => _push?.enabled == true;
  bool get backgroundConfigured => _push?.configured == true;
  bool get backgroundBusy => _push?.busy == true;
  String? get backgroundError => _push?.error;

  Future<void> initialize({String? baseUrl}) => _initializing ??=
      _serial(() => _initialize(baseUrl: baseUrl)).whenComplete(() { _initializing = null; });
  Future<void> _initialize({String? baseUrl, String? profileId}) async {
    if (loaded) {
      if (baseUrl != null && baseUrl.isNotEmpty && this.baseUrl != baseUrl) _attachPush(baseUrl);
      return;
    }
    try {
      PrayerCalculator.initialize();
      _profileId = profileId ?? ReaderProfileStore.instance.activeId;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_settingsKey);
      if (raw != null) settings = PrayerSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      _delivered.addAll(prefs.getStringList(_deliveryKey) ?? []);
      _worship = WorshipStore(profileId: _profileId);
      await _worship!.load();
      final base = baseUrl ?? await ReaderPreferences(profileId: _profileId).loadAdminPublicBaseUrl();
      _attachPush(base);
    } catch (_) { error = 'Prayer settings could not be loaded. Select your location and save them again.'; }
    loaded = true;
    _notBefore = DateTime.now().toUtc();
    try { await _apply(); } catch (_) { error = 'Prayer alarms could not be scheduled. Check permissions.'; }
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_tick()));
    notifyListeners();
  }
  void _attachPush(String value) {
    baseUrl = ReaderPreferences.normalizeSyncBaseUrl(value);
    if (!isWeb) return;
    _push?.removeListener(_pushChanged);
    _push = PrayerPushClient.forProfile(baseUrl, _profileId, _platform)..addListener(_pushChanged);
    if (isWeb) unawaited(_push!.initialize());
  }
  void _pushChanged() => notifyListeners();
  Future<void> switchProfile(String profileId, {String? baseUrl}) => _serial(() async {
    if (_profileId == profileId && loaded) return;
    await _platform.cancel();
    _push?.removeListener(_pushChanged);
    _push = null;
    _worship?.dispose(); _worship = null;
    loaded = false; settings = const PrayerSettings(); currentEvent = null; nextEvent = null;
    todayTimes = {}; _delivered.clear(); _status = {}; error = null;
    _profileId = profileId;
    await _initialize(baseUrl: baseUrl, profileId: profileId);
  });
  void setAppActive(bool value) {
    _active = value;
    if (value && loaded) unawaited(refresh());
  }
  Future<bool> _mutate(Future<void> Function() operation) async {
    if (busy) return false;
    final profile = _profileId;
    busy = true; error = null; notifyListeners();
    try {
      await _serial(() async {
        if (profile != _profileId) throw const FormatException('The reader profile changed. Open prayer settings again.');
        await operation();
      });
      return true;
    }
    catch (e) {
      error = e is FormatException ? e.message : e is PlatformException ? e.message ?? 'Prayer service is unavailable.' :
          'Prayer settings could not be applied. Check location, permissions and connection.';
      return false;
    } finally { busy = false; notifyListeners(); }
  }
  Future<bool> updateSettings(PrayerSettings value) => _mutate(() async {
    final validated = PrayerSettings.fromJson(value.toJson());
    _validateTimes(validated);
    if (validated.enabled && isWeb) await _platform.prepareAudio();
    if (!validated.enabled && backgroundEnabled && !await _push!.setEnabled(false, settings)) {
      throw const FormatException('Reconnect to disable background prayer notifications, then try again.');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_settingsKey, jsonEncode(validated.toJson()))) throw StateError('Could not save settings.');
    settings = validated;
    _notBefore = DateTime.now().toUtc();
    await _apply();
    if (backgroundEnabled && !await _push!.setEnabled(true, settings, requestPermission: false)) {
      error = 'Local settings saved. Background notification settings could not be updated; reconnect and retry.';
    }
  });
  void _validateTimes(PrayerSettings validated) {
    if (validated.location != null) PrayerCalculator.zone(validated);
    if (validated.enabled) {
      final times = PrayerCalculator.timesForDate(validated, PrayerCalculator.dateInZone(DateTime.now(), validated));
      if (PrayerId.values.any((id) => validated.rule(id).enabled && !times.containsKey(id))) {
        throw const FormatException('Automatic times are unavailable here. Set manual times or choose another calculation method.');
      }
    }
  }
  Future<bool> setEnabled(bool value) {
    if (value && isWeb) unawaited(_platform.enableAudio());
    return updateSettings(settings.copyWith(enabled: value));
  }
  Future<void> _apply() async {
    _calculate();
    if (settings.location == null || (!isAndroid && !_anyReminders)) { await _platform.cancel(); currentEvent = null; _status = await _platform.status(); return; }
    _status = await _platform.configure({...settings.toJson(), 'profileId': _profileId,
      'worship': {'ramadan': _worship?.ramadan, 'masjid': _worship?.masjid}});
    final nativeError = _status['error'];
    if (nativeError is String && nativeError.isNotEmpty) error = nativeError;
  }
  Future<bool> refreshWorship() => _mutate(() async {
    final next = WorshipStore(profileId: _profileId);
    await next.load();
    _worship?.dispose(); _worship = next;
    _notBefore = DateTime.now().toUtc();
    await _apply();
  });
  List<PrayerEvent> _allEventsAround(DateTime instant, {int forwardDays = 2}) {
    final day = PrayerCalculator.dateInZone(instant, settings);
    final events = <PrayerEvent>[
      if (settings.enabled) ...PrayerCalculator.eventsAround(settings, instant, forwardDays: forwardDays),
      for (var offset = -1; offset <= forwardDays; offset++)
        ...WorshipSchedule.eventsForDate(settings, day.add(Duration(days: offset)),
          ramadan: _worship?.ramadan, masjid: _worship?.masjid),
    ];
    // An ordinary Adhan at the exact same instant already marks Iftar/Jamaat.
    final adhanInstants = events.where((e) => e.kind == 'adhan' && e.sound != 'silent').map((e) => e.atUtc).toSet();
    events.removeWhere((e) => e.kind == 'worship' && adhanInstants.contains(e.atUtc));
    events.sort((a, b) => a.atUtc.compareTo(b.atUtc));
    return events;
  }
  void _calculate() {
    if (settings.location == null) { todayTimes = {}; nextEvent = null; return; }
    final now = DateTime.now().toUtc();
    todayTimes = PrayerCalculator.timesForDate(settings, PrayerCalculator.dateInZone(now, settings));
    nextEvent = null;
    if (!_anyReminders) return;
    for (final item in _allEventsAround(now, forwardDays: 8)) {
      if (item.atUtc.isAfter(now)) { nextEvent = item; break; }
    }
  }
  Future<void> _tick() async {
    if (!loaded || _ticking || (!_active && !isWeb)) return;
    _ticking = true;
    try { await _serial(() async {
      _calculate();
      if (isAndroid) {
        _status = await _platform.status();
        final playingId = _status['playingEventId'];
        if (playingId is String && settings.location != null) {
          for (final event in _allEventsAround(DateTime.now())) {
            if (playingId == event.id || playingId == '$_profileId:${event.id}') { currentEvent = event; break; }
          }
        }
      }
      if (isWeb && _anyReminders && settings.location != null) {
        final now = DateTime.now().toUtc();
        final events = _allEventsAround(now).where((event) =>
          !event.atUtc.isBefore(_notBefore) && !event.atUtc.isAfter(now) && now.difference(event.atUtc).inSeconds <= 120 &&
          !_delivered.contains(event.id)).toList();
        // A simultaneous main Adhan takes priority over a short auxiliary alert.
        events.sort((a, b) => (a.kind == 'adhan' ? 0 : 1).compareTo(b.kind == 'adhan' ? 0 : 1));
        var sounded = false;
        for (final event in events) {
          if (event.kind == 'worship' && !audioEnabled) continue;
          if (await _claim(event)) {
            if (!sounded) { await _deliver(event); sounded = event.sound != 'silent'; }
          }
        }
      }
      notifyListeners();
    }); } catch (_) { error = 'Prayer reminder check failed. Open settings to retry.'; notifyListeners(); }
    finally { _ticking = false; }
  }
  Future<bool> _claim(PrayerEvent event) async {
    if (_delivered.contains(event.id)) return false;
    final token = newCustomId();
    if (!await _platform.claim('quran.prayer.$_profileId.${event.id}', token)) { _delivered.add(event.id); return false; }
    _delivered.add(event.id);
    while (_delivered.length > 200) { _delivered.remove(_delivered.first); }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deliveryKey, _delivered.toList());
    return true;
  }
  Future<void> _deliver(PrayerEvent event) async {
    if (event.sound != 'azan' && playing) return;
    currentEvent = event; notifyListeners();
    if (event.sound == 'silent') return;
    if (event.sound == 'tone') {
      try { await _platform.play('tone', settings.volume, settings.respectSilent); }
      catch (_) { error = 'Tap Enable Azan audio to allow reminder sounds in this browser.'; }
      return;
    }
    if (beforeAudio != null) await beforeAudio!();
    try { await _platform.play(event.recording, settings.volume, settings.respectSilent); }
    catch (_) { error = 'Tap Enable Azan audio to allow sound in this browser.'; }
  }
  void _onPush(Map<String, dynamic> payload) {
    if (!isWeb || !settings.enabled || payload['instanceId'] != _push?.instanceId) return;
    unawaited(_tick());
  }
  Future<bool> useLocation() => _mutate(() async {
    final result = await _platform.location();
    final location = PrayerLocation.fromJson(result);
    PrayerCalculator.zone(settings.copyWith(location: location));
    final prefs = await SharedPreferences.getInstance();
    final changed = settings.copyWith(location: location);
    _validateTimes(changed);
    if (!await prefs.setString(_settingsKey, jsonEncode(changed.toJson()))) throw StateError('Could not save location.');
    settings = changed;
    await _apply();
    if (backgroundEnabled) await _push!.setEnabled(true, settings, requestPermission: false);
  });
  Future<bool> requestExactAlarm() => _mutate(() async { _status = await _platform.requestExactAlarm(); await _apply(); });
  Future<bool> requestNotifications() => _mutate(() async { _status = await _platform.requestNotifications(); await _apply(); });
  Future<bool> enableAudio() async {
    final result = await _platform.enableAudio();
    error = result ? null : 'Sound is blocked. Allow audio for this website, then retry.';
    notifyListeners(); return result;
  }
  Future<bool> preview({bool fajr = false}) async {
    error = null;
    try {
      if (beforeAudio != null) unawaited(beforeAudio!().catchError((Object _) {}));
      await _platform.play(fajr ? 'fajr' : 'general', settings.volume, settings.respectSilent);
      _status = await _platform.status(); notifyListeners(); return true;
    } catch (_) { error = 'Azan could not play. Check sound permission and try again.'; notifyListeners(); return false; }
  }
  Future<void> stop() async { await _platform.stop(); _status = await _platform.status(); currentEvent = null; notifyListeners(); }
  void dismissCurrentEvent() { currentEvent = null; notifyListeners(); }
  Future<void> refresh() async {
    if (!loaded) { await initialize(); return; }
    try { await _serial(() async { _status = await _platform.status(); _calculate(); }); }
    catch (_) { error = 'Prayer service is unavailable. Retry from settings.'; }
    if (isWeb && _push != null) unawaited(_push!.refresh());
    notifyListeners();
  }
  Future<bool> setBackgroundEnabled(bool value, {bool locationConsent = false}) async {
    if (_push == null) return false;
    final success = await _push!.setEnabled(value, settings, locationConsent: locationConsent);
    notifyListeners(); return success;
  }
  static String newCustomId() => base64UrlEncode(List.generate(18, (_) => Random.secure().nextInt(256))).replaceAll('=', '');
}
