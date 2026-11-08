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

    final promptContext = 'The following context contains excerpts, '
        'which may describe the Surah rather than exact scanned-page '
        'Ayahs. Do not invent Quran text, references, page or line '
        'anchors, or claim acoustic assessment. State when the '
        'supplied context is insufficient.\n\n${context.toPromptBlock()}'
        '${groundingContext.trim().isEmpty ? '' : '\n\n${groundingContext.trim()}'}';
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
            'toolInstruction': _toolInstruction(tool),
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

  String _toolInstruction(QuranAiTool tool) {
    switch (tool) {
      case QuranAiTool.explainer:
        return 'Explain the current Quran page simply with key themes and practical understanding.';
      case QuranAiTool.tafsirAssistant:
        return 'Give short tafsir or context help using only the supplied page context.';
      case QuranAiTool.studyNotes:
        return 'Generate study notes, reflection points, and class-ready summary points.';
      case QuranAiTool.translationSimplifier:
        return 'Rewrite the translation in simpler student-friendly language while keeping meaning faithful.';
      case QuranAiTool.askCurrentPage:
        return 'Answer the user question about the current page in a concise and grounded way.';
      case QuranAiTool.dailyLesson:
        return 'Create a short daily lesson with one reflection and one action point.';
      case QuranAiTool.voiceQna:
        return 'Answer the transcript or typed question in a clear, conversational way.';
      case QuranAiTool.smartSearch:
        return 'Explain relevant Quran themes for the query using the supplied context. Do not invent verse references or page numbers; navigation uses verified Quran data separately.';
      case QuranAiTool.hifzCoach:
        return 'Coach the pasted memorization text using only supplied Arabic lines. State any missing context; do not claim to assess audio or invent missing Quran words.';
      case QuranAiTool.tajweedTutor:
        return 'Give text-based tajweed study guidance using only the supplied Quran context. Do not claim to assess recorded pronunciation or provide acoustic scores.';
      case QuranAiTool.bookmarkAssistant:
        return 'Explain a useful bookmark purpose for the current reading context. The actual bookmark action uses a separate deterministic label and folder.';
      case QuranAiTool.recitationFollow:
        return 'Discuss the pasted phrase against the supplied Arabic context only. Do not invent line numbers or claim live audio following; line actions use a separate text match.';
    }
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
