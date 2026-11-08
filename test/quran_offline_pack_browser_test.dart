@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/core/services/browser_file_store.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_asset_pack_catalog_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_offline_pack_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_resumable_download_service.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_asset_pack_download.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_admin_config.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_settings.dart';

void main() {
  final store = BrowserFileStore.instance;
  const edition = MushafEdition.lines13;
  late Dio dio;
  late _PackAdapter adapter;
  late QuranOfflinePackService service;

  setUp(() async {
    await store.initialize();
    await store.removePrefix('edition:${edition.storageValue}:');
    await store.removePrefix('partial:${edition.storageValue}:');
    adapter = _PackAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    service = QuranOfflinePackService(dio: dio, catalogService: _NoZipCatalog());
  });

  tearDown(() async {
    service.dispose();
    await store.removePrefix('edition:${edition.storageValue}:');
    await store.removePrefix('partial:${edition.storageValue}:');
  });

  test('same-version changed-source ZIP preserves installed generation on cancel', () async {
    const old = QuranZipAssetPack(edition: edition, key: '13_line', url: 'https://example.com/13_line.zip?old');
    final installed = await service.downloadEditionZipPack(zipPack: old);
    final previousManifest = Map.of(store.manifests['edition:${edition.storageValue}:manifest']!);
    final previousUrl = service.localFilePathForPage(edition: edition,
      pack: installed.toRemoteAssetPack(), importedPageNumber: 1);
    expect(previousUrl, isNotNull);
    final token = CancelToken();
    final replacement = QuranZipAssetPack(edition: edition, key: old.key, url: 'https://example.com/13_line.zip?new');
    await expectLater(service.downloadEditionZipPack(zipPack: replacement, cancelToken: token,
      onTransferProgress: (progress) {
        if (progress.phase == QuranPackTransferPhase.publishing) token.cancel(QuranPackDownloadStop.cancel);
      }), throwsA(isA<DioException>()));
    expect(store.manifests['edition:${edition.storageValue}:manifest'], previousManifest);
    expect(service.localFilePathForPage(edition: edition,
      pack: installed.toRemoteAssetPack(), importedPageNumber: 1), previousUrl);
    final updated = await service.downloadEditionZipPack(zipPack: replacement);
    expect(updated.version, '13_line');
    expect(updated.cacheGeneration, isNot(installed.cacheGeneration));
    expect(store.manifests['partial:${edition.storageValue}:manifest'], isNull);
  });

  test('page checkpoint resumes and legacy installed pages survive a pause', () async {
    const pack = ReaderRemoteAssetPack(edition: edition, folderName: 'pages', version: 'v1',
      pageCount: 2, fileExtension: 'webp', availableImportedPages: const [1, 2]);
    for (final page in [1, 2]) {
      await store.putBytes('edition:${edition.storageValue}:page:v1:$page.webp', Uint8List.fromList([9]), 'image/webp');
    }
    await store.putManifest('edition:${edition.storageValue}:manifest', {
      'edition': edition.storageValue, 'folderName': 'pages', 'version': 'v1',
      'sourceUrl': 'https://old.example.com', 'pageCount': 2, 'fileExtension': 'webp',
      'availableImportedPages': [1, 2], 'completedAt': DateTime.now().toIso8601String(),
    });
    final previous = service.localFilePathForPage(edition: edition, pack: pack, importedPageNumber: 1);
    final token = CancelToken();
    await expectLater(service.downloadEditionPack(edition: edition, pack: pack,
      assetsBaseUrl: 'https://new.example.com', cancelToken: token,
      onTransferProgress: (progress) {
        if (progress.receivedBytes > 0) token.cancel(QuranPackDownloadStop.pause);
      }), throwsA(isA<DioException>()));
    expect(service.localFilePathForPage(edition: edition, pack: pack, importedPageNumber: 1), previous);
    expect((await service.loadPartialOfflinePacks())[edition]?.canResume, isTrue);
    expect(adapter.pageRequests, hasLength(1));
    await service.downloadEditionPack(edition: edition, pack: pack, assetsBaseUrl: 'https://new.example.com');
    expect(adapter.pageRequests, hasLength(2));
    expect(adapter.pageRequests.toSet(), hasLength(2));
    expect((await service.loadDownloadedZipPacks())[edition]?.version, 'v1');
    expect(await service.loadPartialOfflinePacks(), isEmpty);
    expect(service.localFilePathForPage(edition: edition, pack: pack, importedPageNumber: 1), isNot(previous));
  });

  test('removing an edition also removes its partial checkpoint', () async {
    await store.putBytes('partial:${edition.storageValue}:chunk:0', Uint8List.fromList([1, 2]), 'application/zip');
    await store.putManifest('partial:${edition.storageValue}:manifest', {
      'edition': edition.storageValue, 'sourceUrl': 'https://example.com/test.zip',
      'version': 'v1', 'receivedBytes': 2, 'totalBytes': 4,
    });
    await service.removeZipPack(edition);
    expect(store.bytesForPrefix('partial:${edition.storageValue}:'), 0);
    expect(store.manifests['partial:${edition.storageValue}:manifest'], isNull);
  });

  test('post-commit cleanup failure preserves published ZIP and page packs', () async {
    service = QuranOfflinePackService(dio: dio, catalogService: _NoZipCatalog(),
      resumableDownloadService: _FailingCleanupDownloads(dio));
    const zip = QuranZipAssetPack(edition: edition, key: '13_line', url: 'https://example.com/13_line.zip');
    final published = await service.downloadEditionZipPack(zipPack: zip);
    expect(service.localFilePathForPage(edition: edition,
      pack: published.toRemoteAssetPack(), importedPageNumber: 1), isNotNull);
    expect((await service.loadDownloadedZipPacks())[edition]?.pageCount, 1);
    const pages = ReaderRemoteAssetPack(edition: edition, folderName: 'pages', version: 'v1',
      pageCount: 2, fileExtension: 'webp', availableImportedPages: const [1, 2]);
    await service.downloadEditionPack(edition: edition, pack: pages, assetsBaseUrl: 'https://new.example.com');
    expect((await service.loadDownloadedZipPacks())[edition]?.version, 'v1');
    expect(service.localFilePathForPage(edition: edition, pack: pages, importedPageNumber: 1), isNotNull);
  });
}

class _FailingCleanupDownloads extends QuranResumableDownloadService {
  _FailingCleanupDownloads(super.dio);
  @override
  Future<void> completeBrowser(MushafEdition edition, {bool discardPages = false}) async {
    if (!discardPages) throw StateError('Simulated IndexedDB cleanup failure');
    return super.completeBrowser(edition, discardPages: true);
  }
}

class _NoZipCatalog extends QuranAssetPackCatalogService {
  @override
  Future<List<QuranZipAssetPack>> fetchAvailablePacks({bool allowFallback = true}) async => [];
}

class _PackAdapter implements HttpClientAdapter {
  final pageRequests = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    if (options.uri.path.endsWith('.zip')) {
      final archive = Archive()..addFile(ArchiveFile('001.webp', 3, [1, 2, 3]));
      final bytes = ZipEncoder().encode(archive)!;
      return ResponseBody.fromBytes(bytes, 200, headers: {'etag': ['"test"']});
    }
    pageRequests.add(options.uri.path);
    return ResponseBody.fromBytes([1, 2, 3], 200);
  }

  @override
  void close({bool force = false}) {}
}
