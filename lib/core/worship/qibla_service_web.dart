// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';

@JS('globalThis.DeviceOrientationEvent')
external _OrientationConstructor? get _orientationConstructor;

extension type _OrientationConstructor(JSObject _) implements JSObject {
  external JSFunction? get requestPermission;
  @JS('requestPermission')
  external JSPromise<JSString> requestAbsolutePermission(bool absolute);
}

extension type _CompassEvent(JSObject _) implements JSObject {
  external double? get webkitCompassHeading;
  external double? get webkitCompassAccuracy;
}

class QiblaPlatform {
  final _headings = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<html.DeviceOrientationEvent>? _relative;
  StreamSubscription<html.DeviceOrientationEvent>? _absolute;
  int _generation = 0;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get headings => _headings.stream;

  Future<bool> start({
    required double latitude,
    required double longitude,
  }) async {
    final generation = ++_generation;
    if (html.window.isSecureContext != true) {
      return false;
    }
    final constructor = _orientationConstructor;
    if (constructor == null) {
      return false;
    }
    if (constructor.requestPermission != null) {
      final permission = await constructor
          .requestAbsolutePermission(true)
          .toDart;
      if (permission.toDart != 'granted') {
        throw StateError('Compass permission was not granted.');
      }
    }
    if (_disposed || generation != _generation) {
      return false;
    }
    await _relative?.cancel();
    await _absolute?.cancel();
    if (_disposed || generation != _generation) {
      return false;
    }
    _relative = html.window.onDeviceOrientation.listen(_onOrientation);
    _absolute = const html.EventStreamProvider<html.DeviceOrientationEvent>(
      'deviceorientationabsolute',
    ).forTarget(html.window).listen(_onOrientation);
    return true;
  }

  void _onOrientation(html.DeviceOrientationEvent event) {
    if (_disposed) {
      return;
    }
    final compass = _CompassEvent(event as JSObject);
    final safariHeading = compass.webkitCompassHeading;
    final safariAccuracy = compass.webkitCompassAccuracy;
    if (safariHeading == null && event.absolute != true) {
      return;
    }
    final angle =
        html.window.screen?.orientation?.angle ?? html.window.orientation ?? 0;
    final beta = event.beta;
    final gamma = event.gamma;
    if (angle != 0 ||
        beta == null ||
        gamma == null ||
        beta.abs() > 20 ||
        gamma.abs() > 20) {
      _headings.add({
        'message': 'Hold your phone flat in portrait orientation.',
      });
      return;
    }
    if (safariHeading != null && safariHeading.isFinite && safariHeading >= 0) {
      if (safariAccuracy != null &&
          (!safariAccuracy.isFinite ||
              safariAccuracy < 0 ||
              safariAccuracy > 50)) {
        _headings.add({
          'message': 'Move away from metal and calibrate your compass.',
        });
        return;
      }
      _headings.add({
        'heading': safariHeading.toDouble() % 360,
        'trueNorth': false,
        'accuracy': safariAccuracy != null && safariAccuracy > 15 ? 1 : 3,
      });
      return;
    }
    final alpha = event.alpha;
    if (event.absolute == true && alpha != null && alpha.isFinite) {
      _headings.add({
        'heading': (360 - alpha.toDouble()) % 360,
        'trueNorth': false,
        'accuracy': -1,
      });
    }
  }

  Future<void> stop() async {
    ++_generation;
    final relative = _relative;
    final absolute = _absolute;
    _relative = null;
    _absolute = null;
    await relative?.cancel();
    await absolute?.cancel();
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _headings.close();
  }
}
