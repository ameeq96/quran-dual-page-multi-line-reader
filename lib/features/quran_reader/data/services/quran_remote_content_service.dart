import 'dart:convert';

import 'package:http/http.dart' as http;

class QuranRemoteContentService {
  static const Duration _requestTimeout = Duration(seconds: 5);

  QuranRemoteContentService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<int, String> _chapterInfoCache = <int, String>{};
  final Map<int, String> _tafsirCache = <int, String>{};
  final Map<int, Future<String?>> _chapterInfoRequests =
      <int, Future<String?>>{};
  final Map<int, Future<String?>> _tafsirRequests = <int, Future<String?>>{};

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'my_flutter_app/1.0',
  };

  Future<String?> chapterInfo(int chapterId) async {
    final cached = _chapterInfoCache[chapterId];
    if (cached != null) {
      return cached;
    }
    final inFlight = _chapterInfoRequests[chapterId];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _loadChapterInfo(chapterId).whenComplete(() {
      _chapterInfoRequests.remove(chapterId);
    });
    _chapterInfoRequests[chapterId] = request;
    return request;
  }

  Future<String?> tafsirExcerptForPage(int standardPageNumber) async {
    final cached = _tafsirCache[standardPageNumber];
    if (cached != null) {
      return cached;
    }
    final inFlight = _tafsirRequests[standardPageNumber];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _loadTafsirExcerpt(standardPageNumber).whenComplete(() {
      _tafsirRequests.remove(standardPageNumber);
    });
    _tafsirRequests[standardPageNumber] = request;
    return request;
  }

  Future<String?> _loadChapterInfo(int chapterId) async {
    final uri = Uri.parse(
      'https://api.quran.com/api/v4/chapters/$chapterId/info',
    );
    final response =
        await _client.get(uri, headers: _headers).timeout(_requestTimeout);
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

  Future<String?> _loadTafsirExcerpt(int standardPageNumber) async {
    final uri = Uri.parse(
      'https://api.quran.com/api/v4/quran/tafsirs/169?page_number=$standardPageNumber',
    );
    final response =
        await _client.get(uri, headers: _headers).timeout(_requestTimeout);
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
