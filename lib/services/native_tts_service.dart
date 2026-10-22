import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeVoiceInfo {
  final String identifier;
  final String name;
  final String language;
  final String quality; // "premium", "enhanced", "default"
  final String gender; // "male", "female", "unspecified"

  const NativeVoiceInfo({
    required this.identifier,
    required this.name,
    required this.language,
    required this.quality,
    required this.gender,
  });

  factory NativeVoiceInfo.fromMap(Map<dynamic, dynamic> map) {
    return NativeVoiceInfo(
      identifier: map['identifier'] as String? ?? '',
      name: map['name'] as String? ?? 'Siri',
      language: map['language'] as String? ?? 'de-DE',
      quality: map['quality'] as String? ?? 'default',
      gender: map['gender'] as String? ?? 'unspecified',
    );
  }

  bool get isNeuralOrPremium => quality == 'premium' || quality == 'enhanced';
}

/// Service für native iOS Siri & Neural Speech Synthesis
class NativeTtsService {
  static final NativeTtsService _instance = NativeTtsService._internal();
  factory NativeTtsService() => _instance;

  static const MethodChannel _channel =
      MethodChannel('de.timm.musicAssistantApp/native_tts');

  final StreamController<void> _speechFinishedController =
      StreamController<void>.broadcast();
  Stream<void> get onSpeechFinished => _speechFinishedController.stream;

  List<NativeVoiceInfo>? _cachedVoices;

  NativeTtsService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onSpeechFinished':
      case 'onSpeechCancelled':
        _speechFinishedController.add(null);
        break;
    }
  }

  /// Prüft, ob Native iOS TTS verfügbar ist
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isSpeaking');
      return res != null;
    } catch (_) {
      return false;
    }
  }

  /// Ruft alle verfügbaren deutschen Stimmen ab
  Future<List<NativeVoiceInfo>> getGermanVoices() async {
    if (_cachedVoices != null && _cachedVoices!.isNotEmpty) {
      return _cachedVoices!;
    }
    try {
      final List<dynamic>? raw =
          await _channel.invokeListMethod<dynamic>('getVoices');
      if (raw != null) {
        _cachedVoices = raw
            .whereType<Map<dynamic, dynamic>>()
            .map((m) => NativeVoiceInfo.fromMap(m))
            .toList();
        return _cachedVoices!;
      }
    } catch (e) {
      debugPrint('[NativeTtsService] Error fetching voices: $e');
    }
    // Standard-Fallback-Stimmen für iOS
    return const [
      NativeVoiceInfo(
        identifier: 'com.apple.ttsbundle.siri_female_de-DE_compact',
        name: 'Siri Stimme 1 (Neural)',
        language: 'de-DE',
        quality: 'enhanced',
        gender: 'female',
      ),
      NativeVoiceInfo(
        identifier: 'com.apple.ttsbundle.siri_male_de-DE_compact',
        name: 'Siri Stimme 2 (DJ X Bass)',
        language: 'de-DE',
        quality: 'premium',
        gender: 'male',
      ),
      NativeVoiceInfo(
        identifier: 'com.apple.voice.enhanced.de-DE.Helena',
        name: 'Helena (Studio Klar)',
        language: 'de-DE',
        quality: 'enhanced',
        gender: 'female',
      ),
      NativeVoiceInfo(
        identifier: 'com.apple.voice.premium.de-DE.Martin',
        name: 'Martin (Radiomoderator)',
        language: 'de-DE',
        quality: 'premium',
        gender: 'male',
      ),
    ];
  }

  /// Spricht einen Text über AVSpeechSynthesizer
  Future<bool> speak({
    required String text,
    String? voiceIdentifier,
    double rate = 1.05,
    double pitch = 0.95,
    double volume = 1.0,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('speak', {
        'text': text,
        'voiceIdentifier': voiceIdentifier,
        'rate': rate,
        'pitch': pitch,
        'volume': volume,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('[NativeTtsService] Speak error: $e');
      return false;
    }
  }

  /// Bricht die Sprachausgabe sofort ab
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  /// Prüft, ob gerade gesprochen wird
  Future<bool> isSpeaking() async {
    try {
      final res = await _channel.invokeMethod<bool>('isSpeaking');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
