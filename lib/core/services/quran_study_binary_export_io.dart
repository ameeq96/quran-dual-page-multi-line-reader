import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportQuranStudyBytes({required String fileName,
    required Uint8List bytes, required String mimeType}) async {
  if (!RegExp(r'^[A-Za-z0-9_-]+\.(png|pdf)$').hasMatch(fileName)) {
    throw const FormatException('Invalid study export filename.');
  }
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], subject: 'Quran study');
}
