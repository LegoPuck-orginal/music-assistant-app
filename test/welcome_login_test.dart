import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_assistant_app/models/user_profile.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/screens/welcome_guide_screen.dart';
import 'package:music_assistant_app/screens/welcome_screen.dart';
import 'package:music_assistant_app/services/mass_api_service.dart';
import 'package:music_assistant_app/services/storage_service.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Welcome & Login Tests', () {
    test('UserProfile model parses json correctly', () {
      final json = {
        'user_id': 'u123',
        'username': 'alex',
        'display_name': 'Alex Demo',
        'role': 'admin',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.userId, 'u123');
      expect(profile.username, 'alex');
      expect(profile.displayName, 'Alex Demo');
      expect(profile.role, 'admin');
      expect(profile.isAdmin, isTrue);
      expect(profile.effectiveName, 'Alex Demo');
    });

    testWidgets('WelcomeScreen renders all essential elements',
        (WidgetTester tester) async {
      final prov = MusicProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: prov,
          child: const MaterialApp(
            home: WelcomeScreen(),
          ),
        ),
      );

      // Verify branding & typography
      expect(find.text('MUSIC ASSISTANT'), findsOneWidget);
      expect(find.text('Musik ohne Grenzen.'), findsOneWidget);

      // Verify input fields
      expect(find.byType(TextField), findsNWidgets(2)); // Username & Password
      expect(find.text('Anmelden'), findsOneWidget);
      expect(find.text('Als Gast / Offline ausprobieren'), findsOneWidget);
      expect(find.text('Willkommens-Guide & Server-Assistent'), findsOneWidget);
    });

    testWidgets('WelcomeGuideScreen walkthrough slides and demo start',
        (WidgetTester tester) async {
      final prov = MusicProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: prov,
          child: const MaterialApp(
            home: WelcomeGuideScreen(),
          ),
        ),
      );

      // Slide 1: Welcome
      expect(find.text('MUSIC ASSISTANT'), findsOneWidget);
      expect(find.text('Deine Musik.\nOhne Grenzen.'), findsOneWidget);
      expect(find.text('Weiter'), findsOneWidget);
      expect(find.text('Demo'), findsOneWidget);

      // Advance to Slide 2
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text('SERVER-ARCHITEKTUR'), findsOneWidget);
      expect(find.text('Wie funktioniert Music Assistant?'), findsOneWidget);

      // Advance to Slide 3
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text('HIGHLIGHTS'), findsOneWidget);
      expect(find.text('Exklusive Audio-Features'), findsOneWidget);

      // Advance to Slide 4
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text('VERBINDUNG EINRICHTEN'), findsOneWidget);
      expect(find.text('Verbinde deinen Server'), findsOneWidget);
      expect(find.text('🔍 Lokale Server automatisch suchen'), findsOneWidget);

      final demoBtn = find.text('Im Demo- & Offline-Modus starten');
      expect(demoBtn, findsOneWidget);
      await tester.ensureVisible(demoBtn);
      await tester.pumpAndSettle();

      // Tap Demo Mode
      await tester.tap(demoBtn);
      await tester.pumpAndSettle();

      expect(prov.hasCompletedWelcomeGuide, isTrue);
      expect(prov.isAuthenticated, isTrue);
      expect(prov.currentUser?.username, 'Gast-Hörer');
    });

    test('StorageService persists onboarding and server defaults', () async {
      final storage = StorageService();

      // Defaults on clean install
      expect(await storage.hasCompletedWelcomeGuide(), isFalse);
      expect(await storage.loadServerUrl(), 'http://homeassistant.local:8095');
      expect(await storage.loadAuthToken(), isNull);

      // Persist onboarding completion
      await storage.setWelcomeGuideCompleted(true);
      expect(await storage.hasCompletedWelcomeGuide(), isTrue);

      // Persist server url
      await storage.saveServerUrl('http://192.168.1.50:8095');
      expect(await storage.loadServerUrl(), 'http://192.168.1.50:8095');
    });

    test('MassApiService testConnection handles invalid and empty urls', () async {
      final resEmpty = await MassApiService.testConnection('');
      expect(resEmpty['success'], isFalse);
      expect(resEmpty['error'], contains('Bitte gib eine Server-Adresse ein'));
    });

    test('MusicProvider logout clears authentication', () async {
      final prov = MusicProvider();
      await prov.continueAsGuest();
      expect(prov.isAuthenticated, isTrue);
      expect(prov.currentUser?.username, 'Gast-Hörer');

      await prov.logout();
      expect(prov.isAuthenticated, isFalse);
      expect(prov.currentUser, isNull);
    });
  });
}
