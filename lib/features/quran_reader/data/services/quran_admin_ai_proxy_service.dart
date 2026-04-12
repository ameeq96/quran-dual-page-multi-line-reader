import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/quran_ai_models.dart';

class QuranAdminAiProxyService {
  QuranAdminAiProxyService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  static bool supportsRemoteTool(QuranAiTool tool) {
    switch (tool) {
      case QuranAiTool.explainer:
      case QuranAiTool.tafsirAssistant:
      case QuranAiTool.studyNotes:
      case QuranAiTool.translationSimplifier:
      case QuranAiTool.askCurrentPage:
      case QuranAiTool.dailyLesson:
      case QuranAiTool.voiceQna:
        return true;
      case QuranAiTool.smartSearch:
      case QuranAiTool.hifzCoach:
      case QuranAiTool.tajweedTutor:
      case QuranAiTool.bookmarkAssistant:
      case QuranAiTool.recitationFollow:
        return false;
    }
  }

  Future<QuranAiToolResult?> runTool({
    required String baseUrl,
    required QuranAiTool tool,
    required ReaderAiSettings settings,
    required QuranAiPageContext context,
    required String userInput,
  }) async {
    if (!supportsRemoteTool(tool) || baseUrl.trim().isEmpty) {
      return null;
    }

    final normalizedBase = _normalizeBaseUrl(baseUrl);
    final uri = Uri.tryParse('$normalizedBase/public/ai/run');
    if (uri == null) {
      return null;
    }

    try {
      final response = await _client.post(
        uri,
        headers: const <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'quran_dual_page/1.0',
        },
        body: json.encode(
          <String, dynamic>{
            'tool': tool.name,
            'toolTitle': tool.title,
            'toolInstruction': _toolInstruction(tool),
            'userInput': userInput.trim(),
            'responseLanguage': settings.responseLanguage.storageValue,
            'responseDepth': settings.responseDepth.storageValue,
            'contextPromptBlock': context.toPromptBlock(),
          },
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final payload = json.decode(response.body) as Map<String, dynamic>;
      final configured = payload['configured'] as bool? ?? false;
      final output = (payload['output'] as String? ?? '').trim();
      if (!configured || output.isEmpty) {
        return null;
      }

      return QuranAiToolResult(
        tool: tool,
        output: output,
        sourceLabel: (payload['sourceLabel'] as String? ?? 'Admin AI').trim(),
        usedOnlineModel: payload['usedOnlineModel'] as bool? ?? true,
      );
    } catch (_) {
      return null;
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
      case QuranAiTool.hifzCoach:
      case QuranAiTool.tajweedTutor:
      case QuranAiTool.bookmarkAssistant:
      case QuranAiTool.recitationFollow:
        return 'Use the current page context to help the user.';
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
