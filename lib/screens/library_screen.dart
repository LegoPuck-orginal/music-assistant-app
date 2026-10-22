import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'Playlists';

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final playlists = prov.playlists;

    // Collect all liked tracks across library
    final likedTracks = <Track>[];
    for (final p in playlists) {
      for (final t in p.tracks) {
        if (t.isLiked && !likedTracks.any((x) => x.id == t.id)) {
          likedTracks.add(t);
        }
      }
    }

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top Bar
            SliverAppBar(
              floating: true,
              backgroundColor: SpotifyColors.pureBlack,
              elevation: 0,
              title: const Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF535353),
                    child: Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Deine Bibliothek',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),

            // Filter Chips
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _filterChip('Playlists'),
                    const SizedBox(width: 8),
                    _filterChip('Podcasts'),
                    const SizedBox(width: 8),
                    _filterChip('Künstler'),
                    const SizedBox(width: 8),
                    _filterChip('Alben'),
                  ],
                ),
              ),
            ),

            // Sorting row ("Kürzlich")
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.swap_vert,
                        color: SpotifyColors.textSecondary, size: 18),
                    const SizedBox(width: 6),
                    const Text(
                      'Kürzlich hinzugefügt',
                      style: TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.grid_view,
                          color: SpotifyColors.textSecondary, size: 18),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),

            // Pinned Item: Lieblingssongs
            SliverToBoxAdapter(
              child: InkWell(
                onTap: () {
                  final likedPlaylist = Playlist(
                    id: 'liked_songs',
                    name: 'Lieblingssongs',
                    owner: 'Music Assistant',
                    trackCount: likedTracks.length,
                    tracks: likedTracks,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PlaylistDetailScreen(playlist: likedPlaylist),
                    ),
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF450AF5),
                              Color(0xFF8E8EE5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lieblingssongs',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.push_pin,
                                    size: 13, color: SpotifyColors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'Playlist • ${likedTracks.length} Songs',
                                  style: const TextStyle(
                                    color: SpotifyColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // List of Playlists / Albums
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final p = playlists[index];
                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaylistDetailScreen(playlist: p),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 64,
                              height: 64,
                              color: SpotifyColors.surfaceElevated,
                              child: p.imageUrl != null
                                  ? Image.network(
                                      p.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.album,
                                        color: SpotifyColors.textSecondary,
                                        size: 32,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.album,
                                      color: SpotifyColors.textSecondary,
                                      size: 32,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${p.type == "album" ? "Album" : "Playlist"} • ${p.owner}',
                                  style: const TextStyle(
                                    color: SpotifyColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: playlists.length,
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String title) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              isSelected ? SpotifyColors.green : SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
