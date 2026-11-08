import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/reader_profile_store.dart';

enum ReaderPagePinKind { note, mistake }

class ReaderPagePin {
  const ReaderPagePin({required this.id, required this.imageIdentity,
    required this.x, required this.y, required this.kind, required this.note,
    required this.createdAt, required this.updatedAt});
  final String id;
  final String imageIdentity;
  final double x;
  final double y;
  final ReaderPagePinKind kind;
  final String note;
  final String createdAt;
  final String updatedAt;

  static String newId() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(12, (_) => random.nextInt(256)));
  }

  Map<String, dynamic> toJson() => {'id': id, 'imageIdentity': imageIdentity,
    'x': x, 'y': y, 'kind': kind.name, 'note': note,
    'createdAt': createdAt, 'updatedAt': updatedAt};

  static ReaderPagePin fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException('Invalid manual pin data.');
    final id = value['id'];
    final image = value['imageIdentity'];
    final x = value['x'];
    final y = value['y'];
    final kind = value['kind'];
    final note = value['note'];
    final created = value['createdAt'];
    final updated = value['updatedAt'];
    if (id is! String || !RegExp(r'^[A-Za-z0-9_-]{16}$').hasMatch(id) ||
        image is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(image) ||
        x is! num || !x.isFinite || x < 0 || x > 1 ||
        y is! num || !y.isFinite || y < 0 || y > 1 ||
        !ReaderPagePinKind.values.any((entry) => entry.name == kind) ||
        note is! String || note.length > 2000 ||
        created is! String || DateTime.tryParse(created) == null ||
        updated is! String || DateTime.tryParse(updated) == null) {
      throw const FormatException('Invalid manual pin data.');
    }
    return ReaderPagePin(id: id, imageIdentity: image, x: x.toDouble(), y: y.toDouble(),
        kind: ReaderPagePinKind.values.firstWhere((entry) => entry.name == kind),
        note: note, createdAt: created, updatedAt: updated);
  }
}

class ReaderPagePinStore {
  ReaderPagePinStore({required this.profileId, required this.edition, required this.page,
    required String Function() activeProfileId}) : _activeProfileId = activeProfileId {
    if (!ReaderProfileStore.validId(profileId) ||
        !RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(edition) || page < 1 || page > 10000) {
      throw const FormatException('Invalid manual pin location.');
    }
  }
  final String profileId;
  final String edition;
  final int page;
  final String Function() _activeProfileId;
  static const int maximumPinsPerPage = 100;
  static final Map<String, Future<void>> _writes = {};
  String get _key => ReaderProfileStore.keyFor('reader.manualPins.v1.$edition.$page', profileId);

  Future<List<ReaderPagePin>> load() async {
    final pending = _writes[_key];
    if (pending != null) await pending;
    return _read();
  }

  Future<List<ReaderPagePin>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return const [];
    if (stored.length > 1000000) throw const FormatException('Manual pin data could not be read.');
    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1 || decoded['pins'] is! List ||
        (decoded['pins'] as List).length > maximumPinsPerPage) {
      throw const FormatException('Manual pin data could not be read.');
    }
    final pins = (decoded['pins'] as List).map(ReaderPagePin.fromJson).toList(growable: false);
    if (pins.map((entry) => entry.id).toSet().length != pins.length) {
      throw const FormatException('Manual pin data could not be read.');
    }
    return pins;
  }

  Future<void> save(ReaderPagePin pin) {
    final validated = ReaderPagePin.fromJson(pin.toJson());
    return _mutate((pins) {
      final index = pins.indexWhere((entry) => entry.id == validated.id);
      if (index >= 0 && pins[index].imageIdentity != validated.imageIdentity) {
        throw const FormatException('A pin belongs to a different scan image.');
      }
      if (index >= 0) {
        pins[index] = validated;
      } else {
        if (pins.length >= maximumPinsPerPage) throw StateError('This page already has 100 manual pins. Remove a pin first.');
        pins.add(validated);
      }
    });
  }

  Future<void> remove({required String pinId, required String imageIdentity}) =>
      _mutate((pins) => pins.removeWhere((entry) => entry.id == pinId && entry.imageIdentity == imageIdentity));

  Future<void> _mutate(void Function(List<ReaderPagePin>) update) {
    final previous = _writes[_key] ?? Future<void>.value();
    final operation = previous.then((_) async {
      void requireProfile() {
        if (_activeProfileId() != profileId) throw StateError('Profile changed. Reopen the page before editing pins.');
      }
      requireProfile();
      final pins = List<ReaderPagePin>.from(await _read());
      requireProfile();
      update(pins);
      final prefs = await SharedPreferences.getInstance();
      requireProfile();
      final payload = jsonEncode({'version': 1, 'pins': pins.map((entry) => entry.toJson()).toList()});
      if (!await prefs.setString(_key, payload)) throw StateError('Manual pin could not be saved. Try again.');
    });
    final settled = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _writes[_key] = settled;
    Future<void> cleanup() async {
      await settled;
      if (identical(_writes[_key], settled)) _writes.remove(_key);
    }
    cleanup();
    return operation;
  }
}
