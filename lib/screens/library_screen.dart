import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isGridView = false;
  bool _isSearching = false;
  final TextEditingController _librarySearchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _librarySearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final allPlaylists = prov.playlists;

    // Filter by category
    var filteredPlaylists = _selectedFilter == 'Playlists'
        ? allPlaylists.where((p) => p.type == 'playlist').toList()
        : _selectedFilter == 'Alben'
            ? allPlaylists.where((p) => p.type == 'album').toList()
            : _selectedFilter == 'Künstler'
                ? allPlaylists.where((p) => p.type == 'artist').toList()
                : allPlaylists.where((p) => p.type == 'podcast').toList();

    // Filter by search query if active
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredPlaylists = filteredPlaylists
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.owner.toLowerCase().contains(q))
          .toList();
    }

    // Collect all liked tracks across library
    final likedTracks = <Track>[];
    for (final p in allPlaylists) {
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
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () => _showProfileDialog(context),
                    child: const CircleAvatar(
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
                  ),
                  const SizedBox(width: 12),
                  const Text(
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
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: Colors.white,
                  ),
                  tooltip: 'Bibliothek durchsuchen',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _librarySearchCtrl.clear();
                        _searchQuery = '';
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: 'Playlist erstellen',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showCreatePlaylistDialog(context, prov);
                  },
                ),
              ],
            ),

            // In-Library Search Field (if searching)
            if (_isSearching)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _librarySearchCtrl,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search,
                            color: SpotifyColors.textSecondary, size: 20),
                        hintText: 'In deiner Bibliothek suchen...',
                        hintStyle: TextStyle(
                            color: SpotifyColors.textMuted, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
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

            // Sorting & Layout Toggle
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
                      icon: Icon(
                        _isGridView ? Icons.view_list : Icons.grid_view,
                        color: SpotifyColors.textSecondary,
                        size: 20,
                      ),
                      tooltip: _isGridView
                          ? 'Als Liste anzeigen'
                          : 'Als Raster anzeigen',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Pinned Item: Lieblingssongs
            if (_searchQuery.isEmpty)
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

            // View: List or Grid
            if (_isGridView)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final p = filteredPlaylists[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: p),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  color: SpotifyColors.surfaceElevated,
                                  child: p.imageUrl != null
                                      ? Image.network(p.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Icon(Icons.album,
                                                  color: SpotifyColors
                                                      .textSecondary,
                                                  size: 36))
                                      : const Icon(Icons.album,
                                          color: SpotifyColors.textSecondary,
                                          size: 36),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              p.owner,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: filteredPlaylists.length,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final p = filteredPlaylists[index];
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
                                        errorBuilder: (context, error,
                                                stackTrace) =>
                                            const Icon(
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
                  childCount: filteredPlaylists.length,
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
        HapticFeedback.lightImpact();
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

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpotifyColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: SpotifyColors.green,
              child: Text('T',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            SizedBox(width: 12),
            Text('Tim Marquardt', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rolle: Administrator',
                style: TextStyle(color: SpotifyColors.textSecondary)),
            SizedBox(height: 4),
            Text('Server: Music Assistant 2.10',
                style: TextStyle(color: SpotifyColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Schließen',
                style: TextStyle(color: SpotifyColors.green)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, MusicProvider prov) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpotifyColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Neue Playlist erstellen',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Name der Playlist',
            hintStyle: TextStyle(color: SpotifyColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Abbrechen',
                style: TextStyle(color: SpotifyColors.textSecondary)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotifyColors.green,
              foregroundColor: Colors.black,
            ),
            child: const Text('Erstellen'),
            onPressed: () {
              final name = textCtrl.text.trim();
              if (name.isNotEmpty) {
                final newPlaylist = Playlist(
                  id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  owner: 'Tim Marquardt',
                  trackCount: 0,
                  tracks: [],
                );
                prov.playlists.insert(0, newPlaylist);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Playlist "$name" erstellt!'),
                    backgroundColor: SpotifyColors.surfaceElevated,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
