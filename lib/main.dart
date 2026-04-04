import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/quran_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeBackgroundAudio();
  runApp(const QuranApp());
}

Future<void> _initializeBackgroundAudio() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.my_flutter_app.quran_audio',
      androidNotificationChannelName: 'Quran Recitation',
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 4));
  } catch (_) {
    // Reader startup must not block on background-audio setup.
  }
}
