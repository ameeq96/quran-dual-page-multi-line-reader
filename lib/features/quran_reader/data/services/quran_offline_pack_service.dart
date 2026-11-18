import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/browser_file_store.dart';
import '../../domain/models/quran_asset_pack_download.dart';
import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_settings.dart';
import 'quran_asset_pack_catalog_service.dart';
import 'quran_zip_extraction_service.dart';
import 'quran_resumable_download_service.dart';

class QuranOfflinePackService {
  QuranOfflinePackService({
    Dio? dio,
    Directory? documentsDirectory,
    Directory? temporaryDirectory,
    QuranResumableDownloadService? resumableDownloadService,
    QuranAssetPackCatalogService? catalogService,
    QuranZipExtractionService extractionService =
        const QuranZipExtractionService(),
  })  : _documentsDirectory = documentsDirectory,
        _temporaryDirectory = temporaryDirectory,
        _injectedResumableDownloads = resumableDownloadService,
        _dio = dio ?? Dio(_downloadOptions),
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
  final Directory? _documentsDirectory;
  final Directory? _temporaryDirectory;
  final QuranResumableDownloadService? _injectedResumableDownloads;
  late final _resumableDownloads = _injectedResumableDownloads ?? QuranResumableDownloadService(_dio);
  final QuranAssetPackCatalogService _catalogService;
  final QuranZipExtractionService _extractionService;
  Directory? _offlineRoot;
  Directory? _archiveRoot;
  final LinkedHashMap<String, String?> _localPagePathCache =
      LinkedHashMap<String, String?>();

  Future<void> initialize() async {
    if (kIsWeb) {
      await BrowserFileStore.instance.initialize();
      return;
    }
    final documentsDirectory = _documentsDirectory ?? await getApplicationDocumentsDirectory();
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

  Future<Map<MushafEdition, QuranPartialAssetPack>> loadPartialOfflinePacks() async {
    await initialize();
    return _resumableDownloads.loadPartials(_archiveRoot);
  }

  Future<void> discardPartialOfflinePack(MushafEdition edition) async {
    await initialize();
    await _resumableDownloads.discardEdition(edition, _archiveRoot, pageRoot: _offlineRoot);
  }

  Future<QuranPackStorageInfo> offlinePackStorageInfo() async {
    await initialize();
    final editionBytes = <MushafEdition, int>{};
    var installed = 0;
    var archives = 0;
    var partial = 0;
    if (kIsWeb) {
      final store = BrowserFileStore.instance;
      for (final edition in MushafEdition.values) {
        final bytes = store.bytesForPrefix('edition:${edition.storageValue}:');
        editionBytes[edition] = bytes;
        installed += bytes;
      }
      partial = store.bytesForPrefix('partial:');
      for (final entry in store.manifests.entries) {
        if (!entry.key.startsWith('partial:') || entry.value['kind'] != 'pages') continue;
        final edition = MushafEdition.register('${entry.value['edition']}');
        final generation = entry.value['pageNamespace'] as String?;
        if (edition == null || generation == null) continue;
        final bytes = store.bytesForPrefix('edition:${edition.storageValue}:page:$generation:');
        partial += bytes;
        installed -= bytes;
        editionBytes[edition] = (editionBytes[edition] ?? 0) - bytes;
      }
      final estimate = await store.storageEstimate();
      return QuranPackStorageInfo(installedBytes: installed, archiveBytes: 0,
        partialBytes: partial, editionBytes: Map.unmodifiable(editionBytes),
        browserUsageBytes: estimate['usage'], browserQuotaBytes: estimate['quota']);
    }
    for (final edition in MushafEdition.values) {
      var bytes = 0;
      final directory = Directory(_editionDirectoryPath(edition));
      if (await directory.exists()) {
        await for (final file in directory.list(recursive: true, followLinks: false)) {
          if (file is File) bytes += await file.length();
        }
      }
      installed += bytes;
      editionBytes[edition] = bytes;
    }
    await for (final file in _archiveRoot!.list(recursive: true, followLinks: false)) {
      if (file is! File) continue;
      if (file.path.endsWith('.download')) partial += await file.length();
      if (file.path.endsWith('.zip')) archives += await file.length();
    }
    await for (final directory in _offlineRoot!.list(followLinks: false)) {
      if (directory is! Directory || !directory.uri.pathSegments.any((segment) => segment.startsWith('.incoming_'))) continue;
      await for (final file in directory.list(recursive: true, followLinks: false)) {
        if (file is File) partial += await file.length();
      }
    }
    return QuranPackStorageInfo(installedBytes: installed, archiveBytes: archives,
      partialBytes: partial, editionBytes: Map.unmodifiable(editionBytes));
  }

  Future<Map<MushafEdition, QuranDownloadedAssetPack>>
      loadDownloadedZipPacks() async {
    await initialize();
    final entries = <MushafEdition, QuranDownloadedAssetPack>{};
    if (kIsWeb) {
      for (final entry in BrowserFileStore.instance.manifests.entries) {
        if (!entry.key.startsWith('edition:') || !entry.key.endsWith(':manifest')) continue;
        final pack = _readBrowserManifest(entry.value);
        if (pack != null && _downloadedPackHasUsableFiles(pack)) entries[pack.edition] = pack;
      }
      return Map.unmodifiable(entries);
    }
    await for (final directory in _offlineRoot!.list(followLinks: false)) {
      if (directory is! Directory) continue;
      final key = directory.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(key)) continue;
      await for (final versionDirectory in directory.list(followLinks: false)) {
        if (versionDirectory is! Directory) continue;
        final manifest = File('${versionDirectory.path}${Platform.pathSeparator}$_manifestFileName');
        if (_isDiscoverableManifest(manifest, key)) {
          MushafEdition.register(key);
          break;
        }
      }
    }
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
    final downloadedPack = kIsWeb
        ? _readBrowserManifest(BrowserFileStore.instance.manifests[_browserManifestKey(edition)])
        : _readManifest(File(_manifestPath(edition, pack.version)));
    return downloadedPack != null &&
        downloadedPack.pageCount > 0 &&
        _downloadedPackHasUsableFiles(downloadedPack);
  }

