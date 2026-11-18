// Uses the app's existing conditional browser bridge without a native dependency.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/quran_reader/domain/models/quran_surah_navigation_entry.dart';
import '../../features/quran_reader/domain/models/reader_settings.dart';
import '../../features/quran_reader/presentation/controllers/quran_reader_controller.dart';
import '../storage/reader_profile_store.dart';

const _readerRouteName = 'quran-web-mushaf-reader';
const RouteSettings? readerWebSurahRouteSettings = RouteSettings(
  name: _readerRouteName,
);

ReaderWebSurahNavigation? createReaderWebSurahNavigation(String profileId) =>
    ReaderWebSurahNavigation._instances.putIfAbsent(
      profileId,
      () => ReaderWebSurahNavigation._(profileId),
    );

class ReaderWebSurahNavigation extends NavigatorObserver {
  ReaderWebSurahNavigation._(this.profileId);

  static final Map<String, ReaderWebSurahNavigation> _instances = {};
  static ReaderWebSurahNavigation? _active;
  static bool _listening = false;
  static const _indexAssets = <String, String>{
    '10_lines': 'assets/quran_pages/quran_navigation_index_10_line.json',
    '13_lines': 'assets/quran_pages/quran_navigation_index_13_line.json',
    '14_lines': 'assets/quran_pages/quran_navigation_index_14_line.json',
    '15_lines': 'assets/quran_pages/quran_navigation_index_15_line.json',
    '16_lines': 'assets/quran_pages/quran_navigation_index_16_line.json',
    '17_lines': 'assets/quran_pages/quran_navigation_index_17_line.json',
    'kanzul_iman': 'assets/quran_pages/quran_navigation_index_kanzul_iman.json',
  };

  final String profileId;
  final List<Route<dynamic>> _routes = [];
  Object? _owner;
  QuranReaderController? _controller;
  Future<void>? _readyFuture;
  VoidCallback? _openReader;
  int _generation = 0;
  _SurahNavigationRequest? _pending;

