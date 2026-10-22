import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'dj_orb_visualizer.dart';

/// Interaktive Apple Watch Fernbedienung & Live-Vorschau der watchOS-App
class AppleWatchRemoteSheet extends StatefulWidget {
  const AppleWatchRemoteSheet({super.key});

  @override
  State<AppleWatchRemoteSheet> createState() => _AppleWatchRemoteSheetState();
}

class _AppleWatchRemoteSheetState extends State<AppleWatchRemoteSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final track = prov.currentTrack;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: SpotifyColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.watch, color: SpotifyColors.green, size: 24),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apple Watch Fernbedienung',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Echte watchOS App & interaktive Steuerung',
                        style: TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: SpotifyColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Photorealistic Apple Watch Hardware Bezel
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAppleWatchHardware(context, prov, track, timeStr),
                      const SizedBox(height: 16),
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPageDot(0, 'Now Playing'),
                          const SizedBox(width: 8),
                          _buildPageDot(1, 'Lautsprecher'),
                          const SizedBox(width: 8),
                          _buildPageDot(2, 'KI-DJ'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Info Banner
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: SpotifyColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: SpotifyColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: SpotifyColors.green.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle,
                                    color: SpotifyColors.green, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'WatchConnectivity Sync aktiv',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'watchOS App in ios/WatchApp bereit für SideStore, AltStore & Xcode.',
                                      style: TextStyle(
                                        color: SpotifyColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageDot(int page, String label) {
    final isSelected = _currentPage == page;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _pageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? SpotifyColors.green
              : SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : SpotifyColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAppleWatchHardware(
      BuildContext context, MusicProvider prov, dynamic track, String timeStr) {
    const watchWidth = 224.0;
    const watchHeight = 276.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Digital Crown on the right side
        Positioned(
          right: -8,
          top: 60,
          child: Container(
            width: 12,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF333333), Color(0xFF666666), Color(0xFF222222)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                6,
                (_) => Container(
                  height: 1.5,
                  width: 8,
                  color: Colors.black26,
                ),
              ),
            ),
          ),
        ),

        // Side Button below Digital Crown
        Positioned(
          right: -5,
          top: 130,
          child: Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),

        // Apple Watch Outer Chassis (Titanium / Space Black)
        Container(
          width: watchWidth + 24,
          height: watchHeight + 24,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(44),
            border: Border.all(color: const Color(0xFF3A3A3A), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 24,
                spreadRadius: 4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            // Glass bezel
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: const Color(0xFF262626), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Column(
                  children: [
                    // Watch Status Bar
                    Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.black,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SpotifyColors.green,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'MASS',
                                style: TextStyle(
                                  color: SpotifyColors.green,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Watch Face Screen Content (PageView)
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                        children: [
                          _buildWatchNowPlaying(prov, track),
                          _buildWatchSpeakers(prov),
                          _buildWatchDj(prov),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Watch Screen 1: Now Playing ---
  Widget _buildWatchNowPlaying(MusicProvider prov, dynamic track) {
    final activeSpeaker = prov.activePlayer?.name ?? 'Sonos';
    final isPlaying = prov.isPlaying;
    final title = track?.title ?? 'Keine Wiedergabe';
    final artist = track?.artist ?? 'Music Assistant';
    final rawVolume = prov.activePlayer?.volume ?? 50;
    final volumeRatio = (rawVolume / 100.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: Column(
        children: [
          // Speaker chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speaker, size: 9, color: SpotifyColors.green),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    activeSpeaker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SpotifyColors.green,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Artwork & Track Title
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: track?.imageUrl != null
                    ? Image.network(
                        track!.imageUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 36,
                          height: 36,
                          color: const Color(0xFF222222),
                          child: const Icon(Icons.music_note,
                              size: 18, color: SpotifyColors.green),
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        color: const Color(0xFF222222),
                        child: const Icon(Icons.music_note,
                            size: 18, color: SpotifyColors.green),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.skip_previous,
                    color: Colors.white, size: 22),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  prov.previous();
                },
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  prov.togglePlayPause();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: SpotifyColors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 26,
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 22),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  prov.next();
                },
              ),
            ],
          ),

          const Spacer(),

          // Volume Bar
          Row(
            children: [
              const Icon(Icons.volume_down, size: 10, color: SpotifyColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: volumeRatio,
                    minHeight: 3,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation(SpotifyColors.green),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$rawVolume%',
                style: const TextStyle(
                  color: SpotifyColors.textMuted,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Watch Screen 2: Speakers List ---
  Widget _buildWatchSpeakers(MusicProvider prov) {
    final players = prov.players;
    final activeId = prov.activePlayer?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RÄUME & SPEAKER',
            style: TextStyle(
              color: SpotifyColors.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: players.length,
              itemBuilder: (context, index) {
                final p = players[index];
                final isSelected = p.id == activeId;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    prov.setActivePlayer(p);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SpotifyColors.green.withValues(alpha: 0.2)
                          : const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? SpotifyColors.green
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.volume_up : Icons.speaker,
                          size: 13,
                          color: isSelected
                              ? SpotifyColors.green
                              : Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? SpotifyColors.green
                                  : Colors.white,
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check,
                              color: SpotifyColors.green, size: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Watch Screen 3: Spotify Virtual DJ ---
  Widget _buildWatchDj(MusicProvider prov) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mini Pulsing Orb
          const DjOrbVisualizer(
            size: 46,
            isSpeaking: false,
          ),
          const SizedBox(height: 6),
          const Text(
            'SPOTIFY KI-DJ',
            style: TextStyle(
              color: SpotifyColors.green,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              prov.currentDjVibe.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Vibe Wechseln Button
          SizedBox(
            width: double.infinity,
            height: 26,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: SpotifyColors.green,
                foregroundColor: Colors.black,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: const Icon(Icons.shuffle, size: 12),
              label: const Text(
                'Vibe wechseln',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                prov.switchDjVibe();
              },
            ),
          ),
        ],
      ),
    );
  }
}