  String? localFilePathForPage({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required int importedPageNumber,
  }) {
    if (kIsWeb) {
      final manifest = _readBrowserManifest(BrowserFileStore.instance.manifests[_browserManifestKey(edition)]);
      final generation = manifest?.version == pack.version ? manifest?.cacheGeneration ?? pack.version : pack.version;
      for (final extension in {pack.fileExtension, ..._supportedImageExtensions}) {
        final url = BrowserFileStore.instance.urlFor(_browserPageKey(edition, generation, importedPageNumber, extension));
        if (url != null) return url;
      }
      return null;
    }
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
    void Function(QuranPackTransferProgress)? onTransferProgress,
    CancelToken? cancelToken,
  }) async {
    await initialize();
    _validatedDownloadUri(zipPack);
    final version = _versionForZipPack(zipPack);
    if (kIsWeb) {
      return _downloadBrowserZipPack(zipPack: zipPack, version: version, onProgress: onProgress, onTransferProgress: onTransferProgress, cancelToken: cancelToken);
    }
    final manifestFile = File(_manifestPath(zipPack.edition, version));
    final existing = _readManifest(manifestFile);
    if (existing != null && existing.sourceUrl == zipPack.url &&
        existing.pageCount > 0 &&
        _downloadedPackHasUsableFiles(existing)) {
      onProgress?.call(1);
      return existing;
    }

    final archiveFile = File(_archivePath(zipPack, version));
    if (await archiveFile.exists() && existing?.sourceUrl != zipPack.url &&
        !await _resumableDownloads.matchesNativeArchive(archiveFile, zipPack, version)) {
      await _resumableDownloads.discardNativeArchive(archiveFile);
    }
    final usedCachedArchive =
        archiveFile.existsSync() && archiveFile.lengthSync() > 0;
    if (!archiveFile.existsSync() || archiveFile.lengthSync() == 0) {
      await _downloadArchive(
        zipPack: zipPack,
        archiveFile: archiveFile,
        cancelToken: cancelToken,
        onProgress: (progress) => onProgress?.call(progress * 0.55),
        onTransferProgress: onTransferProgress,
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
        onTransferProgress: onTransferProgress,
        cancelToken: cancelToken,
      );
    } catch (_) {
      if (cancelToken?.isCancelled == true) rethrow;
      if (!usedCachedArchive) {
        await _resumableDownloads.discardNativeArchive(archiveFile);
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
        onTransferProgress: onTransferProgress,
      );
      return _extractAndPublishArchive(
        zipPack: zipPack,
        version: version,
        archiveFile: archiveFile,
        onProgress: onProgress,
        onTransferProgress: onTransferProgress,
        cancelToken: cancelToken,
      );
    }
  }

  Future<QuranDownloadedAssetPack> _extractAndPublishArchive({
    required QuranZipAssetPack zipPack,
    required String version,
    required File archiveFile,
    void Function(double progress)? onProgress,
    void Function(QuranPackTransferProgress)? onTransferProgress,
    CancelToken? cancelToken,
  }) async {
    final tempRoot = _temporaryDirectory ?? await getTemporaryDirectory();
    final extractDirectory = Directory(
      '${tempRoot.path}${Platform.pathSeparator}'
      'quran_zip_extract_${zipPack.key}_${DateTime.now().microsecondsSinceEpoch}',
    );
    final stagingDirectory = Directory(
      '${_offlineRoot!.path}${Platform.pathSeparator}'
      '.incoming_${zipPack.key}_${DateTime.now().microsecondsSinceEpoch}',
    );

    try {
      cancelToken?.throwIfCancellationRequested();
      final archiveBytes = await archiveFile.length();
      onTransferProgress?.call(QuranPackTransferProgress(progress: 0.55, receivedBytes: archiveBytes,
        totalBytes: archiveBytes, phase: QuranPackTransferPhase.extracting));
      await _extractionService.extractZip(
        zipPath: archiveFile.path,
        outputDirectoryPath: extractDirectory.path,
        cancelToken: cancelToken,
      );
      cancelToken?.throwIfCancellationRequested();
      onProgress?.call(0.72);
      onTransferProgress?.call(QuranPackTransferProgress(progress: 0.72, receivedBytes: archiveBytes,
        totalBytes: archiveBytes, phase: QuranPackTransferPhase.publishing));

      final normalized = await _publishExtractedPages(
        zipPack: zipPack,
        version: version,
        archivePath: archiveFile.path,
        extractDirectory: extractDirectory,
        stagingDirectory: stagingDirectory,
        cancelToken: cancelToken,
        onProgress: (progress) => onProgress?.call(0.72 + progress * 0.26),
      );
      try { await _resumableDownloads.discardNativeArchive(archiveFile, removeArchive: false); } catch (_) { /* Publication has committed; cleanup must not invalidate it. */ }
      onProgress?.call(1);
      return normalized;
    } catch (_) {
      if (cancelToken?.isCancelled == true && !QuranResumableDownloadService.isPaused(cancelToken)) {
        await _resumableDownloads.discardNativeArchive(archiveFile);
      }
      rethrow;
    } finally {
      if (extractDirectory.existsSync()) {
        await extractDirectory.delete(recursive: true);
      }
      if (stagingDirectory.existsSync()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  String _browserManifestKey(MushafEdition edition) => 'edition:${edition.storageValue}:manifest';

  String _browserPageKey(MushafEdition edition, String version, int page, String extension) =>
      'edition:${edition.storageValue}:page:$version:$page.$extension';

  QuranDownloadedAssetPack? _readBrowserManifest(Map<String, dynamic>? value) {
    if (value == null) return null;
    try {
      return QuranDownloadedAssetPack(
        edition: MushafEditionX.fromStorageValue(value['edition'] as String?),
        folderName: value['folderName'] as String,
        version: value['version'] as String,
        sourceUrl: value['sourceUrl'] as String,
        directoryPath: 'browser',
        archivePath: '',
        pageCount: (value['pageCount'] as num).toInt(),
        fileExtension: value['fileExtension'] as String,
        availableImportedPages: (value['availableImportedPages'] as List).map((page) => (page as num).toInt()).toList(),
        completedAtIso: value['completedAt'] as String,
        cacheGeneration: value['cacheGeneration'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<QuranDownloadedAssetPack> _publishBrowserPack({
    required MushafEdition edition,
    required String folderName,
    required String version,
    required String sourceUrl,
    required List<int> pages,
    required Map<String, int> extensions,
    String? cacheGeneration,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancellationRequested();
    pages.sort();
    final value = <String, dynamic>{
      'edition': edition.storageValue,
      'folderName': folderName,
      'version': version,
      'sourceUrl': sourceUrl,
      'pageCount': pages.length,
      'fileExtension': _mostCommonExtension(extensions),
      'availableImportedPages': pages,
      'completedAt': DateTime.now().toUtc().toIso8601String(),
      if (cacheGeneration != null) 'cacheGeneration': cacheGeneration,
    };
    await BrowserFileStore.instance.putManifest(_browserManifestKey(edition), value);
    return _readBrowserManifest(value)!;
  }

  Future<QuranDownloadedAssetPack> _downloadBrowserZipPack({
    required QuranZipAssetPack zipPack,
    required String version,
    void Function(double progress)? onProgress,
    void Function(QuranPackTransferProgress)? onTransferProgress,
    CancelToken? cancelToken,
  }) async {
    final store = BrowserFileStore.instance;
    final existing = _readBrowserManifest(store.manifests[_browserManifestKey(zipPack.edition)]);
    if (existing != null && existing.sourceUrl == zipPack.url && existing.version == version && _downloadedPackHasUsableFiles(existing)) {
      onProgress?.call(1);
      return existing;
    }
    final pageNamespace = '${version}_${DateTime.now().microsecondsSinceEpoch}';
    final prefix = 'edition:${zipPack.edition.storageValue}:page:$pageNamespace:';
    var published = false;
    try {
      final bytes = await _resumableDownloads.downloadBrowser(pack: zipPack, version: version,
        cancelToken: cancelToken, onProgress: (value) {
          onProgress?.call(value.progress * 0.55);
          onTransferProgress?.call(QuranPackTransferProgress(progress: value.progress * 0.55,
            receivedBytes: value.receivedBytes, totalBytes: value.totalBytes));
        });
      cancelToken?.throwIfCancellationRequested();
      onTransferProgress?.call(QuranPackTransferProgress(progress: 0.55, receivedBytes: bytes.length,
        totalBytes: bytes.length, phase: QuranPackTransferPhase.extracting));
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes, verify: true);
      } catch (_) {
        await _resumableDownloads.completeBrowser(zipPack.edition);
        rethrow;
      }
      final pageFiles = <int, ArchiveFile>{};
      for (final entry in archive.files) {
        if (!entry.isFile || entry.isSymbolicLink) continue;
        final name = entry.name.split('/').last;
        final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';
        final page = _pageNumberFromFilename(name);
        if (page != null && page > 0 && _supportedImageExtensions.contains(extension)) pageFiles[page] = entry;
      }
      if (pageFiles.isEmpty) throw StateError('ZIP did not contain page images.');
      final estimate = await store.storageEstimate();
      final extractedBytes = pageFiles.values.fold<int>(0, (sum, file) => sum + file.size);
      if (estimate['quota'] != null && estimate['usage'] != null &&
          extractedBytes > estimate['quota']! - estimate['usage']!) {
        throw StateError('Browser storage is full. Free some space and resume the download.');
      }
      final extensions = <String, int>{};
      var saved = 0;
      for (final entry in pageFiles.entries) {
        cancelToken?.throwIfCancellationRequested();
        final extension = entry.value.name.split('.').last.toLowerCase();
        final bytes = Uint8List.fromList(entry.value.content as List<int>);
        if (bytes.isEmpty) throw StateError('ZIP contains an empty page.');
        await store.putBytes(_browserPageKey(zipPack.edition, pageNamespace, entry.key, extension), bytes,
            extension == 'jpg' || extension == 'jpeg' ? 'image/jpeg' : 'image/$extension');
        extensions[extension] = (extensions[extension] ?? 0) + 1;
        saved++;
        onProgress?.call(0.55 + saved / pageFiles.length * 0.44);
        await Future<void>.delayed(Duration.zero);
      }
      onTransferProgress?.call(QuranPackTransferProgress(progress: 0.99, receivedBytes: bytes.length,
        totalBytes: bytes.length, phase: QuranPackTransferPhase.publishing));
      final pack = await _publishBrowserPack(edition: zipPack.edition, folderName: zipPack.key, version: version, cacheGeneration: pageNamespace,
          sourceUrl: zipPack.url, pages: pageFiles.keys.toList(), extensions: extensions, cancelToken: cancelToken);
      published = true;
      try { await _resumableDownloads.completeBrowser(zipPack.edition); } catch (_) { /* Publication has committed; partial cleanup can be retried. */ }
      if (existing != null) {
        try { await store.removePrefix('edition:${zipPack.edition.storageValue}:page:${existing.cacheGeneration ?? existing.version}:'); } catch (_) { /* Keep the committed edition usable when cleanup fails. */ }
      }
      onProgress?.call(1);
      return pack;
    } catch (_) {
      if (!published) await store.removePrefix(prefix);
      if (cancelToken?.isCancelled == true && !QuranResumableDownloadService.isPaused(cancelToken)) {
        await _resumableDownloads.completeBrowser(zipPack.edition);
      }
      rethrow;
    }
  }

  Future<QuranDownloadedAssetPack> _downloadBrowserPagePack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required String assetsBaseUrl,
    void Function(double progress)? onProgress,
    void Function(QuranPackTransferProgress)? onTransferProgress,
    CancelToken? cancelToken,
  }) async {
    final store = BrowserFileStore.instance;
    final pages = _remotePageNumbers(pack);
    if (pages.isEmpty || assetsBaseUrl.trim().isEmpty) throw StateError('No remote pages are available.');
    final extension = pack.fileExtension.trim().isEmpty ? 'webp' : pack.fileExtension.toLowerCase();
    final existing = _readBrowserManifest(store.manifests[_browserManifestKey(edition)]);
    if (existing != null && existing.sourceUrl == assetsBaseUrl && existing.version == pack.version &&
        existing.folderName == pack.folderName && _downloadedPackHasUsableFiles(existing)) {
      return existing;
    }
    final fingerprint = json.encode([assetsBaseUrl, pack.folderName, pack.version, extension, pages]);
    final partialPrefix = 'partial:${edition.storageValue}:';
    var metadata = store.manifests['${partialPrefix}manifest'];
    if (metadata?['kind'] != 'pages' || metadata?['sourceFingerprint'] != fingerprint) {
      await _resumableDownloads.completeBrowser(edition, discardPages: true);
      metadata = null;
    }
    final generation = metadata?['pageNamespace'] as String? ?? '${pack.version}_${DateTime.now().microsecondsSinceEpoch}';
    final prefix = 'edition:${edition.storageValue}:page:$generation:';
    final completed = ((metadata?['completedPages'] as List?) ?? const []).whereType<int>().toSet()
      ..removeWhere((page) => store.urlFor(_browserPageKey(edition, generation, page, extension)) == null);
    metadata = <String, dynamic>{'kind': 'pages', 'edition': edition.storageValue, 'sourceUrl': assetsBaseUrl,
      'sourceFingerprint': fingerprint, 'version': pack.version, 'pageNamespace': generation,
      'receivedBytes': store.bytesForPrefix(prefix), 'completedPages': completed.toList(),
      'updatedAt': DateTime.now().toUtc().toIso8601String()};
    await store.putManifest('${partialPrefix}manifest', metadata);
    try {
      for (final page in pages) {
        cancelToken?.throwIfCancellationRequested();
        if (!completed.contains(page)) {
          final response = await _dio.get<List<int>>(pack.buildPageUrl(assetsBaseUrl, importedPageNumber: page),
              options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken);
          final bytes = response.data;
          if (bytes == null || bytes.isEmpty) throw StateError('Downloaded page is empty.');
          await store.putBytes(_browserPageKey(edition, generation, page, extension), Uint8List.fromList(bytes),
              extension == 'jpg' || extension == 'jpeg' ? 'image/jpeg' : 'image/$extension');
          completed.add(page);
          metadata['completedPages'] = completed.toList();
          metadata['receivedBytes'] = store.bytesForPrefix(prefix);
          metadata['updatedAt'] = DateTime.now().toUtc().toIso8601String();
          await store.putManifest('${partialPrefix}manifest', metadata);
        }
        final progress = completed.length / pages.length;
        onProgress?.call(progress);
        onTransferProgress?.call(QuranPackTransferProgress(progress: progress,
          receivedBytes: store.bytesForPrefix(prefix)));
      }
      cancelToken?.throwIfCancellationRequested();
      onTransferProgress?.call(QuranPackTransferProgress(progress: 0.99,
        receivedBytes: store.bytesForPrefix(prefix), phase: QuranPackTransferPhase.publishing));
      final downloaded = await _publishBrowserPack(edition: edition, folderName: pack.folderName, version: pack.version,
          sourceUrl: assetsBaseUrl, pages: pages, extensions: {extension: pages.length},
          cacheGeneration: generation, cancelToken: cancelToken);
      try { await _resumableDownloads.completeBrowser(edition); } catch (_) { /* Publication has committed; partial cleanup can be retried. */ }
      if (existing != null && (existing.cacheGeneration ?? existing.version) != generation) {
        try { await store.removePrefix('edition:${edition.storageValue}:page:${existing.cacheGeneration ?? existing.version}:'); } catch (_) { /* Cleanup can be retried without invalidating the published pack. */ }
      }
      return downloaded;
    } catch (_) {
      if (cancelToken?.isCancelled == true && !QuranResumableDownloadService.isPaused(cancelToken)) {
        await _resumableDownloads.completeBrowser(edition, discardPages: true);
      }
      rethrow;
    }
  }

  Future<void> downloadEditionPack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required String assetsBaseUrl,
    void Function(double progress)? onProgress,
    void Function(QuranPackTransferProgress)? onTransferProgress,
    CancelToken? cancelToken,
  }) async {
    final zipPacks = await fetchAvailableZipPacks();
    final zipPack =
        zipPacks.where((item) => item.edition == edition).firstOrNull;
    if (zipPack != null) {
      await downloadEditionZipPack(
        zipPack: zipPack,
        onProgress: onProgress,
        onTransferProgress: onTransferProgress,
        cancelToken: cancelToken,
      );
      return;
    }

    await _downloadRemotePagePack(
      edition: edition,
      pack: pack,
      assetsBaseUrl: assetsBaseUrl,
      onProgress: onProgress,
      onTransferProgress: onTransferProgress,
      cancelToken: cancelToken,
    );
  }

  Future<QuranDownloadedAssetPack> _downloadRemotePagePack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required String assetsBaseUrl,
    void Function(double progress)? onProgress,
    void Function(QuranPackTransferProgress)? onTransferProgress,
    CancelToken? cancelToken,
  }) async {
    await initialize();
    if (kIsWeb) {
      return _downloadBrowserPagePack(edition: edition, pack: pack, assetsBaseUrl: assetsBaseUrl,
        onProgress: onProgress, onTransferProgress: onTransferProgress, cancelToken: cancelToken);
    }
    if (assetsBaseUrl.trim().isEmpty) throw StateError('No asset base URL is available for ${edition.label}.');
    final existing = _readManifest(File(_manifestPath(edition, pack.version)));
    if (existing != null && existing.sourceUrl == assetsBaseUrl && existing.folderName == pack.folderName &&
        existing.pageCount > 0 && _downloadedPackHasUsableFiles(existing)) {
      onProgress?.call(1);
      return existing;
    }
    final pages = _remotePageNumbers(pack);
    if (pages.isEmpty) throw StateError('No remote pages are available for ${edition.label}.');
    final extension = pack.fileExtension.trim().isEmpty ? 'webp' : pack.fileExtension.trim().toLowerCase();
    final fingerprint = json.encode([assetsBaseUrl, pack.folderName, pack.version, extension, pages]);
    final safeVersion = pack.version.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final metadataFile = File('${_archiveEditionDirectoryPath(edition)}${Platform.pathSeparator}$safeVersion.pages.download.json');
    var metadata = await _resumableDownloads.readCheckpoint(metadataFile);
    final storedName = metadata?['stagingDirectoryName'] as String?;
    final canReuse = metadata?['kind'] == 'pages' && metadata?['sourceFingerprint'] == fingerprint &&
      storedName != null && RegExp(r'^\.incoming_[a-zA-Z0-9_-]+$').hasMatch(storedName);
    if (!canReuse) await _resumableDownloads.discardEdition(edition, _archiveRoot, pageRoot: _offlineRoot);
    final name = canReuse ? storedName : '.incoming_${edition.storageValue}_${DateTime.now().microsecondsSinceEpoch}';
    final stagingDirectory = Directory('${_offlineRoot!.path}${Platform.pathSeparator}$name');
    await stagingDirectory.create(recursive: true);
    final completed = canReuse ? ((metadata?['completedPages'] as List?) ?? const []).whereType<int>().toSet() : <int>{};
    completed.removeWhere((page) => !File('${stagingDirectory.path}${Platform.pathSeparator}${page.toString().padLeft(3, '0')}.$extension').existsSync());
    var received = 0;
    for (final page in completed) {
      received += await File('${stagingDirectory.path}${Platform.pathSeparator}${page.toString().padLeft(3, '0')}.$extension').length();
    }
    metadata = {'kind': 'pages', 'edition': edition.storageValue, 'sourceUrl': assetsBaseUrl,
      'sourceFingerprint': fingerprint, 'version': pack.version, 'stagingDirectoryName': name,
      'receivedBytes': received, 'completedPages': completed.toList(),
      'updatedAt': DateTime.now().toUtc().toIso8601String()};
    await metadataFile.parent.create(recursive: true);
    await _resumableDownloads.writeCheckpoint(metadataFile, metadata);
    try {
      for (final page in pages) {
        cancelToken?.throwIfCancellationRequested();
        if (!completed.contains(page)) {
          final destination = File('${stagingDirectory.path}${Platform.pathSeparator}${page.toString().padLeft(3, '0')}.$extension');
          await _downloadRemotePage(url: pack.buildPageUrl(assetsBaseUrl, importedPageNumber: page),
            destinationFile: destination, cancelToken: cancelToken);
          completed.add(page);
          received += await destination.length();
          metadata['completedPages'] = completed.toList();
          metadata['receivedBytes'] = received;
          metadata['updatedAt'] = DateTime.now().toUtc().toIso8601String();
          await _resumableDownloads.writeCheckpoint(metadataFile, metadata);
        }
        final progress = completed.length / pages.length;
        onProgress?.call(progress);
        onTransferProgress?.call(QuranPackTransferProgress(progress: progress, receivedBytes: received));
      }
      cancelToken?.throwIfCancellationRequested();
      onTransferProgress?.call(QuranPackTransferProgress(progress: 0.99, receivedBytes: received,
        phase: QuranPackTransferPhase.publishing));
      final finalDirectory = Directory(_packDirectoryPath(edition, pack.version));
      final downloaded = QuranDownloadedAssetPack(edition: edition, folderName: pack.folderName,
        version: pack.version, sourceUrl: assetsBaseUrl, directoryPath: finalDirectory.path, archivePath: '',
        pageCount: pages.length, fileExtension: extension, availableImportedPages: List.unmodifiable(pages),
        completedAtIso: DateTime.now().toUtc().toIso8601String());
      await _writeManifest(downloaded, directoryPath: stagingDirectory.path);
      await _commitStagedPack(stagingDirectory, finalDirectory);
      try { await metadataFile.delete(); } catch (_) { /* Publication has committed; checkpoint cleanup can be retried. */ }
      _clearLocalPagePathCacheForEdition(edition);
      onProgress?.call(1);
      return downloaded;
    } catch (_) {
      if (cancelToken?.isCancelled == true && !QuranResumableDownloadService.isPaused(cancelToken)) {
        await _resumableDownloads.discardEdition(edition, _archiveRoot, pageRoot: _offlineRoot);
      }
      rethrow;
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
    await _resumableDownloads.discardEdition(edition, _archiveRoot, pageRoot: _offlineRoot);
    if (kIsWeb) {
      await BrowserFileStore.instance.removePrefix('edition:${edition.storageValue}:');
      return;
    }
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
    void Function(QuranPackTransferProgress)? onTransferProgress,
    CancelToken? cancelToken,
  }) async {
    await _resumableDownloads.downloadNative(pack: zipPack, version: _versionForZipPack(zipPack),
      archive: archiveFile, cancelToken: cancelToken, onProgress: (value) {
        onProgress(value.progress);
        onTransferProgress?.call(QuranPackTransferProgress(progress: value.progress * 0.55,
          receivedBytes: value.receivedBytes, totalBytes: value.totalBytes));
      });
  }

  Future<QuranDownloadedAssetPack> _publishExtractedPages({
    required QuranZipAssetPack zipPack,
    required String version,
    required String archivePath,
    required Directory extractDirectory,
    required Directory stagingDirectory,
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
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
      cancelToken?.throwIfCancellationRequested();
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

    cancelToken?.throwIfCancellationRequested();
    final fileExtension = _mostCommonExtension(extensionCounts);
    final finalDirectory =
        Directory(_packDirectoryPath(zipPack.edition, version));
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
    await _writeManifest(downloadedPack, directoryPath: stagingDirectory.path);
    await _commitStagedPack(stagingDirectory, finalDirectory);
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

  Future<void> _writeManifest(QuranDownloadedAssetPack pack, {String? directoryPath}) async {
    final manifestFile = File(directoryPath == null ? _manifestPath(pack.edition, pack.version)
      : '$directoryPath${Platform.pathSeparator}$_manifestFileName');
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

  Future<void> _commitStagedPack(Directory staging, Directory destination) async {
    final backup = Directory('${destination.path}.previous_${DateTime.now().microsecondsSinceEpoch}');
    await destination.parent.create(recursive: true);
    final hadPrevious = await destination.exists();
    if (hadPrevious) await destination.rename(backup.path);
    try {
      await staging.rename(destination.path);
    } catch (_) {
      if (hadPrevious && await backup.exists()) await backup.rename(destination.path);
      rethrow;
    }
    if (hadPrevious && await backup.exists()) {
      try { await backup.delete(recursive: true); } catch (_) { /* A completed pack remains usable if cleanup is deferred. */ }
    }
  }

  bool _isDiscoverableManifest(File manifest, String editionKey) {
    try {
      if (FileSystemEntity.isLinkSync(manifest.path) || !manifest.existsSync() || manifest.lengthSync() == 0) return false;
      final value = json.decode(manifest.readAsStringSync());
      if (value is! Map<String, dynamic> || value['edition'] != editionKey) return false;
      final version = value['version'];
      final versionDirectory = manifest.parent;
      final directoryName = versionDirectory.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (version is! String || version != directoryName || version == '.' || version == '..' ||
          !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(version)) return false;
      final pageCount = value['pageCount'];
      if (pageCount is! num || !pageCount.isFinite || pageCount <= 0) return false;
      for (final key in ['folderName', 'sourceUrl', 'directoryPath', 'archivePath', 'completedAt']) {
        if (value[key] != null && value[key] is! String) return false;
      }
      final extension = value['fileExtension'] ?? 'webp';
      if (extension is! String || !_supportedImageExtensions.contains(extension.toLowerCase())) return false;
      final storedDirectory = value['directoryPath'] as String?;
      if (storedDirectory != null) {
        final storedUri = Directory(storedDirectory).absolute.uri.normalizePath().toString();
        final actualUri = versionDirectory.absolute.uri.normalizePath().toString();
        if (Platform.isWindows ? storedUri.toLowerCase() != actualUri.toLowerCase() : storedUri != actualUri) return false;
      }
      final rawPages = value['availableImportedPages'] ?? const [];
      if (rawPages is! List) return false;
      final pages = rawPages.map((page) => page is num ? page.toInt() : int.tryParse('$page'))
          .whereType<int>().where((page) => page > 0).toList()..sort();
      final probes = pages.isEmpty ? <int>{1} : <int>{pages.first, pages.last};
      return probes.every((page) => _supportedImageExtensions.any((extension) {
        final file = File('${versionDirectory.path}${Platform.pathSeparator}${page.toString().padLeft(3, '0')}.$extension');
        return !FileSystemEntity.isLinkSync(file.path) && file.existsSync() && file.lengthSync() > 0;
      }));
    } catch (_) {
      return false;
    }
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
    if (kIsWeb) {
      return pack.pageCount > 0 && pack.availableImportedPages.isNotEmpty &&
          pack.availableImportedPages.every((page) => _supportedImageExtensions.any((extension) =>
              BrowserFileStore.instance.urlFor(_browserPageKey(pack.edition, pack.cacheGeneration ?? pack.version, page, extension)) != null));
    }
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
