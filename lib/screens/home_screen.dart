import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/album_card.dart';
import 'playlist_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'Alle';

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Guten Morgen';
    if (hour < 18) return 'Guten Tag';
    return 'Guten Abend';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final allPlaylists = prov.playlists;

    final filteredPlaylists = _selectedFilter == 'Alle'
        ? allPlaylists
        : _selectedFilter == 'Musik'
            ? allPlaylists.where((p) => p.type != 'podcast').toList()
            : allPlaylists.where((p) => p.type == 'podcast').toList();

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
                icon: const Icon(Icons.campaign_outlined, color: Colors.white),
                tooltip: 'Durchsage an Lautsprecher',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAnnouncementDialog(context, prov);
                },
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                tooltip: 'Mitteilungen',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showNotificationsSheet(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: 'Zuletzt gehört',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showHistorySheet(context, prov);
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'Einstellungen',
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
                  _buildChip('Alle'),
                  const SizedBox(width: 8),
                  _buildChip('Musik'),
                  const SizedBox(width: 8),
                  _buildChip('Podcasts'),
                ],
              ),
            ),
          ),

          if (filteredPlaylists.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        _selectedFilter == 'Podcasts'
                            ? Icons.podcasts
                            : Icons.music_off,
                        size: 52,
                        color: SpotifyColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Keine ${_selectedFilter == 'Podcasts' ? 'Podcasts' : 'Inhalte'} gefunden',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Füge in Music Assistant neue ${_selectedFilter == 'Podcasts' ? 'Podcasts' : 'Musik'} hinzu.',
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
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
                  itemCount: filteredPlaylists.take(6).length,
                  itemBuilder: (context, index) {
                    final p = filteredPlaylists[index];
                    return _buildQuickTile(context, p, prov);
                  },
                ),
              ),
            ),

            // Section 1
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
                _selectedFilter == 'Podcasts'
                    ? 'Deine Podcasts & Shows'
                    : 'Für dich zusammengestellt',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 215,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredPlaylists.length,
                  itemBuilder: (context, index) {
                    final p = filteredPlaylists[index];
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

            // Section 2
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
                _selectedFilter == 'Podcasts'
                    ? 'Alle Podcasts'
                    : 'Wieder reinhören',
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 215,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: filteredPlaylists.reversed.length,
                  itemBuilder: (context, index) {
                    final p = filteredPlaylists.reversed.toList()[index];
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
          ],

          // Space for bottom MiniPlayer
          const SliverToBoxAdapter(
            child: SizedBox(height: 110),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
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

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Neuigkeiten & Mitteilungen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: SpotifyColors.surfaceHighlight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: SpotifyColors.green, size: 20),
                  ),
                  title: const Text('Music Assistant 2.10 ist online',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Alle Lautsprecher im Homelab sind betriebsbereit.',
                      style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHistorySheet(BuildContext context, MusicProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Zuletzt gehört',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: prov.queue.take(8).length,
                  itemBuilder: (c, idx) {
                    final Track item = prov.queue[idx];
                    return ListTile(
                      leading: const Icon(Icons.music_note, color: SpotifyColors.green),
                      title: Text(item.title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(item.artist,
                          style: const TextStyle(color: SpotifyColors.textSecondary)),
                      onTap: () {
                        prov.playTrack(item);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAnnouncementDialog(BuildContext context, MusicProvider prov) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpotifyColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.campaign, color: SpotifyColors.green),
            SizedBox(width: 8),
            Text('Durchsage senden',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nachricht eingeben (TTS)...',
            hintStyle: const TextStyle(color: SpotifyColors.textSecondary),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen',
                style: TextStyle(color: SpotifyColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotifyColors.green,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final text = textCtrl.text.trim();
              if (text.isNotEmpty) {
                prov.sendAnnouncement(text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Durchsage wird abgespielt: "$text"'),
                    backgroundColor: SpotifyColors.surfaceElevated,
                  ),
                );
              }
            },
            child: const Text('Senden'),
          ),
        ],
      ),
    );
  }
}
