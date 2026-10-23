import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final int? index;
  final VoidCallback? onTap;
  final bool showImage;

  const TrackTile({
    super.key,
    required this.track,
    this.index,
    this.onTap,
    this.showImage = true,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final isCurrent = prov.currentTrack?.id == track.id;
    final isDownloaded = prov.isTrackDownloaded(track.id);
    final isDownloading = prov.isTrackDownloading(track.id);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          prov.playTrack(track);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Index number or current playing wave
            if (index != null && !showImage) ...[
              SizedBox(
                width: 28,
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: isCurrent ? SpotifyColors.green : SpotifyColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // Cover thumbnail if showImage
            if (showImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 48,
                  height: 48,
                  color: SpotifyColors.surfaceElevated,
                  child: track.imageUrl != null
                      ? Image.network(
                          track.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.music_note,
                            color: SpotifyColors.textSecondary,
                            size: 22,
                          ),
                        )
                      : const Icon(
                          Icons.music_note,
                          color: SpotifyColors.textSecondary,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 14),
            ],

            // Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? SpotifyColors.green : Colors.white,
                      fontSize: 15,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (isDownloaded) ...[
                        const Icon(Icons.arrow_circle_down,
                            size: 13, color: SpotifyColors.green),
                        const SizedBox(width: 4),
                      ] else if (isDownloading) ...[
                        const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: SpotifyColors.green,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Heart / Like
            IconButton(
              icon: Icon(
                track.isLiked ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: track.isLiked ? SpotifyColors.green : SpotifyColors.textSecondary,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                prov.toggleLike(track);
              },
            ),

            // More Options
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: SpotifyColors.textSecondary,
              ),
              onPressed: () {
                _showTrackOptions(context, track, prov);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackOptions(BuildContext context, Track track, MusicProvider prov) {
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
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(track.artist,
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
                leading: prov.isTrackDownloaded(track.id)
                    ? const Icon(Icons.download_done, color: SpotifyColors.green)
                    : prov.isTrackDownloading(track.id)
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SpotifyColors.green,
                            ),
                          )
                        : const Icon(Icons.download_for_offline_outlined,
                            color: Colors.white),
                title: Text(
                  prov.isTrackDownloaded(track.id)
                      ? 'Download entfernen'
                      : prov.isTrackDownloading(track.id)
                          ? 'Wird heruntergeladen (${((prov.getDownloadProgress(track.id) ?? 0.0) * 100).round()}%)'
                          : 'Herunterladen (Offline verfügbar)',
                  style: TextStyle(
                    color: prov.isTrackDownloaded(track.id)
                        ? SpotifyColors.green
                        : Colors.white,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (prov.isTrackDownloaded(track.id)) {
                    await prov.removeDownload(track.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Download für "${track.title}" entfernt'),
                          backgroundColor: SpotifyColors.surfaceElevated,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lade "${track.title}" herunter...'),
                          backgroundColor: SpotifyColors.surfaceElevated,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                    await prov.downloadTrack(track);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.queue_play_next, color: Colors.white),
                title: const Text('Als Nächstes abspielen',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await prov.playNext(track);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '"${track.title}" wird als Nächstes abgespielt'),
                        backgroundColor: SpotifyColors.surfaceElevated,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_to_queue, color: Colors.white),
                title: const Text('An Warteschlange anhängen',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await prov.addToQueue(track);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '"${track.title}" an Warteschlange angehängt'),
                        backgroundColor: SpotifyColors.surfaceElevated,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Zu Playlist hinzufügen',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  showAddToPlaylistDialog(context, track, prov);
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
                      content: Text('Song-Radio für "${track.title}" gestartet'),
                      backgroundColor: SpotifyColors.surfaceElevated,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Teilen',
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

  static void showAddToPlaylistDialog(
      BuildContext context, Track track, MusicProvider prov) {
    final userPlaylists =
        prov.playlists.where((p) => p.type == 'playlist').toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Icon(Icons.playlist_add, color: SpotifyColors.green),
                      SizedBox(width: 10),
                      Text(
                        'Zu Playlist hinzufügen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SpotifyColors.green.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: SpotifyColors.green),
                  ),
                  title: const Text(
                    'Neue Playlist erstellen',
                    style: TextStyle(
                      color: SpotifyColors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Erstellt eine neue Playlist mit diesem Song',
                    style: TextStyle(
                        color: SpotifyColors.textSecondary, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _promptCreatePlaylistWithTrack(context, track, prov);
                  },
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                Flexible(
                  child: userPlaylists.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Noch keine eigenen Playlists vorhanden. Tippe oben auf „Neue Playlist erstellen“.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: SpotifyColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: userPlaylists.length,
                          itemBuilder: (ctx, i) {
                            final pl = userPlaylists[i];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: SpotifyColors.surfaceElevated,
                                  child: pl.imageUrl != null
                                      ? Image.network(
                                          pl.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                              Icons.queue_music,
                                              color: Colors.white70),
                                        )
                                      : const Icon(Icons.queue_music,
                                          color: Colors.white70),
                                ),
                              ),
                              title: Text(
                                pl.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${pl.trackCount} Songs • ${pl.owner}',
                                style: const TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                Navigator.pop(sheetCtx);
                                await prov.addTrackToPlaylist(pl, track);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '„${track.title}“ zu „${pl.name}“ hinzugefügt'),
                                      backgroundColor:
                                          SpotifyColors.surfaceElevated,
                                    ),
                                  );
                                }
                              },
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
  }

  static void _promptCreatePlaylistWithTrack(
      BuildContext context, Track track, MusicProvider prov) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: SpotifyColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Neue Playlist erstellen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Name der Playlist...',
            hintStyle: const TextStyle(color: SpotifyColors.textSecondary),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Abbrechen',
                style: TextStyle(color: SpotifyColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotifyColors.green,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogCtx);
              final created = await prov.createPlaylist(name);
              await prov.addTrackToPlaylist(created, track);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Playlist „$name“ erstellt und „${track.title}“ hinzugefügt!'),
                    backgroundColor: SpotifyColors.surfaceElevated,
                  ),
                );
              }
            },
            child: const Text('Erstellen',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
