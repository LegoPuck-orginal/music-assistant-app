import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/virtual_dj_vibe.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/dj_orb_visualizer.dart';
import '../widgets/dj_voice_settings_sheet.dart';

class VirtualDjScreen extends StatelessWidget {
  const VirtualDjScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final currentVibe = prov.currentDjVibe;
    final track = prov.currentTrack;

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            color: Color(0xFF00F2FE), size: 14),
                        SizedBox(width: 6),
                        Text(
                          'SPOTIFY AI DJ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white70,
                    ),
                    tooltip: 'DJ-Stimme & KI-Modell anpassen',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      DjVoiceSettingsSheet.show(context);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      prov.isDjVoiceEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      color: prov.isDjVoiceEnabled
                          ? SpotifyColors.green
                          : SpotifyColors.textSecondary,
                    ),
                    tooltip: prov.isDjVoiceEnabled
                        ? 'Sprachansagen aktiviert'
                        : 'Sprachansagen stumm',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.toggleDjVoice();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(prov.isDjVoiceEnabled
                              ? 'DJ-Sprachansagen auf ${prov.activePlayer?.name ?? "Lautsprecher"} aktiviert'
                              : 'DJ-Sprachansagen stummgeschaltet'),
                          duration: const Duration(seconds: 1),
                          backgroundColor: SpotifyColors.surfaceHighlight,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Active Speaker Badge
            if (prov.activePlayer != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: SpotifyColors.surfaceHighlight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      prov.activePlayer!.isLocal
                          ? Icons.smartphone
                          : Icons.speaker,
                      size: 13,
                      color: SpotifyColors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Spielt auf: ${prov.activePlayer!.name}',
                      style: const TextStyle(
                        color: SpotifyColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Glowing Pulsing Animated DJ Orb
            Center(
              child: DjOrbVisualizer(
                size: 220,
                isSpeaking: prov.isDjSpeaking,
                isPlaying: prov.isPlaying,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  prov.switchDjVibe();
                },
              ),
            ),

            const Spacer(),

            // DJ Speech / Commentary Bubble
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SpotifyColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: prov.isDjSpeaking
                        ? const Color(0xFF00F2FE).withValues(alpha: 0.6)
                        : SpotifyColors.surfaceHighlight,
                    width: prov.isDjSpeaking ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: prov.isDjSpeaking
                                ? const Color(0xFF00F2FE)
                                : SpotifyColors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          prov.isDjSpeaking
                              ? 'DJ SPRICHT GERADE'
                              : 'AKTUELLER VIBE: ${currentVibe.title.toUpperCase()}',
                          style: TextStyle(
                            color: prov.isDjSpeaking
                                ? const Color(0xFF00F2FE)
                                : SpotifyColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      prov.djSpeechText ??
                          'Tippe auf „Vibe wechseln“, um einen neuen Musik-Mix mit persönlicher DJ-Moderation zu starten.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Horizontal Vibe Selector Chips
            SizedBox(
              height: 38,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: DjVibe.allVibes.length,
                itemBuilder: (context, index) {
                  final v = DjVibe.allVibes[index];
                  final isSelected = v.category == currentVibe.category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        prov.switchDjVibe(category: v.category);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SpotifyColors.green
                              : SpotifyColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? SpotifyColors.green
                                : SpotifyColors.surfaceHighlight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(v.icon, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              v.title,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            // "VIBE WECHSELN" Floating Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F2FE),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 8,
                    shadowColor: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    prov.switchDjVibe();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.black, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'VIBE WECHSELN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bottom Track Bar
            if (track != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: SpotifyColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (track.imageUrl != null && track.imageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          track.imageUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.music_note,
                            color: SpotifyColors.green,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.music_note,
                          color: SpotifyColors.green, size: 30),
                    const SizedBox(width: 12),
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
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                    IconButton(
                      icon: Icon(
                        prov.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: prov.togglePlayPause,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next,
                          color: Colors.white, size: 26),
                      onPressed: prov.next,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
