import 'package:dio/dio.dart';

import '../../domain/models/quran_asset_pack_download.dart';
import '../../domain/models/reader_settings.dart';

class QuranAssetPackCatalogService {
  QuranAssetPackCatalogService({
    Dio? dio,
    this.catalogUrl = defaultCatalogUrl,
  }) : _dio = dio ?? Dio(_defaultOptions);

  static const String defaultCatalogUrl =
      'https://quranadminapi.opplexify.com/public/asset-packs.json';

  static const Map<String, String> fallbackZipUrls = <String, String>{
    '10_line':
        'https://quranadminapi.opplexify.com/assets/asset_packs/10_line.zip',
    '13_line':
        'https://quranadminapi.opplexify.com/assets/asset_packs/13_line.zip',
    '14_line':
        'https://quranadminapi.opplexify.com/assets/asset_packs/14_line.zip',
    '15_line':
        'https://quranadminapi.opplexify.com/assets/asset_packs/15_line.zip',
    '16_line':
        'https://quranadminapi.opplexify.com/assets/asset_packs/16_line.zip',
    '17_line':
        'https://quranadminapi.opplexify.com/assets/asset_packs/17_line.zip',
    'kanzul_iman':
        'https://quranadminapi.opplexify.com/assets/asset_packs/kanzul_iman.zip',
  };

  static final BaseOptions _defaultOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 20),
    responseType: ResponseType.json,
    headers: const <String, String>{
      'Accept': 'application/json',
      'User-Agent': 'quran_dual_page/1.0',
    },
  );

  final Dio _dio;
  final String catalogUrl;

  static List<QuranZipAssetPack> defaultPacks() {
    return _packsFromMap(fallbackZipUrls);
  }

  static List<QuranZipAssetPack> packsFromUrls(
    Map<String, String> urlsByKey, {
    bool fillMissingWithFallback = false,
  }) {
    final source = fillMissingWithFallback
        ? <String, String>{
            ...fallbackZipUrls,
            ...urlsByKey,
          }
        : urlsByKey;
    return _packsFromMap(source);
  }

  Future<List<QuranZipAssetPack>> fetchAvailablePacks({
    bool allowFallback = true,
  }) async {
    final normalizedCatalogUrl = catalogUrl.trim();
    if (normalizedCatalogUrl.isEmpty) {
      return defaultPacks();
    }

    try {
      final response = await _dio.get<Object?>(normalizedCatalogUrl);
      final data = response.data;
      if (data is Map) {
        final parsed = _parseCatalogMap(data);
        if (parsed.isEmpty && data['assetPacks'] is List) {
          return const [];
        }
        final packs = packsFromUrls(
          parsed,
          fillMissingWithFallback: allowFallback,
        );
        if (packs.isNotEmpty) {
          return packs;
        }
      }
    } catch (_) {
      if (!allowFallback) {
        rethrow;
      }
    }

    return allowFallback ? defaultPacks() : const [];
  }

  static Map<String, String> _parseCatalogMap(Map<dynamic, dynamic> data) {
    final parsed = <String, String>{};
    final rawPacks = data['assetPacks'];
    if (rawPacks is List) {
      for (final item in rawPacks.whereType<Map>()) {
        final key = '${item['key'] ?? item['edition'] ?? ''}'.trim();
        final value = _normalizedDownloadUrl('${item['url'] ?? ''}');
        if (key.isNotEmpty && value != null) {
          parsed[key] = value;
        }
      }
      return parsed;
    }

    for (final entry in data.entries) {
      final key = '${entry.key}'.trim();
      final value = _normalizedDownloadUrl('${entry.value}');
      if (key.isNotEmpty && value != null) {
        parsed[key] = value;
      }
    }
    return parsed;
  }

  static List<QuranZipAssetPack> _packsFromMap(Map<String, String> urlsByKey) {
    final packs = <QuranZipAssetPack>[];
    for (final edition in MushafEdition.values) {
      final key = keyForEdition(edition);
      final url = _normalizedDownloadUrl(urlsByKey[key]);
      if (url == null) {
        continue;
      }
      packs.add(QuranZipAssetPack(edition: edition, key: key, url: url));
    }
    return packs;
  }

  static String keyForEdition(MushafEdition edition) {
    return switch (edition) {
      MushafEdition.lines10 => '10_line',
      MushafEdition.lines13 => '13_line',
      MushafEdition.lines14 => '14_line',
      MushafEdition.lines15 => '15_line',
      MushafEdition.lines16 => '16_line',
      MushafEdition.lines17 => '17_line',
      MushafEdition.kanzulIman => 'kanzul_iman',
    };
  }

  static String? _normalizedDownloadUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.trim().isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      return null;
    }
    return trimmed;
  }

  void dispose() {
    _dio.close(force: true);
  }
}
