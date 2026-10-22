import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final int? index;
  final VoidCallback? onTap;
  final bool showImage;

  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.onTap,
    this.showImage = true,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final isCurrent = prov.currentTrack?.id == track.id;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          prov.playTrack(track);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Index number or current playing wave
            if (index != null && !showImage) ...[
              SizedBox(
                width: 28,
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: isCurrent ? SpotifyColors.green : SpotifyColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // Cover thumbnail if showImage
            if (showImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 48,
                  height: 48,
                  color: SpotifyColors.surfaceElevated,
                  child: track.imageUrl != null
                      ? Image.network(
                          track.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.music_note,
                            color: SpotifyColors.textSecondary,
                            size: 22,
                          ),
                        )
                      : const Icon(
                          Icons.music_note,
                          color: SpotifyColors.textSecondary,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 14),
            ],

            // Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? SpotifyColors.green : Colors.white,
                      fontSize: 15,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Heart / Like
            IconButton(
              icon: Icon(
                track.isLiked ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: track.isLiked ? SpotifyColors.green : SpotifyColors.textSecondary,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                prov.toggleLike(track);
              },
            ),

            // More Options
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: SpotifyColors.textSecondary,
              ),
              onPressed: () {
                _showTrackOptions(context, track, prov);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track, MusicProvider prov) {
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
            children: [
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: SpotifyColors.surfaceElevated,
                    child: track.imageUrl != null
                        ? Image.network(track.imageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.music_note, color: Colors.white),
                  ),
                ),
                title: Text(track.title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(track.artist,
                    style: const TextStyle(color: SpotifyColors.textSecondary)),
              ),
              const Divider(color: SpotifyColors.borderSubtle),
              ListTile(
                leading: Icon(
                  track.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: track.isLiked ? SpotifyColors.green : Colors.white,
                ),
                title: Text(
                  track.isLiked
                      ? 'Aus Lieblingssongs entfernen'
                      : 'Zu Lieblingssongs hinzufügen',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  prov.toggleLike(track);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Zu Playlist hinzufügen',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"${track.title}" zu Playlist hinzugefügt'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.radio, color: Colors.white),
                title: const Text('Song-Radio starten',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  prov.playTrack(track);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Song-Radio für "${track.title}" gestartet'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Teilen',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Link für "${track.title}" kopiert!'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
