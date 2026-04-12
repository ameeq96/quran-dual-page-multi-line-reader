import 'reader_settings.dart';

enum ReaderAdminConfigSource {
  none,
  cached,
  live,
}

class ReaderAdminAnnouncement {
  const ReaderAdminAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishAtIso,
  });

  final int id;
  final String title;
  final String body;
  final String publishAtIso;
}

class ReaderRemoteAssetPack {
  const ReaderRemoteAssetPack({
    required this.edition,
    required this.folderName,
    required this.version,
    required this.pageCount,
    required this.fileExtension,
    this.availableImportedPages = const <int>[],
    this.contiguousImportedPageStart,
    this.contiguousImportedPageEnd,
  });

  final MushafEdition edition;
  final String folderName;
  final String version;
  final int pageCount;
  final String fileExtension;
  final List<int> availableImportedPages;
  final int? contiguousImportedPageStart;
  final int? contiguousImportedPageEnd;

  bool get hasExplicitPageList => availableImportedPages.isNotEmpty;

  int get maxImportedPageNumber {
    if (availableImportedPages.isNotEmpty) {
      return availableImportedPages.reduce(
        (value, element) => value > element ? value : element,
      );
    }
    if (contiguousImportedPageEnd != null && contiguousImportedPageEnd! > 0) {
      return contiguousImportedPageEnd!;
    }
    return pageCount;
  }

  bool hasImportedPage(int importedPageNumber) {
    if (availableImportedPages.isNotEmpty) {
      return availableImportedPages.contains(importedPageNumber);
    }

    if (contiguousImportedPageStart != null && contiguousImportedPageEnd != null) {
      return importedPageNumber >= contiguousImportedPageStart! &&
          importedPageNumber <= contiguousImportedPageEnd!;
    }

    return importedPageNumber <= pageCount;
  }

  String buildPageUrl(
    String assetsBaseUrl, {
    required int importedPageNumber,
  }) {
    final normalizedBase = assetsBaseUrl.endsWith('/')
        ? assetsBaseUrl.substring(0, assetsBaseUrl.length - 1)
        : assetsBaseUrl;
    final filename = importedPageNumber.toString().padLeft(3, '0');
    return '$normalizedBase/asset_packs/$folderName/$version/$filename.$fileExtension';
  }
}

class ReaderRemoteContentDataset {
  const ReaderRemoteContentDataset({
    required this.key,
    required this.version,
    required this.url,
  });

  final String key;
  final String version;
  final String url;
}

class ReaderAdminEdition {
  const ReaderAdminEdition({
    required this.edition,
    required this.label,
    required this.enabled,
  });

  final MushafEdition edition;
  final String label;
  final bool enabled;
}

class ReaderAdminConfig {
  const ReaderAdminConfig({
    required this.source,
    required this.publicBaseUrl,
    required this.assetsBaseUrl,
    required this.assetPacks,
    required this.contentDatasets,
    required this.editions,
    required this.settings,
    required this.featureFlags,
    required this.announcements,
    required this.serverTimeIso,
  });

  const ReaderAdminConfig.empty()
      : source = ReaderAdminConfigSource.none,
        publicBaseUrl = '',
        assetsBaseUrl = '',
        assetPacks = const <MushafEdition, ReaderRemoteAssetPack>{},
        contentDatasets = const <String, ReaderRemoteContentDataset>{},
        editions = const <MushafEdition, ReaderAdminEdition>{},
        settings = const <String, String>{},
        featureFlags = const <String, bool>{},
        announcements = const <ReaderAdminAnnouncement>[],
        serverTimeIso = '';

  final ReaderAdminConfigSource source;
  final String publicBaseUrl;
  final String assetsBaseUrl;
  final Map<MushafEdition, ReaderRemoteAssetPack> assetPacks;
  final Map<String, ReaderRemoteContentDataset> contentDatasets;
  final Map<MushafEdition, ReaderAdminEdition> editions;
  final Map<String, String> settings;
  final Map<String, bool> featureFlags;
  final List<ReaderAdminAnnouncement> announcements;
  final String serverTimeIso;

  bool get isEmpty =>
      assetsBaseUrl.isEmpty &&
      assetPacks.isEmpty &&
      contentDatasets.isEmpty &&
      editions.isEmpty &&
      settings.isEmpty &&
      featureFlags.isEmpty &&
      announcements.isEmpty;

  bool get hasRemoteAssetPacks => assetsBaseUrl.isNotEmpty && assetPacks.isNotEmpty;
  bool get hasRemoteContentDatasets => contentDatasets.isNotEmpty;
  bool get hasEditionControls => editions.isNotEmpty;

  String? setting(String key) => settings[key];
  ReaderRemoteContentDataset? contentDataset(String key) {
    if (key.trim().toLowerCase() == 'taj_navigation_overrides') {
      return null;
    }
    return contentDatasets[key];
  }
  ReaderAdminEdition? editionConfig(MushafEdition edition) => editions[edition];

  bool isFeatureEnabled(String key, {bool fallback = false}) {
    return featureFlags[key] ?? fallback;
  }

  ReaderAdminConfig withoutContentDataset(String key) {
    if (!contentDatasets.containsKey(key)) {
      return this;
    }

    final nextDatasets = Map<String, ReaderRemoteContentDataset>.from(
      contentDatasets,
    )..remove(key);

    return ReaderAdminConfig(
      source: source,
      publicBaseUrl: publicBaseUrl,
      assetsBaseUrl: assetsBaseUrl,
      assetPacks: assetPacks,
      contentDatasets: Map<String, ReaderRemoteContentDataset>.unmodifiable(
        nextDatasets,
      ),
      editions: editions,
      settings: settings,
      featureFlags: featureFlags,
      announcements: announcements,
      serverTimeIso: serverTimeIso,
    );
  }
}
