import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_assistant_app/models/user_profile.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/screens/welcome_screen.dart';

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
        'username': 'tim-m',
        'display_name': 'Tim Marquardt',
        'role': 'admin',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.userId, 'u123');
      expect(profile.username, 'tim-m');
      expect(profile.displayName, 'Tim Marquardt');
      expect(profile.role, 'admin');
      expect(profile.isAdmin, isTrue);
      expect(profile.effectiveName, 'Tim Marquardt');
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
