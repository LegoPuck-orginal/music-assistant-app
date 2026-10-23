import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_assistant_app/models/equalizer_settings.dart';
import 'package:music_assistant_app/models/player_device.dart';
import 'package:music_assistant_app/models/playlist.dart';
import 'package:music_assistant_app/models/track.dart';
import 'package:music_assistant_app/providers/music_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (MethodCall methodCall) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('de.timm.musicAssistantApp/apple_now_playing'),
    (MethodCall methodCall) async => true,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('de.timm.musicAssistantApp/live_activity'),
    (MethodCall methodCall) async => true,
  );

  group('Music Assistant Model & Provider Tests', () {
    test('Track model formatting & copyWith', () {
      final t = Track(
        id: '123',
        title: 'Test Song',
        artist: 'Test Artist',
        album: 'Test Album',
        durationSeconds: 185,
      );
      expect(t.formattedDuration, '3:05');
      expect(t.isLiked, false);

      final copy = t.copyWith(isLiked: true);
      expect(copy.isLiked, true);
    });

    test('PlayerDevice local vs remote', () {
      final local = PlayerDevice.localIPhone();
      expect(local.isLocal, true);
      expect(local.type, 'iPhone');

      final sonos = PlayerDevice(id: 'sonos_kitchen', name: 'Küche', type: 'Sonos');
      expect(sonos.isLocal, false);
      expect(sonos.volume, 50);
    });

    test('EqualizerSettings presets and band gains', () {
      final eq = EqualizerSettings();
      expect(eq.isEnabled, true);
      expect(eq.currentPreset, 'Flat');

      eq.applyPreset('Bass Booster');
      expect(eq.currentPreset, 'Bass Booster');
      expect(eq.bandGains[0], 6.0);

      eq.setBandGain(0, 8.0);
      expect(eq.currentPreset, 'Custom');
      expect(eq.bandGains[0], 8.0);
    });

    test('Playlist tracks list is mutable and supports loading', () {
      final pl = Playlist(
        id: 'p1',
        name: 'Test Pl',
        owner: 'Tim',
        trackCount: 0,
        provider: 'spotify',
        type: 'album',
      );
      expect(pl.tracks, isEmpty);
      expect(pl.provider, 'spotify');
      expect(pl.type, 'album');
      // Ensure adding to list does not throw UnsupportedError
      pl.tracks.add(Track(
        id: 't1',
        title: 'T',
        artist: 'A',
        album: '',
        durationSeconds: 100,
        provider: 'spotify',
      ));
      expect(pl.tracks.length, 1);
      expect(pl.tracks.first.provider, 'spotify');
    });

    test('Track json serialization includes provider', () {
      final t = Track(
        id: 'sp_1',
        title: 'Get Lucky',
        artist: 'Daft Punk',
        album: 'RAM',
        durationSeconds: 248,
        provider: 'spotify--4VhyAjjD',
      );
      final json = t.toJson();
      expect(json['provider'], 'spotify--4VhyAjjD');

      final fromJson = Track.fromJson(json);
      expect(fromJson.provider, 'spotify--4VhyAjjD');
      expect(fromJson.title, 'Get Lucky');
    });

    test('MusicProvider initial state and search reset', () async {
      final prov = MusicProvider();
      expect(prov.players.isNotEmpty, true);
      expect(prov.activePlayer?.isLocal, true);
      expect(prov.playlists.isNotEmpty, true);
      expect(prov.queue.isNotEmpty, true);

      // Empty query clears results immediately
      await prov.search('');
      expect(prov.searchResultsTracks, isEmpty);
      expect(prov.searchResultsPlaylists, isEmpty);
      expect(prov.searchResultsAlbums, isEmpty);
      expect(prov.searchResultsPodcasts, isEmpty);
      expect(prov.isSearching, false);
    });

    test('Podcast model and library filtering', () {
      final podcast = Playlist(
        id: 'pod_1',
        name: 'Die drei ??? Podcast',
        owner: 'Europa',
        trackCount: 66,
        type: 'podcast',
      );
      final musicPlaylist = Playlist(
        id: 'pl_1',
        name: 'Top 50 Hits',
        owner: 'Spotify',
        trackCount: 50,
        type: 'playlist',
      );

      final all = [podcast, musicPlaylist];
      final podcastsOnly = all.where((p) => p.type == 'podcast').toList();
      final musicOnly = all.where((p) => p.type != 'podcast').toList();

      expect(podcastsOnly.length, 1);
      expect(podcastsOnly.first.name, 'Die drei ??? Podcast');
      expect(musicOnly.length, 1);
      expect(musicOnly.first.name, 'Top 50 Hits');
    });

    test('PlayerDevice playback tracking & takeover control', () async {
      final provider = MusicProvider();

      final sonosLivingRoom = PlayerDevice(
        id: 'sonos_lr',
        name: 'Wohnzimmer Sonos',
        type: 'Sonos',
        state: 'playing',
        currentTitle: 'Wish You Were Here',
        currentArtist: 'Pink Floyd',
        currentAlbum: 'Wish You Were Here',
        currentDurationSeconds: 334,
        elapsedTimeSeconds: 45,
      );

      expect(sonosLivingRoom.isPlaying, isTrue);
      expect(sonosLivingRoom.hasActiveTrack, isTrue);

      await provider.takeOverControl(sonosLivingRoom);

      expect(provider.activePlayer?.id, equals('sonos_lr'));
      expect(provider.currentTrack?.title, equals('Wish You Were Here'));
      expect(provider.currentTrack?.artist, equals('Pink Floyd'));
      expect(provider.totalDuration.inSeconds, equals(334));
      expect(provider.currentPosition.inSeconds, equals(45));
    });
  });
}
