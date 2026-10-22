import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final hasTrack = prov.currentTrack != null;

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: Stack(
        children: [
          // Current Page
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Sticky MiniPlayer floating right above the bottom navigation bar
          if (hasTrack)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MiniPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: SpotifyColors.pureBlack,
          border: Border(
            top: BorderSide(
              color: SpotifyColors.borderSubtle,
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: SpotifyColors.pureBlack,
          selectedItemColor: Colors.white,
          unselectedItemColor: SpotifyColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_filled),
              label: 'Start',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              activeIcon: Icon(Icons.search),
              label: 'Suche',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_outlined),
              activeIcon: Icon(Icons.library_music),
              label: 'Bibliothek',
            ),
          ],
        ),
      ),
    );
  }
}
