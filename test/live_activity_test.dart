import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/services/live_activity_service.dart';

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
  });
}
