import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/quran_asset_pack_download.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_settings.dart';
import 'quran_asset_pack_catalog_service.dart';
import 'quran_zip_extraction_service.dart';

class QuranOfflinePackService {
  QuranOfflinePackService({
    Dio? dio,
    QuranAssetPackCatalogService? catalogService,
    QuranZipExtractionService extractionService =
        const QuranZipExtractionService(),
  })  : _dio = dio ?? Dio(_downloadOptions),
        _catalogService = catalogService ?? QuranAssetPackCatalogService(),
        _extractionService = extractionService;

  static const String _offlineDirectoryName = 'quran_offline_packs';
  static const String _archiveDirectoryName = 'quran_zip_archives';
  static const String _manifestFileName = '.manifest.json';
  static const Set<String> _supportedImageExtensions = <String>{
    'webp',
    'png',
    'jpg',
    'jpeg',
  };

  static final BaseOptions _downloadOptions = BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 20),
    sendTimeout: const Duration(seconds: 30),
    responseType: ResponseType.bytes,
    followRedirects: true,
    headers: const <String, String>{
      'Accept': 'application/zip,application/octet-stream,*/*',
      'User-Agent': 'quran_dual_page/1.0',
    },
  );

  final Dio _dio;
  final QuranAssetPackCatalogService _catalogService;
  final QuranZipExtractionService _extractionService;
  Directory? _offlineRoot;
  Directory? _archiveRoot;
  final LinkedHashMap<String, String?> _localPagePathCache =
      LinkedHashMap<String, String?>();

  Future<void> initialize() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    _offlineRoot ??= Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}'
      '$_offlineDirectoryName',
    );
    _archiveRoot ??= Directory(
      '${documentsDirectory.path}${Platform.pathSeparator}'
      '$_archiveDirectoryName',
    );
    await Future.wait(<Future<void>>[
      _offlineRoot!.create(recursive: true),
      _archiveRoot!.create(recursive: true),
    ]);
  }

  Future<List<QuranZipAssetPack>> fetchAvailableZipPacks() {
    return _catalogService.fetchAvailablePacks();
  }

  List<QuranZipAssetPack> defaultZipPacks() {
    return QuranAssetPackCatalogService.defaultPacks();
  }

  Future<Map<MushafEdition, QuranDownloadedAssetPack>>
      loadDownloadedZipPacks() async {
    await initialize();
    final entries = <MushafEdition, QuranDownloadedAssetPack>{};
    for (final edition in MushafEdition.values) {
      final editionDirectory = Directory(_editionDirectoryPath(edition));
      if (!await editionDirectory.exists()) {
        continue;
      }

      final manifests = <File>[];
      await for (final entity in editionDirectory.list(followLinks: false)) {
        if (entity is! Directory) {
          continue;
        }
        final manifest = File(
          '${entity.path}${Platform.pathSeparator}$_manifestFileName',
        );
        if (await manifest.exists()) {
          manifests.add(manifest);
        }
      }

      for (final manifest in manifests) {
        final downloadedPack = _readManifest(manifest);
        if (downloadedPack == null ||
            downloadedPack.pageCount <= 0 ||
            !_downloadedPackHasUsableFiles(downloadedPack)) {
          continue;
        }
        final current = entries[edition];
        if (current == null ||
            downloadedPack.completedAtIso.compareTo(current.completedAtIso) >
                0) {
          entries[edition] = downloadedPack;
        }
      }
    }
    return Map<MushafEdition, QuranDownloadedAssetPack>.unmodifiable(entries);
  }

  Future<bool> hasEditionPack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
  }) async {
    await initialize();
    final downloadedPack = _readManifest(
      File(_manifestPath(edition, pack.version)),
    );
    return downloadedPack != null &&
        downloadedPack.pageCount > 0 &&
        _downloadedPackHasUsableFiles(downloadedPack);
  }

  String? localFilePathForPage({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required int importedPageNumber,
  }) {
    if (_offlineRoot == null) {
      return null;
    }
    final cacheKey =
        '${edition.storageValue}|${pack.version}|$importedPageNumber|${pack.fileExtension}';
    if (_localPagePathCache.containsKey(cacheKey)) {
      return _readLocalPagePathCache(cacheKey);
    }

    final file = File(_pagePath(edition, pack, importedPageNumber));
    if (!file.existsSync() || file.lengthSync() == 0) {
      for (final extension in _supportedImageExtensions) {
        if (extension == pack.fileExtension) {
          continue;
        }
        final fallbackFile = File(
          _pagePathWithExtension(
            edition,
            pack.version,
            importedPageNumber,
            extension,
          ),
        );
        if (fallbackFile.existsSync() && fallbackFile.lengthSync() > 0) {
          _rememberLocalPagePath(cacheKey, fallbackFile.path);
          return fallbackFile.path;
        }
      }
      _rememberLocalPagePath(cacheKey, null);
      return null;
    }
    _rememberLocalPagePath(cacheKey, file.path);
    return file.path;
  }

  Future<QuranDownloadedAssetPack> downloadEditionZipPack({
    required QuranZipAssetPack zipPack,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await initialize();
    final version = _versionForZipPack(zipPack);
    final manifestFile = File(_manifestPath(zipPack.edition, version));
    final existing = _readManifest(manifestFile);
    if (existing != null &&
        existing.pageCount > 0 &&
        _downloadedPackHasUsableFiles(existing)) {
      onProgress?.call(1);
      return existing;
    }

    final archiveFile = File(_archivePath(zipPack, version));
    final usedCachedArchive =
        archiveFile.existsSync() && archiveFile.lengthSync() > 0;
    if (!archiveFile.existsSync() || archiveFile.lengthSync() == 0) {
      await _downloadArchive(
        zipPack: zipPack,
        archiveFile: archiveFile,
        cancelToken: cancelToken,
        onProgress: (progress) => onProgress?.call(progress * 0.55),
      );
    } else {
      onProgress?.call(0.55);
    }

    try {
      return await _extractAndPublishArchive(
        zipPack: zipPack,
        version: version,
        archiveFile: archiveFile,
        onProgress: onProgress,
      );
    } catch (_) {
      if (!usedCachedArchive) {
        rethrow;
      }
      if (archiveFile.existsSync()) {
        await archiveFile.delete();
      }
      _clearLocalPagePathCacheForEdition(zipPack.edition);
      await _downloadArchive(
        zipPack: zipPack,
        archiveFile: archiveFile,
        cancelToken: cancelToken,
        onProgress: (progress) => onProgress?.call(progress * 0.55),
      );
      return _extractAndPublishArchive(
        zipPack: zipPack,
        version: version,
        archiveFile: archiveFile,
        onProgress: onProgress,
      );
    }
  }

  Future<QuranDownloadedAssetPack> _extractAndPublishArchive({
    required QuranZipAssetPack zipPack,
    required String version,
    required File archiveFile,
    void Function(double progress)? onProgress,
  }) async {
    final tempRoot = await getTemporaryDirectory();
    final extractDirectory = Directory(
      '${tempRoot.path}${Platform.pathSeparator}'
      'quran_zip_extract_${zipPack.key}_${DateTime.now().microsecondsSinceEpoch}',
    );
    final stagingDirectory = Directory(
      '${_offlineRoot!.path}${Platform.pathSeparator}'
      '.incoming_${zipPack.key}_${DateTime.now().microsecondsSinceEpoch}',
    );

    try {
      await _extractionService.extractZip(
        zipPath: archiveFile.path,
        outputDirectoryPath: extractDirectory.path,
      );
      onProgress?.call(0.72);

      final normalized = await _publishExtractedPages(
        zipPack: zipPack,
        version: version,
        archivePath: archiveFile.path,
        extractDirectory: extractDirectory,
        stagingDirectory: stagingDirectory,
        onProgress: (progress) => onProgress?.call(0.72 + progress * 0.26),
      );
      onProgress?.call(1);
      return normalized;
    } finally {
      if (extractDirectory.existsSync()) {
        await extractDirectory.delete(recursive: true);
      }
      if (stagingDirectory.existsSync()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> downloadEditionPack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required String assetsBaseUrl,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final zipPacks = await fetchAvailableZipPacks();
    final zipPack =
        zipPacks.where((item) => item.edition == edition).firstOrNull;
    if (zipPack != null) {
      await downloadEditionZipPack(
        zipPack: zipPack,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return;
    }

    await _downloadRemotePagePack(
      edition: edition,
      pack: pack,
      assetsBaseUrl: assetsBaseUrl,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  Future<QuranDownloadedAssetPack> _downloadRemotePagePack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required String assetsBaseUrl,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await initialize();
    if (assetsBaseUrl.trim().isEmpty) {
      throw StateError('No asset base URL is available for ${edition.label}.');
    }

    final manifestFile = File(_manifestPath(edition, pack.version));
    final existing = _readManifest(manifestFile);
    if (existing != null &&
        existing.pageCount > 0 &&
        _downloadedPackHasUsableFiles(existing)) {
      onProgress?.call(1);
      return existing;
    }

    final pageNumbers = _remotePageNumbers(pack);
    if (pageNumbers.isEmpty) {
      throw StateError('No remote pages are available for ${edition.label}.');
    }

    final stagingDirectory = Directory(
      '${_offlineRoot!.path}${Platform.pathSeparator}'
      '.incoming_${edition.storageValue}_${DateTime.now().microsecondsSinceEpoch}',
    );

    try {
      await stagingDirectory.create(recursive: true);
      final importedPages = <int>[];
      var downloaded = 0;
      for (final pageNumber in pageNumbers) {
        final sourceUrl = pack.buildPageUrl(
          assetsBaseUrl,
          importedPageNumber: pageNumber,
        );
        final extension = pack.fileExtension.trim().isEmpty
            ? 'webp'
            : pack.fileExtension.trim().toLowerCase();
        final destinationFile = File(
          '${stagingDirectory.path}${Platform.pathSeparator}'
          '${pageNumber.toString().padLeft(3, '0')}.$extension',
        );
        await _downloadRemotePage(
          url: sourceUrl,
          destinationFile: destinationFile,
          cancelToken: cancelToken,
        );
        importedPages.add(pageNumber);
        downloaded += 1;
        onProgress?.call((downloaded / pageNumbers.length).clamp(0, 1));
      }

      importedPages.sort();
      final finalDirectory =
          Directory(_packDirectoryPath(edition, pack.version));
      if (finalDirectory.existsSync()) {
        await finalDirectory.delete(recursive: true);
      }
      await finalDirectory.parent.create(recursive: true);
      await stagingDirectory.rename(finalDirectory.path);

      final downloadedPack = QuranDownloadedAssetPack(
        edition: edition,
        folderName: pack.folderName,
        version: pack.version,
        sourceUrl: assetsBaseUrl,
        directoryPath: finalDirectory.path,
        archivePath: '',
        pageCount: importedPages.length,
        fileExtension: pack.fileExtension.trim().isEmpty
            ? 'webp'
            : pack.fileExtension.trim().toLowerCase(),
        availableImportedPages: List<int>.unmodifiable(importedPages),
        completedAtIso: DateTime.now().toUtc().toIso8601String(),
      );
      await _writeManifest(downloadedPack);
      _clearLocalPagePathCacheForEdition(edition);
      onProgress?.call(1);
      return downloadedPack;
    } finally {
      if (stagingDirectory.existsSync()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _downloadRemotePage({
    required String url,
    required File destinationFile,
    CancelToken? cancelToken,
  }) async {
    final tempFile = File('${destinationFile.path}.download');
    await destinationFile.parent.create(recursive: true);
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    await _dio.downloadUri(
      Uri.parse(url),
      tempFile.path,
      cancelToken: cancelToken,
      deleteOnError: true,
    );
    if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
      throw StateError('Downloaded page asset is empty.');
    }
    if (destinationFile.existsSync()) {
      await destinationFile.delete();
    }
    await tempFile.rename(destinationFile.path);
  }

  List<int> _remotePageNumbers(ReaderRemoteAssetPack pack) {
    final explicitPages = pack.availableImportedPages
        .where((pageNumber) => pageNumber > 0)
        .toSet()
        .toList()
      ..sort();
    if (explicitPages.isNotEmpty) {
      return explicitPages;
    }

    final start = pack.contiguousImportedPageStart ?? 1;
    final end = pack.contiguousImportedPageEnd ?? pack.pageCount;
    if (start <= 0 || end < start) {
      return const [];
    }
    return List<int>.generate(end - start + 1, (index) => start + index);
  }

  Future<void> removeEditionPack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
  }) async {
    await removeZipPack(edition);
  }

  Future<void> removeZipPack(MushafEdition edition) async {
    await initialize();
    _clearLocalPagePathCacheForEdition(edition);
    final directory = Directory(_editionDirectoryPath(edition));
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
    final archiveDirectory = Directory(_archiveEditionDirectoryPath(edition));
    if (archiveDirectory.existsSync()) {
      await archiveDirectory.delete(recursive: true);
    }
  }

  Future<void> _downloadArchive({
    required QuranZipAssetPack zipPack,
    required File archiveFile,
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final tempFile = File('${archiveFile.path}.download');
    await archiveFile.parent.create(recursive: true);
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    final uri = _validatedDownloadUri(zipPack);

    await _dio.downloadUri(
      uri,
      tempFile.path,
      cancelToken: cancelToken,
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        if (total <= 0) {
          onProgress(0);
          return;
        }
        onProgress((received / total).clamp(0, 1));
      },
    );

    if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
      throw StateError('Downloaded ZIP for ${zipPack.title} is empty.');
    }
    if (archiveFile.existsSync()) {
      await archiveFile.delete();
    }
    await tempFile.rename(archiveFile.path);
  }

  Future<QuranDownloadedAssetPack> _publishExtractedPages({
    required QuranZipAssetPack zipPack,
    required String version,
    required String archivePath,
    required Directory extractDirectory,
    required Directory stagingDirectory,
    required void Function(double progress) onProgress,
  }) async {
    final pageFiles = _findPageImageFiles(extractDirectory);
    if (pageFiles.isEmpty) {
      throw StateError('ZIP for ${zipPack.title} did not contain page images.');
    }

    await stagingDirectory.create(recursive: true);
    final importedPages = <int>[];
    final extensionCounts = <String, int>{};
    var copied = 0;
    for (final entry in pageFiles.entries) {
      final importedPageNumber = entry.key;
      final sourceFile = entry.value;
      final extension = _fileExtension(sourceFile).toLowerCase();
      extensionCounts[extension] = (extensionCounts[extension] ?? 0) + 1;
      final destinationFile = File(
        '${stagingDirectory.path}${Platform.pathSeparator}'
        '${importedPageNumber.toString().padLeft(3, '0')}.$extension',
      );
      await destinationFile.parent.create(recursive: true);
      await sourceFile.copy(destinationFile.path);
      importedPages.add(importedPageNumber);
      copied += 1;
      onProgress(copied / pageFiles.length);
    }
    importedPages.sort();

    final fileExtension = _mostCommonExtension(extensionCounts);
    final finalDirectory =
        Directory(_packDirectoryPath(zipPack.edition, version));
    if (finalDirectory.existsSync()) {
      await finalDirectory.delete(recursive: true);
    }
    await finalDirectory.parent.create(recursive: true);
    await stagingDirectory.rename(finalDirectory.path);

    final downloadedPack = QuranDownloadedAssetPack(
      edition: zipPack.edition,
      folderName: zipPack.key,
      version: version,
      sourceUrl: zipPack.url,
      directoryPath: finalDirectory.path,
      archivePath: archivePath,
      pageCount: importedPages.length,
      fileExtension: fileExtension,
      availableImportedPages: List<int>.unmodifiable(importedPages),
      completedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    await _writeManifest(downloadedPack);
    _clearLocalPagePathCacheForEdition(zipPack.edition);
    return downloadedPack;
  }

  Map<int, File> _findPageImageFiles(Directory extractDirectory) {
    final result = <int, File>{};
    final files = extractDirectory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>();
    for (final file in files) {
      if (!file.existsSync() || file.lengthSync() == 0) {
        continue;
      }
      final extension = _fileExtension(file).toLowerCase();
      if (!_supportedImageExtensions.contains(extension)) {
        continue;
      }
      final basename = file.uri.pathSegments.last;
      final dotIndex = basename.lastIndexOf('.');
      if (dotIndex <= 0) {
        continue;
      }
      final pageNumber = _pageNumberFromFilename(basename);
      if (pageNumber == null || pageNumber <= 0) {
        continue;
      }
      result[pageNumber] = file;
    }
    return Map<int, File>.fromEntries(
      result.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)),
    );
  }

  Future<void> _writeManifest(QuranDownloadedAssetPack pack) async {
    final manifestFile = File(_manifestPath(pack.edition, pack.version));
    await manifestFile.writeAsString(
      json.encode(<String, dynamic>{
        'edition': pack.edition.storageValue,
        'folderName': pack.folderName,
        'version': pack.version,
        'sourceUrl': pack.sourceUrl,
        'directoryPath': pack.directoryPath,
        'archivePath': pack.archivePath,
        'pageCount': pack.pageCount,
        'fileExtension': pack.fileExtension,
        'availableImportedPages': pack.availableImportedPages,
        'completedAt': pack.completedAtIso,
      }),
      flush: true,
    );
  }

  QuranDownloadedAssetPack? _readManifest(File manifestFile) {
    if (!manifestFile.existsSync() || manifestFile.lengthSync() == 0) {
      return null;
    }

    try {
      final payload =
          json.decode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final edition =
          MushafEditionX.fromStorageValue(payload['edition'] as String?);
      final pages = (payload['availableImportedPages'] as List<dynamic>? ??
              const <dynamic>[])
          .map((value) => value is num ? value.toInt() : int.tryParse('$value'))
          .whereType<int>()
          .where((value) => value > 0)
          .toSet()
          .toList()
        ..sort();
      final version = (payload['version'] as String? ?? '').trim();
      final fallbackVersion = manifestFile.parent.uri.pathSegments
              .where((segment) => segment.trim().isNotEmpty)
              .lastOrNull ??
          edition.storageValue;
      return QuranDownloadedAssetPack(
        edition: edition,
        folderName: (payload['folderName'] as String? ?? '').trim(),
        version: version.isEmpty ? fallbackVersion : version,
        sourceUrl: (payload['sourceUrl'] as String? ?? '').trim(),
        directoryPath:
            (payload['directoryPath'] as String? ?? manifestFile.parent.path)
                .trim(),
        archivePath: (payload['archivePath'] as String? ?? '').trim(),
        pageCount: (payload['pageCount'] as num? ?? pages.length).toInt(),
        fileExtension: (payload['fileExtension'] as String? ?? 'webp')
            .trim()
            .toLowerCase(),
        availableImportedPages: List<int>.unmodifiable(pages),
        completedAtIso: (payload['completedAt'] as String? ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }

  bool _downloadedPackHasUsableFiles(QuranDownloadedAssetPack pack) {
    if (pack.directoryPath.trim().isEmpty ||
        !Directory(pack.directoryPath).existsSync()) {
      return false;
    }

    final pagesToProbe = <int>{};
    if (pack.availableImportedPages.isNotEmpty) {
      pagesToProbe
        ..add(pack.availableImportedPages.first)
        ..add(pack.availableImportedPages.last);
    } else {
      pagesToProbe.add(1);
    }

    for (final pageNumber in pagesToProbe) {
      final primaryFile = File(
        _pagePathWithExtension(
          pack.edition,
          pack.version,
          pageNumber,
          pack.fileExtension,
        ),
      );
      if (primaryFile.existsSync() && primaryFile.lengthSync() > 0) {
        continue;
      }

      final hasFallback = _supportedImageExtensions.any((extension) {
        final fallbackFile = File(
          _pagePathWithExtension(
            pack.edition,
            pack.version,
            pageNumber,
            extension,
          ),
        );
        return fallbackFile.existsSync() && fallbackFile.lengthSync() > 0;
      });
      if (!hasFallback) {
        return false;
      }
    }

    return true;
  }

  String? _readLocalPagePathCache(String cacheKey) {
    final cached = _localPagePathCache.remove(cacheKey);
    _localPagePathCache[cacheKey] = cached;
    return cached;
  }

  void _rememberLocalPagePath(String cacheKey, String? path) {
    _localPagePathCache.remove(cacheKey);
    _localPagePathCache[cacheKey] = path;
    while (_localPagePathCache.length > 512) {
      _localPagePathCache.remove(_localPagePathCache.keys.first);
    }
  }

  void _clearLocalPagePathCacheForEdition(MushafEdition edition) {
    final prefix = '${edition.storageValue}|';
    _localPagePathCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  String _editionDirectoryPath(MushafEdition edition) {
    return '${_offlineRoot!.path}${Platform.pathSeparator}${edition.storageValue}';
  }

  String _archiveEditionDirectoryPath(MushafEdition edition) {
    return '${_archiveRoot!.path}${Platform.pathSeparator}${edition.storageValue}';
  }

  String _packDirectoryPath(MushafEdition edition, String version) {
    return '${_editionDirectoryPath(edition)}${Platform.pathSeparator}$version';
  }

  String _manifestPath(MushafEdition edition, String version) {
    return '${_packDirectoryPath(edition, version)}'
        '${Platform.pathSeparator}$_manifestFileName';
  }

  String _pagePath(
    MushafEdition edition,
    ReaderRemoteAssetPack pack,
    int importedPageNumber,
  ) {
    return _pagePathWithExtension(
      edition,
      pack.version,
      importedPageNumber,
      pack.fileExtension,
    );
  }

  String _pagePathWithExtension(
    MushafEdition edition,
    String version,
    int importedPageNumber,
    String extension,
  ) {
    return '${_packDirectoryPath(edition, version)}'
        '${Platform.pathSeparator}'
        '${importedPageNumber.toString().padLeft(3, '0')}.$extension';
  }

  String _archivePath(QuranZipAssetPack zipPack, String version) {
    return '${_archiveEditionDirectoryPath(zipPack.edition)}'
        '${Platform.pathSeparator}$version.zip';
  }

  String _versionForZipPack(QuranZipAssetPack zipPack) {
    final uri = Uri.tryParse(zipPack.url);
    final filename = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '${zipPack.key}.zip';
    final dotIndex = filename.lastIndexOf('.');
    final basename = dotIndex > 0 ? filename.substring(0, dotIndex) : filename;
    final sanitized = basename
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return sanitized.isEmpty ? zipPack.key : sanitized;
  }

  String _fileExtension(File file) {
    final name = file.uri.pathSegments.last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex <= 0 ? '' : name.substring(dotIndex + 1);
  }

  int? _pageNumberFromFilename(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    final namePart = dotIndex <= 0 ? filename : filename.substring(0, dotIndex);
    final exact = int.tryParse(namePart);
    if (exact != null) {
      return exact;
    }
    final match = RegExp(r'(\d{1,4})$').firstMatch(namePart);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  String _mostCommonExtension(Map<String, int> extensionCounts) {
    if (extensionCounts.isEmpty) {
      return 'webp';
    }
    final entries = extensionCounts.entries.toList()
      ..sort((left, right) {
        final countDiff = right.value.compareTo(left.value);
        if (countDiff != 0) {
          return countDiff;
        }
        return _extensionPriority(right.key).compareTo(
          _extensionPriority(left.key),
        );
      });
    return entries.first.key;
  }

  int _extensionPriority(String extension) {
    return switch (extension.trim().toLowerCase()) {
      'webp' => 4,
      'png' => 3,
      'jpg' => 2,
      'jpeg' => 2,
      _ => 0,
    };
  }

  Uri _validatedDownloadUri(QuranZipAssetPack zipPack) {
    final uri = Uri.tryParse(zipPack.url.trim());
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null ||
        uri.host.trim().isEmpty ||
        (scheme != 'https' && scheme != 'http')) {
      throw StateError('Invalid ZIP URL for ${zipPack.title}.');
    }
    return uri;
  }

  void dispose() {
    _dio.close(force: true);
    _catalogService.dispose();
  }
}
