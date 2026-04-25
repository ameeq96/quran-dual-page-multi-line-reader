import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/storage/reader_preferences.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_settings.dart';

class QuranAdminConfigService {
  static const String _productionAdminBaseUrl =
      'https://adminapi.opplexify.com';
  static const Duration _requestTimeout = Duration(seconds: 4);

  QuranAdminConfigService({
    required ReaderPreferences preferences,
    http.Client? client,
  })  : _preferences = preferences,
        _client = client ?? http.Client();

  final ReaderPreferences _preferences;
  final http.Client _client;

  ReaderAdminConfig _currentConfig = const ReaderAdminConfig.empty();
  String _currentBaseUrl = '';

  ReaderAdminConfig get currentConfig => _currentConfig;
  String get currentBaseUrl => _currentBaseUrl;

  Future<ReaderAdminConfig> loadConfig({bool forceRefresh = false}) async {
    final preferredBaseUrl = await _preferences.loadAdminPublicBaseUrl();
    final candidateBaseUrls = _buildCandidateBaseUrls(preferredBaseUrl);
    _currentBaseUrl =
        candidateBaseUrls.isEmpty ? preferredBaseUrl : candidateBaseUrls.first;
    if (candidateBaseUrls.isEmpty) {
      throw StateError('Admin API base URL is not configured.');
    }

    for (final candidateBaseUrl in candidateBaseUrls) {
      final normalizedBaseUrl = _normalizeBaseUrl(candidateBaseUrl);
      final uri = Uri.tryParse('$normalizedBaseUrl/public/config');
      if (uri == null) {
        continue;
      }

      try {
        final response = await _client.get(
          uri,
          headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': 'quran_dual_page/1.0',
          },
        ).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          final parsedConfig = _configFromJsonString(
            response.body,
            publicBaseUrl: normalizedBaseUrl,
            source: ReaderAdminConfigSource.live,
          );
          if (parsedConfig == null) {
            continue;
          }
          _currentBaseUrl = normalizedBaseUrl;
          _currentConfig = parsedConfig;
          await _preferences.saveAdminPublicConfigJson(response.body);
          return _currentConfig;
        }
      } catch (error) {
        if (error is StateError) {
          continue;
        }
      }
    }

    final cachedPayload = await _preferences.loadAdminPublicConfigJson();
    final cachedBaseUrl = _normalizeBaseUrl(
      preferredBaseUrl.trim().isNotEmpty
          ? preferredBaseUrl
          : _productionAdminBaseUrl,
    );
    final cachedConfig = _configFromJsonString(
      cachedPayload,
      publicBaseUrl: cachedBaseUrl,
      source: ReaderAdminConfigSource.cached,
    );
    if (cachedConfig != null) {
      _currentBaseUrl = cachedBaseUrl;
      _currentConfig = cachedConfig;
      return _currentConfig;
    }

    _currentConfig = _currentConfig.isEmpty
        ? const ReaderAdminConfig.empty()
        : _currentConfig;
    return _currentConfig;
  }

  List<String> _buildCandidateBaseUrls(String preferredBaseUrl) {
    final candidates = <String>[];

    void addCandidate(String value) {
      final normalized = _normalizeBaseUrl(value);
      if (normalized.isEmpty || candidates.contains(normalized)) {
        return;
      }
      candidates.add(normalized);
    }

    addCandidate(preferredBaseUrl);
    addCandidate(_productionAdminBaseUrl);

    if (kIsWeb) {
      return candidates;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final preferredUri = Uri.tryParse(preferredBaseUrl.trim());
      final scheme = preferredUri?.scheme.trim().isNotEmpty == true
          ? preferredUri!.scheme
          : 'http';
      final port = preferredUri?.hasPort == true ? preferredUri!.port : 5052;
      addCandidate('$scheme://127.0.0.1:$port');
      addCandidate('$scheme://localhost:$port');
      addCandidate('$scheme://10.0.2.2:$port');
    }

    addCandidate('http://localhost:5052');
    return candidates;
  }

  ReaderAdminConfig? _configFromJsonString(
    String? jsonString, {
    required String publicBaseUrl,
    required ReaderAdminConfigSource source,
  }) {
    if (jsonString == null || jsonString.trim().isEmpty) {
      return null;
    }

    try {
      final payload = json.decode(jsonString) as Map<String, dynamic>;
      final rawAssetsBaseUrl = payload['assetsBaseUrl'] as String? ?? '';
      final normalizedPublicBase = _normalizeBaseUrl(publicBaseUrl);
      final normalizedAssetsBase = rawAssetsBaseUrl.trim().isEmpty
          ? '$normalizedPublicBase/assets'
          : _normalizeBaseUrl(rawAssetsBaseUrl);

      final assetPacks = <MushafEdition, ReaderRemoteAssetPack>{};
      final rawAssetPacks = payload['assetPacks'] as List<dynamic>? ?? const [];
      for (final item in rawAssetPacks.whereType<Map<String, dynamic>>()) {
        final rawEdition = (item['edition'] as String? ?? '').trim();
        final edition = _parseEdition(rawEdition);
        if (edition == null) {
          continue;
        }
        final normalizedExtension =
            (item['fileExtension'] as String? ?? 'webp').trim().toLowerCase();
        final folderName = (item['folderName'] as String? ?? rawEdition).trim();
        final availableImportedPages = (item['availableImportedPages']
                    as List<dynamic>? ??
                const <dynamic>[])
            .map((value) =>
                value is num ? value.toInt() : int.tryParse('$value'))
            .whereType<int>()
            .where((value) => value > 0)
            .toSet()
            .toList()
          ..sort();
        final contiguousImportedPageStart =
            (item['contiguousImportedPageStart'] as num?)?.toInt();
        final contiguousImportedPageEnd =
            (item['contiguousImportedPageEnd'] as num?)?.toInt();
        assetPacks[edition] = ReaderRemoteAssetPack(
          edition: edition,
          folderName: folderName.isEmpty ? rawEdition : folderName,
          version: (item['version'] as String? ?? '').trim(),
          pageCount: (item['pageCount'] as num? ?? 0).toInt(),
          fileExtension:
              normalizedExtension.isEmpty ? 'webp' : normalizedExtension,
          availableImportedPages:
              List<int>.unmodifiable(availableImportedPages),
          contiguousImportedPageStart: contiguousImportedPageStart,
          contiguousImportedPageEnd: contiguousImportedPageEnd,
        );
      }

      final contentDatasets = <String, ReaderRemoteContentDataset>{};
      final rawContentDatasets =
          payload['contentDatasets'] as List<dynamic>? ?? const [];
      for (final item in rawContentDatasets.whereType<Map<String, dynamic>>()) {
        final key = (item['key'] as String? ?? '').trim();
        final url = (item['url'] as String? ?? '').trim();
        if (key.isEmpty ||
            url.isEmpty ||
            key.toLowerCase() == 'taj_navigation_overrides') {
          continue;
        }
        contentDatasets[key] = ReaderRemoteContentDataset(
          key: key,
          version: (item['version'] as String? ?? '').trim(),
          url: url,
        );
      }

      final editions = <MushafEdition, ReaderAdminEdition>{};
      final rawEditions = payload['editions'] as List<dynamic>? ?? const [];
      for (final item in rawEditions.whereType<Map<String, dynamic>>()) {
        final rawEdition = (item['key'] as String? ?? '').trim();
        final edition = _parseEdition(rawEdition);
        if (edition == null) {
          continue;
        }
        editions[edition] = ReaderAdminEdition(
          edition: edition,
          label: (item['label'] as String? ?? '').trim(),
          enabled: item['enabled'] as bool? ?? true,
        );
      }

      final settings = <String, String>{};
      final rawSettings = payload['settings'] as List<dynamic>? ?? const [];
      for (final item in rawSettings.whereType<Map<String, dynamic>>()) {
        final key = (item['key'] as String? ?? '').trim();
        if (key.isEmpty) {
          continue;
        }
        settings[key] = (item['value'] as String? ?? '').trim();
      }

      final flags = <String, bool>{};
      final rawFlags = payload['featureFlags'] as List<dynamic>? ?? const [];
      for (final item in rawFlags.whereType<Map<String, dynamic>>()) {
        final key = (item['key'] as String? ?? '').trim();
        if (key.isEmpty) {
          continue;
        }
        flags[key] = item['enabled'] as bool? ?? false;
      }

      final announcements = (payload['announcements'] as List<dynamic>? ??
              const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => ReaderAdminAnnouncement(
              id: (item['id'] as num? ?? 0).toInt(),
              title: (item['title'] as String? ?? '').trim(),
              body: (item['body'] as String? ?? '').trim(),
              publishAtIso: (item['publishAt'] as String? ?? '').trim(),
              active: item['active'] as bool? ?? true,
            ),
          )
          .where(
            (item) =>
                item.active && (item.title.isNotEmpty || item.body.isNotEmpty),
          )
          .toList(growable: false);

      return ReaderAdminConfig(
        source: source,
        publicBaseUrl: normalizedPublicBase,
        assetsBaseUrl: normalizedAssetsBase,
        assetPacks: Map<MushafEdition, ReaderRemoteAssetPack>.unmodifiable(
          assetPacks,
        ),
        contentDatasets: Map<String, ReaderRemoteContentDataset>.unmodifiable(
          contentDatasets,
        ),
        editions: Map<MushafEdition, ReaderAdminEdition>.unmodifiable(editions),
        settings: Map<String, String>.unmodifiable(settings),
        featureFlags: Map<String, bool>.unmodifiable(flags),
        announcements: List<ReaderAdminAnnouncement>.unmodifiable(
          announcements,
        ),
        serverTimeIso: (payload['serverTime'] as String? ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }

  MushafEdition? _parseEdition(String rawEdition) {
    final normalized = rawEdition.trim().toLowerCase();
    return switch (normalized) {
      '10_line' || '10_lines' || 'lines10' => MushafEdition.lines10,
      '13_line' || '13_lines' || 'lines13' => MushafEdition.lines13,
      '14_line' || '14_lines' || 'lines14' => MushafEdition.lines14,
      '15_line' || '15_lines' || 'lines15' => MushafEdition.lines15,
      '16_line' || '16_lines' || 'lines16' => MushafEdition.lines16,
      '17_line' || '17_lines' || 'lines17' => MushafEdition.lines17,
      'kanzul_iman' || 'kanzuliman' => MushafEdition.kanzulIman,
      _ => null,
    };
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void dispose() {
    _client.close();
  }
}
