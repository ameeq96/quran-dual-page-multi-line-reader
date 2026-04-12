import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_settings.dart';

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
  MushafEdition _selectedEdition = MushafEdition.lines16;
  String _remoteAssetsBaseUrl = '';

  Future<void> initialize() async {
    // Remote packs are applied from admin config; no local asset scan is needed.
  }

  void setSelectedEdition(MushafEdition edition) {
    _selectedEdition = edition;
  }

  void applyRemoteConfig(ReaderAdminConfig config) {
    _remoteAssetsBaseUrl = config.assetsBaseUrl;
    _remotePacksByEdition
      ..clear()
      ..addAll(config.assetPacks);
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
    final remotePack = _remotePacksByEdition[edition];
    if (remotePack == null || _remoteAssetsBaseUrl.trim().isEmpty) {
      return false;
    }
    return imagePageCountForEdition(edition) > 0;
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
    final remotePack = _remotePacksByEdition[edition];
    if (remotePack == null) {
      return 0;
    }

    final logicalPageCount = remotePack.maxImportedPageNumber -
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
    final adjustedPage = importedPageNumber - leadingPagesToSkipForEdition(edition);
    return adjustedPage < 1 ? 1 : adjustedPage;
  }

  String? assetPathForPage(int pageNumber) {
    return assetPathForEditionPage(_selectedEdition, pageNumber);
  }

  String? assetPathForEditionPage(MushafEdition edition, int pageNumber) {
    final remotePack = _remotePacksByEdition[edition];
    if (remotePack == null || _remoteAssetsBaseUrl.trim().isEmpty) {
      return null;
    }

    final totalPages =
        imagePageCountForEdition(edition) == 0 ? QuranConstants.defaultTotalPages : imagePageCountForEdition(edition);
    final normalized = QuranConstants.clampPage(
      pageNumber,
      totalPages: totalPages,
    );
    final importedPageNumber = normalized + leadingPagesToSkipForEdition(edition);

    if (!remotePack.hasImportedPage(importedPageNumber)) {
      return null;
    }

    return remotePack.buildPageUrl(
      _remoteAssetsBaseUrl,
      importedPageNumber: importedPageNumber,
    );
  }
}
