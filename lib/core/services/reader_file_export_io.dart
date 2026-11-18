import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportReaderFile({
  required String fileName,
  required String contents,
  required String mimeType,
  String? subject,
  String? text,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(contents, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], subject: subject, text: text);
}
