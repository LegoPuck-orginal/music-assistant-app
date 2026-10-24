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
  final List<String> _recentTemplates = [];

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
    Track? previousTrack,
    String? customUserPrompt,
    String? fallbackServerUrl,
  }) async {
    // 1. Lokales Ollama Sprachmodell versuchen (mit schnellem LAN-Failover)
    if (settings.enableOllamaLlm) {
      final generated = await _ollama.generateDjIntro(
        host: settings.ollamaHost,
        model: settings.ollamaModel,
        userName: userName,
        vibeTitle: vibe.title,
        vibeSubtitle: vibe.subtitle,
        trackTitle: nextTrack?.title,
        artistName: nextTrack?.artist,
        previousTrackTitle: previousTrack?.title,
        previousArtistName: previousTrack?.artist,
        customUserPrompt: customUserPrompt,
        fallbackServerUrl: fallbackServerUrl,
      );
      if (generated != null && generated.isNotEmpty) {
        return generated;
      }
    }

    // 2. Dynamische, stimmungs- und tageszeitabhängige Radio-DJ-Templates
    return _buildDynamicTemplate(
      vibe: vibe,
      user: userName,
      track: nextTrack,
      previousTrack: previousTrack,
      customUserPrompt: customUserPrompt,
    );
  }

  /// Spricht den Kommentar über die eingestellte Engine
  Future<bool> speakCommentary({
    required String text,
    required DjVoiceSettings settings,
    String? activeRemotePlayerId,
    Future<void> Function(String playerId, String msg)? onMassAnnounce,
  }) async {
    final cleanText = OllamaService.sanitizeLlmSpeech(text) ?? text;

    // Falls Music Assistant Lautsprecher gewählt ist
    if (settings.engine == DjVoiceEngine.musicAssistant ||
        settings.audioOutput == DjAudioOutput.activeSpeaker) {
      if (activeRemotePlayerId != null &&
          activeRemotePlayerId != 'local_iphone' &&
          onMassAnnounce != null) {
        await onMassAnnounce(activeRemotePlayerId, cleanText);
        return true;
      }
    }

    switch (settings.engine) {
      case DjVoiceEngine.appleSiri:
        final ok = await _nativeTts.speak(
          text: cleanText,
          voiceIdentifier: settings.voiceId,
          rate: settings.speechRate,
          pitch: settings.pitch,
        );
        if (!ok && onMassAnnounce != null && activeRemotePlayerId != null) {
          await onMassAnnounce(activeRemotePlayerId, cleanText);
        }
        return ok;

      case DjVoiceEngine.openAiCompatible:
        final ok = await _localTts.speakOpenAiCompatible(
          endpoint: settings.openAiEndpoint,
          text: cleanText,
          voice: settings.openAiVoice,
          speed: settings.speechRate,
        );
        if (!ok) {
          return _nativeTts.speak(
            text: cleanText,
            voiceIdentifier: settings.voiceId,
            rate: settings.speechRate,
            pitch: settings.pitch,
          );
        }
        return ok;

      case DjVoiceEngine.localServer:
        final ok = await _localTts.speakPiperOrHomeAssistant(
          serverUrl: settings.localTtsUrl,
          text: cleanText,
          token: settings.localTtsToken,
        );
        if (!ok) {
          return _nativeTts.speak(
            text: cleanText,
            voiceIdentifier: settings.voiceId,
            rate: settings.speechRate,
            pitch: settings.pitch,
          );
        }
        return ok;

      case DjVoiceEngine.musicAssistant:
        if (activeRemotePlayerId != null && onMassAnnounce != null) {
          await onMassAnnounce(activeRemotePlayerId, cleanText);
          return true;
        }
        return _nativeTts.speak(
          text: cleanText,
          voiceIdentifier: settings.voiceId,
          rate: settings.speechRate,
          pitch: settings.pitch,
        );
    }
  }

  /// Probehören der Stimme im Einstellungsdialog
  Future<void> previewVoice(DjVoiceSettings settings, String userName) async {
    final previewText =
        'Hey $userName! Hier ist dein persönlicher KI-DJ. Ich sorge für nahtlose Übergänge und genau den richtigen Sound für deine Stimmung.';

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

  String _pickNonRepeating(List<String> options) {
    if (options.isEmpty) return '';
    final available = options.where((o) => !_recentTemplates.contains(o)).toList();
    final pool = available.isNotEmpty ? available : options;
    final chosen = pool[_rnd.nextInt(pool.length)];
    _recentTemplates.add(chosen);
    if (_recentTemplates.length > 8) {
      _recentTemplates.removeAt(0);
    }
    return chosen;
  }

  String _timeGreeting(String user) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return 'Guten Morgen, $user';
    if (hour >= 11 && hour < 17) return 'Hey $user';
    if (hour >= 17 && hour < 22) return 'Schönen Abend, $user';
    return 'Späte Stunde, $user';
  }

  String _buildDynamicTemplate({
    required DjVibe vibe,
    required String user,
    Track? track,
    Track? previousTrack,
    String? customUserPrompt,
  }) {
    final title = OllamaService.cleanTrackTitleForSpeech(track?.title);
    final artist = OllamaService.cleanArtistForSpeech(track?.artist);
    final prevTitle = OllamaService.cleanTrackTitleForSpeech(previousTrack?.title);
    final prevArtist = OllamaService.cleanArtistForSpeech(previousTrack?.artist);
    final hasTrack = title.isNotEmpty && artist.isNotEmpty;
    final hasPrev = prevTitle.isNotEmpty && prevArtist.isNotEmpty;
    final greeting = _timeGreeting(user);

    // 1. Individueller Musikwunsch des Nutzers
    if (customUserPrompt != null && customUserPrompt.trim().isNotEmpty) {
      final wish = customUserPrompt.trim();
      if (hasTrack) {
        return _pickNonRepeating([
          'Alles klar $user, du hast dir $wish gewünscht! Wir starten direkt mit $title von $artist.',
          'Guter Geschmack, $user! Passend zu deinem Wunsch $wish kommt hier $title von $artist.',
          'Dein Wunsch ist mir Befehl, $user. Für $wish hab ich genau das Richtige rausgesucht: $title von $artist.',
        ]);
      }
      return 'Alles klar $user! Ich stelle dir sofort einen frischen Mix für $wish zusammen.';
    }

    // 2. Automatische Überleitung mitten in einer laufenden DJ-Session
    if (hasPrev && hasTrack) {
      switch (vibe.category) {
        case DjVibeCategory.lateNightChill:
          return _pickNonRepeating([
            'Das war $prevTitle von $prevArtist. Wir bleiben ganz entspannt, $user – weiter geht es mit $title von $artist.',
            'Sanfte Übergänge für dich, $user. Nach $prevArtist folgt jetzt $title von $artist.',
            'Lehn dich weiter zurück, $user. Auf $prevTitle lassen wir jetzt $title von $artist folgen.',
          ]);
        case DjVibeCategory.rockClassics:
        case DjVibeCategory.partyVibes:
          return _pickNonRepeating([
            'Starkes Brett von $prevArtist! Wir halten das Energie-Level oben, $user – hier ist $title von $artist!',
            'Nach $prevTitle legen wir direkt nach, $user. Mach dich bereit für $title von $artist!',
            'Keine Pause für die Boxen, $user! Auf $prevArtist folgt jetzt nahtlos $title von $artist.',
          ]);
        default:
          return _pickNonRepeating([
            'Das war $prevTitle von $prevArtist. Als Nächstes im Mix für dich, $user: $title von $artist.',
            'Nahtloser Übergang in deiner Session, $user. Nach $prevArtist hören wir jetzt $title von $artist.',
            'Weiter geht die Reise durch deinen Sound, $user – hier kommt $title von $artist.',
          ]);
      }
    }

    // 3. Stimmungs-spezifische Moderationen MIT Song & Künstler
    if (hasTrack) {
      switch (vibe.category) {
        case DjVibeCategory.allTimeFavorites:
          return _pickNonRepeating([
            '$greeting! Ich hab deine Allzeit-Favoriten geladen. Den Anfang macht ein echter Dauerbrenner bei dir: $title von $artist.',
            'Hier sind die Songs, die dich immer begleiten, $user. Los geht es mit deinem Favoriten $title von $artist!',
            'Zeit für deine persönlichen Klassiker, $user! Wir starten diesen Block mit $title von $artist.',
            'Diesen Track kennst du in- und auswendig, $user: Hier ist $title von $artist aus deinen meistgehörten Favoriten.',
          ]);

        case DjVibeCategory.rockClassics:
          return _pickNonRepeating([
            'Jetzt gibt es ehrliche Gitarren und volle Energie, $user! Wir eröffnen den Rock-Block mit $title von $artist.',
            'Dreh den Verstärker auf, $user! Hier kommt kompromissloser Sound mit $title von $artist.',
            'Zeit für kräftige Riffs und legendäre Stimmen, $user. Los geht es mit $title von $artist!',
            '$greeting! Für deinen Rock-Vibe hab ich genau das richtige Brett bereitgelegt: $title von $artist.',
          ]);

        case DjVibeCategory.forgottenGems:
          return _pickNonRepeating([
            'Lust auf einen kleinen Zeitsprung, $user? Diesen Schatz hast du schon lange nicht mehr gehört: $title von $artist.',
            'Tief aus deiner Mediathek ausgegraben, $user: Erinnerst du dich noch an $title von $artist?',
            'Manche Songs werden mit der Zeit nur besser, $user. Hier ist ein fast vergessenes Highlight: $title von $artist.',
            '$greeting! Ich habe im Archiv gestöbert und eine echte Perle für dich wiederentdeckt: $title von $artist.',
          ]);

        case DjVibeCategory.artistDiscoveries:
          return _pickNonRepeating([
            'Zeit für frischen Wind in deinen Ohren, $user! Hör mal rein in $title von $artist – passt perfekt zu deinem Stil.',
            'Neue Horizonte für deine Playlist, $user: Wir starten die Künstler-Entdeckungen mit $title von $artist.',
            '$greeting! Ich hab da jemanden, der genau deine musikalische DNA trifft: Hier ist $title von $artist.',
            'Lass uns gemeinsam neue Sounds erkunden, $user. Den Auftakt macht $title von $artist.',
          ]);

        case DjVibeCategory.partyVibes:
          return _pickNonRepeating([
            'Jetzt bringen wir ordentlich Bewegung in den Raum, $user! Hier ist dein Party-Start mit $title von $artist!',
            'Gute Laune garantiert, $user! Wir drehen den Beat hoch mit $title von $artist.',
            'Volle Energie für deinen Mix, $user – hier kommt $title von $artist!',
            '$greeting! Zeit für mitreißende Beats. Den Auftakt im Party-Modus macht $title von $artist.',
          ]);

        case DjVibeCategory.lateNightChill:
          return _pickNonRepeating([
            '$greeting. Zeit, einen Gang runterzuschalten und durchzuatmen. Lehn dich zurück zu $title von $artist.',
            'Ruhige Klänge und entspannte Atmosphäre für dich, $user. Wir gleiten sanft rein mit $title von $artist.',
            'Lass den Alltag hinter dir, $user. Hier ist dein Late-Night-Soundtrack mit $title von $artist.',
            'Ganz entspannte Vibes für diesen Moment, $user. Genieß die Ruhe mit $title von $artist.',
          ]);
      }
    }

    // 4. Fallback ohne konkreten Track
    switch (vibe.category) {
      case DjVibeCategory.allTimeFavorites:
        return '$greeting! Hier ist dein persönlicher DJ. Ich hab deine Allzeit-Favoriten geladen – los geht es mit deinen absoluten Lieblings-Tracks!';
      case DjVibeCategory.rockClassics:
        return 'Jetzt drehen wir auf, $user! Hier kommt ein handverlesener Rock-Block mit kräftigen Riffs für dich.';
      case DjVibeCategory.forgottenGems:
        return 'Lust auf etwas Nostalgie, $user? Lass uns gemeinsam alte Schätze aus deiner Mediathek wiederentdecken!';
      case DjVibeCategory.artistDiscoveries:
        return 'Zeit für frische Töne, $user! Diese Künstler passen perfekt zu deiner musikalischen DNA.';
      case DjVibeCategory.partyVibes:
        return 'Bringen wir Energie in den Raum, $user! Hier kommt ein mitreißender Party-Mix für beste Stimmung!';
      case DjVibeCategory.lateNightChill:
        return '$greeting. Hier ist dein entspannter Chill-Mix zum Zurücklehnen und Abschalten.';
    }
  }
}
