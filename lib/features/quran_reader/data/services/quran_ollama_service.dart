import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/models/quran_ai_models.dart';

class QuranOllamaService {
  QuranOllamaService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> complete({
    required ReaderAiSettings settings,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    if (!settings.canUseOllama) {
      throw StateError('Ollama is not enabled.');
    }

    final resolved = await _postWithFallback(
      settings: settings,
      path: '/api/generate',
      timeout: const Duration(seconds: 90),
      body: json.encode(
        <String, dynamic>{
          'model': settings.ollamaModel.trim(),
          'system': systemPrompt,
          'prompt': userPrompt,
          'stream': false,
          'keep_alive': '15m',
          'options': <String, dynamic>{
            'temperature': 0.1,
            'num_predict': 180,
            'num_ctx': 1536,
          },
        },
      ),
    );
    final response = resolved.response;

    final payload = json.decode(response.body) as Map<String, dynamic>;
    final output = (payload['response'] as String? ?? '').trim();
    if (output.isEmpty) {
      throw Exception('Ollama returned an empty response.');
    }
    return output;
  }

  Future<String> testConnection({
    required ReaderAiSettings settings,
  }) async {
    if (!settings.canUseOllama) {
      throw StateError('Ollama setup is incomplete.');
    }

    final resolved = await _getWithFallback(
      settings: settings,
      path: '/api/tags',
      timeout: const Duration(seconds: 15),
    );
    final response = resolved.response;

    final payload = json.decode(response.body) as Map<String, dynamic>;
    final models = (payload['models'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((entry) => (entry['name'] as String? ?? '').trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    if (models.isEmpty) {
      return 'Connected to Ollama, but no models are installed yet.';
    }

    final hasSelectedModel =
        models.any((name) => name == settings.ollamaModel.trim());
    final routeNote = resolved.baseUrl == settings.normalizedOllamaBaseUrl
        ? ''
        : ' via ${resolved.baseUrl}';
    return hasSelectedModel
        ? 'Ollama connected$routeNote. Model ${settings.ollamaModel.trim()} is available.'
        : 'Ollama connected$routeNote. Installed models: ${models.take(6).join(', ')}';
  }

  Future<_ResolvedResponse> _getWithFallback({
    required ReaderAiSettings settings,
    required String path,
    required Duration timeout,
  }) async {
    Object? lastError;
    for (final baseUrl in _candidateBaseUrls(settings)) {
      try {
        final response = await _client
            .get(Uri.parse('$baseUrl$path'))
            .timeout(timeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _ResolvedResponse(baseUrl: baseUrl, response: response);
        }
        lastError = Exception(_extractError(response));
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }
    }
    throw Exception(_friendlyConnectionError(settings, lastError));
  }

  Future<_ResolvedResponse> _postWithFallback({
    required ReaderAiSettings settings,
    required String path,
    required Duration timeout,
    required String body,
  }) async {
    Object? lastError;
    for (final baseUrl in _candidateBaseUrls(settings)) {
      try {
        final response = await _client
            .post(
              Uri.parse('$baseUrl$path'),
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: body,
            )
            .timeout(timeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _ResolvedResponse(baseUrl: baseUrl, response: response);
        }
        lastError = Exception(_extractError(response));
      } on TimeoutException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }
    }
    throw Exception(_friendlyConnectionError(settings, lastError));
  }

  List<String> _candidateBaseUrls(ReaderAiSettings settings) {
    final baseUrl = settings.normalizedOllamaBaseUrl;
    final candidates = <String>[baseUrl];
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) {
      return candidates;
    }

    final host = uri.host.toLowerCase();
    if (host == '127.0.0.1' || host == 'localhost') {
      final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
      final portSuffix = uri.hasPort ? ':${uri.port}' : '';
      candidates.add('$scheme://10.0.2.2$portSuffix');
      candidates.add('$scheme://10.0.3.2$portSuffix');
    }

    return candidates.toSet().toList(growable: false);
  }

  String _friendlyConnectionError(
    ReaderAiSettings settings,
    Object? lastError,
  ) {
    final baseUrl = settings.normalizedOllamaBaseUrl;
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase();
    const genericHelp =
        'Make sure `ollama serve` is running, the model is installed, and your device can reach this address.';

    if (lastError is TimeoutException) {
      if (host == '127.0.0.1' || host == 'localhost') {
        return 'Ollama timed out at $baseUrl. If the app is running on a physical phone, 127.0.0.1 will not reach your PC. Use your PC Wi-Fi IP instead, for example http://192.168.1.5:11434. On an emulator, use http://10.0.2.2:11434. With USB debugging, you can also use `adb reverse tcp:11434 tcp:11434` and keep localhost.';
      }
      return 'Ollama timed out at $baseUrl. $genericHelp';
    }

    if (lastError is SocketException || lastError is http.ClientException) {
      if (host == '127.0.0.1' || host == 'localhost') {
        return 'Could not reach Ollama at $baseUrl. On an Android emulator, use http://10.0.2.2:11434. On a physical phone, use your PC Wi-Fi IP such as http://192.168.1.5:11434. With USB debugging, you can also use `adb reverse tcp:11434 tcp:11434` and keep localhost.';
      }
      return 'Could not reach Ollama at $baseUrl. $genericHelp Also check your firewall and same-network access.';
    }

    return lastError?.toString() ??
        'Could not connect to Ollama at $baseUrl. $genericHelp';
  }

  String _extractError(http.Response response) {
    try {
      final payload = json.decode(response.body) as Map<String, dynamic>;
      final error = payload['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error.trim();
      }
    } catch (_) {}
    return 'Ollama request failed (${response.statusCode}).';
  }

  void dispose() {
    _client.close();
  }
}

class _ResolvedResponse {
  const _ResolvedResponse({
    required this.baseUrl,
    required this.response,
  });

  final String baseUrl;
  final http.Response response;
}
