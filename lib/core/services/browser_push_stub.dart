class BrowserPush {
  bool get supported => false;
  String get timeZone => 'UTC';
  Future<Map<String, dynamic>> subscribe(String publicKey, {bool requestPermission = true}) async =>
      throw UnsupportedError('Background notifications need a supported secure browser.');
  Future<void> unsubscribe() async {}
}
