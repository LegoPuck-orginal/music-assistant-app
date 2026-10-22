import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../theme/spotify_colors.dart';

class AlbumCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final double size;

  const AlbumCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.size = 150,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square Cover Art
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: size,
                height: size,
                color: SpotifyColors.surfaceElevated,
                child: playlist.imageUrl != null
                    ? Image.network(
                        playlist.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            playlist.type == 'podcast'
                                ? Icons.podcasts
                                : playlist.type == 'artist'
                                    ? Icons.person
                                    : Icons.album,
                            color: SpotifyColors.textSecondary,
                            size: 48,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          playlist.type == 'podcast'
                              ? Icons.podcasts
                              : playlist.type == 'artist'
                                  ? Icons.person
                                  : Icons.album,
                          color: SpotifyColors.textSecondary,
                          size: 48,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),

            // Subtitle
            Text(
              playlist.owner.isNotEmpty
                  ? playlist.owner
                  : '${playlist.trackCount} Titel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
