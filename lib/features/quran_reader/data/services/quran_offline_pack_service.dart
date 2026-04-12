import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/reader_admin_config.dart';
import '../../domain/models/reader_settings.dart';

class QuranOfflinePackService {
  QuranOfflinePackService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  Directory? _offlineRoot;

  Future<void> initialize() async {
    _offlineRoot ??= Directory(
      '${(await getApplicationDocumentsDirectory()).path}'
      '${Platform.pathSeparator}quran_offline_packs',
    );
    await _offlineRoot!.create(recursive: true);
  }

  Future<bool> hasEditionPack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
  }) async {
    await initialize();
    return File(_manifestPath(edition, pack)).existsSync();
  }

  String? localFilePathForPage({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required int importedPageNumber,
  }) {
    if (_offlineRoot == null) {
      return null;
    }
    final file = File(_pagePath(edition, pack, importedPageNumber));
    if (!file.existsSync()) {
      return null;
    }
    return file.path;
  }

  Future<void> downloadEditionPack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
    required String assetsBaseUrl,
    void Function(double progress)? onProgress,
  }) async {
    await initialize();
    final packDirectory = Directory(_packDirectoryPath(edition, pack));
    await packDirectory.create(recursive: true);

    final importedPages = _importedPagesForPack(pack);
    if (importedPages.isEmpty) {
      throw StateError('No page files are available for this edition pack.');
    }

    var completed = 0;
    for (final importedPageNumber in importedPages) {
      final destinationFile = File(
        _pagePath(edition, pack, importedPageNumber),
      );
      if (destinationFile.existsSync()) {
        completed += 1;
        onProgress?.call(completed / importedPages.length);
        continue;
      }

      final pageUrl = pack.buildPageUrl(
        assetsBaseUrl,
        importedPageNumber: importedPageNumber,
      );
      final response = await _client.get(
        Uri.parse(pageUrl),
        headers: const <String, String>{'Accept': '*/*'},
      );
      if (response.statusCode != 200) {
        throw StateError(
          'Failed to download page $importedPageNumber for ${edition.label}.',
        );
      }
      await destinationFile.writeAsBytes(response.bodyBytes, flush: true);
      completed += 1;
      onProgress?.call(completed / importedPages.length);
    }

    final manifestFile = File(_manifestPath(edition, pack));
    await manifestFile.writeAsString(
      json.encode(<String, dynamic>{
        'edition': edition.storageValue,
        'folderName': pack.folderName,
        'version': pack.version,
        'pageCount': importedPages.length,
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }

  Future<void> removeEditionPack({
    required MushafEdition edition,
    required ReaderRemoteAssetPack pack,
  }) async {
    await initialize();
    final directory = Directory(_packDirectoryPath(edition, pack));
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  String _packDirectoryPath(
    MushafEdition edition,
    ReaderRemoteAssetPack pack,
  ) {
    return '${_offlineRoot!.path}${Platform.pathSeparator}'
        '${edition.storageValue}${Platform.pathSeparator}${pack.version}';
  }

  String _manifestPath(
    MushafEdition edition,
    ReaderRemoteAssetPack pack,
  ) {
    return '${_packDirectoryPath(edition, pack)}'
        '${Platform.pathSeparator}.manifest.json';
  }

  String _pagePath(
    MushafEdition edition,
    ReaderRemoteAssetPack pack,
    int importedPageNumber,
  ) {
    final filename = importedPageNumber.toString().padLeft(3, '0');
    return '${_packDirectoryPath(edition, pack)}'
        '${Platform.pathSeparator}$filename.${pack.fileExtension}';
  }

  List<int> _importedPagesForPack(ReaderRemoteAssetPack pack) {
    if (pack.availableImportedPages.isNotEmpty) {
      final pages = List<int>.from(pack.availableImportedPages)
        ..sort((left, right) => left.compareTo(right));
      return pages;
    }

    final start = pack.contiguousImportedPageStart ?? 1;
    final end = pack.contiguousImportedPageEnd ?? pack.pageCount;
    if (end < start) {
      return const <int>[];
    }
    return List<int>.generate(
      end - start + 1,
      (index) => start + index,
      growable: false,
    );
  }

  void dispose() {
    _client.close();
  }
}
