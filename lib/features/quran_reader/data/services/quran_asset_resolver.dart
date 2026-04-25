import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/quran_asset_pack_download.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_settings.dart';
import 'quran_offline_pack_service.dart';

class MushafAssetProfile {
  const MushafAssetProfile({
    required this.folderName,
    required this.leadingPagesToSkip,
    this.trailingPagesToTrim = 0,
  });

  final String folderName;
  final int leadingPagesToSkip;
  final int trailingPagesToTrim;
}

class QuranAssetResolver {
  static const int _maxResolvedAssetPathCacheEntries = 1200;
  static const Map<String, int> _extensionPriority = <String, int>{
    'webp': 3,
    'png': 2,
    'jpg': 1,
    'jpeg': 1,
  };

  static const Map<MushafEdition, MushafAssetProfile> _profiles =
      <MushafEdition, MushafAssetProfile>{
    MushafEdition.lines10: MushafAssetProfile(
      folderName: '10_line',
      leadingPagesToSkip: 0,
    ),
    MushafEdition.lines13: MushafAssetProfile(
      folderName: '13_line',
      leadingPagesToSkip: 0,
      trailingPagesToTrim: 1,
    ),
    MushafEdition.lines14: MushafAssetProfile(
      folderName: '14_line',
      leadingPagesToSkip: 0,
      trailingPagesToTrim: 1,
    ),
    MushafEdition.lines15: MushafAssetProfile(
      folderName: '15_line',
      leadingPagesToSkip: 0,
      trailingPagesToTrim: 1,
    ),
    MushafEdition.lines16: MushafAssetProfile(
      folderName: '16_line',
      leadingPagesToSkip: 1,
      trailingPagesToTrim: 1,
    ),
    MushafEdition.lines17: MushafAssetProfile(
      folderName: '17_line',
      leadingPagesToSkip: 0,
    ),
    MushafEdition.kanzulIman: MushafAssetProfile(
      folderName: 'kanzul_iman',
      leadingPagesToSkip: 0,
    ),
  };

  final Map<MushafEdition, ReaderRemoteAssetPack> _remotePacksByEdition =
      <MushafEdition, ReaderRemoteAssetPack>{};
  final Map<MushafEdition, ReaderRemoteAssetPack>
      _configuredRemotePacksByEdition =
      <MushafEdition, ReaderRemoteAssetPack>{};
  final Map<MushafEdition, ReaderRemoteAssetPack> _localPacksByEdition =
      <MushafEdition, ReaderRemoteAssetPack>{};
  final Map<MushafEdition, ReaderRemoteAssetPack> _downloadedZipPacksByEdition =
      <MushafEdition, ReaderRemoteAssetPack>{};
  final Map<MushafEdition, QuranZipAssetPack> _zipCatalogByEdition =
      <MushafEdition, QuranZipAssetPack>{};
  final LinkedHashMap<String, String?> _resolvedAssetPathCache =
      LinkedHashMap<String, String?>();
  final Map<MushafEdition, _EditionAssetMetrics> _editionMetrics =
      <MushafEdition, _EditionAssetMetrics>{};
  final QuranOfflinePackService _offlinePackService = QuranOfflinePackService();
  MushafEdition _selectedEdition = MushafEdition.lines16;
  String _remoteAssetsBaseUrl = '';
  bool _localPacksLoaded = false;
  Set<MushafEdition>? _enabledEditionFilter;
  List<MushafEdition> _availableImageEditionsCache = const <MushafEdition>[];

  Future<void> initialize() async {
    await _offlinePackService.initialize();
    _setZipCatalog(_offlinePackService.defaultZipPacks());
    await _loadDownloadedZipPacks();
    await _loadLocalPacks();
    _rebuildActivePacks();
  }

  void setSelectedEdition(MushafEdition edition) {
    if (_selectedEdition == edition) {
      return;
    }
    _selectedEdition = edition;
  }

  void applyRemoteConfig(ReaderAdminConfig config) {
    _remoteAssetsBaseUrl = config.assetsBaseUrl.trim();
    _configuredRemotePacksByEdition
      ..clear()
      ..addAll(config.assetPacks);
    if (!config.hasEditionControls) {
      _enabledEditionFilter = null;
    } else {
      final disabledEditions = config.editions.entries
          .where((entry) => !entry.value.enabled)
          .map((entry) => entry.key)
          .toSet();
      _enabledEditionFilter = disabledEditions.isEmpty
          ? null
          : MushafEdition.values
              .where((edition) => !disabledEditions.contains(edition))
              .toSet();
    }
    _rebuildActivePacks();
  }

  MushafEdition get selectedEdition => _selectedEdition;

