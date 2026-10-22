import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

class DevicePickerSheet extends StatelessWidget {
  const DevicePickerSheet({super.key});

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('sonos')) return Icons.speaker;
    if (t.contains('airplay') || t.contains('apple')) return Icons.airplay;
    if (t.contains('chromecast') || t.contains('cast') || t.contains('google') || t.contains('shield')) {
      return Icons.cast;
    }
    if (t.contains('phone') || t.contains('iphone')) return Icons.smartphone;
    return Icons.speaker_group;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final active = prov.activePlayer;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
            const SizedBox(height: 14),

            // Title & Refresh Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Text(
                    'Mit einem Gerät verbinden',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.sync,
                        color: SpotifyColors.green, size: 22),
                    tooltip: 'Lautsprecher neu suchen',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.refreshServerData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lautsprecher werden aktualisiert...'),
                          duration: Duration(seconds: 1),
                          backgroundColor: SpotifyColors.surfaceElevated,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: prov.isServerConnected
                          ? SpotifyColors.green
                          : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Music Assistant (${prov.players.length} Geräte gefunden)',
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active Device Volume Slider (if any active player)
            if (active != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SpotifyColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: SpotifyColors.green.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(_iconForType(active.type),
                              color: SpotifyColors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  active.name,
                                  style: const TextStyle(
                                    color: SpotifyColors.green,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  active.isLocal
                                      ? 'Wiedergabe aktiv • iPhone Audio'
                                      : 'Wiedergabe aktiv • ${active.type}',
                                  style: const TextStyle(
                                    color: SpotifyColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${active.volume}%',
                            style: const TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.volume_down,
                              color: SpotifyColors.textSecondary, size: 18),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: SpotifyColors.green,
                                inactiveTrackColor: SpotifyColors.sliderInactive,
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                trackHeight: 3,
                              ),
                              child: Slider(
                                value: active.volume.toDouble(),
                                min: 0,
                                max: 100,
                                onChanged: (val) {
                                  prov.setVolume(val.toInt());
                                },
                              ),
                            ),
                          ),
                          const Icon(Icons.volume_up,
                              color: SpotifyColors.textSecondary, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'WÄHLE EIN GERÄT',
                style: TextStyle(
                  color: SpotifyColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Device list (full height scrollable)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: prov.players.length,
                itemBuilder: (context, index) {
                  final player = prov.players[index];
                  final isCurrent = active?.id == player.id;
                  final isAvail = player.isAvailable;

                  return Opacity(
                    opacity: isAvail ? 1.0 : 0.45,
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(
                          _iconForType(player.type),
                          color: isCurrent
                              ? SpotifyColors.green
                              : (isAvail ? SpotifyColors.textSecondary : SpotifyColors.textMuted),
                          size: 24,
                        ),
                        title: Text(
                          player.name,
                          style: TextStyle(
                            color: isCurrent
                                ? SpotifyColors.green
                                : (isAvail ? Colors.white : SpotifyColors.textSecondary),
                            fontSize: 15,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          !isAvail
                              ? 'Nicht erreichbar (Offline)'
                              : player.isLocal
                                  ? 'Lokaler iPhone-Lautsprecher & Kopfhörer'
                                  : '${player.type} • Lautstärke ${player.volume}%',
                          style: TextStyle(
                            color: isAvail
                                ? SpotifyColors.textSecondary
                                : SpotifyColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.check_circle,
                                color: SpotifyColors.green, size: 20)
                            : null,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          prov.setActivePlayer(player);
                        },
                      ),
                    ),
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
