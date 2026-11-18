import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as tz;

import '../../app/reader_localization.dart';
import '../storage/reader_profile_store.dart';

class ReaderReminderService extends ChangeNotifier {
  ReaderReminderService._({
    DateTime Function()? now,
    bool? inAppOverride,
    bool startTimer = true,
    bool initiallyActive = false,
  }) : _now = now ?? DateTime.now,
       _inAppOverride = inAppOverride,
       _startTimer = startTimer,
       _appActive = initiallyActive;

  @visibleForTesting
  factory ReaderReminderService.forTesting({
    required DateTime Function() now,
  }) => ReaderReminderService._(
    now: now,
    inAppOverride: true,
    startTimer: false,
    initiallyActive: true,
  );

  static final ReaderReminderService instance = ReaderReminderService._();
  String _profileId = 'default';
  String get _preferenceKey => ReaderProfileStore.keyFor('reader.dailyReminder.v1', _profileId);
  Future<void> switchLocalProfile(String profileId) => _enqueue(() async {
    if (_profileId == profileId) return;
    _inAppTimer?.cancel();
    _inAppReminderDue = false;
    _loaded = false;
    _enabled = false; _hour = 20; _minute = 0;
    _notBeforeDate = null; _lastDeliveredDate = null;
    _profileId = profileId;
    await _loadSettings();
    if (supported) await _syncSchedule();
  });
  static const _notificationId = 173016;
  final _notifications = FlutterLocalNotificationsPlugin();
  final DateTime Function() _now;
  final bool? _inAppOverride;
  final bool _startTimer;
  Timer? _inAppTimer;
  bool _appActive;
  bool _inAppReminderDue = false;
  String? _lastDeliveredDate;
  String? _notBeforeDate;
  Future<void> _operations = Future<void>.value();
  Future<void>? _initialization;
  bool _loaded = false;
  bool _pluginReady = false;
  bool _enabled = false;
  bool _busy = false;
  bool _scheduled = false;
  int _hour = 20;
  int _minute = 0;
  String? _timeZoneName;
  String? _errorMessage;

