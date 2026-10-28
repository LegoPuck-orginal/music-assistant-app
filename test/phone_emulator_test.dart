import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/screens/main_navigation_screen.dart';
import 'package:music_assistant_app/screens/virtual_dj_screen.dart';
import 'package:music_assistant_app/theme/spotify_colors.dart';
import 'package:music_assistant_app/widgets/device_picker_sheet.dart';
import 'package:music_assistant_app/widgets/now_playing_sheet.dart';

const String screenshotDir =
    '/home/tim-m/.gemini/antigravity-cli/brain/9680a59f-93f0-40b1-9954-ea3611ce591a';

Future<void> saveScreenshot(
    WidgetTester tester, GlobalKey repaintKey, String filename) async {
  final dir = Directory(screenshotDir);
  if (!dir.existsSync()) {
    // Auf CI-Runnern (z. B. GitHub Actions macOS) existiert das lokale Verzeichnis nicht -> überspringen
    return;
  }
  final boundary = repaintKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final buffer = byteData.buffer.asUint8List();
      final file = File('$screenshotDir/$filename');
      await file.writeAsBytes(buffer);
    }
  });
}

Widget createPhoneEmulatorFrame({
  required Widget child,
  required GlobalKey repaintKey,
  required MusicProvider musicProvider,
}) {
  return ChangeNotifierProvider<MusicProvider>.value(
    value: musicProvider,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: SpotifyColors.pureBlack,
        colorScheme: const ColorScheme.dark(
          primary: SpotifyColors.orange,
          surface: SpotifyColors.surface,
        ),
      ),
      home: RepaintBoundary(
        key: repaintKey,
        child: Container(
          width: 393,
          height: 852,
          color: SpotifyColors.pureBlack,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        return true;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '/tmp',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('de.timm.musicAssistantApp/apple_now_playing'),
      (MethodCall methodCall) async => null,
    );
  });

  group('iPhone 15 Pro Emulation & Screenshot Capture', () {
    testWidgets('1. Home Screen: Entschlackte Top-Bar & Musik-Fokus',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prov = MusicProvider();
      final playerId = prov.localAudioPlayer.playerId;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('xyz.luan/audioplayers/events/$playerId'),
        (MethodCall methodCall) async => null,
      );
      final repaintKey = GlobalKey();

      await tester.pumpWidget(
        createPhoneEmulatorFrame(
          child: const MainNavigationScreen(),
          repaintKey: repaintKey,
          musicProvider: prov,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Top-Bar Checks
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget); // KI-DJ
      expect(find.byIcon(Icons.smartphone_rounded), findsOneWidget); // Geräte
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget); // Overflow-Menü
      expect(find.text('Hörbücher'), findsNothing);
      expect(find.text('KI-DJ STUDIO'), findsNothing);

      await saveScreenshot(tester, repaintKey, 'iphone_01_home.png');

      // Overflow Menü antippen
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Einstellungen'), findsOneWidget);
      expect(find.text('Zuletzt gehört'), findsWidgets);
      expect(find.text('Durchsage'), findsOneWidget);

      await saveScreenshot(tester, repaintKey, 'iphone_02_home_menu.png');

      // Popup-Menü sauber schließen
      Navigator.of(tester.element(find.text('Einstellungen'))).pop();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('2. Now Playing Screen & Live Waveform Scrubber',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prov = MusicProvider();
      final playerId = prov.localAudioPlayer.playerId;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('xyz.luan/audioplayers/events/$playerId'),
        (MethodCall methodCall) async => null,
      );

      // Titel starten
      await prov.playTrack(prov.queue.first);

      final repaintKey = GlobalKey();
      await tester.pumpWidget(
        createPhoneEmulatorFrame(
          child: const Scaffold(body: NowPlayingSheet()),
          repaintKey: repaintKey,
          musicProvider: prov,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(NowPlayingSheet), findsOneWidget);
      expect(find.text(prov.currentTrack!.title), findsWidgets);
      expect(find.text(prov.currentTrack!.artist), findsWidgets);

      await saveScreenshot(tester, repaintKey, 'iphone_03_now_playing.png');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('3. Spotify Connect Device Picker Sheet & Multi-Room Sync',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prov = MusicProvider();
      final playerId = prov.localAudioPlayer.playerId;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('xyz.luan/audioplayers/events/$playerId'),
        (MethodCall methodCall) async => null,
      );
      final repaintKey = GlobalKey();

      await tester.pumpWidget(
        createPhoneEmulatorFrame(
          child: const Scaffold(body: DevicePickerSheet()),
          repaintKey: repaintKey,
          musicProvider: prov,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Überprüfe Hero-Bereich des aktiven Geräts
      expect(find.textContaining('Dieses iPhone'), findsWidgets);

      await saveScreenshot(tester, repaintKey, 'iphone_04_spotify_connect.png');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('4. Neuer Hörspiele Tab in der Hauptnavigation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prov = MusicProvider();
      final playerId = prov.localAudioPlayer.playerId;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('xyz.luan/audioplayers/events/$playerId'),
        (MethodCall methodCall) async => null,
      );
      final repaintKey = GlobalKey();

      await tester.pumpWidget(
        createPhoneEmulatorFrame(
          child: const MainNavigationScreen(),
          repaintKey: repaintKey,
          musicProvider: prov,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Tippe auf den 3. Navigations-Tab: 'Hörspiele'
      await tester.tap(find.text('Hörspiele'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hörspiele'), findsWidgets);
      expect(find.text('Die drei ???'), findsWidgets);

      await saveScreenshot(tester, repaintKey, 'iphone_05_hoerspiele.png');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('5. Bibliothek & Lieblingssongs Direktanzeige',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prov = MusicProvider();
      final playerId = prov.localAudioPlayer.playerId;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('xyz.luan/audioplayers/events/$playerId'),
        (MethodCall methodCall) async => null,
      );
      final repaintKey = GlobalKey();

      await tester.pumpWidget(
        createPhoneEmulatorFrame(
          child: const MainNavigationScreen(),
          repaintKey: repaintKey,
          musicProvider: prov,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Tippe auf den 4. Navigations-Tab: 'Bibliothek'
      await tester.tap(find.text('Bibliothek'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Deine Bibliothek'), findsOneWidget);
      expect(find.text('Lieblingssongs'), findsWidgets);

      await saveScreenshot(tester, repaintKey, 'iphone_06_library.png');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('6. Virtual KI-DJ Studio & Voice Settings',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prov = MusicProvider();
      final playerId = prov.localAudioPlayer.playerId;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel('xyz.luan/audioplayers/events/$playerId'),
        (MethodCall methodCall) async => null,
      );
      final repaintKey = GlobalKey();

      await tester.pumpWidget(
        createPhoneEmulatorFrame(
          child: const VirtualDjScreen(),
          repaintKey: repaintKey,
          musicProvider: prov,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('STUDIO KI-DJ'), findsOneWidget);
      expect(find.text('VIBE & MIX WECHSELN'), findsOneWidget);

      await saveScreenshot(tester, repaintKey, 'iphone_07_virtual_dj.png');

      // Voice Settings Sheet öffnen
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('DJ STIMME & SPRACHMODELL'), findsOneWidget);
      await saveScreenshot(tester, repaintKey, 'iphone_08_dj_voice_settings.png');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
