import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/music_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'theme/spotify_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation & status bar styling for OLED Spotify look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Run the app immediately so the UI renders without blocking
  runApp(
    ChangeNotifierProvider(
      create: (_) => MusicProvider()..initialize(),
      child: const MusicAssistantApp(),
    ),
  );
}

class MusicAssistantApp extends StatelessWidget {
  const MusicAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Assistant',
      debugShowCheckedModeBanner: false,
      theme: SpotifyTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
