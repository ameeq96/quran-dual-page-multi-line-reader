import 'package:flutter/services.dart';

import '../../../../core/constants/quran_constants.dart';
import '../../domain/models/reader_settings.dart';

class MushafAssetProfile {
  const MushafAssetProfile({
    required this.folderName,
    required this.leadingPagesToSkip,
  });

  final String folderName;
  final int leadingPagesToSkip;
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
        ),
        MushafEdition.lines14: MushafAssetProfile(
          folderName: '14_line',
          leadingPagesToSkip: 0,
        ),
        MushafEdition.lines15: MushafAssetProfile(
          folderName: '15_line',
          leadingPagesToSkip: 0,
        ),
        MushafEdition.lines16: MushafAssetProfile(
          folderName: '16_line',
          leadingPagesToSkip: 1,
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

  final Map<MushafEdition, Set<String>> _availableAssetsByEdition =
      <MushafEdition, Set<String>>{};
  final Map<MushafEdition, Set<int>> _availablePageNumbersByEdition =
      <MushafEdition, Set<int>>{};
  MushafEdition _selectedEdition = MushafEdition.lines16;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = manifest.listAssets().toSet();

      for (final entry in _profiles.entries) {
        final folderPrefix = 'assets/quran_pages/${entry.value.folderName}/';
        final editionAssets = allAssets
            .where(
              (assetPath) =>
                  assetPath.startsWith(folderPrefix) &&
                  (assetPath.endsWith('.png') || assetPath.endsWith('.jpg')),
            )
            .toSet();

        _availableAssetsByEdition[entry.key] = editionAssets;
        _availablePageNumbersByEdition[entry.key] =
            editionAssets.map(_pageNumberFromAsset).whereType<int>().toSet();
      }
    } catch (_) {
      _availableAssetsByEdition.clear();
      _availablePageNumbersByEdition.clear();
    }

    _isInitialized = true;
  }

  void setSelectedEdition(MushafEdition edition) {
    _selectedEdition = edition;
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

  bool get hasBundledImageEdition {
    return MushafEdition.values.any(hasAssetsForEdition);
  }

  MushafAssetProfile get _selectedProfile => _profiles[_selectedEdition]!;

  MushafAssetProfile profileForEdition(MushafEdition edition) {
    return _profiles[edition]!;
  }

  Set<int> get _selectedPageNumbers =>
      _availablePageNumbersByEdition[_selectedEdition] ?? const <int>{};

  Set<String> _assetsForEdition(MushafEdition edition) =>
      _availableAssetsByEdition[edition] ?? const <String>{};

  Set<int> _pageNumbersForEdition(MushafEdition edition) =>
      _availablePageNumbersByEdition[edition] ?? const <int>{};

  bool get hasAnyPageAssets => _selectedPageNumbers.isNotEmpty;

  bool hasAssetsForEdition(MushafEdition edition) {
    return _pageNumbersForEdition(edition).isNotEmpty;
  }

  List<MushafEdition> get availableImageEditions {
    return MushafEdition.values
        .where(hasAssetsForEdition)
        .toList(growable: false);
  }

  int get leadingPagesToSkip {
    if (_selectedPageNumbers.length <= _selectedProfile.leadingPagesToSkip) {
      return 0;
    }
    return _selectedProfile.leadingPagesToSkip;
  }

  int leadingPagesToSkipForEdition(MushafEdition edition) {
    final pageNumbers = _pageNumbersForEdition(edition);
    final profile = profileForEdition(edition);
    if (pageNumbers.length <= profile.leadingPagesToSkip) {
      return 0;
    }
    return profile.leadingPagesToSkip;
  }

  int get imagePageCount {
    if (_selectedPageNumbers.isEmpty) {
      return 0;
    }
    final highestAvailablePage = _selectedPageNumbers.reduce(
      (value, element) => value > element ? value : element,
    );
    final logicalPageCount = highestAvailablePage - leadingPagesToSkip;
    if (logicalPageCount < 0) {
      return 0;
    }
    return logicalPageCount;
  }

  int imagePageCountForEdition(MushafEdition edition) {
    final pageNumbers = _pageNumbersForEdition(edition);
    if (pageNumbers.isEmpty) {
      return 0;
    }
    final highestAvailablePage = pageNumbers.reduce(
      (value, element) => value > element ? value : element,
    );
    final logicalPageCount =
        highestAvailablePage - leadingPagesToSkipForEdition(edition);
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
    if (_selectedPageNumbers.isEmpty) {
      return 0;
    }
    return _selectedPageNumbers.reduce(
      (value, element) => value > element ? value : element,
    );
  }

  int lastImportedPageNumberForEdition(MushafEdition edition) {
    final pageNumbers = _pageNumbersForEdition(edition);
    if (pageNumbers.isEmpty) {
      return 0;
    }
    return pageNumbers.reduce(
      (value, element) => value > element ? value : element,
    );
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
    final imagePageCount = imagePageCountForEdition(edition);
    final totalPages =
        imagePageCount == 0 ? QuranConstants.defaultTotalPages : imagePageCount;
    final normalized = QuranConstants.clampPage(
      pageNumber,
      totalPages: totalPages,
    );
    final importedPageNumber = normalized + leadingPagesToSkipForEdition(edition);
    final folderPrefix =
        'assets/quran_pages/${profileForEdition(edition).folderName}/';
    final candidates = <String>[
      '$folderPrefix${QuranConstants.paddedAssetName(importedPageNumber)}.png',
      '$folderPrefix$importedPageNumber.png',
      '$folderPrefix${QuranConstants.paddedAssetName(importedPageNumber)}.jpg',
      '$folderPrefix$importedPageNumber.jpg',
    ];
    final assets = _assetsForEdition(edition);

    for (final candidate in candidates) {
      if (assets.contains(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  int? _pageNumberFromAsset(String assetPath) {
    final filename = assetPath.split('/').last;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) {
      return null;
    }

    return int.tryParse(filename.substring(0, dotIndex));
  }
}
