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
    this.size = 152,
  });

  String get _badgeLabel {
    switch (playlist.type) {
      case 'podcast':
        return 'PODCAST';
      case 'album':
        return 'ALBUM';
      case 'artist':
        return 'ARTIST';
      default:
        return 'PLAYLIST';
    }
  }

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
            // Studio Cover Art mit Obsidian-Rahmen & Play-Emblem
            Stack(
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: SpotifyColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: playlist.imageUrl != null
                        ? Image.network(
                            playlist.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _fallbackIcon(),
                          )
                        : _fallbackIcon(),
                  ),
                ),

                // Typ-Badge oben links
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      _badgeLabel,
                      style: const TextStyle(
                        color: SpotifyColors.orangeLight,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ),

                // Dezenter Studio-Play-Button unten rechts
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: SpotifyColors.orange.withValues(alpha: 0.7),
                        width: 1.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: SpotifyColors.orange,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),

            // Titel
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),

            // Untertitel
            Text(
              playlist.owner.isNotEmpty
                  ? playlist.owner
                  : '${playlist.trackCount} Titel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      decoration: const BoxDecoration(
        gradient: SpotifyColors.obsidianCardGradient,
      ),
      child: Center(
        child: Icon(
          playlist.type == 'podcast'
              ? Icons.podcasts_rounded
              : playlist.type == 'artist'
                  ? Icons.person_rounded
                  : Icons.album_rounded,
          color: SpotifyColors.orange.withValues(alpha: 0.65),
          size: 46,
        ),
      ),
    );
  }
}
