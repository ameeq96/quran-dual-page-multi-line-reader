import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

class QuranZipExtractionService {
  const QuranZipExtractionService();

  Future<void> extractZip({
    required String zipPath,
    required String outputDirectoryPath,
  }) {
    return Isolate.run(
      () => _extractZipOnWorker(
        zipPath: zipPath,
        outputDirectoryPath: outputDirectoryPath,
      ),
    );
  }
}

Future<void> _extractZipOnWorker({
  required String zipPath,
  required String outputDirectoryPath,
}) async {
  final zipFile = File(zipPath);
  if (!zipFile.existsSync() || zipFile.lengthSync() == 0) {
    throw StateError('Downloaded ZIP is missing or empty.');
  }

  final outputDirectory = Directory(outputDirectoryPath);
  if (outputDirectory.existsSync()) {
    outputDirectory.deleteSync(recursive: true);
  }
  outputDirectory.createSync(recursive: true);

  await extractFileToDisk(
    zipFile.path,
    outputDirectory.path,
    asyncWrite: false,
    bufferSize: 64 * 1024,
  );
}
