import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          // Aktuelle Ansicht
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Subtiles oberes Adobe-Orange Studio-Ambient-Licht
          IgnorePointer(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    SpotifyColors.orange.withValues(alpha: 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Schwebende Obsidian-Ember Studio-Kapsel (MiniPlayer)
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
        decoration: BoxDecoration(
          color: const Color(0xFF060609),
          border: Border(
            top: BorderSide(
              color: SpotifyColors.orange.withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: SpotifyColors.orange,
          unselectedItemColor: SpotifyColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            HapticFeedback.selectionClick();
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.space_dashboard_outlined),
              activeIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Start',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.manage_search_rounded),
              activeIcon: Icon(Icons.search_rounded),
              label: 'Suche',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.album_outlined),
              activeIcon: Icon(Icons.album_rounded),
              label: 'Bibliothek',
            ),
          ],
        ),
      ),
    );
  }
}
