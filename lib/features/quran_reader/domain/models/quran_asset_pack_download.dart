import 'reader_admin_config.dart';
import 'reader_settings.dart';

enum QuranAssetPackDownloadStatus {
  notDownloaded,
  downloading,
  ready,
  failed,
}

class QuranZipAssetPack {
  const QuranZipAssetPack({
    required this.edition,
    required this.key,
    required this.url,
  });

  final MushafEdition edition;
  final String key;
  final String url;

  String get title => edition.label;
}

class QuranDownloadedAssetPack {
  const QuranDownloadedAssetPack({
    required this.edition,
    required this.folderName,
    required this.version,
    required this.sourceUrl,
    required this.directoryPath,
    required this.archivePath,
    required this.pageCount,
    required this.fileExtension,
    required this.availableImportedPages,
    required this.completedAtIso,
  });

  final MushafEdition edition;
  final String folderName;
  final String version;
  final String sourceUrl;
  final String directoryPath;
  final String archivePath;
  final int pageCount;
  final String fileExtension;
  final List<int> availableImportedPages;
  final String completedAtIso;

  ReaderRemoteAssetPack toRemoteAssetPack() {
    final sortedPages = List<int>.from(availableImportedPages)..sort();
    return ReaderRemoteAssetPack(
      edition: edition,
      folderName: folderName,
      version: version,
      pageCount: pageCount,
      fileExtension: fileExtension,
      availableImportedPages: List<int>.unmodifiable(sortedPages),
      contiguousImportedPageStart:
          sortedPages.isEmpty ? null : sortedPages.first,
      contiguousImportedPageEnd: sortedPages.isEmpty ? null : sortedPages.last,
    );
  }
}

class QuranAssetPackDownloadState {
  const QuranAssetPackDownloadState({
    required this.pack,
    required this.status,
    this.progress = 0,
    this.errorMessage,
    this.downloadedPack,
  });

  final QuranZipAssetPack pack;
  final QuranAssetPackDownloadStatus status;
  final double progress;
  final String? errorMessage;
  final QuranDownloadedAssetPack? downloadedPack;

  bool get isDownloading => status == QuranAssetPackDownloadStatus.downloading;
  bool get isReady => status == QuranAssetPackDownloadStatus.ready;

  QuranAssetPackDownloadState copyWith({
    QuranAssetPackDownloadStatus? status,
    double? progress,
    String? errorMessage,
    QuranDownloadedAssetPack? downloadedPack,
    bool clearError = false,
  }) {
    return QuranAssetPackDownloadState(
      pack: pack,
      status: status ?? this.status,
      progress: (progress ?? this.progress).clamp(0, 1),
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      downloadedPack: downloadedPack ?? this.downloadedPack,
    );
  }
}
