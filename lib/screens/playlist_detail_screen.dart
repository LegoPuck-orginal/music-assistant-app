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
    final allDownloaded = tracks.isNotEmpty && tracks.every((t) => prov.isTrackDownloaded(t.id));
    final anyDownloading = tracks.any((t) => prov.isTrackDownloading(t.id));

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
                      if (tracks.isNotEmpty) {
                        final playList = List.of(tracks);
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
}
