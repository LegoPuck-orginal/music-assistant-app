import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'device_picker_sheet.dart';
import 'lyrics_sheet.dart';
import 'now_playing_sheet.dart';

/// Schwebende Obsidian & Adobe-Orange Studio-Kapsel (Next-Gen MiniPlayer)
/// mit Direktzugriff auf Buchstabe-für-Buchstabe-Lyrics, Multiroom & Laser-Progress.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final track = prov.currentTrack;

    if (track == null) return const SizedBox.shrink();

    final progress = prov.totalDuration.inMilliseconds > 0
        ? (prov.currentPosition.inMilliseconds /
                prov.totalDuration.inMilliseconds)
            .clamp(0.0, 1.0)
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
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1C120D),
              Color(0xFF111117),
              Color(0xFF0C0C10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: prov.isPlaying
                ? SpotifyColors.orange.withValues(alpha: 0.5)
                : SpotifyColors.borderHighlight,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.78),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            if (prov.isPlaying)
              BoxShadow(
                color: SpotifyColors.orange.withValues(alpha: 0.16),
                blurRadius: 18,
                spreadRadius: 0.5,
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
              child: Row(
                children: [
                  // Studio Cover mit leuchtendem Rahmen
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: prov.isPlaying
                            ? SpotifyColors.orange.withValues(alpha: 0.7)
                            : Colors.white12,
                        width: 1.1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9.5),
                      child: Container(
                        color: SpotifyColors.surfaceHighlight,
                        child: track.imageUrl != null
                            ? Image.network(
                                track.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.music_note_rounded,
                                  color: SpotifyColors.orange,
                                  size: 20,
                                ),
                              )
                            : const Icon(
                                Icons.music_note_rounded,
                                color: SpotifyColors.orange,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),

                  // Song, aktiver Lautsprecher & Künstler
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
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (prov.activePlayer != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: SpotifyColors.orange
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: SpotifyColors.orange
                                        .withValues(alpha: 0.45),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      prov.activePlayer!.isLocal
                                          ? Icons.smartphone_rounded
                                          : Icons.speaker_rounded,
                                      size: 10,
                                      color: SpotifyColors.orange,
                                    ),
                                    const SizedBox(width: 3),
                                    ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 82),
                                      child: Text(
                                        prov.activePlayer!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: SpotifyColors.orange,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 1-Tap Direkt-Button für Buchstabe-für-Buchstabe Lyrics!
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Live-Lyrics (Buchstabe für Buchstabe)',
                    icon: const Icon(
                      Icons.lyrics_outlined,
                      size: 19,
                      color: SpotifyColors.orange,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      LyricsSheet.show(context, track);
                    },
                  ),

                  // Multiroom / Device Picker
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Lautsprecher wählen',
                    icon: Icon(
                      Icons.speaker_group_outlined,
                      size: 19,
                      color: prov.activePlayer != null
                          ? Colors.white
                          : SpotifyColors.textMuted,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const DevicePickerSheet(),
                      );
                    },
                  ),

                  // Favorit / Herz
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      track.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 19,
                      color: track.isLiked
                          ? SpotifyColors.orange
                          : Colors.white70,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.toggleLike(track);
                    },
                  ),

                  const SizedBox(width: 2),

                  // Leuchtender Adobe-Orange Play/Pause Kreis-Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      prov.togglePlayPause();
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
                          ),
                        ],
                      ),
                      child: Icon(
                        prov.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 22,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Laser-Progress-Linie am unteren Kapselrand
            SizedBox(
              height: 2.8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(SpotifyColors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
