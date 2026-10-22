import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'device_picker_sheet.dart';
import 'equalizer_sheet.dart';

class NowPlayingSheet extends StatelessWidget {
  const NowPlayingSheet({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final track = prov.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final posSeconds = prov.currentPosition.inSeconds.toDouble();
    final totalSeconds = prov.totalDuration.inSeconds > 0
        ? prov.totalDuration.inSeconds.toDouble()
        : 1.0;
    final sliderVal = posSeconds.clamp(0.0, totalSeconds);

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF282828),
            SpotifyColors.pureBlack,
            SpotifyColors.pureBlack,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Top Bar: Dismiss chevron, Context title, Options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Column(
                    children: [
                      const Text(
                        'WIEDERGABE AUS',
                        style: TextStyle(
                          color: SpotifyColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        track.album.isNotEmpty ? track.album : 'Music Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white, size: 22),
                    onPressed: () {},
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Large Album Art
              Hero(
                tag: 'now-playing-art',
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SpotifyColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: track.imageUrl != null
                            ? Image.network(
                                track.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.music_note,
                                  color: SpotifyColors.textSecondary,
                                  size: 100,
                                ),
                              )
                            : const Icon(
                                Icons.music_note,
                                color: SpotifyColors.textSecondary,
                                size: 100,
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 1),

              // Title, Artist & Like Heart
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
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
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      track.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: track.isLiked ? SpotifyColors.green : Colors.white,
                      size: 28,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.toggleLike(track);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Scrubber / Progress Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: SpotifyColors.sliderInactive,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  trackHeight: 3.5,
                ),
                child: Slider(
                  value: sliderVal,
                  min: 0,
                  max: totalSeconds,
                  onChanged: (val) {
                    prov.seekTo(Duration(seconds: val.toInt()));
                  },
                ),
              ),

              // Duration labels (0:00 / -3:20)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(prov.currentPosition),
                      style: const TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(prov.totalDuration),
                      style: const TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Controls: Shuffle, Prev, Play/Pause, Next, Repeat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      size: 24,
                      color: prov.isShuffle
                          ? SpotifyColors.green
                          : SpotifyColors.textSecondary,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.toggleShuffle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_previous,
                      size: 38,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.previous();
                    },
                  ),
                  // Big Circular Play/Pause
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      prov.togglePlayPause();
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        prov.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black,
                        size: 36,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.skip_next,
                      size: 38,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.next();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      prov.repeatMode == 2
                          ? Icons.repeat_one
                          : Icons.repeat,
                      size: 24,
                      color: prov.repeatMode > 0
                          ? SpotifyColors.green
                          : SpotifyColors.textSecondary,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.cycleRepeat();
                    },
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Bottom Row: Device selector on left, Queue on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const DevicePickerSheet(),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.devices,
                          color: SpotifyColors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          prov.activePlayer?.name ?? 'Wiedergabegerät wählen',
                          style: const TextStyle(
                            color: SpotifyColors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: prov.equalizerSettings.isEnabled
                              ? SpotifyColors.green
                              : SpotifyColors.textSecondary,
                          size: 21,
                        ),
                        tooltip: 'Equalizer',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const EqualizerSheet(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined,
                            color: SpotifyColors.textSecondary, size: 20),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.queue_music,
                            color: SpotifyColors.textSecondary, size: 22),
                        onPressed: () {
                          _showQueueModal(context, prov);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueueModal(BuildContext context, MusicProvider prov) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Warteschlange',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: prov.queue.length,
                  itemBuilder: (c, idx) {
                    final item = prov.queue[idx];
                    final isNow = item.id == prov.currentTrack?.id;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isNow ? Icons.equalizer : Icons.music_note,
                        color: isNow ? SpotifyColors.green : SpotifyColors.textMuted,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          color: isNow ? SpotifyColors.green : Colors.white,
                          fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        item.artist,
                        style: const TextStyle(color: SpotifyColors.textSecondary),
                      ),
                      trailing: Text(
                        item.formattedDuration,
                        style: const TextStyle(color: SpotifyColors.textMuted, fontSize: 12),
                      ),
                      onTap: () {
                        prov.playTrack(item);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
