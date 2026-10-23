import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'audio_waveform_scrubber.dart';
import 'device_picker_sheet.dart';
import 'equalizer_sheet.dart';
import 'lyrics_sheet.dart';
import 'track_tile.dart';

class NowPlayingSheet extends StatefulWidget {
  const NowPlayingSheet({super.key});

  @override
  State<NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<NowPlayingSheet> {
  double? _dragValue;
  bool _useWaveform = true;

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
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0.0, -0.35),
          radius: 1.15,
          colors: [
            Color(0xFF2B1206),
            Color(0xFF0E0908),
            SpotifyColors.pureBlack,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: SpotifyColors.orange.withValues(alpha: 0.25),
          width: 0.9,
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Top Bar: Dismiss chevron, Studio Context Badge, Options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: SpotifyColors.orange.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: SpotifyColors.orange.withValues(alpha: 0.45),
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          prov.losslessStreaming
                              ? 'STUDIO HI-RES • LIVE'
                              : 'STUDIO STREAM • LIVE',
                          style: const TextStyle(
                            color: SpotifyColors.orangeLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        track.album.isNotEmpty
                            ? track.album
                            : 'Music Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showTrackOptions(context, track, prov);
                    },
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Large Studio Album Art with Ember Glow
              Hero(
                tag: 'now-playing-art',
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SpotifyColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: prov.isPlaying
                              ? SpotifyColors.orange.withValues(alpha: 0.5)
                              : Colors.white12,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.85),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                          if (prov.isPlaying)
                            BoxShadow(
                              color:
                                  SpotifyColors.orange.withValues(alpha: 0.22),
                              blurRadius: 36,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.5),
                        child: track.imageUrl != null
                            ? Image.network(
                                track.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.music_note_rounded,
                                  color: SpotifyColors.orange,
                                  size: 100,
                                ),
                              )
                            : const Icon(
                                Icons.music_note_rounded,
                                color: SpotifyColors.orange,
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
                      _useWaveform ? Icons.graphic_eq : Icons.linear_scale,
                      color: _useWaveform ? SpotifyColors.green : SpotifyColors.textSecondary,
                      size: 24,
                    ),
                    tooltip: _useWaveform
                        ? 'Audio Waveform aktiv (Tippen für Balken)'
                        : 'Balken aktiv (Tippen für Waveform)',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _useWaveform = !_useWaveform;
                      });
                    },
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

              // Scrubber: Audio Waveform oder Klassischer Progress Slider
              if (_useWaveform)
                AudioWaveformScrubber(
                  currentPosition: prov.currentPosition,
                  totalDuration: prov.totalDuration,
                  isPlaying: prov.isPlaying,
                  trackKey: '${track.id}_${track.title}',
                  onSeek: (pos) {
                    prov.seekTo(pos);
                  },
                )
              else ...[
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
                    value: (_dragValue ?? sliderVal).clamp(0.0, totalSeconds),
                    min: 0,
                    max: totalSeconds,
                    onChanged: (val) {
                      setState(() {
                        _dragValue = val;
                      });
                    },
                    onChangeEnd: (val) {
                      prov.seekTo(Duration(seconds: val.toInt()));
                      setState(() {
                        _dragValue = null;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_dragValue != null
                            ? Duration(seconds: _dragValue!.toInt())
                            : prov.currentPosition),
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
              ],

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
                  // Big Circular Studio Ember Play/Pause
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      prov.togglePlayPause();
                    },
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        gradient: SpotifyColors.emberGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: SpotifyColors.orange.withValues(alpha: 0.5),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        prov.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 38,
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

              const SizedBox(height: 8),

              // Live Volume Slider Bar (Direkt adaptiert von der originalen Music Assistant App)
              Builder(
                builder: (context) {
                  final active = prov.activePlayer;
                  final vol = active?.volume ?? 50;
                  final isMuted = active?.isMuted ?? false;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isMuted
                                ? Icons.volume_off
                                : (vol == 0
                                    ? Icons.volume_mute
                                    : vol < 50
                                        ? Icons.volume_down
                                        : Icons.volume_up),
                            color: isMuted
                                ? SpotifyColors.textMuted
                                : SpotifyColors.orange,
                            size: 22,
                          ),
                          tooltip: isMuted ? 'Stummschaltung aufheben' : 'Stummschalten',
                          onPressed: () {
                            if (active != null) {
                              HapticFeedback.lightImpact();
                              prov.toggleMute(active);
                            }
                          },
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: SpotifyColors.orange,
                              inactiveTrackColor: SpotifyColors.sliderInactive,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              trackHeight: 3.5,
                            ),
                            child: Slider(
                              value: isMuted ? 0.0 : vol.toDouble().clamp(0.0, 100.0),
                              min: 0,
                              max: 100,
                              onChanged: (val) {
                                prov.setVolume(val.toInt());
                              },
                              onChangeEnd: (val) {
                                if (active != null) {
                                  prov.flushVolume(active.id);
                                }
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 38,
                          child: Text(
                            isMuted ? '0%' : '$vol%',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(flex: 1),

              // Live Buchstabe-für-Buchstabe Karaoke Preview Banner
              LiveLyricsPreviewCard(
                track: track,
                onTap: () {
                  HapticFeedback.lightImpact();
                  LyricsSheet.show(context, track);
                },
              ),

              // Bottom Row: Device selector on left, Queue on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
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
                        icon: const Icon(Icons.lyrics_outlined,
                            color: SpotifyColors.textSecondary, size: 21),
                        tooltip: 'Songtext (Lyrics)',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          LyricsSheet.show(context, track);
                        },
                      ),
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
                        icon: Icon(
                          Icons.bedtime_outlined,
                          color: prov.hasActiveSleepTimer
                              ? SpotifyColors.green
                              : SpotifyColors.textSecondary,
                          size: 20,
                        ),
                        tooltip: prov.hasActiveSleepTimer
                            ? 'Sleep Timer aktiv (${prov.formattedSleepTimerRemaining})'
                            : 'Sleep Timer',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showSleepTimerDialog(context, prov);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined,
                            color: SpotifyColors.textSecondary, size: 20),
                        tooltip: 'Teilen',
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final shareText =
                              '${track.title} – ${track.artist}${track.uri != null ? " (${track.uri})" : ""}';
                          await Clipboard.setData(
                              ClipboardData(text: shareText));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '„${track.title}“ in die Zwischenablage kopiert!'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: SpotifyColors.surfaceElevated,
                              ),
                            );
                          }
                        },
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
    prov.loadServerQueue();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final queue = prov.queue;
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.only(top: 12),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: SpotifyColors.textMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Warteschlange',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${queue.length} Titel',
                                style: const TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (queue.isNotEmpty)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 18),
                              label: const Text('Leeren',
                                  style: TextStyle(color: Colors.redAccent)),
                              onPressed: () {
                                prov.clearCurrentQueue();
                                setModalState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                    const Divider(color: SpotifyColors.borderSubtle),
                    if (queue.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Warteschlange ist leer',
                            style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: queue.length,
                          itemBuilder: (c, idx) {
                            final item = queue[idx];
                            final isNow = item.id == prov.currentTrack?.id;
                            return Dismissible(
                              key: ValueKey('${item.id}_$idx'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.redAccent.withValues(alpha: 0.8),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) {
                                prov.removeFromQueue(idx);
                                setModalState(() {});
                              },
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  isNow ? Icons.equalizer : Icons.music_note,
                                  color: isNow
                                      ? SpotifyColors.green
                                      : SpotifyColors.textMuted,
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    color: isNow
                                        ? SpotifyColors.green
                                        : Colors.white,
                                    fontWeight: isNow
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  item.artist,
                                  style: const TextStyle(
                                      color: SpotifyColors.textSecondary),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.formattedDuration,
                                      style: const TextStyle(
                                          color: SpotifyColors.textMuted,
                                          fontSize: 12),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          size: 16,
                                          color: SpotifyColors.textMuted),
                                      onPressed: () {
                                        prov.removeFromQueue(idx);
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  prov.jumpToQueueIndex(idx);
                                  Navigator.pop(ctx);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context, MusicProvider prov) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<MusicProvider>(
        builder: (ctx, liveProv, _) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.bedtime, color: SpotifyColors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Sleep Timer (Einschlaftimer)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (liveProv.hasActiveSleepTimer)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SpotifyColors.green.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SpotifyColors.green),
                        ),
                        child: Text(
                          'Aktiv: ${liveProv.formattedSleepTimerRemaining}',
                          style: const TextStyle(
                            color: SpotifyColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(color: SpotifyColors.borderSubtle),
              ListTile(
                leading: const Icon(Icons.timer_10, color: Colors.white),
                title: const Text('15 Minuten',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  liveProv.setSleepTimer(const Duration(minutes: 15));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Einschlaftimer auf 15 Minuten gestellt'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.white),
                title: const Text('30 Minuten',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  liveProv.setSleepTimer(const Duration(minutes: 30));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Einschlaftimer auf 30 Minuten gestellt'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.white),
                title: const Text('45 Minuten',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  liveProv.setSleepTimer(const Duration(minutes: 45));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Einschlaftimer auf 45 Minuten gestellt'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.white),
                title:
                    const Text('1 Stunde', style: TextStyle(color: Colors.white)),
                onTap: () {
                  liveProv.setSleepTimer(const Duration(hours: 1));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Einschlaftimer auf 1 Stunde gestellt'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
              if (liveProv.hasActiveSleepTimer)
                ListTile(
                  leading:
                      const Icon(Icons.timer_off, color: Colors.redAccent),
                  title: const Text('Timer ausschalten',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    liveProv.clearSleepTimer();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Einschlaftimer deaktiviert'),
                        backgroundColor: SpotifyColors.surfaceElevated,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDialog(BuildContext context, MusicProvider prov) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpotifyColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.campaign, color: SpotifyColors.green),
            SizedBox(width: 8),
            Text('Durchsage senden',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nachricht eingeben (TTS)...',
            hintStyle: const TextStyle(color: SpotifyColors.textSecondary),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen',
                style: TextStyle(color: SpotifyColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotifyColors.green,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final text = textCtrl.text.trim();
              if (text.isNotEmpty) {
                prov.sendAnnouncement(text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Durchsage wird abgespielt: "$text"'),
                    backgroundColor: SpotifyColors.surfaceElevated,
                  ),
                );
              }
            },
            child: const Text('Senden'),
          ),
        ],
      ),
    );
  }

  void _showTrackOptions(
      BuildContext context, Track track, MusicProvider prov) {
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  TrackTile.showAddToPlaylistDialog(context, track, prov);
                },
              ),
              ListTile(
                leading: const Icon(Icons.radio, color: Colors.white),
                title: const Text('Song-Radio starten',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  prov.startTrackRadio(track);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Song-Radio für „${track.title}“ gestartet'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune, color: Colors.white),
                title: const Text('Equalizer anpassen',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const EqualizerSheet(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.devices, color: Colors.white),
                title: const Text('Wiedergabegerät wechseln',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const DevicePickerSheet(),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.bedtime,
                  color: prov.hasActiveSleepTimer
                      ? SpotifyColors.green
                      : Colors.white,
                ),
                title: Text(
                  prov.hasActiveSleepTimer
                      ? 'Sleep Timer aktiv (${prov.formattedSleepTimerRemaining})'
                      : 'Sleep Timer / Einschlaftimer',
                  style: TextStyle(
                    color: prov.hasActiveSleepTimer
                        ? SpotifyColors.green
                        : Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSleepTimerDialog(context, prov);
                },
              ),
              ListTile(
                leading: const Icon(Icons.campaign, color: Colors.white),
                title: const Text('Durchsage an Lautsprecher senden',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAnnouncementDialog(context, prov);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Titel teilen',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final shareText =
                      '${track.title} – ${track.artist}${track.uri != null ? " (${track.uri})" : ""}';
                  await Clipboard.setData(ClipboardData(text: shareText));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '„${track.title}“ in die Zwischenablage kopiert!'),
                        backgroundColor: SpotifyColors.surfaceElevated,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