  MushafEdition resolveSupportedEdition(MushafEdition edition) {
    if (hasAssetsForEdition(edition)) {
      return edition;
    }
    if (hasAssetsForEdition(MushafEdition.lines16)) {
      return MushafEdition.lines16;
    }
    for (final candidate in MushafEdition.values) {
      if (hasAssetsForEdition(candidate)) {
        return candidate;
      }
    }
    return edition;
  }

  bool get hasRemoteImageEdition {
    return MushafEdition.values.any(hasAssetsForEdition);
  }

  MushafAssetProfile profileForEdition(MushafEdition edition) {
    return _profiles[edition]!;
  }

  bool get hasAnyPageAssets => hasAssetsForEdition(_selectedEdition);

  bool hasAssetsForEdition(MushafEdition edition) {
    return imagePageCountForEdition(edition) > 0;
  }

  bool hasBundledPackForEdition(MushafEdition edition) {
    return _localPacksByEdition.containsKey(edition);
  }

  List<MushafEdition> get availableImageEditions {
    return _availableImageEditionsCache;
  }

  int get leadingPagesToSkip {
    return leadingPagesToSkipForEdition(_selectedEdition);
  }

  int leadingPagesToSkipForEdition(MushafEdition edition) {
    return _editionMetrics[edition]?.leadingPagesToSkip ?? 0;
  }

  int trailingPagesToTrimForEdition(MushafEdition edition) {
    return _editionMetrics[edition]?.trailingPagesToTrim ?? 0;
  }

  int get imagePageCount => imagePageCountForEdition(_selectedEdition);

  int imagePageCountForEdition(MushafEdition edition) {
    return _editionMetrics[edition]?.logicalPageCount ?? 0;
  }

  int get firstQuranImportedPage => leadingPagesToSkip + 1;

  int firstImportedPageForEdition(MushafEdition edition) {
    return leadingPagesToSkipForEdition(edition) + 1;
  }

  int get lastImportedPageNumber {
    return lastImportedPageNumberForEdition(_selectedEdition);
  }

  int lastImportedPageNumberForEdition(MushafEdition edition) {
    return _remotePacksByEdition[edition]?.maxImportedPageNumber ?? 0;
  }

  int logicalPageForImportedPage(int importedPageNumber) {
    final adjustedPage = importedPageNumber - leadingPagesToSkip;
    return adjustedPage < 1 ? 1 : adjustedPage;
  }

  int logicalPageForImportedPageInEdition(
    MushafEdition edition,
    int importedPageNumber,
  ) {
    final adjustedPage =
        importedPageNumber - leadingPagesToSkipForEdition(edition);
    return adjustedPage < 1 ? 1 : adjustedPage;
  }

  String? assetPathForPage(int pageNumber) {
    return assetPathForEditionPage(_selectedEdition, pageNumber);
  }

  String? assetPathForEditionPage(MushafEdition edition, int pageNumber) {
    final pack = _remotePacksByEdition[edition];
    if (pack == null) {
      return null;
    }

    final totalPages = imagePageCountForEdition(edition) == 0
        ? QuranConstants.defaultTotalPages
        : imagePageCountForEdition(edition);
    final normalized = QuranConstants.clampPage(
      pageNumber,
      totalPages: totalPages,
    );
    final cacheKey = '${edition.storageValue}|$normalized';
    final cached = _readResolvedAssetPath(cacheKey);
    if (cached != null || _resolvedAssetPathCache.containsKey(cacheKey)) {
      return cached;
    }
    final importedPageNumber =
        normalized + leadingPagesToSkipForEdition(edition);

    if (!pack.hasImportedPage(importedPageNumber)) {
      _rememberResolvedAssetPath(cacheKey, null);
      return null;
    }

    final localFilePath = _offlinePackService.localFilePathForPage(
      edition: edition,
      pack: pack,
      importedPageNumber: importedPageNumber,
    );
    if (localFilePath != null && localFilePath.trim().isNotEmpty) {
      _rememberResolvedAssetPath(cacheKey, localFilePath);
      return localFilePath;
    }

    final localPack = _localPacksByEdition[edition];
    if (localPack != null) {
      final localAssetPath = _buildLocalAssetPath(
        localPack,
        importedPageNumber,
      );
      _rememberResolvedAssetPath(cacheKey, localAssetPath);
      return localAssetPath;
    }

    if (_remoteAssetsBaseUrl.trim().isEmpty) {
      _rememberResolvedAssetPath(cacheKey, null);
      return null;
    }

    final remoteUrl = pack.buildPageUrl(
      _remoteAssetsBaseUrl,
      importedPageNumber: importedPageNumber,
    );
    _rememberResolvedAssetPath(cacheKey, remoteUrl);
    return remoteUrl;
  }

  Future<bool> hasOfflinePackForEdition(MushafEdition edition) async {
    return _downloadedZipPacksByEdition.containsKey(edition);
  }

