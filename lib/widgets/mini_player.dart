import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'device_picker_sheet.dart';
import 'now_playing_sheet.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final track = prov.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final progress = prov.totalDuration.inSeconds > 0
        ? (prov.currentPosition.inSeconds / prov.totalDuration.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const NowPlayingSheet(),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 6),
              child: Row(
                children: [
                  // Album Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 40,
                      height: 40,
                      color: SpotifyColors.surfaceHighlight,
                      child: track.imageUrl != null
                          ? Image.network(
                              track.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.music_note,
                                color: SpotifyColors.textSecondary,
                                size: 20,
                              ),
                            )
                          : const Icon(
                              Icons.music_note,
                              color: SpotifyColors.textSecondary,
                              size: 20,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Song & Artist Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Speaker / Device Icon
                  IconButton(
                    icon: Icon(
                      Icons.devices,
                      size: 20,
                      color: prov.activePlayer != null
                          ? SpotifyColors.green
                          : SpotifyColors.textMuted,
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const DevicePickerSheet(),
                      );
                    },
                  ),

                  // Heart / Like Button
                  IconButton(
                    icon: Icon(
                      track.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: track.isLiked ? SpotifyColors.green : Colors.white,
                    ),
                    onPressed: () => prov.toggleLike(track),
                  ),

                  // Play/Pause Button
                  IconButton(
                    icon: Icon(
                      prov.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 28,
                      color: Colors.white,
                    ),
                    onPressed: () => prov.togglePlayPause(),
                  ),
                ],
              ),
            ),

            // Progress Line
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: SpotifyColors.surfaceHighlight,
                valueColor: const AlwaysStoppedAnimation<Color>(SpotifyColors.green),
                minHeight: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
