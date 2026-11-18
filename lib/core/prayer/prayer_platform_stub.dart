class PrayerPlatform {
  bool get isAndroid => false;
  bool get isWeb => false;
  bool get supported => false;
  bool get backgroundSupported => false;
  bool get audioEnabled => false;
  bool get playing => false;
  Stream<Map<String, dynamic>> get messages => const Stream.empty();
  Future<Map<String, dynamic>> status() async => {};
  Future<Map<String, dynamic>> configure(Map<String, dynamic> settings) async => {};
  Future<void> cancel() async {}
  Future<bool> enableAudio() async => false;
  Future<void> prepareAudio() async {}
  Future<void> play(String sound, double volume, bool respectSilent) async {}
  Future<void> stop() async {}
  Future<Map<String, dynamic>> location() async => throw UnsupportedError('Location is unavailable.');
  Future<Map<String, dynamic>> requestExactAlarm() => status();
  Future<Map<String, dynamic>> requestNotifications() => status();
  Future<Map<String, dynamic>> subscribe(String key, {bool requestPermission = true}) async => throw UnsupportedError('Background notifications are unavailable.');
  Future<void> unsubscribe() async {}
  Future<bool> claim(String key, String value) async => true;
}
