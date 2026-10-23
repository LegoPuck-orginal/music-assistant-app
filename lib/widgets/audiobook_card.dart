import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/audiobook.dart';
import '../theme/spotify_colors.dart';

/// Next-Gen Studio Hörbuch & Hörspiel Karte (z. B. für Die drei ???)
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
        width: 158,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Art mit Episode Badge & Adobe-Orange Play Button
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SpotifyColors.orange.withValues(alpha: 0.28),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Container(
                        color: SpotifyColors.surfaceElevated,
                        child: Image.network(
                          audiobook.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            decoration: const BoxDecoration(
                              gradient: SpotifyColors.emberHeroGradient,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.auto_stories_rounded,
                                color: SpotifyColors.orange,
                                size: 42,
                              ),
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
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: SpotifyColors.orange.withValues(alpha: 0.8),
                        width: 0.9,
                      ),
                    ),
                    child: Text(
                      'FOLGE ${audiobook.episodeNumber}',
                      style: const TextStyle(
                        color: SpotifyColors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
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
                        gradient: SpotifyColors.emberGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: SpotifyColors.orange.withValues(alpha: 0.45),
                            blurRadius: 10,
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
              audiobook.series.toUpperCase(),
              maxLines: 1,
              style: const TextStyle(
                color: SpotifyColors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
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
                fontWeight: FontWeight.w800,
                height: 1.22,
              ),
            ),

            const SizedBox(height: 3),

            // Duration
            Text(
              audiobook.formattedDuration,
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
