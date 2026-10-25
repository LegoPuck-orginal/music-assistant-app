import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/services/apple_now_playing_service.dart';
import 'package:music_assistant_app/services/watch_service.dart';
import 'package:music_assistant_app/widgets/apple_watch_remote_sheet.dart';

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('de.timm.musicAssistantApp/apple_now_playing'),
      (MethodCall call) async {
        return true;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('de.timm.musicAssistantApp/live_activity'),
      (MethodCall call) async {
        return true;
      },
    );
  });

  group('Apple Watch & WatchConnectivity Tests', () {
    late MusicProvider provider;
    final List<MethodCall> methodChannelCalls = [];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      methodChannelCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('de.timm.musicAssistantApp/watch'),
        (MethodCall call) async {
          methodChannelCalls.add(call);
          if (call.method == 'isSupported') return true;
          if (call.method == 'isPaired') return true;
          return null;
        },
      );

      provider = MusicProvider();
      WatchService.instance.init(provider);
    });

    tearDown(() {
      provider.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('de.timm.musicAssistantApp/watch'),
        null,
      );
    });

    test('WatchService singleton is accessible', () {
      expect(WatchService.instance, isNotNull);
      expect(WatchService(), same(WatchService.instance));
    });

    test('WatchService reports support and pairing status', () async {
      final isSupported = await WatchService.instance.isSupported();
      final isPaired = await WatchService.instance.isPaired();

      expect(isSupported, isTrue);
      expect(isPaired, isTrue);
    });

    test('WatchService.syncState formats state dictionary and dispatches via channel', () async {
      await WatchService.instance.syncState(provider);

      expect(methodChannelCalls, isNotEmpty);
      final syncCall = methodChannelCalls.firstWhere((c) => c.method == 'syncState');
      expect(syncCall, isNotNull);

      final data = syncCall.arguments as Map;
      expect(data.containsKey('trackTitle'), isTrue);
      expect(data.containsKey('artist'), isTrue);
      expect(data.containsKey('isPlaying'), isTrue);
      expect(data.containsKey('volume'), isTrue);
      expect(data.containsKey('activeSpeakerName'), isTrue);
      expect(data.containsKey('speakers'), isTrue);
      expect(data.containsKey('currentDjVibe'), isTrue);
    });

    test('WatchService handles incoming watch remote actions', () async {
      expect(provider.isPlaying, isFalse);

      // Simulate Play Action from Apple Watch
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'de.timm.musicAssistantApp/watch',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWatchAction', {'action': 'togglePlayPause'}),
        ),
        (ByteData? data) {},
      );

      // Provider toggles playback
      expect(provider.isPlaying, isTrue);

      // Simulate Volume change from Digital Crown
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'de.timm.musicAssistantApp/watch',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onWatchAction', {'action': 'setVolume', 'volume': 75.0}),
        ),
        (ByteData? data) {},
      );

      expect(provider.activePlayer?.volume, equals(75));
    });

    testWidgets('AppleWatchRemoteSheet renders watch hardware bezel and views',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MusicProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: AppleWatchRemoteSheet(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check Watch title and status
      expect(find.text('Apple Watch Fernbedienung'), findsOneWidget);
      expect(find.text('Now Playing'), findsOneWidget);
      expect(find.text('Lautsprecher'), findsOneWidget);
      expect(find.text('KI-DJ'), findsOneWidget);
      expect(find.text('MASS'), findsOneWidget);

      // Check Play/Pause button on watch screen
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Apple Native MediaPlayer & Dynamic Island Tests', () {
    late MusicProvider provider;
    final List<MethodCall> nowPlayingCalls = [];

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      nowPlayingCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('de.timm.musicAssistantApp/apple_now_playing'),
        (MethodCall call) async {
          nowPlayingCalls.add(call);
          return true;
        },
      );

      provider = MusicProvider();
      AppleNowPlayingService.instance.initialize(provider);
    });

    tearDown(() {
      provider.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('de.timm.musicAssistantApp/apple_now_playing'),
        null,
      );
    });

    test('AppleNowPlayingService singleton is accessible', () {
      expect(AppleNowPlayingService.instance, isNotNull);
      expect(AppleNowPlayingService(), same(AppleNowPlayingService.instance));
    });

    test('AppleNowPlayingService.sync formats metadata and dispatches updateNowPlaying', () async {
      if (provider.currentTrack == null && provider.queue.isNotEmpty) {
        await provider.playTrack(provider.queue.first);
      }
      await AppleNowPlayingService.instance.sync(provider);

      expect(nowPlayingCalls, isNotEmpty);
      final updateCall = nowPlayingCalls.firstWhere((c) => c.method == 'updateNowPlaying');
      expect(updateCall, isNotNull);

      final data = updateCall.arguments as Map;
      expect(data.containsKey('title'), isTrue);
      expect(data.containsKey('artist'), isTrue);
      expect(data.containsKey('album'), isTrue);
      expect(data.containsKey('durationSeconds'), isTrue);
      expect(data.containsKey('positionSeconds'), isTrue);
      expect(data.containsKey('isPlaying'), isTrue);
    });

    test('AppleNowPlayingService handles remote commands from Dynamic Island & Watch Crown', () async {
      expect(provider.isPlaying, isFalse);

      // Simulate Play command from Lock Screen / Dynamic Island
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'de.timm.musicAssistantApp/apple_now_playing',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onRemoteCommand', {'action': 'play'}),
        ),
        (ByteData? data) {},
      );

      expect(provider.isPlaying, isTrue);

      // Simulate Pause command
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'de.timm.musicAssistantApp/apple_now_playing',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onRemoteCommand', {'action': 'pause'}),
        ),
        (ByteData? data) {},
      );

      expect(provider.isPlaying, isFalse);
    });
  });
}
