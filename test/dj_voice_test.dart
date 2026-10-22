import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/dj_voice_settings.dart';
import 'package:music_assistant_app/models/track.dart';
import 'package:music_assistant_app/models/virtual_dj_vibe.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/services/native_tts_service.dart';
import 'package:music_assistant_app/services/storage_service.dart';
import 'package:music_assistant_app/services/virtual_dj_service.dart';
import 'package:music_assistant_app/widgets/dj_voice_settings_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channelGlobal =
      MethodChannel('xyz.luan/audioplayers.global');
  const MethodChannel channelPlayer = MethodChannel('xyz.luan/audioplayers');
  const MethodChannel channelNativeTts =
      MethodChannel('de.timm.musicAssistantApp/native_tts');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelGlobal, (MethodCall methodCall) async {
      return 1;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelPlayer, (MethodCall methodCall) async {
      return 1;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelNativeTts, (MethodCall methodCall) async {
      if (methodCall.method == 'getVoices') {
        return [
          {
            'identifier': 'com.apple.voice.premium.de-DE.Martin',
            'name': 'Martin (Radiomoderator)',
            'language': 'de-DE',
            'quality': 'premium',
            'gender': 'male',
          }
        ];
      }
      return true;
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DJ Voice Settings & Serialization Tests', () {
    test('DjVoiceSettings defaults to Apple Siri Neural with pitch and rate presets', () {
      const s = DjVoiceSettings();
      expect(s.engine, equals(DjVoiceEngine.appleSiri));
      expect(s.voiceId, equals('de-DE-Siri-1'));
      expect(s.speechRate, equals(1.05));
      expect(s.pitch, equals(0.95));
      expect(s.enableDucking, isTrue);
      expect(s.duckingVolumePercent, equals(20));
      expect(s.enableOllamaLlm, isTrue);
      expect(s.ollamaHost, equals('http://127.0.0.1:11434'));
      expect(s.ollamaModel, equals('llama3.2:latest'));
    });

    test('DjVoiceSettings JSON roundtrip preserves all attributes', () {
      const original = DjVoiceSettings(
        engine: DjVoiceEngine.localServer,
        voiceId: 'thorsten-high',
        voiceName: 'Thorsten High (Piper)',
        speechRate: 1.15,
        pitch: 0.90,
        enableDucking: false,
        duckingVolumePercent: 30,
        audioOutput: DjAudioOutput.activeSpeaker,
        enableOllamaLlm: false,
        ollamaHost: 'http://192.168.188.244:11434',
        ollamaModel: 'mistral:latest',
        localTtsUrl: 'http://192.168.188.25:8123',
        localTtsToken: 'secret_token_123',
        openAiEndpoint: 'http://127.0.0.1:8000/v1/audio/speech',
        openAiVoice: 'onyx',
      );

      final jsonStr = original.toJsonString();
      final restored = DjVoiceSettings.fromJsonString(jsonStr);

      expect(restored.engine, equals(DjVoiceEngine.localServer));
      expect(restored.voiceId, equals('thorsten-high'));
      expect(restored.voiceName, equals('Thorsten High (Piper)'));
      expect(restored.speechRate, equals(1.15));
      expect(restored.pitch, equals(0.90));
      expect(restored.enableDucking, isFalse);
      expect(restored.duckingVolumePercent, equals(30));
      expect(restored.audioOutput, equals(DjAudioOutput.activeSpeaker));
      expect(restored.enableOllamaLlm, isFalse);
      expect(restored.ollamaHost, equals('http://192.168.188.244:11434'));
      expect(restored.ollamaModel, equals('mistral:latest'));
      expect(restored.localTtsUrl, equals('http://192.168.188.25:8123'));
      expect(restored.localTtsToken, equals('secret_token_123'));
    });

    test('StorageService persists and loads DjVoiceSettings correctly', () async {
      final storage = StorageService();

      const customSettings = DjVoiceSettings(
        engine: DjVoiceEngine.openAiCompatible,
        voiceId: 'onyx',
        voiceName: 'Onyx Radio DJ',
        speechRate: 1.1,
      );

      await storage.saveDjVoiceSettings(customSettings);
      final loaded = await storage.loadDjVoiceSettings();

      expect(loaded.engine, equals(DjVoiceEngine.openAiCompatible));
      expect(loaded.voiceId, equals('onyx'));
      expect(loaded.voiceName, equals('Onyx Radio DJ'));
      expect(loaded.speechRate, equals(1.1));
    });
  });

  group('Virtual DJ & Speech Generation Tests', () {
    test('VirtualDjService composes dynamic radio intro with track context', () async {
      final service = VirtualDjService();
      final vibe = DjVibe.allVibes.first;
      final track = Track(
        id: 'track_queen_1',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        durationSeconds: 354,
      );

      // Mit deaktiviertem Ollama für reinen Template-Test
      const settings = DjVoiceSettings(enableOllamaLlm: false);
      final speech = await service.composeDjSpeech(
        settings: settings,
        vibe: vibe,
        userName: 'Tim',
        nextTrack: track,
      );

      expect(speech, contains('Tim'));
      expect(speech, contains('Bohemian Rhapsody'));
      expect(speech, contains('Queen'));
    });

    test('NativeTtsService provides German studio and neural fallback voices', () async {
      final tts = NativeTtsService();
      final voices = await tts.getGermanVoices();

      expect(voices.isNotEmpty, isTrue);
      expect(voices.any((v) => v.language.startsWith('de')), isTrue);
      expect(voices.any((v) => v.name.contains('Siri') || v.name.contains('Helena') || v.name.contains('Martin')), isTrue);
    });
  });

  group('DJ Voice Settings UI Tests', () {
    testWidgets('DjVoiceSettingsSheet renders all engines and controls', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = MusicProvider();
      addTearDown(() => provider.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<MusicProvider>.value(
            value: provider,
            child: const Scaffold(
              body: DjVoiceSettingsSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('DJ STIMME & SPRACHMODELL'), findsOneWidget);
      expect(find.text('Virtueller Spotify DJ'), findsOneWidget);

      // Engines
      expect(find.textContaining('Apple Neural Siri'), findsOneWidget);
      expect(find.text('Home Assistant / Lokaler Piper Server'), findsOneWidget);
      expect(find.textContaining('Lokaler OpenAI-kompatibler Server'), findsOneWidget);
      expect(find.text('Music Assistant Raumlautsprecher'), findsOneWidget);

      // Controls
      expect(find.text('Echte KI-DJ-Moderationen'), findsOneWidget);
      expect(find.text('Sprechtempo'), findsOneWidget);
      expect(find.text('Tonhöhe / Bass'), findsOneWidget);
      expect(find.text('Musik-Ducking'), findsOneWidget);
      expect(find.text('DJ-STIMME TESTEN'), findsOneWidget);
    });
  });
}
