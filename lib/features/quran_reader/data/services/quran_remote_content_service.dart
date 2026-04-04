import 'dart:convert';

import 'package:http/http.dart' as http;

class QuranRemoteContentService {
  QuranRemoteContentService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<int, String> _chapterInfoCache = <int, String>{};
  final Map<int, String> _tafsirCache = <int, String>{};

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'my_flutter_app/1.0',
  };

  Future<String?> chapterInfo(int chapterId) async {
    if (_chapterInfoCache.containsKey(chapterId)) {
      return _chapterInfoCache[chapterId];
    }

    final uri = Uri.parse(
      'https://api.quran.com/api/v4/chapters/$chapterId/info',
    );
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      return null;
    }

    final payload = json.decode(response.body) as Map<String, dynamic>;
    final info = payload['chapter_info'] as Map<String, dynamic>?;
    if (info == null) {
      return null;
    }

    final shortText = _cleanHtml(info['short_text'] as String? ?? '');
    final longText = _cleanHtml(info['text'] as String? ?? '');
    final combined = [shortText, longText]
        .where((value) => value.trim().isNotEmpty)
        .join('\n\n')
        .trim();
    if (combined.isEmpty) {
      return null;
    }

    _chapterInfoCache[chapterId] = combined;
    return combined;
  }

  Future<String?> tafsirExcerptForPage(int standardPageNumber) async {
    if (_tafsirCache.containsKey(standardPageNumber)) {
      return _tafsirCache[standardPageNumber];
    }

    final uri = Uri.parse(
      'https://api.quran.com/api/v4/quran/tafsirs/169?page_number=$standardPageNumber',
    );
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      return null;
    }

    final payload = json.decode(response.body) as Map<String, dynamic>;
    final tafsirs = payload['tafsirs'] as List<dynamic>? ?? const [];
    if (tafsirs.isEmpty) {
      return null;
    }

    final raw =
        (tafsirs.first as Map<String, dynamic>)['text'] as String? ?? '';
    final cleaned = _cleanHtml(raw);
    if (cleaned.isEmpty) {
      return null;
    }
    final excerpt = cleaned.length > 1200
        ? '${cleaned.substring(0, 1197).trim()}...'
        : cleaned;
    _tafsirCache[standardPageNumber] = excerpt;
    return excerpt;
  }

  String _cleanHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\[[^\]]+\]'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void dispose() {
    _client.close();
  }
}
