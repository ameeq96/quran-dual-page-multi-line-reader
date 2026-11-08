import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';

class QuranZipExtractionService {
  const QuranZipExtractionService();

  Future<void> extractZip({
    required String zipPath,
    required String outputDirectoryPath,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.throwIfCancellationRequested();
    final messages = ReceivePort();
    final exits = ReceivePort();
    final result = Completer<void>();
    final subscription = messages.listen((message) {
      if (result.isCompleted) return;
      if (message == true) {
        result.complete();
      } else {
        result.completeError(StateError('Unable to extract Quran ZIP: $message'));
      }
    });
    Isolate? worker;
    try {
      worker = await Isolate.spawn(
        _extractZipWorker,
        <Object>[zipPath, outputDirectoryPath, messages.sendPort],
        onError: messages.sendPort,
        onExit: exits.sendPort,
      );
      cancelToken?.whenCancel.then((error) {
        if (!result.isCompleted) result.completeError(error);
      });
      await result.future;
      cancelToken?.throwIfCancellationRequested();
    } finally {
      worker?.kill(priority: Isolate.immediate);
      if (worker != null) {
        await exits.first.timeout(const Duration(seconds: 2), onTimeout: () => null);
      }
      await subscription.cancel();
      messages.close();
      exits.close();
    }
  }
}

void _extractZipWorker(List<Object> arguments) async {
  final port = arguments[2] as SendPort;
  try {
    await _extractZipOnWorker(zipPath: arguments[0] as String, outputDirectoryPath: arguments[1] as String);
    port.send(true);
  } catch (error) {
    port.send(error.toString());
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

  final input = InputFileStream(zipFile.path);
  try {
    final archive = ZipDecoder().decodeBuffer(input, verify: true);
    // Never materialize symlinks from a downloaded pack.
    final files = Archive();
    for (final file in archive.files) {
      if (!file.isSymbolicLink) files.addFile(file);
    }
    await extractArchiveToDisk(files, outputDirectory.path);
  } finally {
    await input.close();
  }
}

extension QuranCancelTokenCheck on CancelToken {
  void throwIfCancellationRequested() {
    if (isCancelled) throw cancelError!;
  }
}
