import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/player_device.dart';
import 'package:music_assistant_app/models/track.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/services/player_position_tracker.dart';
import 'package:music_assistant_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('PlayerPositionTracker & Live Playback Sync Tests', () {
    late PlayerPositionTracker tracker;

    setUp(() {
      tracker = PlayerPositionTracker();
    });

    test('initial position is 0.0 for unknown queue', () {
      expect(tracker.getPosition('unknown_player'), 0.0);
      expect(tracker.hasAnchor('unknown_player'), isFalse);
    });

    test('setAnchor sets paused elapsed time without advancing', () async {
      tracker.setAnchor(
        queueId: 'player_livingroom',
        elapsedSec: 42.0,
        isPlaying: false,
        durationSec: 180.0,
      );

      expect(tracker.hasAnchor('player_livingroom'), isTrue);
      expect(tracker.getPosition('player_livingroom'), 42.0);

      // Wait 100ms: position should remain static because isPlaying is false
      await Future.delayed(const Duration(milliseconds: 100));
      expect(tracker.getPosition('player_livingroom'), 42.0);
    });

    test('playing anchor smoothly advances with wall-clock time', () async {
      tracker.setAnchor(
        queueId: 'player_kitchen',
        elapsedSec: 10.0,
        isPlaying: true,
        durationSec: 180.0,
      );

      // Wait 250ms
      await Future.delayed(const Duration(milliseconds: 250));
      final pos = tracker.getPosition('player_kitchen');
      expect(pos, greaterThanOrEqualTo(10.2));
      expect(pos, lessThan(11.0));
    });

    test('setPlaying pauses and snapshots without drifting', () async {
      tracker.setAnchor(
        queueId: 'player_bedroom',
        elapsedSec: 20.0,
        isPlaying: true,
        durationSec: 200.0,
      );

      await Future.delayed(const Duration(milliseconds: 150));
      tracker.setPlaying('player_bedroom', false);

      final snapshotted = tracker.getPosition('player_bedroom');
      expect(snapshotted, greaterThan(20.0));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(tracker.getPosition('player_bedroom'), snapshotted);
    });

    test('clamped to durationSec when track reaches end', () {
      tracker.setAnchor(
        queueId: 'player_office',
        elapsedSec: 199.9,
        isPlaying: true,
        durationSec: 200.0,
      );

      // Even if effectiveNow calculates 205.0 with wall clock delta, it should clamp to 200.0
      final anchor = PlayerPositionAnchor(
        elapsedSec: 199.0,
        wallMs: DateTime.now().millisecondsSinceEpoch - 5000,
        isPlaying: true,
        durationSec: 200.0,
      );
      expect(anchor.effectiveNow(), 200.0);
    });

    test('speed scaling works accurately for audiobooks and podcasts', () {
      final anchor1x = PlayerPositionAnchor(
        elapsedSec: 10.0,
        wallMs: DateTime.now().millisecondsSinceEpoch - 1000,
        isPlaying: true,
        durationSec: 100.0,
        speed: 1.0,
      );
      final anchor2x = PlayerPositionAnchor(
        elapsedSec: 10.0,
        wallMs: DateTime.now().millisecondsSinceEpoch - 1000,
        isPlaying: true,
        durationSec: 100.0,
        speed: 2.0,
      );

      expect(anchor1x.effectiveNow(), closeTo(11.0, 0.1));
      expect(anchor2x.effectiveNow(), closeTo(12.0, 0.1));
    });

    test('getPositionDuration converts to Duration with millisecond accuracy', () {
      tracker.setAnchor(
        queueId: 'player_test',
        elapsedSec: 65.432,
        isPlaying: false,
      );

      final dur = tracker.getPositionDuration('player_test');
      expect(dur.inSeconds, 65);
      expect(dur.inMilliseconds, 65432);
    });
  });

  group('MusicProvider End-to-End Feature Tests', () {
    late MusicProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      provider = MusicProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('createPlaylist and addTrackToPlaylist work and persist', () async {
      final pl = await provider.createPlaylist('Wochenend-Mix');
      expect(pl.name, 'Wochenend-Mix');
      expect(provider.playlists.first.name, 'Wochenend-Mix');

      final testTrack = Track(
        id: 'track_999',
        title: 'Starlight',
        artist: 'Muse',
        album: 'Black Holes and Revelations',
        durationSeconds: 240,
      );

      final added = await provider.addTrackToPlaylist(pl, testTrack);
      expect(added, isTrue);
      expect(pl.tracks.length, 1);
      expect(pl.trackCount, 1);
      expect(pl.tracks.first.title, 'Starlight');
    });

    test('playNext and addToQueue update queue accurately', () async {
      final initialLen = provider.queue.length;
      final nextTrack = Track(
        id: 'next_1',
        title: 'Next Song',
        artist: 'Artist A',
        album: 'Album A',
        durationSeconds: 180,
      );
      final endTrack = Track(
        id: 'end_1',
        title: 'End Song',
        artist: 'Artist B',
        album: 'Album B',
        durationSeconds: 200,
      );

      await provider.playNext(nextTrack);
      expect(provider.queue.length, initialLen + 1);
      expect(provider.queue[1].id, 'next_1');

      await provider.addToQueue(endTrack);
      expect(provider.queue.length, initialLen + 2);
      expect(provider.queue.last.id, 'end_1');
    });

    test('toggleLike updates likedTracks across library and queue', () async {
      final track = provider.queue.first;
      expect(provider.likedTracks.any((t) => t.id == track.id), isFalse);

      await provider.toggleLike(track);
      expect(track.isLiked, isTrue);
      expect(provider.likedTracks.any((t) => t.id == track.id), isTrue);

      await provider.toggleLike(track);
      expect(track.isLiked, isFalse);
      expect(provider.likedTracks.any((t) => t.id == track.id), isFalse);
    });

    test('Sleep Timer sets active countdown and clears cleanly', () async {
      expect(provider.hasActiveSleepTimer, isFalse);
      expect(provider.formattedSleepTimerRemaining, isNull);

      await provider.setSleepTimer(const Duration(minutes: 15));
      expect(provider.hasActiveSleepTimer, isTrue);
      expect(provider.formattedSleepTimerRemaining, isNotNull);

      await provider.clearSleepTimer();
      expect(provider.hasActiveSleepTimer, isFalse);
      expect(provider.formattedSleepTimerRemaining, isNull);
    });

    test('Audio & Playback settings toggle and persist', () async {
      expect(provider.allowLocalPlayback, isTrue);
      expect(provider.losslessStreaming, isTrue);
      expect(provider.crossfadeEnabled, isTrue);
      expect(provider.dontStopTheMusic, isTrue);

      await provider.setLosslessStreaming(false);
      await provider.setCrossfadeEnabled(false);
      await provider.setDontStopTheMusic(false);

      expect(provider.losslessStreaming, isFalse);
      expect(provider.crossfadeEnabled, isFalse);
      expect(provider.dontStopTheMusic, isFalse);
    });

    test(
        'selectPreferredRealSpeaker ignores saved local_iphone and prioritizes real speaker (Tim)',
        () {
      final local = PlayerDevice.localIPhone();
      final hueLight = PlayerDevice(
        id: 'hue-65d7c8a1ea3c43ec',
        name: 'Hue: Tim-Razer',
        type: 'Companion',
        isAvailable: true,
      );
      final kitchen = PlayerDevice(
        id: 'RINCON_38420B9E504201400',
        name: 'Küche',
        type: 'Sonos',
        isAvailable: true,
      );
      final timSonos = PlayerDevice(
        id: 'RINCON_38420BB9399301400',
        name: 'Tim',
        type: 'Sonos',
        isAvailable: true,
      );

      final chosen = provider.selectPreferredRealSpeaker(
        [local, hueLight, kitchen, timSonos],
        savedPlayerId: 'local_iphone',
      );
      expect(chosen, isNotNull);
      expect(chosen!.id, 'RINCON_38420BB9399301400');
      expect(chosen.name, 'Tim');
    });

    test(
        'resolveTrackMediaUri strips 30s preview URLs and builds full-length MA track URIs',
        () {
      final spotifyTrackWithPreview = Track(
        id: '6x0aZr7BCu50xkl8TfmqSi',
        title: '1000 mal berührt',
        artist: 'Die Zipfelbuben',
        album: 'Jetzt wird es heiss',
        durationSeconds: 184,
        provider: 'spotify--4VhyAjjD',
        uri:
            'https://p.scdn.co/mp3-preview/aa674e1677ce7a11b28bd58a06681e7b147f6e5a',
      );

      expect(
        provider.resolveTrackMediaUri(spotifyTrackWithPreview),
        'spotify--4VhyAjjD://track/6x0aZr7BCu50xkl8TfmqSi',
      );

      final libraryTrack = Track(
        id: '189',
        title: '1000 mal berührt',
        artist: 'Die Zipfelbuben',
        album: 'Jetzt wird es heiss',
        durationSeconds: 184,
        provider: 'library',
        uri: 'library://track/189',
      );
      expect(provider.resolveTrackMediaUri(libraryTrack), 'library://track/189');
    });

    test('setActivePlayer never persists local_iphone to SharedPreferences',
        () async {
      final storage = StorageService();
      await provider.setActivePlayer(PlayerDevice.localIPhone());
      expect(await storage.loadActivePlayerId(), isNull);

      final realSpeaker = PlayerDevice(
        id: 'RINCON_38420BB9399301400',
        name: 'Tim',
        type: 'Sonos',
      );
      await provider.setActivePlayer(realSpeaker);
      expect(await storage.loadActivePlayerId(), 'RINCON_38420BB9399301400');
    });
  });
}
