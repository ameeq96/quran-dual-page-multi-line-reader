import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/quran_app.dart';
import 'features/quran_reader/presentation/widgets/quran_page_image_provider.dart';

final _memoryPressureObserver = _ImageCachePressureObserver();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureImageCache();
  WidgetsBinding.instance.addObserver(_memoryPressureObserver);
  unawaited(_initializeBackgroundAudio());
  runApp(const QuranApp());
}

void _configureImageCache() {
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSizeBytes = 160 << 20;
  cache.maximumSize = 220;
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

class _ImageCachePressureObserver extends WidgetsBindingObserver {
  @override
  void didHaveMemoryPressure() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    clearQuranPageImageProviderCache();
  }
}
