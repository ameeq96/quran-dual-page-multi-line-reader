import 'dart:async';

import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter/foundation.dart';

import '../prayer/prayer_models.dart';
import '../prayer/prayer_platform.dart';
import 'qibla_service_stub.dart'
    if (dart.library.io) 'qibla_service_io.dart'
    if (dart.library.html) 'qibla_service_web.dart'
    as platform;

class QiblaService extends ChangeNotifier {
  final _platform = platform.QiblaPlatform();
  StreamSubscription<Map<String, dynamic>>? _headings;
  Timer? _readingTimeout;
  Future<void>? _stopping;
  int _generation = 0;
  int _locationGeneration = 0;
  bool _disposed = false;
  bool _compassUnreliable = false;
  PrayerLocation? location;
  double? bearing;
  double? heading;
  double? accuracyMeters;
  bool trueNorth = true;
  bool locating = false;
  bool compassEnabled = false;
  String? locationError;
  String? compassMessage;

  bool get live => compassEnabled && heading != null;
  bool get compassUnreliable => live && _compassUnreliable;
  bool get stopping => _stopping != null;
  double? get arrowDegrees =>
      bearing == null ? null : (bearing! - (heading ?? 0) + 360) % 360;

  static double bearingFor(double latitude, double longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      throw const FormatException('Invalid coordinates.');
    }
    return adhan.Qibla.qibla(adhan.Coordinates(latitude, longitude));
  }

  void setLocation(PrayerLocation value, {double? accuracy}) {
    final nextBearing = bearingFor(value.latitude, value.longitude);
    ++_locationGeneration;
    unawaited(stopCompass());
    locating = false;
    location = value;
    bearing = nextBearing;
    accuracyMeters = accuracy;
    locationError = null;
    compassMessage = null;
    _notify();
  }

  Future<void> useCurrentLocation() async {
    if (locating || _disposed) return;
    locating = true;
    locationError = null;
    _notify();
    final generation = ++_locationGeneration;
    try {
      await stopCompass();
      if (_disposed || generation != _locationGeneration) return;
      final result = await PrayerPlatform().location().timeout(
        const Duration(seconds: 20),
      );
      if (_disposed || generation != _locationGeneration) return;
      final accuracy = result['accuracyMeters'];
      setLocation(
        PrayerLocation.fromJson(result),
        accuracy: accuracy is num ? accuracy.toDouble() : null,
      );
    } catch (_) {
      if (!_disposed && generation == _locationGeneration) {
        locationError =
            'Location is unavailable. Allow location access or enter coordinates manually.';
      }
    } finally {
      if (!_disposed && generation == _locationGeneration) {
        locating = false;
        _notify();
      }
    }
  }

  Future<void> startCompass() async {
    final place = location;
    if (_disposed || place == null || compassEnabled || stopping || locating)
      return;
    final generation = ++_generation;
    compassEnabled = true;
    heading = null;
    _compassUnreliable = false;
    compassMessage = 'Waiting for the compass…';
    _notify();
    _armReadingTimeout(generation, const Duration(seconds: 8));
    _headings = _platform.headings.listen(
      (value) {
        if (_disposed || generation != _generation || !compassEnabled) return;
        final next = value['heading'];
        final accuracy = value['accuracy'];
        final unreliableAndroidHeading = accuracy == 0 &&
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
        if (next is! num || !next.isFinite ||
            (accuracy == 0 && !unreliableAndroidHeading)) {
          _readingTimeout?.cancel();
          heading = null;
          compassMessage = value['message'] is String
              ? value['message'] as String
              : 'Move away from metal and calibrate your compass.';
        } else {
          heading = next.toDouble() % 360;
          _compassUnreliable = unreliableAndroidHeading;
          trueNorth = value['trueNorth'] == true;
          compassMessage = accuracy == 0 || accuracy == 1
              ? 'Compass accuracy is low. Move away from metal and calibrate your compass.'
              : null;
          _armReadingTimeout(generation, const Duration(seconds: 2));
        }
        _notify();
      },
      onError: (Object _) {
        if (_disposed || generation != _generation) return;
        _readingTimeout?.cancel();
        heading = null;
        compassMessage =
            'Live compass is unavailable. Align N with geographic north to use the bearing.';
        _notify();
      },
    );
    try {
      final supported = await _platform.start(
        latitude: place.latitude,
        longitude: place.longitude,
      );
      if (_disposed || generation != _generation) return;
      if (!supported) {
        await stopCompass();
        if (!_disposed) {
          compassMessage =
              'Live compass is unavailable. Align N with geographic north to use the bearing.';
          _notify();
        }
        return;
      }
    } catch (_) {
      if (_disposed || generation != _generation) return;
      await stopCompass();
      if (!_disposed) {
        compassMessage =
            'Compass permission or sensors are unavailable. Use the north-referenced bearing.';
        _notify();
      }
    }
  }

  void _armReadingTimeout(int generation, Duration delay) {
    _readingTimeout?.cancel();
    _readingTimeout = Timer(delay, () {
      if (!_disposed && generation == _generation && compassEnabled) {
        heading = null;
        _compassUnreliable = false;
        compassMessage =
            'No reliable compass reading. Hold your phone flat or use the north-referenced bearing.';
        _notify();
      }
    });
  }

  Future<void> stopCompass() {
    final existing = _stopping;
    if (existing != null) return existing;
    ++_generation;
    _readingTimeout?.cancel();
    _readingTimeout = null;
    compassEnabled = false;
    heading = null;
    _compassUnreliable = false;
    compassMessage = null;
    final subscription = _headings;
    _headings = null;
    final operation = _stop(subscription);
    _stopping = operation;
    _notify();
    return operation;
  }

  Future<void> _stop(
    StreamSubscription<Map<String, dynamic>>? subscription,
  ) async {
    try {
      await subscription?.cancel();
      await _platform.stop();
    } catch (_) {
      // The platform may have stopped itself while the screen was hidden.
    } finally {
      _stopping = null;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    ++_locationGeneration;
    _readingTimeout?.cancel();
    unawaited(_headings?.cancel());
    unawaited(_platform.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
