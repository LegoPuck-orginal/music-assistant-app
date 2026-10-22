import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/album_card.dart';
import 'playlist_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Guten Morgen';
    if (hour < 18) return 'Guten Tag';
    return 'Guten Abend';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final playlists = prov.playlists;

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: CustomScrollView(
        slivers: [
          // Spotify Top Bar
          SliverAppBar(
            floating: true,
            backgroundColor: SpotifyColors.pureBlack,
            elevation: 0,
            title: Text(
              _getGreeting(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),

          // Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildChip('Alle', isSelected: true),
                  const SizedBox(width: 8),
                  _buildChip('Musik'),
                  const SizedBox(width: 8),
                  _buildChip('Podcasts'),
                ],
              ),
            ),
          ),

          // 2x3 Quick Tiles ("Kürzlich gehört")
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3.0,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: playlists.take(6).length,
                itemBuilder: (context, index) {
                  final p = playlists[index];
                  return _buildQuickTile(context, p, prov);
                },
              ),
            ),
          ),

          // Section 1: Für dich zusammengestellt
          SliverToBoxAdapter(
            child: _buildSectionHeader(context, 'Für dich zusammengestellt'),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 215,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final p = playlists[index];
                  return AlbumCard(
                    playlist: p,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlist: p),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Section 2: Kürzlich gehört
          SliverToBoxAdapter(
            child: _buildSectionHeader(context, 'Wieder reinhören'),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 215,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: playlists.reversed.length,
                itemBuilder: (context, index) {
                  final p = playlists.reversed.toList()[index];
                  return AlbumCard(
                    playlist: p,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlist: p),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Space for bottom MiniPlayer
          const SliverToBoxAdapter(
            child: SizedBox(height: 110),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected ? SpotifyColors.green : SpotifyColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildQuickTile(
      BuildContext context, Playlist playlist, MusicProvider prov) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: playlist),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              color: SpotifyColors.surfaceHighlight,
              child: playlist.imageUrl != null
                  ? Image.network(
                      playlist.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.music_note,
                        color: SpotifyColors.textSecondary,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.music_note,
                      color: SpotifyColors.textSecondary,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}
