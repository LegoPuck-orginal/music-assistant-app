import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service zur Kommunikation mit einem lokalen Ollama Sprachmodell-Server
/// inklusive intelligenter Host-Auflösung (iPhone -> LAN Server) und
/// Sprach-Bereinigung für natürliche Radio-Moderationen.
class OllamaService {
  static final OllamaService _instance = OllamaService._internal();
  factory OllamaService() => _instance;
  OllamaService._internal();

  String? _lastWorkingHost;
  final Map<String, DateTime> _failedHostsCooldown = {};
  static const Duration _cooldownDuration = Duration(seconds: 45);

  /// Bereinigt Songtitel von technischen Zusätzen wie "(Remastered 2023)", "[Explicit]",
  /// Track-Nummern ("216 - ...") oder "(feat. ...)", damit die Sprachausgabe
  /// wie ein echter Radiomoderator klingt.
  static String cleanTrackTitleForSpeech(String? rawTitle) {
    if (rawTitle == null || rawTitle.trim().isEmpty) return '';
    var t = rawTitle.trim();

    // Führende Episoden-/Tracknummern entfernen (z.B. "216 - " oder "01. ")
    t = t.replaceFirst(RegExp(r'^\d{1,4}\s*[-–.]\s*'), '');

    // Klammerzusätze mit technischen Metadaten entfernen
    t = t.replaceAll(
      RegExp(
        r'\s*[\(\[][^)\]]*(remaster|explicit|radio edit|single version|album version|official|video|audio|live|feat\.|ft\.|with |prod\.|mix|version|edit|bonus|deluxe|mono|stereo|19\d\d|20\d\d)[^)\]]*[\)\]]',
        caseSensitive: false,
      ),
      '',
    );

    // Bindestrich-Anhänge wie " - Remastered 2021" oder " - Titelsong" entfernen
    t = t.replaceAll(
      RegExp(
        r'\s+[-–]\s+(remaster.*|radio edit.*|single version.*|live.*|titelsong.*|original mix.*|explicit.*)$',
        caseSensitive: false,
      ),
      '',
    );

    // Schrägstriche im Titel natürlich auflösen
    t = t.replaceAll('/', ' ');
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return t.isEmpty ? rawTitle.trim() : t;
  }

