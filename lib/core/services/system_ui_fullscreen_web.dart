import 'dart:js_interop';

@JS('document')
external _FullscreenDocument get _document;

extension type _FullscreenDocument(JSObject _) implements JSObject {
  external bool? get fullscreenEnabled;
  external JSObject? get fullscreenElement;
  external _FullscreenElement? get documentElement;
  external JSPromise<JSAny?> exitFullscreen();
}

extension type _FullscreenElement(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestFullscreen(_FullscreenOptions options);
}

extension type _FullscreenOptions._(JSObject _) implements JSObject {
  external factory _FullscreenOptions({String navigationUI});
}

Future<void> setBrowserFullscreen(bool enabled) async {
  try {
    if (enabled) {
      if (_document.fullscreenElement == null &&
          _document.fullscreenEnabled == true) {
        await _document.documentElement
            ?.requestFullscreen(_FullscreenOptions(navigationUI: 'hide'))
            .toDart;
      }
    } else if (_document.fullscreenElement != null) {
      await _document.exitFullscreen().toDart;
    }
  } catch (_) {
    // Keep in-app reading available if the browser refuses fullscreen.
  }
}
