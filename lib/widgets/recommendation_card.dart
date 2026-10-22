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
    final isPlayingThis = prov.currentTrack?.title.toLowerCase() == item.name.toLowerCase() &&
        prov.isPlaying;

    if (isArtist) {
      return _buildArtistCard(context, prov);
    }

    return _buildStandardCard(context, prov, isPlayingThis);
  }

  Widget _buildStandardCard(
      BuildContext context, MusicProvider prov, bool isPlayingThis) {
    return Container(
      width: 145,
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
            // Artwork with Play overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 145,
                    height: 145,
                    color: SpotifyColors.surfaceElevated,
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallbackCover(),
                          )
                        : _fallbackCover(),
                  ),
                ),
                // Green Play FAB Overlay on bottom-right of the cover
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: SpotifyColors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isPlayingThis ? Icons.pause : Icons.play_arrow,
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
                color: isPlayingThis ? SpotifyColors.green : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
            // Search or play artist
            prov.search(item.name);
          }
        },
        child: Column(
          children: [
            // Circular Avatar
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SpotifyColors.surfaceElevated,
                border: Border.all(
                  color: SpotifyColors.green.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
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

            // Artist Name
            Text(
              item.name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),

            // Tag
            const Text(
              'Künstler',
              style: TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      color: SpotifyColors.surfaceHighlight,
      child: Center(
        child: Icon(
          item.mediaType == 'album' ? Icons.album : Icons.music_note,
          color: SpotifyColors.textMuted,
          size: 38,
        ),
      ),
    );
  }

  Widget _fallbackArtistIcon() {
    return Container(
      color: SpotifyColors.surfaceHighlight,
      child: const Center(
        child: Icon(
          Icons.person,
          color: SpotifyColors.textMuted,
          size: 44,
        ),
      ),
    );
  }
}
