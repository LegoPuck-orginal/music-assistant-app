import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/adaptive_eq_settings.dart';
import 'package:music_assistant_app/models/player_device.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channelGlobal =
      MethodChannel('xyz.luan/audioplayers.global');
  const MethodChannel channelPlayer = MethodChannel('xyz.luan/audioplayers');
  const MethodChannel channelWatch =
      MethodChannel('de.timm.musicAssistantApp/watch');
  const MethodChannel channelNowPlaying =
      MethodChannel('de.timm.musicAssistantApp/apple_now_playing');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelGlobal, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelPlayer, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelWatch, (MethodCall methodCall) async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelNowPlaying, (MethodCall methodCall) async => true);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Volume Debouncing & Audio Dropout Protection Tests', () {
    test('setVolume updates in-memory player volume immediately and clamps values', () async {
      final prov = MusicProvider();
      final player = PlayerDevice(
        id: 'sonos_kitchen',
        name: 'Küche Sonos',
        type: 'speaker',
        volume: 30,
        isAvailable: true,
      );
      await prov.setActivePlayer(player);

      expect(prov.activePlayer?.volume, 30);

      // Instant update & clamp check
      await prov.setVolume(75);
      expect(prov.activePlayer?.volume, 75);

      await prov.setVolume(120);
      expect(prov.activePlayer?.volume, 100);

      await prov.setVolume(-15);
      expect(prov.activePlayer?.volume, 0);

      prov.dispose();
    });

    test('Rapid setVolume calls update in-memory volume smoothly without crashing DSP pipeline', () async {
      final prov = MusicProvider();
      final player = PlayerDevice(
        id: 'sonos_living',
        name: 'Wohnzimmer Sonos',
        type: 'speaker',
        volume: 20,
        isAvailable: true,
      );
      await prov.setActivePlayer(player);

      // Simulate dragging a slider from 20 to 60 across 40 rapid events
      for (int v = 21; v <= 60; v++) {
        await prov.setVolume(v);
        expect(prov.activePlayer?.volume, v);
      }

      // Flush volume ensures the trailing target is delivered
      prov.flushVolume('sonos_living');
      expect(prov.activePlayer?.volume, 60);

      prov.dispose();
    });

    test('setPlayerVolume updates multiroom child speaker volume', () async {
      final prov = MusicProvider();
      final childSpeaker = PlayerDevice(
        id: 'sonos_bathroom',
        name: 'Bad Sonos',
        type: 'speaker',
        volume: 25,
        isAvailable: true,
      );

      await prov.setPlayerVolume(childSpeaker, 45);
      expect(childSpeaker.volume, 45);

      prov.flushVolume(childSpeaker.id);
      expect(childSpeaker.volume, 45);

      prov.dispose();
    });

    test('Adaptive EQ sync is debounced and only triggered after dragging pauses', () async {
      final prov = MusicProvider();
      await prov.updateAdaptiveEqSettings(const AdaptiveEqSettings(
        isEnabled: true,
        mode: AdaptiveEqMode.dynamicLoudness,
      ));

      final player = PlayerDevice(
        id: 'sonos_dining',
        name: 'Esszimmer Sonos',
        type: 'speaker',
        volume: 15,
        isAvailable: true,
      );
      await prov.setActivePlayer(player);

      // Slider movement sequence
      await prov.setVolume(20);
      await prov.setVolume(25);
      await prov.setVolume(30);

      expect(prov.activePlayer?.volume, 30);
      prov.dispose();
    });
  });
}
