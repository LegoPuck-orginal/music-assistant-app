import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
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
  bool _isDownloaded = false;
  bool _isLoadingTracks = false;

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
    final tracks = widget.playlist.tracks;

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
                                      const Icon(
                                    Icons.album,
                                    size: 80,
                                    color: SpotifyColors.textSecondary,
                                  ),
                                )
                              : const Icon(
                                  Icons.album,
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
                        '${widget.playlist.owner} • ${tracks.length} Songs',
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
                    icon: Icon(
                      _isDownloaded
                          ? Icons.download_done
                          : Icons.download_for_offline_outlined,
                      color: _isDownloaded
                          ? SpotifyColors.green
                          : SpotifyColors.textSecondary,
                      size: 24,
                    ),
                    tooltip: 'Herunterladen',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isDownloaded = !_isDownloaded;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_isDownloaded
                              ? 'Playlist offline verfügbar gemacht'
                              : 'Offline-Download entfernt'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: SpotifyColors.surfaceElevated,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  // Big Green Play Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      if (tracks.isNotEmpty) {
                        prov.playTrack(tracks.first, newQueue: tracks);
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
          else if (tracks.isEmpty)
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
                        'Keine Titel in dieser Auswahl',
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
                  final track = tracks[index];
                  return TrackTile(
                    track: track,
                    index: index + 1,
                    showImage: true,
                    onTap: () {
                      prov.playTrack(track, newQueue: tracks);
                    },
                  );
                },
                childCount: tracks.length,
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
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Playlist teilen',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Playlist-Link in die Zwischenablage kopiert!'),
                    backgroundColor: SpotifyColors.surfaceElevated,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: Colors.white),
              title: const Text('An Warteschlange anhängen',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                final prov = context.read<MusicProvider>();
                prov.queue.addAll(widget.playlist.tracks);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${widget.playlist.tracks.length} Songs an die Warteschlange angehängt'),
                    backgroundColor: SpotifyColors.surfaceElevated,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