  bool get usesInAppReminders => _inAppOverride ?? kIsWeb;
  bool get inAppReminderDue =>
      usesInAppReminders && _enabled && _appActive && _inAppReminderDue;
  bool get supported =>
      usesInAppReminders ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));
  bool get enabled => _enabled;
  bool get busy => _busy;
  bool get scheduled => _scheduled;
  int get hour => _hour;
  int get minute => _minute;
  String? get timeZoneName => _timeZoneName;
  String? get errorMessage => _errorMessage;

  Future<void> setAppActive(bool active) async {
    _appActive = active;
    if (!active) {
      _inAppTimer?.cancel();
      _inAppTimer = null;
      notifyListeners();
      return;
    }
    await refreshSchedule();
  }

  void dismissInAppReminder() {
    if (!_inAppReminderDue) return;
    _inAppReminderDue = false;
    notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _enqueue(() async {
    await _loadSettings();
    if (supported) await _syncSchedule();
  });

  Future<void> refreshSchedule() async {
    await initialize();
    await _enqueue(() async {
      await _loadSettings();
      if (supported) await _syncSchedule();
    });
  }

  Future<void> setEnabled(bool enabled) async {
    await initialize();
    await _enqueue(() async {
      await _loadSettings();
      if (!supported) {
        throw const _ReminderFailure(
          'Daily reminders are unavailable on this device.',
        );
      }
      if (usesInAppReminders) {
        await _saveSettings(
          enabled: enabled,
          hour: _hour,
          minute: _minute,
          notBeforeDate: _firstEligibleDate(_hour, _minute),
        );
        if (!enabled) _inAppReminderDue = false;
        await _syncSchedule();
        return;
      }
      await _initializePlugin();
      if (enabled) {
        final bool? granted;
        if (defaultTargetPlatform == TargetPlatform.android) {
          granted = await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission();
        } else {
          granted = await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true);
        }
        if (granted != true || !await _permissionGranted()) {
          throw const _ReminderFailure(
            'Notifications are blocked. Enable them in your device settings, then try again.',
          );
        }
      }
      await _saveSettings(enabled: enabled, hour: _hour, minute: _minute);
      await _syncSchedule();
    });
  }

  Future<void> setTime({required int hour, required int minute}) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid reminder time');
    }
    await initialize();
    await _enqueue(() async {
      await _loadSettings();
      if (!supported) {
        throw const _ReminderFailure(
          'Daily reminders are unavailable on this device.',
        );
      }
      await _saveSettings(
        enabled: _enabled,
        hour: hour,
        minute: minute,
        notBeforeDate: usesInAppReminders
            ? _firstEligibleDate(hour, minute)
            : null,
      );
      await _syncSchedule();
    });
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _operations.then((_) async {
      _busy = true;
      _errorMessage = null;
      notifyListeners();
      try {
        await action();
      } on _ReminderFailure catch (error) {
        _errorMessage = error.message;
      } catch (_) {
        _errorMessage = 'Reminder could not be updated. Try again.';
      } finally {
        _busy = false;
        notifyListeners();
      }
    });
    _operations = operation;
    return operation;
  }

  Future<void> _loadSettings() async {
    if (_loaded) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_preferenceKey);
      if (value != null) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map<String, dynamic>) {
            _enabled = decoded['enabled'] == true;
            final delivered = decoded['lastDeliveredDate'];
            final notBefore = decoded['notBeforeDate'];
            _lastDeliveredDate = delivered is String ? delivered : null;
            _notBeforeDate = notBefore is String ? notBefore : null;
            final hour = decoded['hour'];
            final minute = decoded['minute'];
            if (hour is int && hour >= 0 && hour < 24) _hour = hour;
            if (minute is int && minute >= 0 && minute < 60) _minute = minute;
          }
        } on FormatException {
          _enabled = false;
        }
      }
      _loaded = true;
    } catch (_) {
      throw const _ReminderFailure(
        'Reminder settings could not be loaded. Try again.',
      );
    }
  }

  Future<void> _saveSettings({
    required bool enabled,
    required int hour,
    required int minute,
    String? notBeforeDate,
    String? lastDeliveredDate,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _preferenceKey,
        jsonEncode({
          'enabled': enabled,
          'hour': hour,
          'minute': minute,
          if (notBeforeDate ?? _notBeforeDate case final date?)
            'notBeforeDate': date,
          if (lastDeliveredDate ?? _lastDeliveredDate case final date?)
            'lastDeliveredDate': date,
        }),
      );
      if (!saved) throw StateError('Settings were not saved');
      _enabled = enabled;
      _hour = hour;
      _minute = minute;
      _notBeforeDate = notBeforeDate ?? _notBeforeDate;
      _lastDeliveredDate = lastDeliveredDate ?? _lastDeliveredDate;
    } catch (_) {
      throw const _ReminderFailure(
        'Reminder changes could not be saved. Try again.',
      );
    }
  }

  Future<void> _initializePlugin() async {
    if (_pluginReady) return;
    try {
      await _notifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_quran'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            requestProvisionalPermission: false,
          ),
        ),
      );
      time_zone_data.initializeTimeZones();
      _pluginReady = true;
    } catch (_) {
      throw const _ReminderFailure(
        'Daily reminders are unavailable on this device.',
      );
    }
  }

  Future<bool> _permissionGranted() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    final permissions = await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.checkPermissions();
    return permissions != null &&
        (permissions.isEnabled || permissions.isProvisionalEnabled);
  }

  Future<void> _syncSchedule() async {
    if (usesInAppReminders) {
      await _syncInAppSchedule();
      return;
    }
    await _initializePlugin();
    try {
      await _notifications.cancel(_notificationId);
      _scheduled = false;
    } catch (_) {
      throw const _ReminderFailure(
        'Reminder could not be cancelled. Try again.',
      );
    }
    if (!_enabled) return;
    if (!await _permissionGranted()) {
      throw const _ReminderFailure(
        'Notifications are blocked. Enable them in your device settings, then try again.',
      );
    }
    final tz.Location location;
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      location = tz.getLocation(name);
      _timeZoneName = name;
    } catch (_) {
      throw const _ReminderFailure(
        'Could not detect the device time zone. Try again.',
      );
    }
    final strings = ReaderLocalization.instance;
    try {
      await _notifications.zonedSchedule(
        _notificationId,
        strings.translate('Time for Quran'),
        strings.translate(
          'Read a few pages and revisit your Hifz revision queue.',
        ),
        nextDailyTime(tz.TZDateTime.now(location), _hour, _minute),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'quran_daily_reading',
            strings.translate('Daily reading reminders'),
            channelDescription: strings.translate(
              'Optional reminders to read Quran and revise memorized pages.',
            ),
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(presentBadge: false),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      final pending = await _notifications.pendingNotificationRequests();
      if (!pending.any((request) => request.id == _notificationId)) {
        throw StateError('Daily reminder was not registered');
      }
      _scheduled = true;
    } catch (_) {
      throw const _ReminderFailure(
        'Reminder could not be scheduled. Try again.',
      );
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _firstEligibleDate(int hour, int minute) {
    final now = _now().toLocal();
    final selected = DateTime(now.year, now.month, now.day, hour, minute);
    return _dateKey(
      DateTime(now.year, now.month, now.day + (selected.isAfter(now) ? 0 : 1)),
    );
  }

  Future<void> _syncInAppSchedule() async {
    _scheduled = _enabled;
    if (!_enabled || !_appActive) {
      _inAppTimer?.cancel();
      _inAppTimer = null;
      if (!_enabled) _inAppReminderDue = false;
      return;
    }
    if (_startTimer) {
      _inAppTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
        if (!_busy && _appActive) unawaited(refreshSchedule());
      });
    }
    final now = _now().toLocal();
    final today = _dateKey(now);
    if ((_notBeforeDate != null && today.compareTo(_notBeforeDate!) < 0) ||
        (_lastDeliveredDate != null &&
            today.compareTo(_lastDeliveredDate!) <= 0) ||
        now.isBefore(DateTime(now.year, now.month, now.day, _hour, _minute))) {
      return;
    }
    await _saveSettings(
      enabled: _enabled,
      hour: _hour,
      minute: _minute,
      lastDeliveredDate: today,
    );
    _inAppReminderDue = true;
  }

  @override
  void dispose() {
    _inAppTimer?.cancel();
    super.dispose();
  }

  @visibleForTesting
  static tz.TZDateTime nextDailyTime(tz.TZDateTime now, int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Invalid reminder time');
    }
    var day = now.day;
    var next = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      day,
      hour,
      minute,
    );
    while (!next.isAfter(now) || next.hour != hour || next.minute != minute) {
      next = tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        ++day,
        hour,
        minute,
      );
    }
    return next;
  }
}

class _ReminderFailure implements Exception {
  const _ReminderFailure(this.message);

  final String message;
}
