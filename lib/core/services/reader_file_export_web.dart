import 'dart:async';
import 'dart:html' as html;

Future<void> exportReaderFile({
  required String fileName,
  required String contents,
  required String mimeType,
  String? subject,
  String? text,
}) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([contents], mimeType));
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 30), () => html.Url.revokeObjectUrl(url));
}