  Future<void> downloadOfflinePack(
    MushafEdition edition, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await _loadZipCatalog();
    final zipPack = _zipCatalogByEdition[edition];
    if (zipPack != null) {
      final downloadedPack = await _offlinePackService.downloadEditionZipPack(
        zipPack: zipPack,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      _downloadedZipPacksByEdition[edition] =
          downloadedPack.toRemoteAssetPack();
      _rebuildActivePacks();
      _clearResolvedAssetPathCache();
      return;
    }

    final remotePack = _remotePacksByEdition[edition];
    if (remotePack == null || _remoteAssetsBaseUrl.trim().isEmpty) {
      throw StateError('No ZIP pack is available for ${edition.label}.');
    }
    await _offlinePackService.downloadEditionPack(
      edition: edition,
      pack: remotePack,
      assetsBaseUrl: _remoteAssetsBaseUrl,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    await _loadDownloadedZipPacks();
    _rebuildActivePacks();
    _clearResolvedAssetPathCache();
  }

  Future<void> removeOfflinePack(MushafEdition edition) async {
    await _offlinePackService.removeZipPack(edition);
    _downloadedZipPacksByEdition.remove(edition);
    _rebuildActivePacks();
    _clearResolvedAssetPathCache();
  }

  List<QuranZipAssetPack> get availableZipPacksSnapshot {
    return _zipCatalogSnapshot();
  }

  Future<List<QuranZipAssetPack>> fetchAvailableZipPacks({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh || _zipCatalogByEdition.isEmpty) {
      await _loadZipCatalog();
    }
    return _zipCatalogSnapshot();
  }

  Future<void> _loadZipCatalog() async {
    final packs = await _offlinePackService.fetchAvailableZipPacks();
    _setZipCatalog(packs);
  }

  void _setZipCatalog(List<QuranZipAssetPack> packs) {
    _zipCatalogByEdition
      ..clear()
      ..addEntries(packs.map((pack) => MapEntry(pack.edition, pack)));
  }

  List<QuranZipAssetPack> _zipCatalogSnapshot() {
    return MushafEdition.values
        .map((edition) => _zipCatalogByEdition[edition])
        .whereType<QuranZipAssetPack>()
        .toList(growable: false);
  }

  Future<void> _loadDownloadedZipPacks() async {
    final packs = await _offlinePackService.loadDownloadedZipPacks();
    _downloadedZipPacksByEdition
      ..clear()
      ..addEntries(
        packs.entries.map(
          (entry) => MapEntry(entry.key, entry.value.toRemoteAssetPack()),
        ),
      );
  }

  Future<void> _loadLocalPacks() async {
    if (_localPacksLoaded) {
      return;
    }
    _localPacksLoaded = true;

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetKeys = manifest
        .listAssets()
        .where((key) => key.startsWith('assets/asset_packs/'))
        .toList(growable: false);
    if (assetKeys.isEmpty) {
      return;
    }

    final builders = <String, _LocalPackBuilder>{};
    for (final key in assetKeys) {
      final parts = key.split('/');
      if (parts.length < 5) {
        continue;
      }
      final folderName = parts[2];
      final version = parts[3];
      final filename = parts[4];
      final dotIndex = filename.lastIndexOf('.');
      if (dotIndex <= 0) {
        continue;
      }
      final namePart = filename.substring(0, dotIndex);
      final extension = filename.substring(dotIndex + 1);
      final importedPageNumber = int.tryParse(namePart);
      if (importedPageNumber == null) {
        continue;
      }

      final keyId = '$folderName|$version|$extension';
      builders.putIfAbsent(
        keyId,
        () => _LocalPackBuilder(
          folderName: folderName,
          version: version,
          extension: extension,
        ),
      );
      builders[keyId]!.importedPages.add(importedPageNumber);
    }

    final packsByEdition = <MushafEdition, List<_LocalPackBuilder>>{};
    for (final builder in builders.values) {
      final match = _profiles.entries
          .where((entry) => entry.value.folderName == builder.folderName)
          .toList(growable: false);
      if (match.isEmpty) {
        continue;
      }
      final edition = match.first.key;
      packsByEdition.putIfAbsent(edition, () => <_LocalPackBuilder>[]).add(
            builder,
          );
    }

    for (final entry in packsByEdition.entries) {
      final best = entry.value
        ..sort((a, b) {
          final pageCountDiff =
              b.importedPages.length.compareTo(a.importedPages.length);
          if (pageCountDiff != 0) {
            return pageCountDiff;
          }
          return _extensionRank(b.extension).compareTo(
            _extensionRank(a.extension),
          );
        });
      final selected = best.first;
      final importedPages = selected.importedPages.toList()..sort();
      final start = importedPages.isEmpty ? null : importedPages.first;
      final end = importedPages.isEmpty ? null : importedPages.last;
      _localPacksByEdition[entry.key] = ReaderRemoteAssetPack(
        edition: entry.key,
        folderName: selected.folderName,
        version: selected.version,
        pageCount: importedPages.length,
        fileExtension: selected.extension,
        availableImportedPages: importedPages,
        contiguousImportedPageStart: start,
        contiguousImportedPageEnd: end,
      );
    }
  }

  void _rebuildActivePacks() {
    _remotePacksByEdition.clear();
    for (final edition in MushafEdition.values) {
      if (_enabledEditionFilter != null &&
          !_enabledEditionFilter!.contains(edition)) {
        continue;
      }
      final downloadedZipPack = _downloadedZipPacksByEdition[edition];
      if (downloadedZipPack != null) {
        _remotePacksByEdition[edition] = downloadedZipPack;
        continue;
      }
      final configuredPack = _configuredRemotePacksByEdition[edition];
      if (configuredPack != null) {
        _remotePacksByEdition[edition] = configuredPack;
        continue;
      }
      final localPack = _localPacksByEdition[edition];
      if (localPack != null) {
        _remotePacksByEdition[edition] = localPack;
      }
    }
    _rebuildEditionMetrics();
    _clearResolvedAssetPathCache();
  }

  String _buildLocalAssetPath(
    ReaderRemoteAssetPack pack,
    int importedPageNumber,
  ) {
    final filename = importedPageNumber.toString().padLeft(3, '0');
    return 'assets/asset_packs/${pack.folderName}/${pack.version}/$filename.${pack.fileExtension}';
  }

  int _extensionRank(String extension) {
    return _extensionPriority[extension.trim().toLowerCase()] ?? 0;
  }

  void _clearResolvedAssetPathCache() {
    _resolvedAssetPathCache.clear();
  }

  String? _readResolvedAssetPath(String cacheKey) {
    final cached = _resolvedAssetPathCache.remove(cacheKey);
    if (cached != null) {
      _resolvedAssetPathCache[cacheKey] = cached;
    }
    return cached;
  }

  void _rememberResolvedAssetPath(String cacheKey, String? value) {
    _resolvedAssetPathCache.remove(cacheKey);
    _resolvedAssetPathCache[cacheKey] = value;
    while (_resolvedAssetPathCache.length > _maxResolvedAssetPathCacheEntries) {
      _resolvedAssetPathCache.remove(_resolvedAssetPathCache.keys.first);
    }
  }

  void _rebuildEditionMetrics() {
    _editionMetrics
      ..clear()
      ..addEntries(
        MushafEdition.values.map(
          (edition) => MapEntry(
            edition,
            _computeEditionMetrics(edition),
          ),
        ),
      );
    _availableImageEditionsCache = MushafEdition.values
        .where((edition) => imagePageCountForEdition(edition) > 0)
        .toList(growable: false);
  }

  _EditionAssetMetrics _computeEditionMetrics(MushafEdition edition) {
    final pack = _remotePacksByEdition[edition];
    if (pack == null) {
      return const _EditionAssetMetrics.empty();
    }

    final profile = profileForEdition(edition);
    final maxImportedPageNumber = pack.maxImportedPageNumber;
    final leadingPagesToSkip =
        maxImportedPageNumber <= profile.leadingPagesToSkip
            ? 0
            : profile.leadingPagesToSkip;
    final reservedPages = leadingPagesToSkip + profile.trailingPagesToTrim;
    final trailingPagesToTrim = maxImportedPageNumber <= reservedPages
        ? 0
        : profile.trailingPagesToTrim;
    final logicalPageCount =
        maxImportedPageNumber - leadingPagesToSkip - trailingPagesToTrim;

    return _EditionAssetMetrics(
      leadingPagesToSkip: leadingPagesToSkip,
      trailingPagesToTrim: trailingPagesToTrim,
      logicalPageCount: logicalPageCount < 0 ? 0 : logicalPageCount,
    );
  }

  void dispose() {
    _offlinePackService.dispose();
  }
}

class _LocalPackBuilder {
  _LocalPackBuilder({
    required this.folderName,
    required this.version,
    required this.extension,
  });

  final String folderName;
  final String version;
  final String extension;
  final List<int> importedPages = <int>[];
}

class _EditionAssetMetrics {
  const _EditionAssetMetrics({
    required this.leadingPagesToSkip,
    required this.trailingPagesToTrim,
    required this.logicalPageCount,
  });

  const _EditionAssetMetrics.empty()
      : leadingPagesToSkip = 0,
        trailingPagesToTrim = 0,
        logicalPageCount = 0;

  final int leadingPagesToSkip;
  final int trailingPagesToTrim;
  final int logicalPageCount;
}
