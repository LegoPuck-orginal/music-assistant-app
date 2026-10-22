import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_assistant_app/models/downloaded_track.dart';
import 'package:music_assistant_app/models/track.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/services/download_service.dart';
import 'package:music_assistant_app/widgets/downloads_sheet.dart';

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

  group('DownloadService & Offline Playback Tests', () {
    late Directory tempDir;
    late MusicProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('mass_downloads_test_');
      DownloadService.instance.setCustomStoragePath(tempDir.path);
      await DownloadService.instance.init();

      provider = MusicProvider();
    });

    tearDown(() async {
      provider.dispose();
      DownloadService.instance.setCustomStoragePath(null);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('DownloadedTrack model serializes and converts to Track', () {
      final downloaded = DownloadedTrack(
        id: 'track_123',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        durationSeconds: 354,
        localFilePath: '/tmp/track_123.mp3',
        fileSizeBytes: 5 * 1024 * 1024,
        downloadedAt: DateTime.now(),
      );

      expect(downloaded.id, 'track_123');
      expect(downloaded.formattedSize, '5.0 MB');

      final track = downloaded.toTrack();
      expect(track.id, 'track_123');
      expect(track.title, 'Bohemian Rhapsody');
      expect(track.uri, '/tmp/track_123.mp3');
    });

    test('DownloadService downloads track and creates local file', () async {
      final testTrack = Track(
        id: 'test_dl_1',
        title: 'Offline Rock Song',
        artist: 'The Testers',
        album: 'Unit Hits',
        durationSeconds: 120,
      );

      expect(DownloadService.instance.isDownloaded(testTrack.id), isFalse);

      final success = await DownloadService.instance.downloadTrack(testTrack);
      expect(success, isTrue);
      expect(DownloadService.instance.isDownloaded(testTrack.id), isTrue);

      final downloaded = DownloadService.instance.getDownloadedTrack(testTrack.id);
      expect(downloaded, isNotNull);
      expect(File(downloaded!.localFilePath).existsSync(), isTrue);
      expect(DownloadService.instance.getTotalSizeBytes(), greaterThan(0));

      // Remove download
      final removed = await DownloadService.instance.removeDownload(testTrack.id);
      expect(removed, isTrue);
      expect(DownloadService.instance.isDownloaded(testTrack.id), isFalse);
      expect(File(downloaded.localFilePath).existsSync(), isFalse);
    });

    testWidgets('DownloadsSheet renders offline mode toggle and empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<MusicProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadsSheet(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header checks
      expect(find.text('Downloads & Offline-Musik'), findsOneWidget);
      expect(find.text('Offline-Modus erzwingen'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Empty state
      expect(find.text('Noch keine Downloads vorhanden'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
