import 'reader_admin_config.dart';
import 'reader_settings.dart';

enum QuranAssetPackDownloadStatus {
  notDownloaded,
  downloading,
  paused,
  ready,
  failed,
}

enum QuranPackDownloadStop { pause, cancel }

enum QuranPackTransferPhase { downloading, extracting, publishing }

class QuranPackTransferProgress {
  const QuranPackTransferProgress({
    required this.progress,
    required this.receivedBytes,
    this.totalBytes,
    this.phase = QuranPackTransferPhase.downloading,
  });

  final double progress;
  final int receivedBytes;
  final int? totalBytes;
  final QuranPackTransferPhase phase;
}

class QuranPartialAssetPack {
  const QuranPartialAssetPack({
    required this.edition,
    required this.sourceUrl,
    required this.version,
    required this.receivedBytes,
    required this.updatedAtIso,
    this.totalBytes,
    this.canResume = true,
  });

  final MushafEdition edition;
  final String sourceUrl;
  final String version;
  final int receivedBytes;
  final int? totalBytes;
  final String updatedAtIso;
  final bool canResume;
}

class QuranPackStorageInfo {
  const QuranPackStorageInfo({
    required this.installedBytes,
    required this.archiveBytes,
    required this.partialBytes,
    required this.editionBytes,
    this.browserUsageBytes,
    this.browserQuotaBytes,
  });

  final int installedBytes;
  final int archiveBytes;
  final int partialBytes;
  final Map<MushafEdition, int> editionBytes;
  final int? browserUsageBytes;
  final int? browserQuotaBytes;
  int get totalBytes => installedBytes + archiveBytes + partialBytes;
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
    this.cacheGeneration,
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
  final String? cacheGeneration;

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
