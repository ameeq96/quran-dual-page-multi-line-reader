import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderDownloadPolicy {
  static const _wifiOnlyKey = 'reader.downloads.wifiOnly.v1';
  final Connectivity _connectivity = Connectivity();
  bool wifiOnly = false;

  bool get supportsWifiOnly => !kIsWeb;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    wifiOnly = supportsWifiOnly && (preferences.getBool(_wifiOnlyKey) ?? false);
  }

  Future<void> setWifiOnly(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_wifiOnlyKey, enabled)) {
      throw StateError('Unable to save download setting.');
    }
    wifiOnly = supportsWifiOnly && enabled;
  }

  static bool hasWifi(List<ConnectivityResult> connections) =>
      connections.contains(ConnectivityResult.wifi);

  Future<bool> allowsDownload() async {
    if (!wifiOnly) return true;
    try {
      return hasWifi(await _connectivity.checkConnectivity());
    } catch (_) {
      return false;
    }
  }

  Stream<bool> get allowedChanges => supportsWifiOnly
      ? _connectivity.onConnectivityChanged
          .map((connections) => !wifiOnly || hasWifi(connections))
      : const Stream<bool>.empty();

  Future<int?> availableStorageBytes() async {
    if (kIsWeb) return null;
    try {
      final mebibytes = await DiskSpace.getFreeDiskSpace;
      return mebibytes == null ? null : (mebibytes * 1024 * 1024).floor();
    } catch (_) {
      return null;
    }
  }
}
