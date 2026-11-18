import 'dart:typed_data';

class BrowserFileStore {
  BrowserFileStore._();
  static final BrowserFileStore instance = BrowserFileStore._();
  final Map<String, Map<String, dynamic>> manifests = {};
  Set<String> get keys => const {};
  Future<void> initialize() async {}
  String? urlFor(String key) => null;
  Future<void> putBytes(String key, Uint8List bytes, String mimeType) async {
    throw UnsupportedError('Browser storage is only available on the web.');
  }
  Future<void> putManifest(String key, Map<String, dynamic> value) async {
    throw UnsupportedError('Browser storage is only available on the web.');
  }
  int bytesForPrefix(String prefix) => 0;
  Future<Uint8List> readBytes(List<String> keys) async => Uint8List(0);
  Future<Map<String, int>> storageEstimate() async => const {};
  Future<void> removePrefix(String prefix) async {}
}
