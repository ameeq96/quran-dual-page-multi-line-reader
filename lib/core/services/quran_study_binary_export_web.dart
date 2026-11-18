import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> exportQuranStudyBytes({required String fileName,
    required Uint8List bytes, required String mimeType}) async {
  if (!RegExp(r'^[A-Za-z0-9_-]+\.(png|pdf)$').hasMatch(fileName)) {
    throw const FormatException('Invalid study export filename.');
  }
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
  final anchor = html.AnchorElement(href: url)..download = fileName..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 30), () => html.Url.revokeObjectUrl(url));
}
