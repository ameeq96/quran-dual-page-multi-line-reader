import 'quran_page_line.dart';

enum QuranPageContentType {
  image,
  text,
  placeholder,
}

class QuranPage {
  const QuranPage({
    required this.number,
    required this.isLeftPage,
    required this.contentType,
    this.assetPath,
    this.lines = const <QuranPageLine>[],
  });

  final int number;
  final bool isLeftPage;
  final String? assetPath;
  final QuranPageContentType contentType;
  final List<QuranPageLine> lines;

  bool get usesImage => contentType == QuranPageContentType.image;
  bool get usesText => contentType == QuranPageContentType.text;
}
