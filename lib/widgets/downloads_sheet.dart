import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'track_tile.dart';

/// Modal-Ansicht zur Verwaltung aller heruntergeladenen Titel und des Offline-Speichers
class DownloadsSheet extends StatelessWidget {
  const DownloadsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final downloadedTracks = prov.downloadedTracks;
    final totalSize = prov.formattedDownloadedSize;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: SpotifyColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SpotifyColors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.download_done,
                        color: SpotifyColors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Downloads & Offline-Musik',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '$totalSize • ${downloadedTracks.length} Titel verfügbar',
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: SpotifyColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Offline Mode Toggle Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: SpotifyColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: prov.isOfflineMode
                        ? SpotifyColors.green
                        : SpotifyColors.borderSubtle,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      prov.isOfflineMode ? Icons.cloud_off : Icons.wifi,
                      color: prov.isOfflineMode
                          ? SpotifyColors.green
                          : SpotifyColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline-Modus erzwingen',
                            style: TextStyle(
                              color: prov.isOfflineMode
                                  ? SpotifyColors.green
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Spielt Musik ausschließlich aus lokalem Speicher ab',
                            style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: prov.isOfflineMode,
                      activeThumbColor: SpotifyColors.green,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        prov.setOfflineMode(val);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Action Row (Play All & Clear All)
            if (downloadedTracks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpotifyColors.green,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.shuffle, size: 18),
                      label: const Text(
                        'Alle offline abspielen',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        prov.playTrack(downloadedTracks.first,
                            newQueue: downloadedTracks);
                        Navigator.pop(context);
                      },
                    ),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Alle löschen',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: SpotifyColors.surfaceElevated,
                            title: const Text('Alle Downloads löschen?',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'Möchtest du wirklich alle heruntergeladenen Titel vom Gerät löschen?',
                              style: TextStyle(
                                  color: SpotifyColors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Abbrechen',
                                    style: TextStyle(
                                        color: SpotifyColors.textSecondary)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  prov.clearAllDownloads();
                                },
                                child: const Text('Löschen'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Track list or Empty State
            Expanded(
              child: downloadedTracks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.download_for_offline_outlined,
                            size: 54,
                            color: SpotifyColors.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Noch keine Downloads vorhanden',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Tippe bei Playlists oder im Menü eines Titels auf das Download-Symbol, um Musik ohne Internet zu hören.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: downloadedTracks.length,
                      itemBuilder: (context, index) {
                        final track = downloadedTracks[index];
                        return TrackTile(
                          track: track,
                          index: index + 1,
                          onTap: () {
                            prov.playTrack(track, newQueue: downloadedTracks);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
