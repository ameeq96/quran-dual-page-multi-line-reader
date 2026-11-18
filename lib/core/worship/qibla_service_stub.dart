class QiblaPlatform {
  Stream<Map<String, dynamic>> get headings => const Stream.empty();
  Future<bool> start({
    required double latitude,
    required double longitude,
  }) async => false;
  Future<void> stop() async {}
  Future<void> dispose() async {}
}
