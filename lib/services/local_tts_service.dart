import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service für lokale HTTP-basierte TTS-Dienste (Piper, Home Assistant, Kokoro, OpenAI-kompatibel)
class LocalTtsService {
  static final LocalTtsService _instance = LocalTtsService._internal();
  factory LocalTtsService() => _instance;

  AudioPlayer? _player;
  final StreamController<void> _finishedController = StreamController<void>.broadcast();
  Stream<void> get onSpeechFinished => _finishedController.stream;

  LocalTtsService._internal();

  AudioPlayer _ensurePlayer() {
    if (_player == null) {
      _player = AudioPlayer();
      _player!.onPlayerComplete.listen((_) {
        _finishedController.add(null);
      });
    }
    return _player!;
  }

  /// Spricht über einen lokalen OpenAI-kompatiblen Server (z.B. Kokoro TTS, LocalAI, Speaches)
  Future<bool> speakOpenAiCompatible({
    required String endpoint,
    required String text,
    required String voice,
    String? apiKey,
    double speed = 1.0,
  }) async {
    try {
      final uri = Uri.parse(endpoint);
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final body = jsonEncode({
        'model': 'tts-1',
        'input': text,
        'voice': voice,
        'speed': speed,
      });

      final res = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/dj_speech_temp.mp3');
        await file.writeAsBytes(res.bodyBytes);

        final player = _ensurePlayer();
        await player.stop();
        await player.play(DeviceFileSource(file.path));
        return true;
      }
    } catch (e) {
      debugPrint('[LocalTtsService] OpenAI-compatible TTS error: $e');
    }
    return false;
  }

  /// Spricht über Piper HTTP REST API oder Home Assistant
  Future<bool> speakPiperOrHomeAssistant({
    required String serverUrl,
    required String text,
    String? token,
  }) async {
    try {
      final sanitized = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;

      // 1. Prüfen auf Piper HTTP Endpoint
      final piperUri = Uri.parse('$sanitized/api/tts?text=${Uri.encodeComponent(text)}');
      try {
        final res = await http.get(piperUri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/dj_piper_temp.wav');
          await file.writeAsBytes(res.bodyBytes);

          final player = _ensurePlayer();
          await player.stop();
          await player.play(DeviceFileSource(file.path));
          return true;
        }
      } catch (_) {}

      // 2. Home Assistant TTS API
      if (token != null && token.isNotEmpty) {
        final haUri = Uri.parse('$sanitized/api/tts_get_url');
        final res = await http.post(
          haUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'message': text,
            'platform': 'piper',
          }),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final url = data['url'] as String?;
          if (url != null && url.isNotEmpty) {
            final player = _ensurePlayer();
            await player.stop();
            await player.play(UrlSource(url));
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalTtsService] Piper/HA error: $e');
    }
    return false;
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    try {
      _player?.dispose();
    } catch (_) {}
  }
}
