import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/track_tile.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final tracks = playlist.tracks;

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
                onPressed: () {},
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
                          child: playlist.imageUrl != null
                              ? Image.network(
                                  playlist.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
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
                        playlist.name,
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
                        '${playlist.owner} • ${tracks.length} Songs',
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

          // Action Row (Shuffle, Play Big Button)
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
                    onPressed: () => prov.toggleShuffle(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border,
                        color: SpotifyColors.textSecondary, size: 24),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_for_offline_outlined,
                        color: SpotifyColors.textSecondary, size: 24),
                    onPressed: () {},
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

          // Track List
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
}
