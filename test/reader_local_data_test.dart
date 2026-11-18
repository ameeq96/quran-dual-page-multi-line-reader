import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_flutter_app/core/storage/reader_profile_store.dart';
import 'package:my_flutter_app/core/storage/reader_preferences.dart';
import 'package:my_flutter_app/core/storage/reader_backup_history.dart';
import 'package:my_flutter_app/core/services/reader_reminder_service.dart';
import 'package:my_flutter_app/app/reader_localization.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_growth_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profile = 'p_0123456789abcdef01234567';
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('creating a profile preserves existing default reader preferences', () async {
    SharedPreferences.setMockInitialValues({'reader.lastPageNumber': 1052, ReaderLocalization.storageKey: 'urdu'});
    final store = ReaderProfileStore();
    await store.load();
    final id = await store.create('Family');
    expect(store.activeId, 'default');
    await store.activate(id);
    final reloaded = ReaderProfileStore();
    await reloaded.load();
    expect(reloaded.activeId, id);
    expect(await ReaderPreferences().loadLastPageNumber(), 1052);
    expect(await ReaderPreferences(profileId: id).loadLastPageNumber(), 1);
    expect((await SharedPreferences.getInstance()).getString(ReaderLocalization.storageKey), 'urdu');
  });
  test('reader data and private identities are isolated including concurrent loads', () async {
    final main = ReaderPreferences();
    final other = ReaderPreferences(profileId: profile);
    await main.saveLastPageNumber(25);
    await other.saveLastPageNumber(55);
    await main.savePageNotesByEdition({'16_line': {25: 'Main note'}});
    await other.savePageNotesByEdition({'16_line': {55: 'Family note'}});
    final identities = await Future.wait([main.loadOrCreateSyncIdentity('https://example.com'), other.loadOrCreateSyncIdentity('https://example.com')]);
    expect(identities[0].deviceId, isNot(identities[1].deviceId));
    expect(identities[0].token, isNot(identities[1].token));
    expect(await main.loadLastPageNumber(), 25);
    expect(await other.loadLastPageNumber(), 55);
    expect((await main.loadPageNotesByEdition())['16_line'], {25: 'Main note'});
    expect((await other.loadPageNotesByEdition())['16_line'], {55: 'Family note'});
    expect((await other.loadExperienceSettings()).syncMode, ReaderSyncMode.localOnly);
  });
  test('settings writes captured in one profile cannot land in another', () async {
    final main = ReaderPreferences(); final other = ReaderPreferences(profileId: profile);
    final original = await main.loadSettings();
    await Future.wait([main.saveSettings(original.copyWith(nightMode: true)), other.saveSettings(original.copyWith(nightMode: false))]);
    expect((await main.loadSettings()).nightMode, isTrue);
    expect((await other.loadSettings()).nightMode, isFalse);
  });
  test('interface language belongs to the selected profile and legacy language is kept', () async {
    final locale = ReaderLocalization();
    await locale.setLanguage(ReaderLanguage.arabic);
    await locale.loadForProfile(profile);
    expect(locale.language, ReaderLanguage.english);
    await locale.setLanguage(ReaderLanguage.urdu);
    await locale.loadForProfile('default');
    expect(locale.language, ReaderLanguage.arabic);
    await locale.loadForProfile(profile);
    expect(locale.language, ReaderLanguage.urdu);
    locale.dispose();
  });
  test('profile validation rejects corrupt metadata without overwriting it', () async {
    const corrupt = '{"version":1,"activeId":"missing","profiles":[]}';
    SharedPreferences.setMockInitialValues({ReaderProfileStore.storageKey: corrupt});
    await expectLater(ReaderProfileStore().load(), throwsFormatException);
    expect((await SharedPreferences.getInstance()).getString(ReaderProfileStore.storageKey), corrupt);
    expect(() => ReaderPreferences(profileId: '../other'), throwsArgumentError);
  });
  test('foreground reminders switch profile settings without carrying old state', () async {
    final reminder = ReaderReminderService.forTesting(now: () => DateTime(2026, 11, 8, 10));
    addTearDown(reminder.dispose);
    await reminder.initialize();
    await reminder.setTime(hour: 9, minute: 10);
    await reminder.setEnabled(true);
    await reminder.switchLocalProfile(profile);
    expect(reminder.enabled, isFalse);
    expect(reminder.hour, 20);
    await reminder.setTime(hour: 7, minute: 25);
    await reminder.switchLocalProfile('default');
    expect(reminder.enabled, isTrue);
    expect(reminder.hour, 9);
    expect(reminder.minute, 10);
    await reminder.switchLocalProfile(profile);
    expect(reminder.hour, 7);
    expect(reminder.minute, 25);
  });
  test('profile count and names are bounded, rename keeps identity', () async {
    final store = ReaderProfileStore();
    for (var i = 0; i < 7; i++) { await store.create('Reader $i'); }
    await expectLater(store.create('Ninth'), throwsArgumentError);
    final p = store.profiles.last;
    await store.rename(p.id, 'Renamed');
    expect(store.profiles.last.id, p.id);
    expect(store.profiles.last.name, 'Renamed');
  });
  String backup(int page, {String? note}) => jsonEncode({'formatVersion': 2, 'settings': {'mushafEdition': '16_line'}, 'lastPageNumber': page,
    'pageNotes': {if (note != null) '$page': note}, 'exportedAtIso': DateTime.now().toIso8601String()});
  test('history preserves pre-delete snapshot and stores an undo for restore', () async {
    final history = ReaderBackupHistory(profileId: 'default');
    final before = backup(12, note: 'Keep this');
    await history.save(before, reason: 'Before changing note');
    final deleted = backup(12);
    await history.save(deleted, reason: 'Before restoring backup', force: true);
    final points = await history.list();
    expect(points.length, 2);
    expect(points.last.backup, before);
    expect(points.first.backup, deleted);
    expect((await ReaderBackupHistory(profileId: profile).list()), isEmpty);
  });
  test('automatic snapshot becomes an Undo point before an identical pre-delete save', () async {
    final history = ReaderBackupHistory(profileId: 'default');
    final before = backup(12, note: 'Keep this');
    await history.save(before, reason: 'Automatic backup');
    await history.save(before, reason: 'Before changing note');
    await history.save(backup(12), reason: 'Automatic backup');
    final points = await history.list();
    final undo = points.firstWhere((p) => p.reason.startsWith('Before '));
    expect(undo.backup, before);
    expect(points.length, 2);
  });
  test('history serializes concurrent saves, deduplicates dates and bounds retention', () async {
    final history = ReaderBackupHistory(profileId: 'default');
    await Future.wait([for (var i = 1; i < 30; i++) history.save(backup(i), reason: 'Automatic backup')]);
    final points = await history.list();
    expect(points.length, ReaderBackupHistory.maxPoints);
    expect(jsonDecode(points.first.backup)['lastPageNumber'], 29);
    await history.save(backup(29), reason: 'Automatic backup');
    expect((await history.list()).first.id, points.first.id);
  });
  test('corrupt history fails closed and is never cleared by a new save', () async {
    const raw = 'invalid JSON';
    SharedPreferences.setMockInitialValues({'reader.backupHistory.v1': raw});
    final history = ReaderBackupHistory(profileId: 'default');
    await expectLater(history.save(backup(1), reason: 'Manual backup'), throwsFormatException);
    expect((await SharedPreferences.getInstance()).getString('reader.backupHistory.v1'), raw);
  });
}
