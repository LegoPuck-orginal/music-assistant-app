import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../screens/virtual_dj_screen.dart';
import '../theme/spotify_colors.dart';
import 'now_playing_sheet.dart';

class DynamicIslandOverlay extends StatefulWidget {
  const DynamicIslandOverlay({super.key});

  @override
  State<DynamicIslandOverlay> createState() => _DynamicIslandOverlayState();
}

class _DynamicIslandOverlayState extends State<DynamicIslandOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _barsController;

  @override
  void initState() {
    super.initState();
    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _barsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final track = prov.currentTrack;
    final isDjSpeaking = prov.isDjSpeaking;
    final isDjActive = prov.isDjActive;
    final isExpanded = prov.isDynamicIslandExpanded;

    // Show island if track is playing, or DJ is active/speaking
    if (track == null && !isDjSpeaking && !isDjActive) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final compactWidth = isDjSpeaking ? 245.0 : 215.0;
    final expandedWidth = math.min(screenWidth - 24, 390.0);

    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              prov.setDynamicIslandExpanded(!isExpanded);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              if (isDjActive) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VirtualDjScreen()),
                );
              } else {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const NowPlayingSheet(),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.fastOutSlowIn,
              width: isExpanded ? expandedWidth : compactWidth,
              height: isExpanded ? 94 : 36,
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded ? 16 : 10,
                vertical: isExpanded ? 12 : 6,
              ),
              decoration: BoxDecoration(
                color: SpotifyColors.pureBlack,
                borderRadius: BorderRadius.circular(isExpanded ? 34 : 20),
                border: Border.all(
                  color: isDjSpeaking
                      ? const Color(0xFF00F2FE).withValues(alpha: 0.6)
                      : (isExpanded
                          ? SpotifyColors.green.withValues(alpha: 0.4)
                          : const Color(0xFF222222)),
                  width: isDjSpeaking ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDjSpeaking
                            ? const Color(0xFF00F2FE)
                            : SpotifyColors.green)
                        .withValues(alpha: isExpanded ? 0.35 : 0.15),
                    blurRadius: isExpanded ? 24 : 10,
                    spreadRadius: isExpanded ? 2 : 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isExpanded
                  ? _buildExpandedContent(context, prov, track, isDjSpeaking)
                  : _buildCompactContent(context, prov, track, isDjSpeaking),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactContent(BuildContext context, MusicProvider prov,
      Track? track, bool isDjSpeaking) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: DJ Orb or Album Art
        if (isDjSpeaking || prov.isDjActive) ...[
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFF00F2FE),
                  Color(0xFF4FACFE),
                  SpotifyColors.green,
                  Color(0xFF00F2FE),
                ],
              ),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome, size: 12, color: Colors.black),
            ),
          ),
        ] else if (track?.imageUrl != null && track!.imageUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.network(
              track.imageUrl!,
              width: 22,
              height: 22,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.music_note,
                size: 16,
                color: SpotifyColors.green,
              ),
            ),
          ),
        ] else ...[
          const Icon(Icons.music_note, size: 16, color: SpotifyColors.green),
        ],

        const SizedBox(width: 8),

        // Center: Track Title or DJ State
        Expanded(
          child: Text(
            isDjSpeaking
                ? '🎙️ DJ X spricht...'
                : prov.isDjActive
                    ? 'DJ X • ${track?.title ?? "Mix"}'
                    : (track?.title ?? 'Music Assistant'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDjSpeaking ? const Color(0xFF00F2FE) : Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Right: Animated Soundwave Visualizer Bars
        _buildBouncingBars(prov.isPlaying || isDjSpeaking),
      ],
    );
  }

  Widget _buildExpandedContent(BuildContext context, MusicProvider prov,
      Track? track, bool isDjSpeaking) {
    return Row(
      children: [
        // Left: Big Avatar / DJ Orb
        if (isDjSpeaking || prov.isDjActive) ...[
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VirtualDjScreen()),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFF00F2FE),
                    Color(0xFF4FACFE),
                    Color(0xFF7F00FF),
                    SpotifyColors.green,
                    Color(0xFF00F2FE),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0A0E17),
                  ),
                  child: const Center(
                    child: Icon(Icons.graphic_eq,
                        color: Color(0xFF00F2FE), size: 24),
                  ),
                ),
              ),
            ),
          ),
        ] else if (track?.imageUrl != null && track!.imageUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              track.imageUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 60,
                height: 60,
                color: SpotifyColors.surfaceHighlight,
                child: const Icon(Icons.music_note,
                    color: SpotifyColors.green, size: 28),
              ),
            ),
          ),
        ] else ...[
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note,
                color: SpotifyColors.green, size: 28),
          ),
        ],

        const SizedBox(width: 14),

        // Center info
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDjSpeaking) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'DJ X MODERATION',
                        style: TextStyle(
                          color: Color(0xFF00F2FE),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      prov.currentDjVibe.title,
                      style: const TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  prov.djSpeechText ?? 'Spielt für dich...',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ] else ...[
                Text(
                  track?.title ?? 'Titel unbekannt',
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
                  track?.artist ?? 'Künstler',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      prov.activePlayer?.isLocal == true
                          ? Icons.smartphone
                          : Icons.speaker,
                      size: 11,
                      color: SpotifyColors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      prov.activePlayer?.name ?? 'Lautsprecher',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SpotifyColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Right Action Buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prov.isDjActive) ...[
              IconButton(
                icon: const Icon(Icons.auto_awesome,
                    color: Color(0xFF00F2FE), size: 22),
                tooltip: 'Vibe wechseln',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  prov.switchDjVibe();
                },
              ),
            ],
            IconButton(
              icon: Icon(
                prov.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                prov.togglePlayPause();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBouncingBars(bool isPlaying) {
    if (!isPlaying) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          4,
          (index) => Container(
            width: 2.5,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: SpotifyColors.textSecondary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _barsController,
      builder: (context, _) {
        final val = _barsController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final offset = (index * 0.25);
            final barVal = (math.sin((val + offset) * math.pi * 2).abs());
            final height = 5.0 + (barVal * 12.0);
            return Container(
              width: 2.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [SpotifyColors.green, Color(0xFF00F2FE)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}
