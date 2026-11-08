import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/quran_ai_models.dart';

class QuranAdminAiException implements Exception {
  const QuranAdminAiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class QuranAdminAiProxyService {
  QuranAdminAiProxyService({
    http.Client? client,
    Duration timeout = const Duration(seconds: 95),
  }) : _client = client ?? http.Client(), _timeout = timeout;

  final http.Client _client;
  final Duration _timeout;
  static const modelName = 'qwen3:0.6b';

  static bool supportsRemoteTool(QuranAiTool tool) {
    switch (tool) {
      case QuranAiTool.explainer:
      case QuranAiTool.tafsirAssistant:
      case QuranAiTool.studyNotes:
      case QuranAiTool.translationSimplifier:
      case QuranAiTool.askCurrentPage:
      case QuranAiTool.dailyLesson:
      case QuranAiTool.voiceQna:
      case QuranAiTool.smartSearch:
      case QuranAiTool.hifzCoach:
      case QuranAiTool.tajweedTutor:
      case QuranAiTool.bookmarkAssistant:
      case QuranAiTool.recitationFollow:
      case QuranAiTool.studyChat:
      case QuranAiTool.quranQuiz:
      case QuranAiTool.flashcards:
      case QuranAiTool.revisionPlan:
        return true;
    }
  }

  Future<QuranAiToolResult?> runTool({
    required String baseUrl,
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
    String groundingContext = '',
    bool searchPlanning = false,
  }) async {
    if (!supportsRemoteTool(tool) || baseUrl.trim().isEmpty) {
      throw const QuranAdminAiException('Ollama is not configured.');
    }

    final normalizedBase = _normalizeBaseUrl(baseUrl);
    final uri = Uri.tryParse('$normalizedBase/public/ai/run');
    if (uri == null || !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const QuranAdminAiException('The Ollama backend address is invalid.');
    }

    final planning = searchPlanning && tool == QuranAiTool.smartSearch;
    final promptContext = planning
        ? 'You translate a full-Quran search request into lookup parameters; '
            'you do not answer it. Convert semantic, Hindi, Roman Urdu, Urdu or Arabic '
            'input into up to 3 short English search queries. For a topical '
            'request, supply useful query keywords even without a named Surah. '
            'Examples of query translation: pani ki ahmiyat -> water; '
            'insaf -> justice; how the sky was created -> heavens, creation. '
            'Apply the actual user request, not the examples. '
            'Return only {"surahIds":[],"queries":[],"references":[],"collectionIds":[]}. '
            'Use up to 4 numeric Surah IDs from 1 to 114 only when the user '
            'names a Surah filter; a bare Surah request has empty queries. '
            'Use up to 4 valid Surah:Ayah candidate references and up to 4 '
            'collection IDs listed in the catalogue. Use empty arrays for '
            'uncertain references or filters. No answers, Quran quotations, '
            'personal notes, extra fields or markdown. Catalogue:\n\n'
            '${groundingContext.trim().isEmpty
                ? 'No Surah or collection catalogue was supplied.'
                : groundingContext.trim()}'
        : tool == QuranAiTool.smartSearch
        ? 'Rank the following verified Ayah search results for the query. '
            'Return only a JSON object with a matches array of supplied '
            'Ayah keys, best match first, up to 12 supplied keys. Select at least one key when '
            'results are supplied, or an empty array when none are supplied. '
            'Do not write explanations, new references or Quran quotations. '
            'The app displays the original translations.\n\n'
            '${groundingContext.trim().isEmpty
                ? 'No verified Ayah hits were supplied for this query.'
                : groundingContext.trim()}'
        : 'Rank the supplied verified Quran study references for this tool '
            'and question. Return only {"matches":["supplied Ayah key"]}. '
            'Use only supplied keys, without duplicates, and select at least '
            'one when candidates exist. Return an empty array for no '
            'candidates. The app builds lessons, quizzes, cards, plans and '
            'text comparisons from the original source data; do not invent '
            'facts, translations, pronunciation scores or scan positions.\n\n'
            '${groundingContext.trim().isEmpty
                ? 'No verified Ayah candidates were supplied.'
                : groundingContext.trim()}';
    if (promptContext.length > 8000) {
      throw const QuranAdminAiException(
          'The Quran context is too large. Try a shorter query or another page.');
    }
    final abort = Completer<void>();
    final deadline = Timer(_timeout, () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final request = http.AbortableRequest('POST', uri,
          abortTrigger: abort.future)
        ..headers.addAll(const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'quran_dual_page/1.0',
        })
        ..body = json.encode(
          <String, dynamic>{
            'tool': tool.name,
            'toolTitle': tool.title,
            'toolInstruction': _toolInstruction(tool, searchPlanning: planning),
            'userInput': userInput.trim(),
            'responseLanguage': settings.responseLanguage.storageValue,
            'responseDepth': settings.responseDepth.storageValue,
            'contextPromptBlock': promptContext,
          },
        );
      final response = await (() async {
        final stream = await _client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(_timeout);

      if (response.statusCode != 200) {
        throw const QuranAdminAiException(
            'Ollama is unavailable or busy. Try again shortly.');
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final configured = payload['configured'] == true;
      final output = (payload['output'] as String? ?? '').trim();
      if (!configured || output.isEmpty || payload['provider'] != 'ollama' ||
          payload['model'] != modelName || payload['usedOnlineModel'] != true) {
        throw const QuranAdminAiException(
            'A verified Ollama qwen3:0.6b response is unavailable.');
      }

      return QuranAiToolResult(
        tool: tool,
        output: output,
        sourceLabel: 'Ollama $modelName',
        usedOnlineModel: true,
        sourceNotes: payload['sourceNotes'] is List
            ? (payload['sourceNotes'] as List)
                .whereType<String>()
                .where((note) => note.length <= 1800)
                .take(4)
                .toList(growable: false)
            : const [],
      );
    } on QuranAdminAiException {
      rethrow;
    } on TimeoutException {
      if (!abort.isCompleted) abort.complete();
      throw const QuranAdminAiException('Ollama timed out. Please try again.');
    } on http.RequestAbortedException {
      throw const QuranAdminAiException('Ollama timed out. Please try again.');
    } catch (_) {
      throw const QuranAdminAiException(
          'Ollama could not be reached. Please try again.');
    } finally {
      deadline.cancel();
    }
  }

  String _toolInstruction(QuranAiTool tool, {bool searchPlanning = false}) {
    if (searchPlanning && tool == QuranAiTool.smartSearch) {
      return 'QURAN_QUERY_PLAN_V1\nTranslate the actual user search into lookup parameters, not an answer. Return only {"surahIds":[],"queries":[],"references":[],"collectionIds":[]}. Topical questions need up to 3 short English queries. Use at most 4 valid candidate references, 4 explicitly named Surah IDs and 4 exact catalogue collection IDs. A bare Surah request has empty queries. No markdown, quotations, personal notes or additional fields.';
    }
    if (tool == QuranAiTool.smartSearch) {
      return 'QURAN_STUDY_KEYS_V1\nRank up to 12 supplied Ayah results by relevance to the query. Return only {"matches":["supplied Ayah key"]}. Use only supplied keys, with no duplicates. Select at least one supplied key when results exist; otherwise return {"matches":[]}. Do not generate translations or explanations.';
    }
    return 'QURAN_STUDY_KEYS_V1\nRank the supplied verified Ayah references for ${tool.name}. Return only {"matches":["supplied Ayah key"]}. Use only supplied keys, with no duplicates. Select at least one supplied key when candidates exist, or an empty array for no candidates. Do not generate Quran text, translations, tafsir or audio assessments.';
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void dispose() {
    _client.close();
  }
}
