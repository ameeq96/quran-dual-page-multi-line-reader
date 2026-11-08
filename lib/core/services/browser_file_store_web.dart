import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:typed_data';

@JS('navigator.storage')
external _BrowserStorage? get _browserStorage;

extension type _BrowserStorage(JSObject _) implements JSObject {
  external JSPromise<_BrowserStorageEstimate> estimate();
}

extension type _BrowserStorageEstimate(JSObject _) implements JSObject {
  external JSNumber? get usage;
  external JSNumber? get quota;
}

class BrowserFileStore {
  BrowserFileStore._();
  static final BrowserFileStore instance = BrowserFileStore._();
  final Map<String, String> _urls = {};
  final Map<String, int> _sizes = {};
  final Map<String, Map<String, dynamic>> manifests = {};
  dynamic _database;
  Future<void>? _opening;

  Set<String> get keys => _urls.keys.toSet();
  String? urlFor(String key) => _urls[key];

  Future<void> initialize() => _opening ??= _open();

  Future<void> _open() async {
    final factory = html.window.indexedDB;
    if (factory == null) {
      throw StateError('This browser does not support offline storage.');
    }
    try {
      final database = await factory.open(
        'quran_reader_offline',
        version: 1,
        onUpgradeNeeded: (event) {
          final database = (event.target as dynamic).result;
          database.createObjectStore('files');
        },
      );
      _database = database;
      final transaction = database.transaction('files', 'readonly');
      await for (final cursor in transaction.objectStore('files').openCursor(autoAdvance: true)) {
        final key = cursor.key as String;
        final value = cursor.value;
        if (value is html.Blob) {
          _urls[key] = html.Url.createObjectUrlFromBlob(value);
          _sizes[key] = value.size;
        } else if (value is Map) {
          manifests[key] = Map<String, dynamic>.from(value);
        }
      }
      await transaction.completed;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> putBytes(String key, Uint8List bytes, String mimeType) async {
    await initialize();
    final blob = html.Blob([bytes], mimeType);
    final transaction = _database!.transaction('files', 'readwrite');
    await transaction.objectStore('files').put(blob, key);
    await transaction.completed;
    final previous = _urls.remove(key);
    if (previous != null) html.Url.revokeObjectUrl(previous);
    _urls[key] = html.Url.createObjectUrlFromBlob(blob);
    _sizes[key] = bytes.length;
  }

  int bytesForPrefix(String prefix) => _sizes.entries
      .where((entry) => entry.key.startsWith(prefix))
      .fold(0, (total, entry) => total + entry.value);

  Future<Uint8List> readBytes(List<String> keys) async {
    await initialize();
    final transaction = _database!.transaction('files', 'readonly');
    final blobs = <html.Blob>[];
    for (final key in keys) {
      final blob = await transaction.objectStore('files').getObject(key);
      if (blob is! html.Blob) throw StateError('Offline download chunk is missing.');
      blobs.add(blob);
    }
    await transaction.completed;
    final reader = html.FileReader()..readAsArrayBuffer(html.Blob(blobs));
    await reader.onLoadEnd.first;
    if (reader.error != null) throw StateError('Unable to read offline download.');
    return reader.result as Uint8List;
  }

  Future<Map<String, int>> storageEstimate() async {
    try {
      final storage = _browserStorage;
      if (storage == null) return const {};
      final value = await storage.estimate().toDart;
      final usage = value.usage?.toDartInt;
      final quota = value.quota?.toDartInt;
      return {if (usage != null) 'usage': usage, if (quota != null) 'quota': quota};
    } catch (_) {
      return const {};
    }
  }

  Future<void> putManifest(String key, Map<String, dynamic> value) async {
    await initialize();
    final transaction = _database!.transaction('files', 'readwrite');
    await transaction.objectStore('files').put(value, key);
    await transaction.completed;
    manifests[key] = Map<String, dynamic>.from(value);
  }

  Future<void> removePrefix(String prefix) async {
    await initialize();
    final matching = {..._urls.keys, ...manifests.keys}
        .where((key) => key.startsWith(prefix)).toList();
    if (matching.isEmpty) return;
    final transaction = _database!.transaction('files', 'readwrite');
    final store = transaction.objectStore('files');
    await Future.wait(matching.map(store.delete));
    await transaction.completed;
    for (final key in matching) {
      final url = _urls.remove(key);
      if (url != null) html.Url.revokeObjectUrl(url);
      manifests.remove(key);
      _sizes.remove(key);
    }
  }
}
