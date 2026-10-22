import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:music_assistant_app/providers/music_provider.dart';
import 'package:music_assistant_app/screens/search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  testWidgets('SearchScreen renders search field and genres', (WidgetTester tester) async {
    final musicProvider = MusicProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<MusicProvider>.value(
        value: musicProvider,
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      ),
    );

    // Initial state check
    expect(find.text('Suche'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Alles durchsuchen'), findsOneWidget);
    expect(find.text('Pop'), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget);
    expect(find.text('Hip-Hop'), findsOneWidget);

    // Enter search query
    await tester.enterText(find.byType(TextField), 'Daft');
    await tester.pump();

    // Verify text entered
    expect(find.text('Daft'), findsOneWidget);
  });
}
