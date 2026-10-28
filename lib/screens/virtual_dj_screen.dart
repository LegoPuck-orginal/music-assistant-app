import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/virtual_dj_vibe.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/dj_orb_visualizer.dart';
import '../widgets/dj_voice_settings_sheet.dart';

class VirtualDjScreen extends StatefulWidget {
  const VirtualDjScreen({super.key});

  @override
  State<VirtualDjScreen> createState() => _VirtualDjScreenState();
}

class _VirtualDjScreenState extends State<VirtualDjScreen> {
  final TextEditingController _wishCtrl = TextEditingController();
  bool _isSubmittingWish = false;

  static const List<String> _quickWishes = [
    '🔥 Mehr Energie',
    '🌙 Entspannte Nacht',
    '🎸 Rock-Bretter',
    '🚀 Überrasch mich',
    '⏳ Nostalgie-Mix',
  ];

  @override
  void dispose() {
    _wishCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitWish(MusicProvider prov, String rawWish) async {
    final cleaned = rawWish
        .replaceAll(RegExp(r'^[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]\s*', unicode: true), '')
        .trim();
    if (cleaned.isEmpty || _isSubmittingWish) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() => _isSubmittingWish = true);
    _wishCtrl.clear();
    try {
      await prov.askDjCustomPrompt(cleaned);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingWish = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final currentVibe = prov.currentDjVibe;
    final track = prov.currentTrack;
    final primaryVibeColor = currentVibe.gradient.isNotEmpty
        ? currentVibe.gradient.first
        : SpotifyColors.orange;

    // Nächsten Song in der DJ-Queue ermitteln
    final q = prov.queue;
    final curIdx = track != null ? q.indexWhere((t) => t.id == track.id) : -1;
    final nextInMix = (curIdx != -1 && curIdx + 1 < q.length)
        ? q[curIdx + 1]
        : (q.length > 1 ? q[1] : null);

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Ambient Studio Radial Glow
          Positioned(
            top: -80,
            left: -60,
            right: -60,
            child: IgnorePointer(
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      primaryVibeColor.withValues(alpha: 0.22),
                      SpotifyColors.orange.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    radius: 0.85,
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Studio App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                        decoration: BoxDecoration(
                          color: SpotifyColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: SpotifyColors.orange.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: SpotifyColors.orange,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'STUDIO KI-DJ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
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
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: prov.isDjVoiceEnabled
                              ? SpotifyColors.orange
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
                              content: Text(
                                prov.isDjVoiceEnabled
                                    ? 'DJ-Sprachansagen aktiviert'
                                    : 'DJ-Sprachansagen stummgeschaltet',
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: SpotifyColors.surfaceHighlight,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Active Speaker Badge
                if (prov.activePlayer != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SpotifyColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          prov.activePlayer!.isLocal
                              ? Icons.smartphone_rounded
                              : Icons.speaker_group_rounded,
                          size: 13,
                          color: SpotifyColors.amber,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Spielt auf: ${prov.activePlayer!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SpotifyColors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Scrollable Main Body so keyboard never overflows
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),

                        // Glowing Pulsing Animated DJ Orb
                        Center(
                          child: DjOrbVisualizer(
                            size: 176,
                            isSpeaking: prov.isDjSpeaking,
                            isPlaying: prov.isPlaying,
                            accentColors: currentVibe.gradient,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              prov.switchDjVibe();
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // DJ Speech / Commentary Bubble
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: SpotifyColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: prov.isDjSpeaking
                                    ? SpotifyColors.orange.withValues(alpha: 0.7)
                                    : SpotifyColors.glassBorder,
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
                                            ? SpotifyColors.orange
                                            : SpotifyColors.amber,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        prov.isDjSpeaking
                                            ? 'DJ X MODERIERT LIVE'
                                            : 'VIBE: ${currentVibe.title.toUpperCase()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: prov.isDjSpeaking
                                              ? SpotifyColors.orange
                                              : SpotifyColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.9,
                                        ),
                                      ),
                                    ),
                                    if (prov.isDjSpeaking)
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          prov.skipDjSpeech();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.fast_forward_rounded,
                                                color: Colors.white70,
                                                size: 12,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Überspringen',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    else
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          prov.triggerDjModerationNow();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: SpotifyColors.orange.withValues(alpha: 0.14),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.mic_rounded,
                                                color: SpotifyColors.orange,
                                                size: 12,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Anmoderieren',
                                                style: TextStyle(
                                                  color: SpotifyColors.orange,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  prov.djSpeechText ??
                                      'Tippe auf „Vibe wechseln“ oder wünsch dir direkt einen Künstler, ein Genre oder eine Stimmung.',
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

                        const SizedBox(height: 14),

                        // Interactive KI-Musikwunsch Input Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: SpotifyColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: SpotifyColors.glassBorder),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: SpotifyColors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _wishCtrl,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    textInputAction: TextInputAction.send,
                                    decoration: const InputDecoration(
                                      hintText: 'Wünsch dir Stimmung, Genre oder Künstler...',
                                      hintStyle: TextStyle(
                                        color: SpotifyColors.textMuted,
                                        fontSize: 12.5,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onSubmitted: (val) => _submitWish(prov, val),
                                  ),
                                ),
                                IconButton(
                                  icon: _isSubmittingWish
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              SpotifyColors.orange,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: SpotifyColors.orange,
                                          size: 19,
                                        ),
                                  onPressed: () => _submitWish(prov, _wishCtrl.text),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Quick-Wish Chips
                        SizedBox(
                          height: 32,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: _quickWishes.length,
                            itemBuilder: (context, index) {
                              final wish = _quickWishes[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _submitWish(prov, wish),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SpotifyColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.08),
                                      ),
                                    ),
                                    child: Text(
                                      wish,
                                      style: const TextStyle(
                                        color: SpotifyColors.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

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
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? SpotifyColors.primaryGradient
                                          : null,
                                      color: isSelected
                                          ? null
                                          : SpotifyColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? SpotifyColors.orange
                                            : SpotifyColors.glassBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          v.icon,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          v.title,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
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
                      ],
                    ),
                  ),
                ),

                // "VIBE WECHSELN" Studio Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: SpotifyColors.primaryGradient,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: SpotifyColors.orange.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          prov.switchDjVibe();
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shuffle_rounded,
                              color: Colors.black,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'VIBE & MIX WECHSELN',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Bottom Track & Next-In-Mix Bar
                if (track != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SpotifyColors.glassBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (track.imageUrl != null && track.imageUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.network(
                                  track.imageUrl!,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.music_note_rounded,
                                    color: SpotifyColors.orange,
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.music_note_rounded,
                                color: SpotifyColors.orange,
                                size: 30,
                              ),
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
                                  if (nextInMix != null && nextInMix.id != track.id)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Danach: ${nextInMix.title} • ${nextInMix.artist}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: SpotifyColors.amber,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                prov.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_filled_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                              onPressed: prov.togglePlayPause,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                              onPressed: prov.next,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
