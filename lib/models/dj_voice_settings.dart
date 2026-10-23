import 'dart:convert';

/// Verfügbare Audio-/Stimmen-Engines für den DJ
enum DjVoiceEngine {
  /// Apple Neural iOS Siri / System-Stimmen (direkt auf iPhone, lokal, studio-klar)
  appleSiri,

  /// Lokaler Piper / Wyoming / Home Assistant Server
  localServer,

  /// Lokaler OpenAI-kompatibler Server (Kokoro TTS, LocalAI, Speaches) oder OpenAI API
  openAiCompatible,

  /// Music Assistant Server (spielt Sprachansage über den gewählten Raumlautsprecher)
  musicAssistant,
}

/// Wohin der DJ sprechen soll
enum DjAudioOutput {
  /// Über das iPhone / verbundene AirPods / Bluetooth / CarPlay
  device,

  /// Über den aktiven Music Assistant Raum-Lautsprecher (z.B. Sonos, AirPlay)
  activeSpeaker,
}

/// Detaillierte Einstellungen für die Stimme und KI-Moderation des DJs
class DjVoiceSettings {
  final DjVoiceEngine engine;
  final String voiceId;
  final String voiceName;
  final double speechRate; // 0.8 bis 1.4 (Standard 1.05 für flüssigen Radio-Flow)
  final double pitch; // 0.8 bis 1.2 (Standard 0.95 für tiefere, sonorigere Stimme)
  final bool enableDucking; // Musik während Moderation sanft absenken
  final int duckingVolumePercent; // Lautstärke in % während des Redens (z. B. 20%)
  final DjAudioOutput audioOutput;

  // Lokale KI-Moderation (Ollama)
  final bool enableOllamaLlm; // Echte dynamische Song-Moderation per lokalem Ollama
  final String ollamaHost; // z.B. http://192.168.188.244:11434 oder http://127.0.0.1:11434
  final String ollamaModel; // z.B. llama3.2:latest

  // Lokaler TTS-Server (Piper / Home Assistant / OpenAI-kompatibel)
  final String localTtsUrl; // z.B. http://192.168.188.25:8123 oder http://127.0.0.1:5000/api/tts
  final String localTtsToken; // Optionaler Token / API-Key
  final String openAiEndpoint; // z.B. http://192.168.188.25:8000/v1/audio/speech
  final String openAiVoice; // onyx (tiefe Radio-Stimme), alloy, echo, nova

  const DjVoiceSettings({
    this.engine = DjVoiceEngine.appleSiri,
    this.voiceId = 'de-DE-Siri-1',
    this.voiceName = 'Apple Siri (Neural)',
    this.speechRate = 1.05,
    this.pitch = 0.95,
    this.enableDucking = true,
    this.duckingVolumePercent = 20,
    this.audioOutput = DjAudioOutput.device,
    this.enableOllamaLlm = true,
    this.ollamaHost = 'http://127.0.0.1:11434',
    this.ollamaModel = 'llama3.2:latest',
    this.localTtsUrl = 'http://homeassistant.local:8123',
    this.localTtsToken = '',
    this.openAiEndpoint = 'http://127.0.0.1:8000/v1/audio/speech',
    this.openAiVoice = 'onyx',
  });

  DjVoiceSettings copyWith({
    DjVoiceEngine? engine,
    String? voiceId,
    String? voiceName,
    double? speechRate,
    double? pitch,
    bool? enableDucking,
    int? duckingVolumePercent,
    DjAudioOutput? audioOutput,
    bool? enableOllamaLlm,
    String? ollamaHost,
    String? ollamaModel,
    String? localTtsUrl,
    String? localTtsToken,
    String? openAiEndpoint,
    String? openAiVoice,
  }) {
    return DjVoiceSettings(
      engine: engine ?? this.engine,
      voiceId: voiceId ?? this.voiceId,
      voiceName: voiceName ?? this.voiceName,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      enableDucking: enableDucking ?? this.enableDucking,
      duckingVolumePercent: duckingVolumePercent ?? this.duckingVolumePercent,
      audioOutput: audioOutput ?? this.audioOutput,
      enableOllamaLlm: enableOllamaLlm ?? this.enableOllamaLlm,
      ollamaHost: ollamaHost ?? this.ollamaHost,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      localTtsUrl: localTtsUrl ?? this.localTtsUrl,
      localTtsToken: localTtsToken ?? this.localTtsToken,
      openAiEndpoint: openAiEndpoint ?? this.openAiEndpoint,
      openAiVoice: openAiVoice ?? this.openAiVoice,
    );
  }

  Map<String, dynamic> toJson() => {
        'engine': engine.name,
        'voiceId': voiceId,
        'voiceName': voiceName,
        'speechRate': speechRate,
        'pitch': pitch,
        'enableDucking': enableDucking,
        'duckingVolumePercent': duckingVolumePercent,
        'audioOutput': audioOutput.name,
        'enableOllamaLlm': enableOllamaLlm,
        'ollamaHost': ollamaHost,
        'ollamaModel': ollamaModel,
        'localTtsUrl': localTtsUrl,
        'localTtsToken': localTtsToken,
        'openAiEndpoint': openAiEndpoint,
        'openAiVoice': openAiVoice,
      };

  factory DjVoiceSettings.fromJson(Map<String, dynamic> json) {
    DjVoiceEngine parseEngine(String? val) {
      return DjVoiceEngine.values.firstWhere(
        (e) => e.name == val,
        orElse: () => DjVoiceEngine.appleSiri,
      );
    }

    DjAudioOutput parseOutput(String? val) {
      return DjAudioOutput.values.firstWhere(
        (o) => o.name == val,
        orElse: () => DjAudioOutput.device,
      );
    }

    return DjVoiceSettings(
      engine: parseEngine(json['engine']),
      voiceId: json['voiceId'] as String? ?? 'de-DE-Siri-1',
      voiceName: json['voiceName'] as String? ?? 'Apple Siri (Neural)',
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 1.05,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 0.95,
      enableDucking: json['enableDucking'] as bool? ?? true,
      duckingVolumePercent: json['duckingVolumePercent'] as int? ?? 20,
      audioOutput: parseOutput(json['audioOutput']),
      enableOllamaLlm: json['enableOllamaLlm'] as bool? ?? true,
      ollamaHost: json['ollamaHost'] as String? ?? 'http://127.0.0.1:11434',
      ollamaModel: json['ollamaModel'] as String? ?? 'llama3.2:latest',
      localTtsUrl: json['localTtsUrl'] as String? ?? 'http://homeassistant.local:8123',
      localTtsToken: json['localTtsToken'] as String? ?? '',
      openAiEndpoint: json['openAiEndpoint'] as String? ?? 'http://127.0.0.1:8000/v1/audio/speech',
      openAiVoice: json['openAiVoice'] as String? ?? 'onyx',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory DjVoiceSettings.fromJsonString(String str) {
    try {
      return DjVoiceSettings.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return const DjVoiceSettings();
    }
  }
}
