import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/audiobook.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

/// Detail- und Kapitel-Übersicht für ein Hörbuch / Hörspiel (z. B. Die drei ???)
class AudiobookDetailScreen extends StatelessWidget {
  final Audiobook audiobook;

  const AudiobookDetailScreen({
    super.key,
    required this.audiobook,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final isCurrentAudiobook = prov.currentTrack != null &&
        audiobook.chapters.any((c) => c.id == prov.currentTrack!.id);

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: CustomScrollView(
        slivers: [
          // App Bar mit Cover
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: const Color(0xFF1E1E1E),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                tooltip: 'Teilen',
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          '${audiobook.series} – Folge ${audiobook.episodeNumber}: ${audiobook.title}',
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '„${audiobook.series} – ${audiobook.title}“ in die Zwischenablage kopiert!'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: SpotifyColors.surfaceElevated,
                      ),
                    );
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    audiobook.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                          SpotifyColors.pureBlack,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: SpotifyColors.green,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${audiobook.series.toUpperCase()} • FOLGE ${audiobook.episodeNumber}',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          audiobook.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${audiobook.formattedDuration} • ${audiobook.chapters.length} Teile',
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Bar & Beschreibung
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Play / Resume Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpotifyColors.green,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        if (isCurrentAudiobook) {
                          prov.togglePlayPause();
                        } else if (audiobook.chapters.isNotEmpty) {
                          prov.playAudiobook(audiobook);
                        }
                      },
                      icon: Icon(
                        isCurrentAudiobook && prov.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 26,
                      ),
                      label: Text(
                        isCurrentAudiobook && prov.isPlaying
                            ? 'PAUSIEREN'
                            : 'FOLGE JETZT ABSPIELEN',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sprecher & Autor Info-Karten
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: SpotifyColors.borderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.mic, color: SpotifyColors.green, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'SPRECHER & CAST',
                              style: TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          audiobook.narrator,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const Divider(
                            color: SpotifyColors.borderSubtle, height: 20),
                        const Row(
                          children: [
                            Icon(Icons.menu_book, color: SpotifyColors.green, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'AUTOR / BUCHVORLAGE',
                              style: TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          audiobook.author,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Beschreibung / Klappentext
                  Text(
                    audiobook.description,
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'KAPITEL & TEILE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Kapitel / Track-Liste
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final chapter = audiobook.chapters[index];
                final isPlayingThisChapter =
                    prov.currentTrack?.id == chapter.id && prov.isPlaying;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isPlayingThisChapter
                          ? SpotifyColors.green.withValues(alpha: 0.2)
                          : SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: isPlayingThisChapter
                          ? Border.all(color: SpotifyColors.green, width: 1.2)
                          : null,
                    ),
                    child: Center(
                      child: isPlayingThisChapter
                          ? const Icon(
                              Icons.volume_up,
                              color: SpotifyColors.green,
                              size: 18,
                            )
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                  title: Text(
                    chapter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlayingThisChapter ? SpotifyColors.green : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    chapter.formattedDuration,
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isPlayingThisChapter
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: isPlayingThisChapter
                          ? SpotifyColors.green
                          : SpotifyColors.textSecondary,
                      size: 28,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (isPlayingThisChapter) {
                        prov.togglePlayPause();
                      } else {
                        prov.playAudiobook(audiobook, chapter: chapter);
                      }
                    },
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (isPlayingThisChapter) {
                      prov.togglePlayPause();
                    } else {
                      prov.playAudiobook(audiobook, chapter: chapter);
                    }
                  },
                );
              },
              childCount: audiobook.chapters.length,
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}