  Route<dynamic>? get _topRoute => _routes.isEmpty ? null : _routes.last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) _routes.clear();
    _routes.remove(route);
    _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
  }

  void bind({
    required Object owner,
    required QuranReaderController controller,
    required Future<void> readyFuture,
    required VoidCallback openReader,
  }) {
    _active?._cancelPending(
      'The reader changed. Please choose the Surah again.',
    );
    _generation++;
    _owner = owner;
    _controller = controller;
    _readyFuture = readyFuture;
    _openReader = openReader;
    _active = this;
    if (!_listening) {
      _listening = true;
      html.window.addEventListener('quran-reader-open-surah', _receiveOpen);
      html.window.addEventListener('quran-reader-surah-cancel', _receiveCancel);
    }
    html.document.documentElement?.dataset['readerSurahNavigation'] = 'bound';
    html.window.dispatchEvent(
      html.CustomEvent('quran-reader-navigation-ready'),
    );
  }

  void unbind(Object owner) {
    if (!identical(_owner, owner)) return;
    _cancelPending('The reader changed. Please choose the Surah again.');
    _generation++;
    _owner = null;
    _controller = null;
    _readyFuture = null;
    _openReader = null;
    if (identical(_active, this)) {
      _active = null;
      html.document.documentElement?.dataset.remove('readerSurahNavigation');
    }
  }

  static Map<String, dynamic>? _payload(html.Event event) {
    if (event is! html.CustomEvent || event.detail is! String) return null;
    final raw = event.detail as String;
    if (raw.length > 2048) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) return null;
      final requestId = value['requestId'];
      if (requestId is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(requestId))
        return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  static void _receiveOpen(html.Event event) {
    final bridge = _active;
    final payload = _payload(event);
    if (bridge == null || bridge._owner == null || payload == null) return;
    // The HTML caller needs a synchronous acknowledgement before dispatch returns.
    event.preventDefault();
    final requestId = payload['requestId'] as String;
    final surahId = payload['surahId'];
    if (surahId is! int || surahId < 1 || surahId > 114) {
      _reply(requestId, false, 'Choose a valid Surah.');
      return;
    }
    if (bridge._pending != null) {
      _reply(requestId, false, 'The reader is opening a Surah. Please wait.');
      return;
    }
    final request = _SurahNavigationRequest(
      requestId,
      surahId,
      bridge._owner!,
      bridge._generation,
    );
    bridge._pending = request;
    unawaited(bridge._navigate(request));
  }

  static void _receiveCancel(html.Event event) {
    final payload = _payload(event);
    final bridge = _active;
    if (payload == null ||
        bridge == null ||
        bridge._pending?.requestId != payload['requestId'])
      return;
    bridge._pending!.cancelled = true;
    bridge._pending = null;
  }

  static void _reply(String requestId, bool success, [String? message]) {
    html.window.dispatchEvent(
      html.CustomEvent(
        'quran-reader-surah-result',
        detail: jsonEncode({
          'requestId': requestId,
          'success': success,
          if (message != null) 'message': message,
        }),
      ),
    );
  }

  void _cancelPending(String message) {
    final request = _pending;
    if (request == null) return;
    request.cancelled = true;
    _pending = null;
    _reply(request.requestId, false, message);
  }

  void _checkCurrent(
    _SurahNavigationRequest request, {
    MushafEdition? edition,
  }) {
    if (request.cancelled ||
        !identical(_pending, request) ||
        !identical(_active, this) ||
        !identical(_owner, request.owner) ||
        _generation != request.generation ||
        ReaderProfileStore.instance.activeId != profileId ||
        _controller == null) {
      throw const _SurahNavigationFailure(
        'The reader changed. Please choose the Surah again.',
      );
    }
    final expectedEdition = edition ?? request.edition;
    if ((expectedEdition != null &&
            _controller!.settings.mushafEdition != expectedEdition) ||
        (request.editionFence != null &&
            !identical(
              request.editionFence,
              _controller!.pendingMushafEditionChange,
            ))) {
      throw const _SurahNavigationFailure(
        'The selected edition changed. Please choose the Surah again.',
      );
    }
  }

  Future<void> _navigate(_SurahNavigationRequest request) async {
    try {
      _checkCurrent(request);
      final ready = _readyFuture;
      if (ready == null)
        throw const _SurahNavigationFailure('The reader is not ready yet.');
      await ready.timeout(const Duration(seconds: 20));
      _checkCurrent(request);
      final controller = _controller!;
      if (controller.isLoading)
        throw const _SurahNavigationFailure(
          'The reader is still loading. Please try again.',
        );
      await _openSurah(request, controller).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          request.cancelled = true;
          throw const _SurahNavigationFailure(
            'The selected edition is taking too long to load. Please try again.',
          );
        },
      );
      _checkCurrent(request);
      _reply(request.requestId, true);
    } on _SurahNavigationFailure catch (error) {
      if (identical(_pending, request))
        _reply(request.requestId, false, error.message);
    } on TimeoutException {
      request.cancelled = true;
      if (identical(_pending, request))
        _reply(
          request.requestId,
          false,
          'The reader is taking too long to start. Please try again.',
        );
    } catch (_) {
      if (identical(_pending, request))
        _reply(
          request.requestId,
          false,
          'The Surah could not be opened in the selected edition. Please try again.',
        );
    } finally {
      if (identical(_pending, request)) _pending = null;
    }
  }

  Future<void> _openSurah(
    _SurahNavigationRequest request,
    QuranReaderController controller,
  ) async {
    while (true) {
      _checkCurrent(request);
      final fence = controller.pendingMushafEditionChange;
      await fence;
      _checkCurrent(request);
      if (identical(fence, controller.pendingMushafEditionChange)) {
        request.editionFence = fence;
        break;
      }
    }
    final edition = controller.settings.mushafEdition;
    request.edition = edition;
    _checkCurrent(request);
    final asset = _indexAssets[edition.storageValue];
    if (asset == null)
      throw const _SurahNavigationFailure(
        'This edition has no available Surah index.',
      );
    final raw = await rootBundle.loadString(asset);
    _checkCurrent(request, edition: edition);
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['surahs'] is! List) {
      throw const _SurahNavigationFailure(
        'This edition has no usable Surah index.',
      );
    }
    final matches = (decoded['surahs'] as List)
        .whereType<Map>()
        .where((entry) => _readInt(entry['id']) == request.surahId)
        .toList();
    final active = controller.surahEntries
        .where((entry) => entry.id == request.surahId)
        .toList();
    if (matches.length != 1 || active.length != 1) {
      throw const _SurahNavigationFailure(
        'This Surah is not indexed for the selected edition.',
      );
    }
    final indexed = matches.single;
    final standard = _readInt(indexed['standardStartPage']);
    final anchor = _readInt(indexed['tajScanStartPage']) ?? standard;
    final QuranSurahNavigationEntry entry = active.single;
    if (standard == null ||
        anchor == null ||
        standard < 1 ||
        anchor < 1 ||
        entry.standardStartPage != standard ||
        entry.tajScanStartPage != anchor) {
      throw const _SurahNavigationFailure(
        'The selected edition\'s Surah index does not match.',
      );
    }
    if (!controller.isMushafEditionReady(edition)) {
      throw const _SurahNavigationFailure(
        'The original pages are unavailable for the selected edition. Download its page pack and try again.',
      );
    }
    if (!controller.settings.preferImageMode) {
      await controller.togglePreferImageMode(true);
      _checkCurrent(request, edition: edition);
    }
    _checkCurrent(request, edition: edition);
    final target = controller.navigationPageForSurahEntry(entry);
    final page = controller.pageForNumber(target);
    if (target < 1 ||
        target > controller.totalPages ||
        !page.usesImage ||
        page.assetPath == null ||
        page.assetPath!.isEmpty) {
      throw const _SurahNavigationFailure(
        'The original page image is unavailable in the selected edition.',
      );
    }
    await controller.jumpToSurah(entry);
    _checkCurrent(request, edition: edition);
    if (controller.currentPageNumber != target) {
      throw const _SurahNavigationFailure(
        'The selected Surah page changed. Please try again.',
      );
    }
    if (_topRoute?.settings.name != _readerRouteName ||
        _topRoute?.isCurrent != true) {
      _openReader!();
      _checkCurrent(request, edition: edition);
    }
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.isFinite ? value.toInt() : null;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed) ??
          int.tryParse(RegExp(r'\d+').firstMatch(trimmed)?.group(0) ?? '');
    }
    return null;
  }
}

class _SurahNavigationRequest {
  _SurahNavigationRequest(
    this.requestId,
    this.surahId,
    this.owner,
    this.generation,
  );
  final String requestId;
  final int surahId;
  final Object owner;
  final int generation;
  Future<void>? editionFence;
  MushafEdition? edition;
  bool cancelled = false;
}

class _SurahNavigationFailure implements Exception {
  const _SurahNavigationFailure(this.message);
  final String message;
}
