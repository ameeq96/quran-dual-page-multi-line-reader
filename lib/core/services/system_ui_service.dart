import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'system_ui_fullscreen_stub.dart'
    if (dart.library.js_interop) 'system_ui_fullscreen_web.dart' as browser_ui;

abstract final class SystemUiService {
  static Future<void> allowReaderOrientations() {
    return SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  static Future<void> setFullscreen(bool enabled) async {
    if (kIsWeb) {
      await browser_ui.setBrowserFullscreen(enabled);
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        systemNavigationBarColor: Color(0x00000000),
      ),
    );
  }

  static Future<void> restoreDefaultUi() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await setFullscreen(false);
  }
}