  /// Bereinigt Künstlernamen wie "bac/Max Grimm/Ella Stern" zu "bac und Max Grimm",
  /// damit TTS niemals "Schrägstrich" vorliest oder 5 Produzenten aufzählt.
  static String cleanArtistForSpeech(String? rawArtist) {
    if (rawArtist == null || rawArtist.trim().isEmpty) return '';
    var a = rawArtist.trim();

    // Klammerzusätze entfernen
    a = a.replaceAll(RegExp(r'\s*[\(\[][^)\]]*[\)\]]'), '');

    // Bei "/" oder ";" oder "," oder "feat." aufteilen
    final parts = a
        .split(RegExp(r'\s*(?:\/|;|,|\bfeat\.?|\bft\.?)\s*', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) return rawArtist.trim();
    if (parts.length == 1) return parts.first;
    // Maximal die ersten zwei Hauptkünstler nennen für flüssigen Radio-Flow
    return '${parts[0]} und ${parts[1]}';
  }

  /// Bereinigt die Roh-Antwort eines LLMs (Llama 3.2, Qwen, Mistral etc.)
  /// von Markdown, Regieanweisungen, Anführungszeichen und Meta-Kommentaren.
  static String? sanitizeLlmSpeech(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.trim();

    // 1. <think>...</think> Blöcke entfernen
    s = s.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '').trim();

    // 2. Meta-Einleitungen des Sprachmodells abschneiden
    s = s.replaceFirst(
      RegExp(
        r'^(hier ist[^:]*:|deine moderation:|moderation:|dj x:|radiomoderator:|dj:|antwort:|natürlich[,!]?\s*)',
        caseSensitive: false,
      ),
      '',
    ).trim();

    // 3. Markdown-Fettdruck (**Text**) erhalten, aber Regieanweisungen entfernen
    s = s.replaceAll('**', '');
    s = s.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    s = s.replaceAll(
      RegExp(
        r'[\(\*][^\)\*]*(lacht|pause|musik|intro|outro|beat|leise|laut|lächelt|zwinkert)[^\)\*]*[\)\*]',
        caseSensitive: false,
      ),
      '',
    );

    // 4. Markdown-Zeichen und Emojis bereinigen
    s = s.replaceAll(RegExp(r'[*_#`~]'), '');
    s = s.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
        unicode: true,
      ),
      '',
    );

    // 5. Schrägstriche zwischen Wörtern durch " und " ersetzen
    s = s.replaceAll(RegExp(r'\s*\/\s*'), ' und ');

    // 6. Äußere Anführungszeichen entfernen
    s = s.replaceAll(RegExp(r'^["„“”«»\x27]+|["„“”«»\x27]+$'), '').trim();
    // Auch doppelte Anführungszeichen im Satz entfernen, damit TTS nicht stockt
    s = s.replaceAll(RegExp(r'["„“”«»]'), '');

    // 7. Zeilenumbrüche in Leerzeichen umwandeln
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 8. Qualitäts-Check: Zu kurz, zu lang oder englische KI-Floskeln verwerfen
    if (s.length < 12 || s.length > 280) return null;
    final lower = s.toLowerCase();
    if (lower.contains('as an ai') ||
        lower.contains('i cannot') ||
        lower.contains('here is a') ||
        lower.contains('ich kann als ki')) {
      return null;
    }

    return s;
  }

  /// Ermittelt mögliche Ollama-Hosts (inkl. automatischem Fallback von 127.0.0.1
  /// auf die IP des Music Assistant Servers im Heimnetzwerk).
  List<String> resolveCandidateHosts(String configuredHost, {String? fallbackServerUrl}) {
    final candidates = <String>[];

    String normalize(String h) {
      var trimmed = h.trim();
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        trimmed = 'http://$trimmed';
      }
      if (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      return trimmed;
    }

    if (_lastWorkingHost != null && _lastWorkingHost!.isNotEmpty) {
      candidates.add(_lastWorkingHost!);
    }

    final primary = normalize(configuredHost);
    if (!candidates.contains(primary)) {
      candidates.add(primary);
    }

    // Falls auf dem iPhone noch 127.0.0.1 oder localhost eingestellt ist,
    // automatisch die IP des Music Assistant Servers auf Port 11434 probieren!
    if (fallbackServerUrl != null && fallbackServerUrl.isNotEmpty) {
      try {
        final maUri = Uri.parse(fallbackServerUrl);
        if (maUri.host.isNotEmpty &&
            maUri.host != '127.0.0.1' &&
            maUri.host != 'localhost') {
          final lanOllama = 'http://${maUri.host}:11434';
          if (!candidates.contains(lanOllama)) {
            candidates.add(lanOllama);
          }
        }
      } catch (_) {}
    }

    return candidates;
  }

  bool _isHostInCooldown(String host) {
    final failedAt = _failedHostsCooldown[host];
    if (failedAt == null) return false;
    if (DateTime.now().difference(failedAt) < _cooldownDuration) {
      return true;
    }
    _failedHostsCooldown.remove(host);
    return false;
  }

  /// Ruft alle auf dem Ollama Server installierten Modelle ab
  Future<List<String>> fetchInstalledModels(
    String host, {
    String? fallbackServerUrl,
  }) async {
    final candidates = resolveCandidateHosts(host, fallbackServerUrl: fallbackServerUrl);
    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/tags');
        final res = await http.get(uri).timeout(const Duration(milliseconds: 2200));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final models = data['models'] as List<dynamic>?;
          if (models != null) {
            _lastWorkingHost = candidate;
            _failedHostsCooldown.remove(candidate);
            return models
                .map((m) => (m['name'] as String?) ?? '')
                .where((name) => name.isNotEmpty)
                .toList();
          }
        }
      } catch (e) {
        debugPrint('[OllamaService] Error fetching models from $candidate: $e');
      }
    }
    return [];
  }

  String _timeOfDayLabel() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'am Morgen';
    if (hour >= 11 && hour < 14) return 'am Mittag';
    if (hour >= 14 && hour < 18) return 'am Nachmittag';
    if (hour >= 18 && hour < 22) return 'am Abend';
    return 'in der späten Nacht';
  }

  /// Generiert eine dynamische, persönliche DJ-Moderation
  Future<String?> generateDjIntro({
    required String host,
    required String model,
    required String userName,
    required String vibeTitle,
    String? vibeSubtitle,
    String? trackTitle,
    String? artistName,
    String? previousTrackTitle,
    String? previousArtistName,
    String? customUserPrompt,
    String? fallbackServerUrl,
  }) async {
    final cleanTrack = cleanTrackTitleForSpeech(trackTitle);
    final cleanArtist = cleanArtistForSpeech(artistName);
    final cleanPrevTrack = cleanTrackTitleForSpeech(previousTrackTitle);
    final cleanPrevArtist = cleanArtistForSpeech(previousArtistName);
    final timeContext = _timeOfDayLabel();

    final StringBuffer contextBuf = StringBuffer();
    contextBuf.writeln('Tageszeit: $timeContext.');
    contextBuf.writeln('Aktueller Musik-Vibe: $vibeTitle (${vibeSubtitle ?? "Persönlicher Mix"}).');
    if (customUserPrompt != null && customUserPrompt.trim().isNotEmpty) {
      contextBuf.writeln('Musikwunsch des Hörers: "${customUserPrompt.trim()}".');
    }
    if (cleanPrevTrack.isNotEmpty && cleanPrevArtist.isNotEmpty) {
      contextBuf.writeln('Gerade lief: $cleanPrevTrack von $cleanPrevArtist.');
    }
    if (cleanTrack.isNotEmpty && cleanArtist.isNotEmpty) {
      contextBuf.writeln('Nächster Song: $cleanTrack von $cleanArtist.');
    }

    final prompt = '''
Du bist DJ X, der charismatische, warmherzige und moderne persönliche KI-Radiomoderator für $userName.
Deine Aufgabe: Sprich eine kurze, natürliche Überleitung auf Deutsch (1 bis maximal 2 kurze Sätze), die exakt zur Stimmung passt.

Kontext:
$contextBuf
Wichtige Regeln:
- Sprich $userName locker per "du" an.
- Nenne den nächsten Song ($cleanTrack) und Künstler ($cleanArtist) natürlich im Satzfluss.
- Passe deinen Tonfall an den Vibe an (bei Chill ruhig & entspannt, bei Rock/Party energiegeladen, bei Favoriten persönlich).
- Gib NUR den gesprochenen Moderationstext aus. Keine Anführungszeichen, keine Regieanweisungen, kein Markdown, keine Emojis.
''';

    final payload = jsonEncode({
      'model': model,
      'prompt': prompt,
      'stream': false,
      'options': {
        'temperature': 0.65,
        'top_p': 0.9,
        'repeat_penalty': 1.15,
        'num_predict': 65,
      },
    });

    final candidates = resolveCandidateHosts(host, fallbackServerUrl: fallbackServerUrl);

    for (final candidate in candidates) {
      if (_isHostInCooldown(candidate)) continue;
      try {
        final uri = Uri.parse('$candidate/api/generate');
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(milliseconds: 2600));

        if (res.statusCode == 200) {
          _lastWorkingHost = candidate;
          _failedHostsCooldown.remove(candidate);
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final rawResponse = data['response'] as String?;
          final sanitized = sanitizeLlmSpeech(rawResponse);
          if (sanitized != null && sanitized.isNotEmpty) {
            return sanitized;
          }
        } else {
          _failedHostsCooldown[candidate] = DateTime.now();
        }
      } catch (e) {
        _failedHostsCooldown[candidate] = DateTime.now();
        debugPrint('[OllamaService] Host $candidate unreachable: $e');
      }
    }
    return null;
  }
}
