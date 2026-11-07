import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_offline_pack_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_asset_pack_catalog_service.dart';
import 'package:my_flutter_app/features/quran_reader/data/services/quran_resumable_download_service.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/quran_asset_pack_download.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_admin_config.dart';
import 'package:my_flutter_app/features/quran_reader/domain/models/reader_settings.dart';

void main() {
  late Directory root;
  late HttpServer server;
  late Dio dio;
  late QuranResumableDownloadService service;
  late QuranZipAssetPack pack;
  late File archive;
  late Uint8List payload;
  late Future<void> Function(HttpRequest) respond;
  final ranges = <String?>[];
  final validators = <String?>[];

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quran_download_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dio = Dio();
    service = QuranResumableDownloadService(dio);
    pack = QuranZipAssetPack(edition: MushafEdition.lines13, key: '13_line',
      url: 'http://127.0.0.1:${server.port}/13_line.zip');
    archive = File('${root.path}/13_line/13_line.zip');
    payload = Uint8List.fromList(List.generate(512 * 1024, (index) => index % 251));
    ranges.clear();
    validators.clear();
    respond = (request) => _send(request, payload);
    server.listen((request) async {
      ranges.add(request.headers.value('range'));
      validators.add(request.headers.value('if-range'));
      try { await respond(request); } catch (_) { /* Cancellation closes the socket. */ }
    });
  });

  tearDown(() async {
    dio.close(force: true);
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  Future<int> pause() async {
    final token = CancelToken();
    await expectLater(service.downloadNative(pack: pack, version: '13_line', archive: archive,
      cancelToken: token, onProgress: (progress) {
        if (progress.receivedBytes > 0) token.cancel(QuranPackDownloadStop.pause);
      }), throwsA(isA<DioException>()));
    final partial = File('${archive.path}.download');
    final bytes = await partial.length();
    expect(bytes, greaterThan(0));
    expect(bytes, lessThan(payload.length));
    return bytes;
  }

  test('pause persists partial bytes and resume sends Range with If-Range', () async {
    final saved = await pause();
    final partials = await service.loadPartials(root);
    expect(partials[pack.edition]?.receivedBytes, saved);
    expect(partials[pack.edition]?.canResume, isTrue);
    await service.downloadNative(pack: pack, version: '13_line', archive: archive);
    expect(ranges.last, 'bytes=$saved-');
    expect(validators.last, '"version-1"');
    expect(await archive.readAsBytes(), payload);
    expect(await File('${archive.path}.download').exists(), isFalse);
  });

  test('a server ignoring Range replaces the partial instead of appending', () async {
    await pause();
    respond = (request) => _send(request, payload, ignoreRange: true);
    await service.downloadNative(pack: pack, version: '13_line', archive: archive);
    expect(await archive.readAsBytes(), payload);
    expect(await archive.length(), payload.length);
  });

  test('mismatched Content-Range is rejected without touching installed pages', () async {
    await pause();
    final installed = File('${root.path}/installed/001.webp');
    await installed.parent.create();
    await installed.writeAsBytes([7, 8, 9]);
    respond = (request) => _send(request, payload, wrongRange: true);
    await expectLater(service.downloadNative(pack: pack, version: '13_line', archive: archive),
      throwsA(isA<StateError>()));
    expect(await File('${archive.path}.download').exists(), isFalse);
    expect(await installed.readAsBytes(), [7, 8, 9]);
  });

  test('explicit cancel removes partial bytes and metadata', () async {
    final saved = await pause();
    final token = CancelToken();
    await expectLater(service.downloadNative(pack: pack, version: '13_line', archive: archive,
      cancelToken: token, onProgress: (progress) {
        if (progress.receivedBytes > saved) token.cancel(QuranPackDownloadStop.cancel);
      }), throwsA(isA<DioException>()));
    expect(await File('${archive.path}.download').exists(), isFalse);
    expect(await File('${archive.path}.download.json').exists(), isFalse);
    expect(await service.loadPartials(root), isEmpty);
  });

  test('changed source URL discards previous source bytes', () async {
    await pause();
    final other = QuranZipAssetPack(edition: pack.edition, key: pack.key, url: '${pack.url}?revision=2');
    await service.downloadNative(pack: other, version: '13_line', archive: archive);
    expect(ranges.last, isNull);
    expect(await archive.readAsBytes(), payload);
  });

  test('network interruption retains a resumable partial', () async {
    final networkAdapter = dio.httpClientAdapter;
    dio.httpClientAdapter = _InterruptedAdapter(payload);
    await expectLater(service.downloadNative(pack: pack, version: '13_line', archive: archive), throwsA(anything));
    final partials = await service.loadPartials(root);
    expect(partials[pack.edition]?.receivedBytes, greaterThan(0));
    dio.httpClientAdapter = networkAdapter;
    await service.downloadNative(pack: pack, version: '13_line', archive: archive);
    expect(await archive.readAsBytes(), payload);
  });

  test('CRC failure never replaces an installed edition', () async {
    final zip = Archive()..addFile(ArchiveFile('001.webp', 4, [1, 2, 3, 4]));
    payload = Uint8List.fromList(ZipEncoder().encode(zip)!);
    payload[14] ^= 0xff;
    for (var index = 0; index < payload.length - 20; index++) {
      if (payload[index] == 0x50 && payload[index + 1] == 0x4b &&
          payload[index + 2] == 0x01 && payload[index + 3] == 0x02) {
        payload[index + 16] ^= 0xff;
        break;
      }
    }
    final installed = File('${root.path}/quran_offline_packs/${pack.edition.storageValue}/13_line/001.webp');
    await installed.parent.create(recursive: true);
    await installed.writeAsBytes([9, 9, 9]);
    final offline = QuranOfflinePackService(dio: dio, documentsDirectory: root, temporaryDirectory: root);
    await expectLater(offline.downloadEditionZipPack(zipPack: pack), throwsA(isA<StateError>()));
    expect(await installed.readAsBytes(), [9, 9, 9]);
    expect(await File('${installed.parent.path}/.manifest.json').exists(), isFalse);
    offline.dispose();
  });

  test('pause before extraction retains installed pages and resumes publication', () async {
    final zip = Archive()..addFile(ArchiveFile('001.webp', 4, [1, 2, 3, 4]));
    payload = Uint8List.fromList(ZipEncoder().encode(zip)!);
    final installed = File('${root.path}/quran_offline_packs/${pack.edition.storageValue}/13_line/001.webp');
    await installed.parent.create(recursive: true);
    await installed.writeAsBytes([9, 9, 9]);
    final offline = QuranOfflinePackService(dio: dio, documentsDirectory: root, temporaryDirectory: root);
    final token = CancelToken();
    await expectLater(offline.downloadEditionZipPack(zipPack: pack, cancelToken: token,
      onTransferProgress: (progress) {
        if (progress.phase == QuranPackTransferPhase.extracting) token.cancel(QuranPackDownloadStop.pause);
      }), throwsA(isA<DioException>()));
    expect(await installed.readAsBytes(), [9, 9, 9]);
    expect((await offline.loadPartialOfflinePacks())[pack.edition]?.receivedBytes, payload.length);
    final downloaded = await offline.downloadEditionZipPack(zipPack: pack);
    expect(downloaded.pageCount, 1);
    expect(await installed.readAsBytes(), [1, 2, 3, 4]);
    expect(await File('${installed.parent.path}/.manifest.json').exists(), isTrue);
    expect(await offline.loadPartialOfflinePacks(), isEmpty);
    offline.dispose();
  });

  test('Content-Range parser rejects invalid and unbounded ranges', () {
    expect(QuranDownloadRange.parse('bytes 3-9/10')?.start, 3);
    for (final value in ['bytes 0-10/10', 'bytes 4-3/10', 'bytes 0-9/*', 'bytes */10', null]) {
      expect(QuranDownloadRange.parse(value), isNull);
    }
  });

  test('native page checkpoint resumes completed pages and preserves installed pages', () async {
    final offline = QuranOfflinePackService(dio: dio, documentsDirectory: root, temporaryDirectory: root,
      catalogService: _NoZipCatalog());
    final remote = ReaderRemoteAssetPack(edition: pack.edition, folderName: 'pages', version: 'v1',
      pageCount: 2, fileExtension: 'webp', availableImportedPages: const [1, 2]);
    final installed = File('${root.path}/quran_offline_packs/${pack.edition.storageValue}/v1/001.webp');
    await installed.parent.create(recursive: true);
    await installed.writeAsBytes([9]);
    final token = CancelToken();
    await expectLater(offline.downloadEditionPack(edition: pack.edition, pack: remote,
      assetsBaseUrl: 'http://127.0.0.1:${server.port}', cancelToken: token,
      onTransferProgress: (progress) {
        if (progress.receivedBytes > 0) token.cancel(QuranPackDownloadStop.pause);
      }), throwsA(isA<DioException>()));
    expect(await installed.readAsBytes(), [9]);
    expect((await offline.loadPartialOfflinePacks())[pack.edition]?.canResume, isTrue);
    expect((await offline.offlinePackStorageInfo()).partialBytes, payload.length);
    expect(ranges, hasLength(1));
    await offline.downloadEditionPack(edition: pack.edition, pack: remote,
      assetsBaseUrl: 'http://127.0.0.1:${server.port}');
    expect(ranges, hasLength(2));
    expect(await installed.readAsBytes(), payload);
    expect(await offline.loadPartialOfflinePacks(), isEmpty);
    offline.dispose();
  });
}

class _NoZipCatalog extends QuranAssetPackCatalogService {
  @override
  Future<List<QuranZipAssetPack>> fetchAvailablePacks({bool allowFallback = true}) async => [];
}

class _InterruptedAdapter implements HttpClientAdapter {
  _InterruptedAdapter(this.bytes);
  final Uint8List bytes;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async => ResponseBody(_interrupted(), 200, headers: {
        'etag': ['"version-1"'], 'content-length': ['${bytes.length}'],
      });

  Stream<Uint8List> _interrupted() async* {
    yield bytes.sublist(0, 64 * 1024);
    throw const SocketException('Connection interrupted');
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _send(HttpRequest request, Uint8List bytes,
    {bool ignoreRange = false, bool wrongRange = false}) async {
  final range = request.headers.value('range');
  final start = !ignoreRange && range != null ? int.parse(range.substring(6).split('-').first) : 0;
  request.response.headers.set('etag', '"version-1"');
  if (!ignoreRange && range != null) {
    request.response.statusCode = 206;
    request.response.headers.set('content-range', 'bytes ${wrongRange ? start + 1 : start}-${bytes.length - 1}/${bytes.length}');
  }
  request.response.contentLength = bytes.length - start;
  for (var offset = start; offset < bytes.length; offset += 8192) {
    request.response.add(bytes.sublist(offset, (offset + 8192).clamp(0, bytes.length)));
    await request.response.flush();
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  await request.response.close();
}
