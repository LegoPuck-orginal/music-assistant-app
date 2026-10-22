import 'dart:async';
import 'dart:math';
import '../models/dj_voice_settings.dart';
import '../models/track.dart';
import '../models/virtual_dj_vibe.dart';
import 'local_tts_service.dart';
import 'native_tts_service.dart';
import 'ollama_service.dart';

/// Zentraler DJ-Koordinator für KI-Sprachmodell, Sprachsynthese und DJ-Stimme
class VirtualDjService {
  static final VirtualDjService _instance = VirtualDjService._internal();
  factory VirtualDjService() => _instance;

  final NativeTtsService _nativeTts = NativeTtsService();
  final OllamaService _ollama = OllamaService();
  final LocalTtsService _localTts = LocalTtsService();
  final Random _rnd = Random();

  StreamSubscription? _nativeSub;
  StreamSubscription? _localSub;

  final StreamController<void> _speechDoneController =
      StreamController<void>.broadcast();
  Stream<void> get onSpeechCompleted => _speechDoneController.stream;

  VirtualDjService._internal() {
    _nativeSub = _nativeTts.onSpeechFinished.listen((_) {
      _speechDoneController.add(null);
    });
    _localSub = _localTts.onSpeechFinished.listen((_) {
      _speechDoneController.add(null);
    });
  }

  /// Generiert den Moderationstext (entweder über lokales Ollama oder smarte Radio-Templates)
  Future<String> composeDjSpeech({
    required DjVoiceSettings settings,
    required DjVibe vibe,
    required String userName,
    Track? nextTrack,
  }) async {
    // 1. Lokales Ollama Sprachmodell versuchen
    if (settings.enableOllamaLlm) {
      final generated = await _ollama.generateDjIntro(
        host: settings.ollamaHost,
        model: settings.ollamaModel,
        userName: userName,
        vibeTitle: vibe.title,
        trackTitle: nextTrack?.title,
        artistName: nextTrack?.artist,
      );
      if (generated != null && generated.isNotEmpty) {
        return generated;
      }
    }

    // 2. Dynamische, personalisierte Radio-DJ-Templates
    return _buildDynamicTemplate(vibe, userName, nextTrack);
  }

  /// Spricht den Kommentar über die eingestellte Engine
  Future<bool> speakCommentary({
    required String text,
    required DjVoiceSettings settings,
    String? activeRemotePlayerId,
    Future<void> Function(String playerId, String msg)? onMassAnnounce,
  }) async {
    // Falls Music Assistant Lautsprecher gewählt ist
    if (settings.engine == DjVoiceEngine.musicAssistant ||
        settings.audioOutput == DjAudioOutput.activeSpeaker) {
      if (activeRemotePlayerId != null &&
          activeRemotePlayerId != 'local_iphone' &&
          onMassAnnounce != null) {
        await onMassAnnounce(activeRemotePlayerId, text);
        return true;
      }
    }

    switch (settings.engine) {
      case DjVoiceEngine.appleSiri:
        final ok = await _nativeTts.speak(
          text: text,
          voiceIdentifier: settings.voiceId,
          rate: settings.speechRate,
          pitch: settings.pitch,
        );
        if (!ok && onMassAnnounce != null && activeRemotePlayerId != null) {
          await onMassAnnounce(activeRemotePlayerId, text);
        }
        return ok;

      case DjVoiceEngine.openAiCompatible:
        final ok = await _localTts.speakOpenAiCompatible(
          endpoint: settings.openAiEndpoint,
          text: text,
          voice: settings.openAiVoice,
          speed: settings.speechRate,
        );
        if (!ok) {
          // Fallback auf Apple Siri
          return _nativeTts.speak(
            text: text,
            voiceIdentifier: settings.voiceId,
            rate: settings.speechRate,
            pitch: settings.pitch,
          );
        }
        return ok;

      case DjVoiceEngine.localServer:
        final ok = await _localTts.speakPiperOrHomeAssistant(
          serverUrl: settings.localTtsUrl,
          text: text,
          token: settings.localTtsToken,
        );
        if (!ok) {
          return _nativeTts.speak(
            text: text,
            voiceIdentifier: settings.voiceId,
            rate: settings.speechRate,
            pitch: settings.pitch,
          );
        }
        return ok;

      case DjVoiceEngine.musicAssistant:
        if (activeRemotePlayerId != null && onMassAnnounce != null) {
          await onMassAnnounce(activeRemotePlayerId, text);
          return true;
        }
        return _nativeTts.speak(
          text: text,
          voiceIdentifier: settings.voiceId,
          rate: settings.speechRate,
          pitch: settings.pitch,
        );
    }
  }

