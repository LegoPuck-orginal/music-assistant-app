import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service zur Kommunikation mit einem lokalen Ollama Server
class OllamaService {
  static final OllamaService _instance = OllamaService._internal();
  factory OllamaService() => _instance;
  OllamaService._internal();

  /// Ruft alle auf dem Ollama Server installierten Modelle ab
  Future<List<String>> fetchInstalledModels(String host) async {
    try {
      final sanitizedHost = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
      final uri = Uri.parse('$sanitizedHost/api/tags');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final models = data['models'] as List<dynamic>?;
        if (models != null) {
          return models
              .map((m) => (m['name'] as String?) ?? '')
              .where((name) => name.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('[OllamaService] Error fetching models from $host: $e');
    }
    return [];
  }

  /// Generiert eine dynamische, persönliche DJ-Moderation
  Future<String?> generateDjIntro({
    required String host,
    required String model,
    required String userName,
    required String vibeTitle,
    String? trackTitle,
    String? artistName,
  }) async {
    try {
      final sanitizedHost = host.endsWith('/') ? host.substring(0, host.length - 1) : host;
      final uri = Uri.parse('$sanitizedHost/api/generate');

      final songContext = (trackTitle != null && artistName != null)
          ? 'Der nächste Song ist "$trackTitle" von "$artistName".'
          : 'Die Musikstimmung ist "$vibeTitle".';

      final prompt = '''
Du bist ein lässiger, hochprofessioneller Radio-DJ wie bei Spotify ("DJ X").
Formuliere genau EINEN knackigen, mitreißenden Satz auf Deutsch zur Moderation.
Sprich den Hörer "$userName" direkt und freundschaftlich an.
Kontext: $songContext
Regeln:
- Maximal 1 bis 2 kurze, flüssige Sätze.
- Keine Anführungszeichen, keine Emojis, keine Begrüßungsfloskeln wie "Guten Abend", nur echte Radio-Moderation.
- Sofort bereit zum Vorlesen.
''';

      final payload = jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': false,
        'options': {
          'temperature': 0.7,
          'num_predict': 60,
        },
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        String? response = data['response'] as String?;
        if (response != null && response.trim().isNotEmpty) {
          // Bereinigen von Anführungszeichen
          response = response.trim();
          if (response.startsWith('"') && response.endsWith('"')) {
            response = response.substring(1, response.length - 1).trim();
          }
          return response;
        }
      }
    } catch (e) {
      debugPrint('[OllamaService] LLM generation error: $e');
    }
    return null;
  }
}
