import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderLocalProfile {
  const ReaderLocalProfile(this.id, this.name);
  final String id;
  final String name;
}

class ReaderProfileStore extends ChangeNotifier {
  ReaderProfileStore({SharedPreferences? preferences}) : _injected = preferences;
  static final instance = ReaderProfileStore();
  static const storageKey = 'reader.localProfiles.v1';
  final SharedPreferences? _injected;
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  String _activeId = 'default';
  List<ReaderLocalProfile> _profiles = const [ReaderLocalProfile('default', 'Main reader')];
  String get activeId => _activeId;
  List<ReaderLocalProfile> get profiles => List.unmodifiable(_profiles);
  static bool validId(String id) => id == 'default' || RegExp(r'^p_[a-f0-9]{24}$').hasMatch(id);
  static String keyFor(String key, String profileId) {
    if (!validId(profileId)) throw ArgumentError('Invalid local profile.');
    return profileId == 'default' ? key : 'reader.profile.$profileId.$key';
  }
  Future<SharedPreferences> get _prefs async => _injected ?? await SharedPreferences.getInstance();
  Future<void> load() => _loading ??= _load().catchError((Object error) {
    _loading = null;
    throw error;
  });
  Future<void> _load() async {
    final raw = (await _prefs).getString(storageKey);
    if (raw == null) return;
    if (raw.length > 5000) throw const FormatException('Local profiles are unreadable.');
    final value = jsonDecode(raw);
    if (value is! Map || value['version'] != 1 || value['profiles'] is! List) {
      throw const FormatException('Local profiles are unreadable.');
    }
    final list = <ReaderLocalProfile>[];
    for (final item in value['profiles'] as List) {
      if (item is! Map || item['id'] is! String || !validId(item['id']) ||
          item['name'] is! String || (item['name'] as String).trim().isEmpty ||
          (item['name'] as String).length > 40 || list.any((p) => p.id == item['id'])) {
        throw const FormatException('Local profiles are unreadable.');
      }
      list.add(ReaderLocalProfile(item['id'], item['name']));
    }
    if (list.isEmpty || list.length > 8 || !list.any((p) => p.id == 'default') ||
        !list.any((p) => p.id == value['activeId'])) {
      throw const FormatException('Local profiles are unreadable.');
    }
    _profiles = list;
    _activeId = value['activeId'];
  }
  Future<void> _update(List<ReaderLocalProfile> profiles, String active) async {
    if (!await (await _prefs).setString(storageKey, jsonEncode({
      'version': 1, 'activeId': active,
      'profiles': [for (final p in profiles) {'id': p.id, 'name': p.name}],
    }))) {
      throw StateError('Unable to save local profiles.');
    }
    _profiles = profiles;
    _activeId = active;
    notifyListeners();
  }
  Future<T> _serial<T>(Future<T> Function() task) {
    final next = _writes.then((_) => task());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
  Future<String> create(String name) => _serial(() async {
    await load();
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 40 || _profiles.length >= 8) {
      throw ArgumentError('Use a name of 1–40 characters. Up to 8 profiles are supported.');
    }
    final random = Random.secure();
    final id = 'p_${List.generate(12, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    await _update([..._profiles, ReaderLocalProfile(id, clean)], _activeId);
    return id;
  });
  Future<void> activate(String id) => _serial(() async {
    await load();
    if (!_profiles.any((p) => p.id == id)) throw ArgumentError('Unknown local profile.');
    if (_activeId != id) await _update(_profiles, id);
  });
  Future<void> rename(String id, String name) => _serial(() async {
    await load();
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 40 || !_profiles.any((p) => p.id == id)) {
      throw ArgumentError('Use a name of 1–40 characters.');
    }
    await _update([for (final p in _profiles) p.id == id ? ReaderLocalProfile(id, clean) : p], _activeId);
  });
}
