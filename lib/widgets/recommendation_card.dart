import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/recommendation.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

class RecommendationCard extends StatelessWidget {
  final RecommendationItem item;
  final List<RecommendationItem> contextItems;
  final VoidCallback? onTap;

  const RecommendationCard({
    super.key,
    required this.item,
    this.contextItems = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final isArtist = item.mediaType == 'artist';
    final isPlayingThis =
        prov.currentTrack?.title.toLowerCase() == item.name.toLowerCase() &&
            prov.isPlaying;

    if (isArtist) {
      return _buildArtistCard(context, prov);
    }

    return _buildStandardCard(context, prov, isPlayingThis);
  }

  Widget _buildStandardCard(
      BuildContext context, MusicProvider prov, bool isPlayingThis) {
    return Container(
      width: 148,
      margin: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onTap != null) {
            onTap!();
          } else {
            prov.playRecommendationItem(item, contextItems: contextItems);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Artwork mit Obsidian-Rahmen & Play-Emblem
            Stack(
              children: [
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    color: SpotifyColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPlayingThis
                          ? SpotifyColors.orange
                          : Colors.white.withValues(alpha: 0.09),
                      width: isPlayingThis ? 1.5 : 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isPlayingThis
                            ? SpotifyColors.orange.withValues(alpha: 0.25)
                            : Colors.black.withValues(alpha: 0.5),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallbackCover(),
                          )
                        : _fallbackCover(),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: SpotifyColors.emberGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: SpotifyColors.orange.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlayingThis
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlayingThis ? SpotifyColors.orange : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),

            // Subtitle / Artist
            Text(
              item.subtitle.isNotEmpty
                  ? item.subtitle
                  : (item.mediaType == 'album' ? 'Album' : 'Titel'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

  Widget _buildArtistCard(BuildContext context, MusicProvider prov) {
    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onTap != null) {
            onTap!();
          } else {
            prov.search(item.name);
          }
        },
        child: Column(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SpotifyColors.surfaceElevated,
                border: Border.all(
                  color: SpotifyColors.orange.withValues(alpha: 0.45),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SpotifyColors.orange.withValues(alpha: 0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackArtistIcon(),
                      )
                    : _fallbackArtistIcon(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'KÜNSTLER',
              style: TextStyle(
                color: SpotifyColors.orangeLight,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: SpotifyColors.obsidianCardGradient,
      ),
      child: Center(
        child: Icon(
          item.mediaType == 'album'
              ? Icons.album_rounded
              : Icons.music_note_rounded,
          color: SpotifyColors.orange.withValues(alpha: 0.6),
          size: 38,
        ),
      ),
    );
  }

  Widget _fallbackArtistIcon() {
    return Container(
      decoration: const BoxDecoration(
        gradient: SpotifyColors.obsidianCardGradient,
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: SpotifyColors.orange,
          size: 44,
        ),
      ),
    );
  }
}