  /// Probehören der Stimme im Einstellungsdialog
  Future<void> previewVoice(DjVoiceSettings settings, String userName) async {
    final previewText =
        'Hey $userName! Hier ist dein Radio-DJ mit vollem Bass und bester Laune. Wie gefällt dir diese Stimme?';

    switch (settings.engine) {
      case DjVoiceEngine.appleSiri:
      case DjVoiceEngine.musicAssistant:
        await _nativeTts.speak(
          text: previewText,
          voiceIdentifier: settings.voiceId,
          rate: settings.speechRate,
          pitch: settings.pitch,
        );
        break;

      case DjVoiceEngine.openAiCompatible:
        final ok = await _localTts.speakOpenAiCompatible(
          endpoint: settings.openAiEndpoint,
          text: previewText,
          voice: settings.openAiVoice,
          speed: settings.speechRate,
        );
        if (!ok) {
          await _nativeTts.speak(
            text: previewText,
            voiceIdentifier: settings.voiceId,
            rate: settings.speechRate,
            pitch: settings.pitch,
          );
        }
        break;

      case DjVoiceEngine.localServer:
        final ok = await _localTts.speakPiperOrHomeAssistant(
          serverUrl: settings.localTtsUrl,
          text: previewText,
          token: settings.localTtsToken,
        );
        if (!ok) {
          await _nativeTts.speak(
            text: previewText,
            voiceIdentifier: settings.voiceId,
            rate: settings.speechRate,
            pitch: settings.pitch,
          );
        }
        break;
    }
  }

  /// Bricht die Sprachausgabe aller Engines ab
  Future<void> stop() async {
    await _nativeTts.stop();
    await _localTts.stop();
  }

  void dispose() {
    _nativeSub?.cancel();
    _localSub?.cancel();
    _localTts.dispose();
  }

  String _buildDynamicTemplate(DjVibe vibe, String user, Track? track) {
    if (track != null) {
      final templatesWithTrack = [
        'Hey $user! Jetzt kommt ein absolutes Highlight für dich: "${track.title}" von ${track.artist}. Drehen wir die Boxen auf!',
        'Hier ist dein Spotify DJ, $user! Als Nächstes gibt\'s feinsten Sound: "${track.title}" von ${track.artist}. Viel Spaß beim Hören!',
        'Klasse Song-Wahl, $user! Mach dich bereit für "${track.title}" von ${track.artist}!',
        'Jetzt schalten wir einen Gang höher, $user! Hier ist "${track.title}" von ${track.artist}.',
      ];
      return templatesWithTrack[_rnd.nextInt(templatesWithTrack.length)];
    }

    switch (vibe.category) {
      case DjVibeCategory.allTimeFavorites:
        return 'Hey $user! Hier ist dein persönlicher DJ. Ich hab deine Allzeit-Favoriten geladen – los geht\'s mit deinen absoluten Lieblings-Tracks!';
      case DjVibeCategory.rockClassics:
        return 'Jetzt drehen wir auf, $user! Hier kommt ein handverlesener Rock-Block für dich. Boxen aufdrehen und abgehen!';
      case DjVibeCategory.forgottenGems:
        return 'Lust auf etwas Nostalgie, $user? Diese Songs hast du schon viel zu lange nicht mehr gehört. Lass uns alte Schätze wiederentdecken!';
      case DjVibeCategory.artistDiscoveries:
        return 'Zeit für frische Töne, $user! Diese neuen Künstler passen perfekt zu deiner musikalischen DNA.';
      case DjVibeCategory.partyVibes:
        return 'Bringen wir Energie in die Bude, $user! Hier kommt ein mitreißender Party-Mix für maximale Stimmung!';
      case DjVibeCategory.lateNightChill:
        return 'Späte Stunden, entspannte Töne, $user. Hier ist dein Chill-Mix zum Zurücklehnen und Abschalten.';
    }
  }
}
