class WorshipSpeech {
  Future<void> speakArabic(String text) async {
    throw UnsupportedError(
      'Arabic device pronunciation is unavailable on this device.',
    );
  }

  Future<void> stop() async {}

  void dispose() {}
}
