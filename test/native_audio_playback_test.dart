import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/player_device.dart';
import 'package:music_assistant_app/models/track.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/services/mass_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channelGlobal =
      MethodChannel('xyz.luan/audioplayers.global');
  const MethodChannel channelPlayer = MethodChannel('xyz.luan/audioplayers');
  const MethodChannel channelNowPlaying =
      MethodChannel('de.timm.musicAssistantApp/apple_now_playing');

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
        .setMockMethodCallHandler(channelNowPlaying, (MethodCall methodCall) async {
      return 1;
    });
  });

  group('Native iOS Audio Flow Streaming Tests', () {
    late MassApiService api;

    setUp(() {
      api = MassApiService();
      api.configure('http://192.168.1.100:8095', 'test_token');
    });

    test('getQueueFlowStreamUrl formats correct continuous HTTP stream URL for MP3 & FLAC', () {
      final mp3Url = api.getQueueFlowStreamUrl('sonos_kitchen');
      expect(mp3Url, equals('http://192.168.1.100:8095/flow/sonos_kitchen/stream.mp3'));

      final flacUrl = api.getQueueFlowStreamUrl('sonos_kitchen', lossless: true);
      expect(flacUrl, equals('http://192.168.1.100:8095/flow/sonos_kitchen/stream.flac'));
    });

    test('fetchFullTrackStreamUrl resolves direct HTTP streams for podcasts/radio without alteration', () async {
      final radioTrack = Track(
        id: 'radio_1',
        title: 'Rock Antenne',
        artist: 'Radio',
        album: 'Live Stream',
        durationSeconds: 0,
        uri: 'https://stream.rockantenne.hamburg/rockantenne-hamburg/stream/mp3',
      );

      final streamUrl = await api.fetchFullTrackStreamUrl(radioTrack);
      expect(streamUrl, equals('https://stream.rockantenne.hamburg/rockantenne-hamburg/stream/mp3'));
    });

    test('fetchFullTrackStreamUrl returns queue flow stream when queueId is provided', () async {
      final track = Track(
        id: 'track_123',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        durationSeconds: 354,
        provider: 'spotify',
      );

      final streamUrl = await api.fetchFullTrackStreamUrl(track, queueId: 'player_living_room');
      expect(streamUrl, equals('http://192.168.1.100:8095/flow/player_living_room/stream.mp3'));
    });

    test('fetchFullTrackStreamUrl falls back to standard /api/stream endpoint without queueId', () async {
      final track = Track(
        id: 'track_456',
        title: 'Stairway to Heaven',
        artist: 'Led Zeppelin',
        album: 'Led Zeppelin IV',
        durationSeconds: 482,
        provider: 'spotify',
      );

      final streamUrl = await api.fetchFullTrackStreamUrl(track);
      expect(streamUrl, contains('http://192.168.1.100:8095/api/stream?track_id=track_456'));
      expect(streamUrl, isNot(contains('mp3-preview')));
    });
  });

  group('MusicProvider Local Playback & Queue Management Tests', () {
    late MusicProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = MusicProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('isLocalPlayback is true by default when no active remote speaker is connected', () {
      expect(provider.isLocalPlayback, isTrue);
    });

    test('isLocalPlayback is true when activePlayer is local_iphone', () async {
      await provider.setActivePlayer(PlayerDevice.localIPhone());
      expect(provider.isLocalPlayback, isTrue);
    });

    test('activePlayer is not local when selecting an external network speaker', () async {
      final remoteSpeaker = PlayerDevice(
        id: 'sonos_one',
        name: 'Sonos One Wohnzimmer',
        type: 'Sonos',
        isAvailable: true,
        volume: 45,
        state: 'idle',
      );
      await provider.setActivePlayer(remoteSpeaker);
      expect(provider.activePlayer?.isLocal, isFalse);
    });

    test('Local playback advances queue with next() and previous()', () async {
      final track1 = Track(
        id: 't1',
        title: 'Song 1',
        artist: 'Artist A',
        album: 'Album 1',
        durationSeconds: 200,
      );
      final track2 = Track(
        id: 't2',
        title: 'Song 2',
        artist: 'Artist B',
        album: 'Album 2',
        durationSeconds: 210,
      );
      final track3 = Track(
        id: 't3',
        title: 'Song 3',
        artist: 'Artist C',
        album: 'Album 3',
        durationSeconds: 220,
      );

      await provider.playTrack(track1, newQueue: [track1, track2, track3]);
      expect(provider.currentTrack?.id, equals('t1'));

      await provider.next();
      expect(provider.currentTrack?.id, equals('t2'));

      await provider.next();
      expect(provider.currentTrack?.id, equals('t3'));

      await provider.previous();
      expect(provider.currentTrack?.id, equals('t2'));
    });

    test('togglePlayPause cleanly flips playing state on local iPhone output', () async {
      final track = Track(
        id: 't_toggle',
        title: 'Toggle Song',
        artist: 'Artist X',
        album: 'Album X',
        durationSeconds: 180,
      );

      await provider.playTrack(track, newQueue: [track]);
      expect(provider.isPlaying, isTrue);

      await provider.togglePlayPause();
      expect(provider.isPlaying, isFalse);

      await provider.togglePlayPause();
      expect(provider.isPlaying, isTrue);
    });
  });
}
