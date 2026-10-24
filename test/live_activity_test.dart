import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_assistant_app/models/player_device.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/services/apple_now_playing_service.dart';
import 'package:music_assistant_app/services/live_activity_service.dart';
import 'package:music_assistant_app/services/mass_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channelGlobal =
      MethodChannel('xyz.luan/audioplayers.global');
  const MethodChannel channelPlayer = MethodChannel('xyz.luan/audioplayers');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelGlobal, (MethodCall methodCall) async {
      return 1;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelPlayer, (MethodCall methodCall) async {
      return 1;
    });
  });

  group('Apple Dynamic Island & Live Activity Tests', () {
    late MusicProvider provider;
    final List<MethodCall> liveActivityCalls = [];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      liveActivityCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('de.timm.musicAssistantApp/live_activity'),
        (MethodCall call) async {
          liveActivityCalls.add(call);
          if (call.method == 'isSupported') return true;
          return null;
        },
      );

      provider = MusicProvider();
    });

    tearDown(() {
      provider.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('de.timm.musicAssistantApp/live_activity'),
        null,
      );
    });

    test('LiveActivityService singleton is accessible', () {
      expect(LiveActivityService.instance, isNotNull);
      expect(LiveActivityService(), same(LiveActivityService.instance));
    });

    test('LiveActivityService syncs active playback state with Apple Dynamic Island', () async {
      final track = provider.currentTrack!;

      await LiveActivityService.instance.sync(provider);

      expect(liveActivityCalls, isNotEmpty);
      final call = liveActivityCalls.firstWhere((c) => c.method == 'startOrUpdate');
      expect(call, isNotNull);

      final args = call.arguments as Map;
      expect(args['trackTitle'], equals(track.title));
      expect(args['artist'], equals(track.artist));
      expect(args['isPlaying'], equals(provider.isPlaying));
      expect(args['speakerName'], isNotNull);
      expect(args['djVibe'], isNotNull);
    });

    test('LiveActivityService ends activity on stop', () async {
      await LiveActivityService.instance.endActivity();

      expect(liveActivityCalls, isNotEmpty);
      final endCall = liveActivityCalls.firstWhere((c) => c.method == 'endActivity');
      expect(endCall, isNotNull);
    });

    test('AppleNowPlayingService re-syncs when artworkUrl is resolved via activePlayer', () async {
      final List<MethodCall> nowPlayingCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('de.timm.musicAssistantApp/apple_now_playing'),
        (MethodCall call) async {
          nowPlayingCalls.add(call);
          return true;
        },
      );

      await AppleNowPlayingService.instance.clear();
      nowPlayingCalls.clear();

      // 1. Initial player without artwork URL
      await provider.setActivePlayer(
        PlayerDevice(
          id: 'RINCON_TIM',
          name: 'Tim',
          type: 'Sonos',
          state: 'playing',
          currentTitle: 'Krieg',
          currentArtist: 'Yu',
          currentAlbum: 'Krieg',
          currentDurationSeconds: 161,
        ),
      );
      expect(nowPlayingCalls.where((c) => c.method == 'updateNowPlaying'), isNotEmpty);
      final firstArgs = nowPlayingCalls.last.arguments as Map;
      expect(firstArgs['artworkUrl'], equals(''));

      nowPlayingCalls.clear();

      // 2. Same track receives resolved artwork URL -> must NOT be skipped by signature check!
      await provider.setActivePlayer(
        PlayerDevice(
          id: 'RINCON_TIM',
          name: 'Tim',
          type: 'Sonos',
          state: 'playing',
          currentTitle: 'Krieg',
          currentArtist: 'Yu',
          currentAlbum: 'Krieg',
          currentImageUrl: 'http://192.168.188.25:8095/imageproxy/abc123?size=512&fmt=jpg',
          currentDurationSeconds: 161,
        ),
      );
      expect(nowPlayingCalls.where((c) => c.method == 'updateNowPlaying'), isNotEmpty);
      final secondArgs = nowPlayingCalls.last.arguments as Map;
      expect(
        secondArgs['artworkUrl'],
        equals('http://192.168.188.25:8095/imageproxy/abc123?size=512&fmt=jpg'),
      );
    });

    test('MassApiService.resolveImageUrl resolves proxy_id, https, and relative paths', () {
      final api = MassApiService();
      api.configure('http://192.168.188.25:8095', 'test_token');

      expect(
        api.resolveImageUrl({
          'path': 'https://i.scdn.co/image/ab67616d0000b2734f23f5243a7845b6a45c5f14',
          'remotely_accessible': true,
          'proxy_id': 'ff1b60b9',
        }),
        equals('https://i.scdn.co/image/ab67616d0000b2734f23f5243a7845b6a45c5f14'),
      );

      expect(
        api.resolveImageUrl({
          'path': '/media/audiobooks/cover.jpg',
          'remotely_accessible': false,
          'proxy_id': 'ff1b60b9',
        }),
        equals('http://192.168.188.25:8095/imageproxy/ff1b60b9?size=512&fmt=jpg'),
      );

      expect(
        api.resolveImageUrl('/imageproxy/custom123?size=512'),
        equals('http://192.168.188.25:8095/imageproxy/custom123?size=512'),
      );
      api.dispose();
    });
  });
}
