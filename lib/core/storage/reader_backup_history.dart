import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'reader_profile_store.dart';

class ReaderRestorePoint {
  const ReaderRestorePoint({required this.id, required this.createdAt, required this.reason, required this.backup});
  final String id;
  final DateTime createdAt;
  final String reason;
  final String backup;
}

class ReaderBackupHistory {
  ReaderBackupHistory({required this.profileId, SharedPreferences? preferences}) : _injected = preferences;
  final String profileId;
  final SharedPreferences? _injected;
  static const maxPoints = 15;
  static const maxBytes = 3000000;
  Future<void> _writes = Future.value();
  Future<SharedPreferences> get _prefs async => _injected ?? await SharedPreferences.getInstance();
  String get _key => ReaderProfileStore.keyFor('reader.backupHistory.v1', profileId);
  String _canonical(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic> || value['settings'] is! Map) throw const FormatException('Invalid restore point.');
    return jsonEncode({...value}..remove('exportedAtIso')..remove('updatedAtIso')..remove('deviceId'));
  }
  Future<List<ReaderRestorePoint>> list() async {
    final raw = (await _prefs).getString(_key);
    if (raw == null) return [];
    if (utf8.encode(raw).length > maxBytes) throw const FormatException('Restore history is unreadable.');
    final list = jsonDecode(raw);
    if (list is! List || list.length > maxPoints) throw const FormatException('Restore history is unreadable.');
    return list.map((item) {
      if (item is! Map || item['id'] is! String || item['reason'] is! String || item['backup'] is! String ||
          item['date'] is! String || DateTime.tryParse(item['date']) == null) {
        throw const FormatException('Restore history is unreadable.');
      }
      _canonical(item['backup']);
      return ReaderRestorePoint(id: item['id'], createdAt: DateTime.parse(item['date']), reason: item['reason'], backup: item['backup']);
    }).toList();
  }
  Future<void> save(String backup, {required String reason, bool force = false}) {
    final next = _writes.then((_) async {
      final canonical = _canonical(backup);
      final previous = await list();
      if (!force && previous.isNotEmpty && _canonical(previous.first.backup) == canonical) {
        if (!reason.startsWith('Before ') || previous.first.reason.startsWith('Before ')) return;
        previous.removeAt(0);
      }
      final now = DateTime.now().toUtc();
      final points = [ReaderRestorePoint(id: '${now.microsecondsSinceEpoch}', createdAt: now, reason: reason, backup: backup), ...previous];
      String encode() => jsonEncode([for (final p in points) {'id': p.id, 'date': p.createdAt.toIso8601String(), 'reason': p.reason, 'backup': p.backup}]);
      while (points.length > maxPoints) { points.removeLast(); }
      while (points.length > 1 && utf8.encode(encode()).length > maxBytes) { points.removeLast(); }
      final data = encode();
      if (utf8.encode(data).length > maxBytes) throw StateError('Restore point is too large. Export a backup first.');
      if (!await (await _prefs).setString(_key, data)) throw StateError('Unable to save restore history.');
    });
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }
}
