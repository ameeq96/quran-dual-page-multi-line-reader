import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../core/constants/quran_constants.dart';
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
  final Map<MushafEdition, ReaderRemoteAssetPack> _localPacksByEdition =
      <MushafEdition, ReaderRemoteAssetPack>{};
  final QuranOfflinePackService _offlinePackService = QuranOfflinePackService();
  MushafEdition _selectedEdition = MushafEdition.lines16;
  String _remoteAssetsBaseUrl = '';
  bool _localPacksLoaded = false;
  Set<MushafEdition>? _enabledEditionFilter;

  Future<void> initialize() async {
    await _offlinePackService.initialize();
    await _loadLocalPacks();
    _rebuildActivePacks();
  }

  void setSelectedEdition(MushafEdition edition) {
    _selectedEdition = edition;
  }

  void applyRemoteConfig(ReaderAdminConfig config) {
    _remoteAssetsBaseUrl = '';
    if (!config.hasEditionControls) {
      _enabledEditionFilter = null;
    } else {
      _enabledEditionFilter = config.editions.entries
          .where((entry) => entry.value.enabled)
          .map((entry) => entry.key)
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
    final pack = _remotePacksByEdition[edition];
    if (pack == null) {
      return false;
    }
    return imagePageCountForEdition(edition) > 0;
  }

  bool hasBundledPackForEdition(MushafEdition edition) {
    return _localPacksByEdition.containsKey(edition);
  }

  List<MushafEdition> get availableImageEditions {
    return MushafEdition.values
        .where(hasAssetsForEdition)
        .toList(growable: false);
  }

  int get leadingPagesToSkip {
    return leadingPagesToSkipForEdition(_selectedEdition);
  }

  int leadingPagesToSkipForEdition(MushafEdition edition) {
    final remotePack = _remotePacksByEdition[edition];
    final profile = profileForEdition(edition);
    if (remotePack == null ||
        remotePack.maxImportedPageNumber <= profile.leadingPagesToSkip) {
      return 0;
    }
    return profile.leadingPagesToSkip;
  }

  int trailingPagesToTrimForEdition(MushafEdition edition) {
    final remotePack = _remotePacksByEdition[edition];
    final profile = profileForEdition(edition);
    if (remotePack == null) {
      return 0;
    }
    final reservedPages =
        leadingPagesToSkipForEdition(edition) + profile.trailingPagesToTrim;
    if (remotePack.maxImportedPageNumber <= reservedPages) {
      return 0;
    }
    return profile.trailingPagesToTrim;
  }

  int get imagePageCount => imagePageCountForEdition(_selectedEdition);

  int imagePageCountForEdition(MushafEdition edition) {
    final pack = _remotePacksByEdition[edition];
    if (pack == null) {
      return 0;
    }

    final logicalPageCount = pack.maxImportedPageNumber -
        leadingPagesToSkipForEdition(edition) -
        trailingPagesToTrimForEdition(edition);
    if (logicalPageCount < 0) {
      return 0;
    }
    return logicalPageCount;
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
    final importedPageNumber =
        normalized + leadingPagesToSkipForEdition(edition);

    if (!pack.hasImportedPage(importedPageNumber)) {
      return null;
    }

    final localFilePath = _offlinePackService.localFilePathForPage(
      edition: edition,
      pack: pack,
      importedPageNumber: importedPageNumber,
    );
    if (localFilePath != null && localFilePath.trim().isNotEmpty) {
      return localFilePath;
    }

    final localPack = _localPacksByEdition[edition];
    if (localPack != null) {
      return _buildLocalAssetPath(
        localPack,
        importedPageNumber,
      );
    }

    if (_remoteAssetsBaseUrl.trim().isEmpty) {
      return null;
    }

    return pack.buildPageUrl(
      _remoteAssetsBaseUrl,
      importedPageNumber: importedPageNumber,
    );
  }

  Future<bool> hasOfflinePackForEdition(MushafEdition edition) async {
    final remotePack = _remotePacksByEdition[edition];
    if (remotePack == null) {
      return false;
    }
    return _offlinePackService.hasEditionPack(
      edition: edition,
      pack: remotePack,
    );
  }

  Future<void> downloadOfflinePack(
    MushafEdition edition, {
    void Function(double progress)? onProgress,
  }) async {
    final remotePack = _remotePacksByEdition[edition];
    if (remotePack == null || _remoteAssetsBaseUrl.trim().isEmpty) {
      throw StateError(
          'No active admin pack is available for ${edition.label}.');
    }
    await _offlinePackService.downloadEditionPack(
      edition: edition,
      pack: remotePack,
      assetsBaseUrl: _remoteAssetsBaseUrl,
      onProgress: onProgress,
    );
  }

  Future<void> removeOfflinePack(MushafEdition edition) async {
    final remotePack = _remotePacksByEdition[edition];
    if (remotePack == null) {
      return;
    }
    await _offlinePackService.removeEditionPack(
      edition: edition,
      pack: remotePack,
    );
  }

  Future<void> _loadLocalPacks() async {
    if (_localPacksLoaded) {
      return;
    }
    _localPacksLoaded = true;

    final manifestJson = await rootBundle.loadString('AssetManifest.json');
    final manifest = json.decode(manifestJson) as Map<String, dynamic>;
    final assetKeys = manifest.keys
        .where((key) => key.startsWith('assets/asset_packs/'))
        .toList(growable: false);
    if (assetKeys.isEmpty) {
      _seedFallbackLocalPacks();
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
        ..sort(
            (a, b) => b.importedPages.length.compareTo(a.importedPages.length));
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

    if (_localPacksByEdition.isEmpty) {
      _seedFallbackLocalPacks();
    }
  }

  void _rebuildActivePacks() {
    _remotePacksByEdition
      ..clear()
      ..addEntries(
        _localPacksByEdition.entries.where((entry) {
          if (_enabledEditionFilter == null) {
            return true;
          }
          return _enabledEditionFilter!.contains(entry.key);
        }),
      );
  }

  String _buildLocalAssetPath(
    ReaderRemoteAssetPack pack,
    int importedPageNumber,
  ) {
    final filename = importedPageNumber.toString().padLeft(3, '0');
    return 'assets/asset_packs/${pack.folderName}/${pack.version}/$filename.${pack.fileExtension}';
  }

  void _seedFallbackLocalPacks() {
    for (final entry in _profiles.entries) {
      final profile = entry.value;
      final totalPages = QuranConstants.defaultTotalPages +
          profile.leadingPagesToSkip +
          profile.trailingPagesToTrim;
      _localPacksByEdition[entry.key] = ReaderRemoteAssetPack(
        edition: entry.key,
        folderName: profile.folderName,
        version: 'mobile-app-source',
        pageCount: totalPages,
        fileExtension: 'jpg',
        availableImportedPages: const <int>[],
        contiguousImportedPageStart: 1,
        contiguousImportedPageEnd: totalPages,
      );
    }
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
