import '../../domain/models/quran_page_line.dart';

class QuranTextPageData {
  const QuranTextPageData({
    required this.pageNumber,
    required this.lines,
  });

  factory QuranTextPageData.fromJson(Map<String, dynamic> json) {
    final linesJson = json['lines'] as List<dynamic>? ?? const <dynamic>[];
    return QuranTextPageData(
      pageNumber: json['pageNumber'] as int,
      lines: linesJson
          .map(
            (line) => QuranPageLine(
              lineNumber: (line as Map<String, dynamic>)['lineNumber'] as int,
              text: line['text'] as String,
            ),
          )
          .toList(growable: false),
    );
  }

  final int pageNumber;
  final List<QuranPageLine> lines;
}
