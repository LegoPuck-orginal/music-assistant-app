import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/track_tile.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _isLiked = false;
  bool _isLoadingTracks = false;
  String _sortMode = 'default'; // 'default', 'title', 'artist', 'album', 'duration'
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();

  String get _sortLabel {
    switch (_sortMode) {
      case 'title':
        return 'Titel (A–Z)';
      case 'artist':
        return 'Künstler (A–Z)';
      case 'album':
        return 'Album (A–Z)';
      case 'duration':
        return 'Längste zuerst';
      default:
        return 'Kürzlich hinzugefügt';
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.playlist.tracks.isEmpty) {
      _isLoadingTracks = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final prov = context.read<MusicProvider>();
        await prov.loadPlaylistTracks(widget.playlist);
        if (mounted) {
          setState(() {
            _isLoadingTracks = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final tracks = widget.playlist.id == 'liked_songs'
        ? prov.likedTracks
        : widget.playlist.tracks;

    var displayTracks = List<Track>.from(tracks);
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayTracks = displayTracks
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q) ||
              t.album.toLowerCase().contains(q))
          .toList();
    }

    if (_sortMode == 'title') {
      displayTracks.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sortMode == 'artist') {
      displayTracks.sort(
          (a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
    } else if (_sortMode == 'album') {
      displayTracks.sort(
          (a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()));
    } else if (_sortMode == 'duration') {
      displayTracks
          .sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    }

    final allDownloaded = displayTracks.isNotEmpty &&
        displayTracks.every((t) => prov.isTrackDownloaded(t.id));
    final anyDownloading =
        displayTracks.any((t) => prov.isTrackDownloading(t.id));

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: CustomScrollView(
        slivers: [
          // Collapsible App Bar with Album Art
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: SpotifyColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                tooltip: 'Optionen',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showPlaylistOptions(context);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF383838),
                      SpotifyColors.pureBlack,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // Album Cover Art
                      Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: widget.playlist.imageUrl != null
                              ? Image.network(
                                  widget.playlist.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    widget.playlist.type == 'podcast'
                                        ? Icons.podcasts
                                        : widget.playlist.type == 'artist'
                                            ? Icons.person
                                            : Icons.album,
                                    size: 80,
                                    color: SpotifyColors.textSecondary,
                                  ),
                                )
                              : Icon(
                                  widget.playlist.type == 'podcast'
                                      ? Icons.podcasts
                                      : widget.playlist.type == 'artist'
                                          ? Icons.person
                                          : Icons.album,
                                  size: 80,
                                  color: SpotifyColors.textSecondary,
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.playlist.type == 'podcast'
                            ? '${widget.playlist.owner} • ${tracks.isNotEmpty ? tracks.length : widget.playlist.trackCount} Folgen'
                            : widget.playlist.type == 'artist'
                                ? 'Künstler • ${tracks.length} Titel'
                                : '${widget.playlist.owner} • ${tracks.length} Songs',
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Action Row (Shuffle, Like, Download, Big Green Play)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: prov.isShuffle
                          ? SpotifyColors.green
                          : SpotifyColors.textSecondary,
                      size: 26,
                    ),
                    tooltip: 'Zufallswiedergabe',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.toggleShuffle();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? SpotifyColors.green : SpotifyColors.textSecondary,
                      size: 24,
                    ),
                    tooltip: 'Zu Favoriten hinzufügen',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isLiked = !_isLiked;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isLiked
                              ? 'Playlist zu deinen Favoriten hinzugefügt'
                              : 'Playlist aus Favoriten entfernt'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: SpotifyColors.surfaceElevated,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: anyDownloading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SpotifyColors.green,
                            ),
                          )
                        : Icon(
                            allDownloaded
                                ? Icons.download_done
                                : Icons.download_for_offline_outlined,
                            color: allDownloaded
                                ? SpotifyColors.green
                                : SpotifyColors.textSecondary,
                            size: 24,
                          ),
                    tooltip: allDownloaded
                        ? 'Downloads verwalten / entfernen'
                        : 'Playlist herunterladen',
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      if (allDownloaded) {
                        for (final t in tracks) {
                          await prov.removeDownload(t.id);
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Offline-Downloads für Playlist entfernt'),
                              duration: Duration(seconds: 1),
                              backgroundColor: SpotifyColors.surfaceElevated,
                            ),
                          );
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Lade ${tracks.length} Titel für Offline-Wiedergabe herunter...'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: SpotifyColors.surfaceElevated,
                            ),
                          );
                        }
                        await prov.downloadPlaylist(widget.playlist);
                      }
                    },
                  ),
                  const Spacer(),
                  // Big Green Play Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (displayTracks.isNotEmpty) {
                        final playList = List.of(displayTracks);
                        if (prov.isShuffle && playList.length > 1) {
                          playList.shuffle();
                        }
                        prov.playTrack(playList.first, newQueue: playList);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Diese Auswahl enthält aktuell noch keine Titel.'),
                            backgroundColor: SpotifyColors.surfaceElevated,
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: SpotifyColors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Interaktive Suchleiste innerhalb der Playlist
          if (_isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: SpotifyColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SpotifyColors.green.withValues(alpha: 0.35),
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search,
                          color: SpotifyColors.green, size: 18),
                      hintText: 'In dieser Playlist suchen...',
                      hintStyle: TextStyle(
                          color: SpotifyColors.textMuted, fontSize: 12.5),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ),

          // Sortier- & Filter-Leiste
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
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
                          const Icon(Icons.swap_vert_rounded,
                              color: SpotifyColors.green, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _sortLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
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
                      _isSearching ? Icons.close : Icons.search,
                      color: SpotifyColors.textSecondary,
                      size: 20,
                    ),
                    tooltip: 'In Playlist suchen',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchCtrl.clear();
                          _searchQuery = '';
                        }
                      });
                    },
                  ),
                  Text(
                    '${displayTracks.length} Titel',
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator or Empty State or Track List
          if (_isLoadingTracks)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: SpotifyColors.green,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          else if (displayTracks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.music_off,
                          size: 48, color: SpotifyColors.textMuted),
                      SizedBox(height: 12),
                      Text(
                        'Keine Titel gefunden',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = displayTracks[index];
                  return TrackTile(
                    track: track,
                    index: index + 1,
                    showImage: true,
                    onTap: () {
                      prov.playTrack(track, newQueue: displayTracks);
                    },
                  );
                },
                childCount: displayTracks.length,
              ),
            ),

          // Padding at bottom so sticky mini player does not cover content
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  void _showPlaylistOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_play_next, color: Colors.white),
              title: const Text('Als Nächstes abspielen',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final prov = context.read<MusicProvider>();
                await prov.enqueueTracks(widget.playlist.tracks,
                    playNext: true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${widget.playlist.tracks.length} Songs werden als Nächstes abgespielt'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue, color: Colors.white),
              title: const Text('An Warteschlange anhängen',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final prov = context.read<MusicProvider>();
                await prov.enqueueTracks(widget.playlist.tracks,
                    playNext: false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${widget.playlist.tracks.length} Songs an die Warteschlange angehängt'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Playlist teilen',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        '${widget.playlist.name} (${widget.playlist.owner}) – ${widget.playlist.tracks.length} Songs',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '„${widget.playlist.name}“ in die Zwischenablage kopiert!'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                'Sortieren nach',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _buildSortOption('default', 'Kürzlich hinzugefügt (Standard)'),
            _buildSortOption('title', 'Titel (A–Z)'),
            _buildSortOption('artist', 'Künstler (A–Z)'),
            _buildSortOption('album', 'Album (A–Z)'),
            _buildSortOption('duration', 'Dauer (Längste zuerst)'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String mode, String label) {
    final isSelected = _sortMode == mode;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? SpotifyColors.green : Colors.white,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: SpotifyColors.green, size: 20)
          : null,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _sortMode = mode;
        });
        Navigator.pop(context);
      },
    );
  }
}
