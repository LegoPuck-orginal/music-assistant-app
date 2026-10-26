import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_edit_dialog.dart';
import '../widgets/track_tile.dart';
import 'playlist_detail_screen.dart';
import 'virtual_dj_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _selectedFilter = 'Alle';
  String _sortMode = 'recent'; // 'recent', 'alpha', 'artist', 'tracks'
  bool _isGridView = false;
  bool _isSearching = false;
  final TextEditingController _librarySearchCtrl = TextEditingController();
  String _searchQuery = '';

  String get _sortLabel {
    switch (_sortMode) {
      case 'alpha':
        return 'Alphabetisch (A–Z)';
      case 'artist':
        return 'Künstler (A–Z)';
      case 'tracks':
        return 'Meiste Titel';
      default:
        return 'Kürzlich hinzugefügt';
    }
  }

  @override
  void dispose() {
    _librarySearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final allPlaylists = prov.playlists;
    final likedTracks = prov.likedTracks;

    var filteredLikedTracks = List.of(likedTracks);
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredLikedTracks = filteredLikedTracks
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q) ||
              t.album.toLowerCase().contains(q))
          .toList();
    }
    if (_sortMode == 'alpha') {
      filteredLikedTracks.sort((a, b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sortMode == 'artist') {
      filteredLikedTracks.sort((a, b) =>
          a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    } else if (_sortMode == 'tracks') {
      filteredLikedTracks
          .sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    }

    // Filter by category
    var filteredPlaylists = <Playlist>[];
    if (_selectedFilter == 'Alle') {
      filteredPlaylists = List.of(allPlaylists);
    } else if (_selectedFilter == 'Playlists') {
      filteredPlaylists = allPlaylists.where((p) => p.type == 'playlist').toList();
    } else if (_selectedFilter == 'Alben') {
      filteredPlaylists = allPlaylists.where((p) => p.type == 'album').toList();
    } else if (_selectedFilter == 'Künstler') {
      filteredPlaylists = allPlaylists.where((p) => p.type == 'artist').toList();
    } else if (_selectedFilter == 'Podcasts') {
      filteredPlaylists = allPlaylists.where((p) => p.type == 'podcast').toList();
    }

    // Filter by search query if active
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredPlaylists = filteredPlaylists
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.owner.toLowerCase().contains(q))
          .toList();
    }

    // Apply interactive sorting
    if (_sortMode == 'alpha') {
      filteredPlaylists.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } else if (_sortMode == 'artist') {
      filteredPlaylists.sort(
        (a, b) => a.owner.toLowerCase().compareTo(b.owner.toLowerCase()),
      );
    } else if (_sortMode == 'tracks') {
      filteredPlaylists.sort((a, b) => b.trackCount.compareTo(a.trackCount));
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
                    onTap: () => ProfileEditDialog.show(context),
                    child: ProfileAvatar(user: prov.currentUser, radius: 17),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Deine Bibliothek',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                // Dezent platzierter KI-DJ
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded,
                      color: SpotifyColors.orangeLight, size: 21),
                  tooltip: 'KI-DJ Studio',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const VirtualDjScreen()),
                    );
                  },
                ),
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
                    _filterChip('Alle'),
                    const SizedBox(width: 8),
                    _filterChip('Playlists'),
                    const SizedBox(width: 8),
                    _filterChip('Lieblingssongs'),
                    const SizedBox(width: 8),
                    _filterChip('Alben'),
                    const SizedBox(width: 8),
                    _filterChip('Künstler'),
                    const SizedBox(width: 8),
                    _filterChip('Podcasts'),
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
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showSortSheet(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.swap_vert,
                                color: SpotifyColors.green, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              _sortLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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

            // Pinned Item: Lieblingssongs im Adobe-Ember Studio Vault Design
            if (_searchQuery.isEmpty && _selectedFilter != 'Lieblingssongs')
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
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
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: SpotifyColors.emberHeroGradient,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SpotifyColors.orange.withValues(alpha: 0.48),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                SpotifyColors.orange.withValues(alpha: 0.14),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: SpotifyColors.emberGradient,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: SpotifyColors.orange
                                      .withValues(alpha: 0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: Colors.black,
                              size: 28,
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
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.push_pin_rounded,
                                        size: 13, color: SpotifyColors.orange),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Angepinnte Favoriten • ${likedTracks.length} Songs',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: SpotifyColors.textSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (likedTracks.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.play_circle_fill_rounded,
                                color: SpotifyColors.orange,
                                size: 34,
                              ),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                prov.playTrack(likedTracks.first,
                                    newQueue: likedTracks);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Content: Lieblingssongs direkt als Trackliste anzeigen wenn Filter aktiv
            if (_selectedFilter == 'Lieblingssongs')
              if (filteredLikedTracks.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                    child: Center(
                      child: Text(
                        'Keine Lieblingssongs vorhanden.\nMarkiere Titel mit dem Herz-Symbol, um sie hier zu sammeln.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = filteredLikedTracks[index];
                      return TrackTile(
                        track: track,
                        index: index + 1,
                        showImage: true,
                        onTap: () {
                          prov.playTrack(track, newQueue: filteredLikedTracks);
                        },
                      );
                    },
                    childCount: filteredLikedTracks.length,
                  ),
                )
            else if (filteredPlaylists.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Keine Ergebnisse für „$_searchQuery“'
                          : 'Keine Einträge in dieser Kategorie.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              )
            // View: List or Grid for Playlists / Alben / Künstler
            else if (_isGridView)
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

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'Sortieren nach',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(color: SpotifyColors.borderSubtle),
            ListTile(
              title: Text(
                'Kürzlich hinzugefügt',
                style: TextStyle(
                  color: _sortMode == 'recent'
                      ? SpotifyColors.green
                      : Colors.white,
                  fontWeight: _sortMode == 'recent'
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
              trailing: _sortMode == 'recent'
                  ? const Icon(Icons.check, color: SpotifyColors.green)
                  : null,
              onTap: () {
                setState(() => _sortMode = 'recent');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(
                'Alphabetisch (A–Z)',
                style: TextStyle(
                  color:
                      _sortMode == 'alpha' ? SpotifyColors.green : Colors.white,
                  fontWeight: _sortMode == 'alpha'
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
              trailing: _sortMode == 'alpha'
                  ? const Icon(Icons.check, color: SpotifyColors.green)
                  : null,
              onTap: () {
                setState(() => _sortMode = 'alpha');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(
                'Künstler (A–Z)',
                style: TextStyle(
                  color: _sortMode == 'artist'
                      ? SpotifyColors.green
                      : Colors.white,
                  fontWeight: _sortMode == 'artist'
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
              trailing: _sortMode == 'artist'
                  ? const Icon(Icons.check, color: SpotifyColors.green)
                  : null,
              onTap: () {
                setState(() => _sortMode = 'artist');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(
                'Meiste Titel',
                style: TextStyle(
                  color: _sortMode == 'tracks'
                      ? SpotifyColors.green
                      : Colors.white,
                  fontWeight: _sortMode == 'tracks'
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
              trailing: _sortMode == 'tracks'
                  ? const Icon(Icons.check, color: SpotifyColors.green)
                  : null,
              onTap: () {
                setState(() => _sortMode = 'tracks');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
            child: const Text('Erstellen',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () async {
              final name = textCtrl.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await prov.createPlaylist(name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playlist „$name“ erstellt!'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
