import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/audiobook.dart';
import '../theme/spotify_colors.dart';

/// Spotify-Style Hörbuch & Hörspiel Karte (z.B. für Die drei ???)
class AudiobookCard extends StatelessWidget {
  final Audiobook audiobook;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const AudiobookCard({
    super.key,
    required this.audiobook,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 154,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Art mit Episode Badge & Play Button
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      color: SpotifyColors.surfaceElevated,
                      child: Image.network(
                        audiobook.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFF1E1E1E),
                          child: const Center(
                            child: Icon(
                              Icons.auto_stories,
                              color: SpotifyColors.green,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Episode Badge Oben Links
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: SpotifyColors.green.withValues(alpha: 0.7),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      'FOLGE ${audiobook.episodeNumber}',
                      style: const TextStyle(
                        color: SpotifyColors.green,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Quick Play Floating Action Button Unten Rechts
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onPlay();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: SpotifyColors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Series Name
            Text(
              audiobook.series,
              maxLines: 1,
              style: const TextStyle(
                color: SpotifyColors.green,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),

            const SizedBox(height: 2),

            // Episode Title
            Text(
              audiobook.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),

            const SizedBox(height: 4),

            // Duration
            Text(
              audiobook.formattedDuration,
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
