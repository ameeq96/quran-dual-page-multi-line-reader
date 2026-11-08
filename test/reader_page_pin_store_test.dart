import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/reader_page_pin_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const profileA = 'p_aaaaaaaaaaaaaaaaaaaaaaaa';
  const profileB = 'p_bbbbbbbbbbbbbbbbbbbbbbbb';
  var active = 'default';
  ReaderPagePinStore store({String profile = 'default', String edition = '16_lines', int page = 1}) =>
      ReaderPagePinStore(profileId: profile, edition: edition, page: page, activeProfileId: () => active);
  ReaderPagePin pin({String id = 'abcdefghijklmnop', String image = 'a', double x = .25, double y = .75,
      ReaderPagePinKind kind = ReaderPagePinKind.note, String note = 'Manual note'}) => ReaderPagePin(
    id: id, imageIdentity: image * 64, x: x, y: y, kind: kind, note: note,
    createdAt: '2026-11-08T12:00:00.000Z', updatedAt: '2026-11-08T12:00:00.000Z');

  setUp(() { active = 'default'; SharedPreferences.setMockInitialValues({}); });

  test('note and mistake pins persist with exact image identity and normalized coordinates', () async {
    final subject = store();
    await subject.save(pin());
    await subject.save(pin(id: 'bcdefghijklmnopq', kind: ReaderPagePinKind.mistake, note: 'Repeat this portion'));
    final restored = await store().load();
    expect(restored.length, 2);
    expect(restored.first.x, .25);
    expect(restored.first.y, .75);
    expect(restored.first.imageIdentity, 'a' * 64);
    expect(restored.last.kind, ReaderPagePinKind.mistake);
  });

  test('edition, page, profile and replacement image scopes remain separate', () async {
    await store().save(pin());
    await store().save(pin(id: 'bcdefghijklmnopq', image: 'b'));
    expect((await store().load()).where((entry) => entry.imageIdentity == 'a' * 64).length, 1);
    expect(await store(edition: '17_lines').load(), isEmpty);
    expect(await store(page: 2).load(), isEmpty);
    active = profileA;
    await store(profile: profileA).save(pin(note: 'Family profile note'));
    expect((await store(profile: profileA).load()).single.note, 'Family profile note');
    active = profileB;
    expect(await store(profile: profileB).load(), isEmpty);
    expect((await store().load()).length, 2);
  });

  test('invalid coordinates, notes and image fingerprints are rejected before persistence', () async {
    for (final invalid in [pin(x: double.nan), pin(x: double.infinity), pin(x: -.001), pin(y: 1.001),
      pin(note: 'x' * 2001), pin(image: 'z')]) {
      expect(() => store().save(invalid), throwsFormatException);
    }
    expect(await store().load(), isEmpty);
  });

  test('changing profile before writing cannot put an annotation in the new profile', () async {
    active = profileA;
    final original = store(profile: profileA);
    active = profileB;
    await expectLater(original.save(pin()), throwsStateError);
    expect(await store(profile: profileA).load(), isEmpty);
    expect(await store(profile: profileB).load(), isEmpty);
  });

  test('concurrent page writes preserve both annotations', () async {
    await Future.wait([
      store().save(pin()),
      store().save(pin(id: 'bcdefghijklmnopq', note: 'Second note')),
    ]);
    expect((await store().load()).map((entry) => entry.note), containsAll(['Manual note', 'Second note']));
  });

  test('editing a pin preserves identity and other image annotations', () async {
    final subject = store();
    await subject.save(pin());
    await subject.save(pin(id: 'bcdefghijklmnopq', image: 'b'));
    await subject.save(pin(x: .7, y: .4, kind: ReaderPagePinKind.mistake, note: 'Moved and edited'));
    final saved = await subject.load();
    expect(saved.length, 2);
    expect(saved.first.x, .7);
    expect(saved.first.kind, ReaderPagePinKind.mistake);
    expect(saved.last.imageIdentity, 'b' * 64);
    await expectLater(subject.save(pin(image: 'b')), throwsFormatException);
  });

  test('deleting a pin is bounded to its image and keeps other pins', () async {
    final subject = store();
    await subject.save(pin());
    await subject.save(pin(id: 'bcdefghijklmnopq', image: 'b'));
    await subject.remove(pinId: 'abcdefghijklmnop', imageIdentity: 'b' * 64);
    expect((await subject.load()).length, 2);
    await subject.remove(pinId: 'abcdefghijklmnop', imageIdentity: 'a' * 64);
    expect((await subject.load()).single.imageIdentity, 'b' * 64);
  });

  test('malformed stored records are kept and never overwritten by a new pin', () async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'reader.manualPins.v1.16_lines.1';
    const broken = '{"version":1,"pins":[{"x":900}]}';
    await prefs.setString(key, broken);
    await expectLater(store().load(), throwsFormatException);
    await expectLater(store().save(pin()), throwsFormatException);
    expect(prefs.getString(key), broken);
  });

  test('duplicate stored IDs cannot silently overwrite an annotation', () async {
    final prefs = await SharedPreferences.getInstance();
    final record = pin().toJson();
    await prefs.setString('reader.manualPins.v1.16_lines.1', jsonEncode({'version': 1, 'pins': [record, record]}));
    await expectLater(store().load(), throwsFormatException);
  });

  test('offline pack cleanup does not remove annotation storage', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader.offlinePack.16_lines', 'temporary pack metadata');
    await store().save(pin());
    await prefs.remove('reader.offlinePack.16_lines');
    expect((await store().load()).single.note, 'Manual note');
  });

  test('page limits stop growth without altering the installed records', () async {
    final subject = store();
    final prefs = await SharedPreferences.getInstance();
    final records = List.generate(ReaderPagePinStore.maximumPinsPerPage,
      (index) => pin(id: index.toString().padLeft(16, '0')).toJson());
    await prefs.setString('reader.manualPins.v1.16_lines.1', jsonEncode({'version': 1, 'pins': records}));
    await expectLater(subject.save(pin()), throwsStateError);
    expect((await subject.load()).length, ReaderPagePinStore.maximumPinsPerPage);
  });
}
