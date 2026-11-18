import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/services/browser_file_store.dart';
import '../../domain/models/quran_asset_pack_download.dart';
import '../../domain/models/reader_settings.dart';
import 'quran_zip_extraction_service.dart';

class QuranResumableDownloadService {
  QuranResumableDownloadService(this._dio);

  final Dio _dio;
  static const _chunkSize = 4 * 1024 * 1024;

  static bool isPaused(CancelToken? token) =>
      token?.cancelError?.error == QuranPackDownloadStop.pause;

  String _browserPrefix(MushafEdition edition) =>
      'partial:${edition.storageValue}:';

  String? _validator(Map<String, dynamic>? metadata) {
    final etag = metadata?['etag'] as String?;
    if (etag != null && etag.isNotEmpty && !etag.startsWith('W/')) return etag;
    final modified = metadata?['lastModified'] as String?;
    return modified == null || modified.isEmpty ? null : modified;
  }

  Map<String, dynamic> _metadata(QuranZipAssetPack pack, String version,
      Headers headers, int received, int? total, {int chunks = 0}) => {
        'edition': pack.edition.storageValue,
        'sourceUrl': pack.url,
        'version': version,
        'etag': headers.value('etag'),
        'lastModified': headers.value('last-modified'),
        'receivedBytes': received,
        'totalBytes': total,
        'chunks': chunks,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

  bool _matches(Map<String, dynamic>? value, QuranZipAssetPack pack,
          String version) =>
      value?['sourceUrl'] == pack.url && value?['version'] == version &&
      value?['edition'] == pack.edition.storageValue;

  Future<Map<String, dynamic>?> _readMetadata(File file) async {
    for (final candidate in [file, File('${file.path}.tmp')]) {
      try {
        return Map<String, dynamic>.from(json.decode(await candidate.readAsString()) as Map);
      } catch (_) {
        // A process interruption can leave the flushed checkpoint awaiting rename.
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> readCheckpoint(File file) => _readMetadata(file);

  Future<void> writeCheckpoint(File file, Map<String, dynamic> value) => _writeMetadata(file, value);

  Future<void> _writeMetadata(File file, Map<String, dynamic> value) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(json.encode(value), flush: true);
    // Windows cannot rename over an existing file.
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  void _report(int received, int? total,
      void Function(QuranPackTransferProgress)? callback) {
    callback?.call(QuranPackTransferProgress(
      progress: total != null && total > 0 ? (received / total).clamp(0, 1) : 0,
      receivedBytes: received,
      totalBytes: total,
    ));
  }

  Future<void> downloadNative({
    required QuranZipAssetPack pack,
    required String version,
    required File archive,
    CancelToken? cancelToken,
    void Function(QuranPackTransferProgress)? onProgress,
  }) async {
    await archive.parent.create(recursive: true);
    final partial = File('${archive.path}.download');
    final metadataFile = File('${partial.path}.json');
    var metadata = await _readMetadata(metadataFile);
    var offset = await partial.exists() ? await partial.length() : 0;
    if (!_matches(metadata, pack, version) || (_validator(metadata) == null &&
        (offset == 0 || metadata?['totalBytes'] != offset)) ||
        (metadata?['totalBytes'] is num && offset > (metadata!['totalBytes'] as num))) {
      if (await partial.exists()) await partial.delete();
      offset = 0;
      metadata = null;
    }
    RandomAccessFile? output;
    try {
      cancelToken?.throwIfCancellationRequested();
      if (offset > 0 && metadata?['totalBytes'] == offset) {
        if (await archive.exists()) await archive.delete();
        await partial.rename(archive.path);
        _report(offset, offset, onProgress);
        return;
      }
      final response = await _dio.get<ResponseBody>(pack.url,
        options: Options(responseType: ResponseType.stream,
          headers: {'Accept-Encoding': 'identity', if (offset > 0) ...{
            'Range': 'bytes=$offset-', 'If-Range': _validator(metadata),
          }},
          validateStatus: (status) => status == 200 || status == 206 || status == 416),
        cancelToken: cancelToken,
      );
      final body = response.data!;
      if (response.statusCode == 416) {
        await body.stream.drain<void>();
        final total = int.tryParse((response.headers.value('content-range') ?? '').split('/').last);
        if (offset > 0 && total == offset && metadata?['totalBytes'] == total) {
          if (await archive.exists()) await archive.delete();
          await partial.rename(archive.path);
          _report(offset, total, onProgress);
          return;
        }
        throw StateError('Server rejected the saved download range.');
      }
      int? total;
      int? expectedEnd;
      if (response.statusCode == 206) {
        final range = QuranDownloadRange.parse(response.headers.value('content-range'));
        if (range == null || range.start != offset ||
            (metadata?['totalBytes'] != null && metadata!['totalBytes'] != range.total) ||
            (offset > 0 && _responseValidatorChanged(metadata!, response.headers))) {
          await body.stream.drain<void>();
          await discardNativeArchive(archive);
          throw StateError('Server returned a mismatched download range.');
        }
        total = range.total;
        expectedEnd = range.end;
      } else {
        // A server may ignore Range or If-Range when the resource changed.
        offset = 0;
        total = int.tryParse(response.headers.value('content-length') ?? '');
      }
      metadata = _metadata(pack, version, response.headers, offset, total);
      await _writeMetadata(metadataFile, metadata);
      output = await partial.open(mode: offset > 0 ? FileMode.append : FileMode.write);
      var received = offset;
      _report(received, total, onProgress);
      await for (final bytes in body.stream) {
        cancelToken?.throwIfCancellationRequested();
        await output.writeFrom(bytes);
        received += bytes.length;
        if (expectedEnd != null && received > expectedEnd + 1) {
          throw StateError('Downloaded ZIP does not match its declared range.');
        }
        if (total != null && received > total) throw StateError('Downloaded ZIP exceeds its declared size.');
        _report(received, total, onProgress);
      }
      await output.close();
      output = null;
      cancelToken?.throwIfCancellationRequested();
      if (received == 0 || (expectedEnd != null && received != expectedEnd + 1) ||
          (total != null && received != total)) {
        throw StateError('Downloaded ZIP is incomplete.');
      }
      metadata['receivedBytes'] = received;
      metadata['totalBytes'] = received;
      await _writeMetadata(metadataFile, metadata);
      if (await archive.exists()) await archive.delete();
      await partial.rename(archive.path);
      _report(received, received, onProgress);
    } catch (_) {
      await output?.close();
      if (cancelToken?.isCancelled == true && !isPaused(cancelToken)) {
        await discardNativeArchive(archive);
      }
      rethrow;
    }
  }

  bool _responseValidatorChanged(Map<String, dynamic> metadata, Headers headers) {
    final old = _validator(metadata);
    final current = _validator({'etag': headers.value('etag'),
      'lastModified': headers.value('last-modified')});
    return old != current;
  }

  Future<Uint8List> downloadBrowser({
    required QuranZipAssetPack pack,
    required String version,
    CancelToken? cancelToken,
    void Function(QuranPackTransferProgress)? onProgress,
  }) async {
    final store = BrowserFileStore.instance;
    final prefix = _browserPrefix(pack.edition);
    var metadata = store.manifests['${prefix}manifest'];
    if (!_matches(metadata, pack, version) || (_validator(metadata) == null &&
        metadata?['receivedBytes'] != metadata?['totalBytes'])) {
      await completeBrowser(pack.edition, discardPages: true);
      metadata = null;
    }
    var received = (metadata?['receivedBytes'] as num?)?.toInt() ?? 0;
    var total = (metadata?['totalBytes'] as num?)?.toInt();
    var chunks = (metadata?['chunks'] as num?)?.toInt() ?? 0;
    if (store.bytesForPrefix('${prefix}chunk:') != received) {
      await store.removePrefix(prefix);
      metadata = null;
      received = chunks = 0;
      total = null;
    }
    try {
      _report(received, total, onProgress);
      while (total == null || received < total) {
        cancelToken?.throwIfCancellationRequested();
        var response = await _dio.get<List<int>>(pack.url,
          options: Options(responseType: ResponseType.bytes,
            headers: {'Range': 'bytes=$received-${received + _chunkSize - 1}',
              if (received > 0) 'If-Range': _validator(metadata)},
            validateStatus: (status) => status == 200 || status == 206),
          cancelToken: cancelToken);
        cancelToken?.throwIfCancellationRequested();
        var range = QuranDownloadRange.parse(response.headers.value('content-range'));
        if (response.statusCode == 206 && (range == null ||
            (received == 0 && _validator(_metadata(pack, version, response.headers, 0, null)) == null))) {
          // Range headers/validators may be hidden by CORS. Restart safely using
          // the original full-response download instead of combining identities.
          response = await _dio.get<List<int>>(pack.url,
            options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken);
          range = null;
        }
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) throw StateError('Downloaded ZIP is empty.');
        if (response.statusCode == 206) {
          if (range == null || range.start != received || range.end - range.start + 1 != bytes.length ||
              (total != null && total != range.total) ||
              (received > 0 && _responseValidatorChanged(metadata!, response.headers))) {
            await store.removePrefix(prefix);
            throw StateError('Server returned a mismatched download range.');
          }
          total = range.total;
        } else if (response.statusCode == 200) {
          await store.removePrefix(prefix);
          received = chunks = 0;
          total = bytes.length;
        } else {
          throw StateError('Unexpected ZIP download response.');
        }
        final estimate = await store.storageEstimate();
        if (estimate['quota'] != null && estimate['usage'] != null &&
            bytes.length > estimate['quota']! - estimate['usage']!) {
          throw StateError('Browser storage is full. Free some space and resume the download.');
        }
        await store.putBytes('${prefix}chunk:$chunks', Uint8List.fromList(bytes), 'application/zip');
        received += bytes.length;
        chunks++;
        metadata = _metadata(pack, version, response.headers, received, total, chunks: chunks);
        await store.putManifest('${prefix}manifest', metadata);
        _report(received, total, onProgress);
      }
      cancelToken?.throwIfCancellationRequested();
      return store.readBytes(List.generate(chunks, (index) => '${prefix}chunk:$index'));
    } catch (_) {
      if (cancelToken?.isCancelled == true && !isPaused(cancelToken)) {
        await store.removePrefix(prefix);
      }
      rethrow;
    }
  }

  Future<void> discardNativeArchive(File archive, {bool removeArchive = true}) async {
    for (final path in ['${archive.path}.download', '${archive.path}.download.json',
      '${archive.path}.download.json.tmp', if (removeArchive) archive.path]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<bool> matchesNativeArchive(File archive, QuranZipAssetPack pack, String version) async =>
      _matches(await _readMetadata(File('${archive.path}.download.json')), pack, version);

  Future<void> completeBrowser(MushafEdition edition, {bool discardPages = false}) async {
    final store = BrowserFileStore.instance;
    final prefix = _browserPrefix(edition);
    final metadata = store.manifests['${prefix}manifest'];
    if (discardPages && metadata?['kind'] == 'pages' && metadata?['pageNamespace'] is String) {
      await store.removePrefix('edition:${edition.storageValue}:page:${metadata!['pageNamespace']}:');
    }
    await store.removePrefix(prefix);
  }

  Future<Map<MushafEdition, QuranPartialAssetPack>> loadPartials(Directory? root) async {
    final result = <MushafEdition, QuranPartialAssetPack>{};
    final values = <Map<String, dynamic>>[];
    if (root == null) {
      values.addAll(BrowserFileStore.instance.manifests.entries
          .where((entry) => entry.key.startsWith('partial:') && entry.key.endsWith(':manifest'))
          .map((entry) => entry.value));
    } else {
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.download.json')) continue;
        final value = await _readMetadata(entity);
        if (value == null) continue;
        if (value['kind'] == 'pages') {
          values.add(value);
          continue;
        }
        final archive = File(entity.path.substring(0, entity.path.length - '.download.json'.length));
        final partial = File('${archive.path}.download');
        final file = await partial.exists() ? partial : archive;
        if (!await file.exists()) continue;
        value['receivedBytes'] = await file.length();
        values.add(value);
      }
    }
    for (final value in values) {
      final key = value['edition'] as String?;
      final edition = key == null ? null : MushafEdition.register(key);
      if (edition == null || value['sourceUrl'] is! String || value['version'] is! String) continue;
      final received = (value['receivedBytes'] as num?)?.toInt() ?? 0;
      if (received <= 0) continue;
      result[edition] = QuranPartialAssetPack(edition: edition,
        sourceUrl: value['sourceUrl'] as String, version: value['version'] as String,
        receivedBytes: received, totalBytes: (value['totalBytes'] as num?)?.toInt(),
        updatedAtIso: value['updatedAt'] as String? ?? '',
        canResume: value['kind'] == 'pages' || received == value['totalBytes'] || _validator(value) != null);
    }
    return result;
  }

  Future<void> discardEdition(MushafEdition edition, Directory? root, {Directory? pageRoot}) async {
    if (root == null) return completeBrowser(edition, discardPages: true);
    final directory = Directory('${root.path}${Platform.pathSeparator}${edition.storageValue}');
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.download.json')) {
        final metadata = await _readMetadata(entity);
        if (metadata?['kind'] == 'pages') {
          final name = metadata?['stagingDirectoryName'] as String?;
          if (pageRoot != null && name != null && RegExp(r'^\.incoming_[a-zA-Z0-9_-]+$').hasMatch(name)) {
            final staging = Directory('${pageRoot.path}${Platform.pathSeparator}$name');
            if (await staging.exists()) await staging.delete(recursive: true);
          }
        }
        await discardNativeArchive(File(entity.path.substring(0, entity.path.length - '.download.json'.length)));
      }
    }
  }
}

class QuranDownloadRange {
  const QuranDownloadRange(this.start, this.end, this.total);
  final int start;
  final int end;
  final int total;

  static QuranDownloadRange? parse(String? value) {
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(value ?? '');
    if (match == null) return null;
    final start = int.tryParse(match[1]!);
    final end = int.tryParse(match[2]!);
    final total = int.tryParse(match[3]!);
    if (start == null || end == null || total == null || start < 0 || end < start || end >= total) return null;
    return QuranDownloadRange(start, end, total);
  }
}
