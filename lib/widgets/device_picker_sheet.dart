import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'apple_watch_remote_sheet.dart';
import 'equalizer_sheet.dart';

class DevicePickerSheet extends StatefulWidget {
  const DevicePickerSheet({super.key});

  @override
  State<DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<DevicePickerSheet> {
  // Merkt sich geöffnete Lautsprecher-Detailkarten
  final Set<String> _expandedPlayerIds = {};

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('sonos')) return Icons.speaker_rounded;
    if (t.contains('airplay') || t.contains('apple')) return Icons.airplay_rounded;
    if (t.contains('chromecast') ||
        t.contains('cast') ||
        t.contains('google') ||
        t.contains('shield')) {
      return Icons.cast_rounded;
    }
    if (t.contains('phone') || t.contains('iphone') || t.contains('sendspin')) {
      return Icons.smartphone_rounded;
    }
    return Icons.speaker_group_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final active = prov.activePlayer;
    final players = prov.players;

    // Finde alle synchronisierten Lautsprecher
    final syncedSpeakers = players.where((p) {
      if (active == null || p.id == active.id) return false;
      return (p.syncedTo == active.id) ||
          active.groupChilds.contains(p.id) ||
          (p.isSynced && p.syncedTo == active.syncedTo);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: SpotifyColors.textMuted.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header: Titel & Aktionen
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Geräte & Multiroom',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.watch_rounded,
                        color: SpotifyColors.textSecondary, size: 22),
                    tooltip: 'Apple Watch Fernbedienung',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const AppleWatchRemoteSheet(),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync_rounded,
                        color: SpotifyColors.green, size: 22),
                    tooltip: 'Lautsprecher aktualisieren',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      prov.refreshServerData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Suche nach Music Assistant Lautsprechern...'),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: prov.isServerConnected
                          ? SpotifyColors.green
                          : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Music Assistant • ${players.length} Lautsprecher verfügbar',
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 1. Spotify Connect Hero: Aktuelles Hauptgerät
            if (active != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        SpotifyColors.green.withValues(alpha: 0.18),
                        SpotifyColors.surfaceElevated,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SpotifyColors.green.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SpotifyColors.green.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: SpotifyColors.green.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_iconForType(active.type),
                                color: SpotifyColors.green, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'AKTUELLES GERÄT',
                                      style: TextStyle(
                                        color: SpotifyColors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (syncedSpeakers.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: SpotifyColors.green
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+${syncedSpeakers.length} synchronisiert',
                                          style: const TextStyle(
                                            color: SpotifyColors.green,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  active.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  active.isLocal
                                      ? 'Wiedergabe aktiv • Dieses iPhone (Sendspin Hi-Fi)'
                                      : 'Wiedergabe aktiv • ${active.type}',
                                  style: const TextStyle(
                                    color: SpotifyColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              active.isMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: active.isMuted
                                  ? Colors.redAccent
                                  : SpotifyColors.green,
                              size: 22,
                            ),
                            tooltip: active.isMuted
                                ? 'Stummschaltung aufheben'
                                : 'Stummschalten',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              prov.toggleMute(active);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Lautstärkeregler für das aktive Hauptgerät
                      Row(
                        children: [
                          const Icon(Icons.volume_down_rounded,
                              color: SpotifyColors.textSecondary, size: 18),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: SpotifyColors.green,
                                inactiveTrackColor: SpotifyColors.sliderInactive,
                                thumbColor: Colors.white,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                trackHeight: 3.5,
                              ),
                              child: Slider(
                                value: active.volume.toDouble(),
                                min: 0,
                                max: 100,
                                onChanged: (val) {
                                  prov.setVolume(val.toInt());
                                },
                                onChangeEnd: (val) {
                                  prov.flushVolume(active.id);
                                },
                              ),
                            ),
                          ),
                          Text(
                            '${active.volume}%',
                            style: const TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Sektions-Titel
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'WEITERE LAUTSPRECHER IM NETZWERK',
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Tippe auf „Mitspielen“ für Multiroom',
                    style: TextStyle(
                      color: SpotifyColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Liste aller Lautsprecher
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isCurrent = active?.id == player.id;
                  final isAvail = player.isAvailable;
                  final isSynced = (player.syncedTo == active?.id) ||
                      (active != null && active.groupChilds.contains(player.id));
                  final isExpanded = _expandedPlayerIds.contains(player.id);

                  if (isCurrent) {
                    // Das aktive Hauptgerät ist bereits oben im Hero-Banner
                    return const SizedBox.shrink();
                  }

                  return Opacity(
                    opacity: isAvail ? 1.0 : 0.45,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isSynced
                            ? SpotifyColors.green.withValues(alpha: 0.08)
                            : SpotifyColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSynced
                              ? SpotifyColors.green.withValues(alpha: 0.45)
                              : SpotifyColors.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            leading: Icon(
                              _iconForType(player.type),
                              color: isSynced
                                  ? SpotifyColors.green
                                  : (isAvail
                                      ? Colors.white
                                      : SpotifyColors.textMuted),
                              size: 24,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    player.name,
                                    style: TextStyle(
                                      color: isSynced
                                          ? SpotifyColors.green
                                          : Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (isSynced)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: SpotifyColors.green
                                          .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'SPIELT MIT',
                                      style: TextStyle(
                                        color: SpotifyColors.green,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              !isAvail
                                  ? 'Nicht erreichbar (Offline)'
                                  : isSynced
                                      ? '🔗 Synchron mit ${active?.name} • Multiroom'
                                      : player.isPlaying && player.hasActiveTrack
                                          ? '▶️ Spielt eigenständig: ${player.currentTitle}'
                                          : '${player.type} • Lautstärke: ${player.volume}%',
                              style: TextStyle(
                                color: isSynced
                                    ? SpotifyColors.green
                                    : SpotifyColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Multiroom "Mitspielen" Toggle
                                if (isAvail && !player.isLocal)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor: isSynced
                                          ? SpotifyColors.green
                                          : SpotifyColors.surface,
                                      foregroundColor:
                                          isSynced ? Colors.black : Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: isSynced
                                              ? SpotifyColors.green
                                              : SpotifyColors.borderSubtle,
                                        ),
                                      ),
                                    ),
                                    icon: Icon(
                                      isSynced
                                          ? Icons.check_circle_rounded
                                          : Icons.add_circle_outline_rounded,
                                      size: 15,
                                    ),
                                    label: Text(
                                      isSynced ? 'Spielt mit' : 'Mitspielen',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      if (isSynced) {
                                        prov.unsyncSpeaker(player);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${player.name} aus der Gruppe entfernt.'),
                                            duration: const Duration(seconds: 1),
                                            backgroundColor:
                                                SpotifyColors.surfaceElevated,
                                          ),
                                        );
                                      } else {
                                        prov.syncSpeakerWithActive(player);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${player.name} spielt nun synchron mit!'),
                                            duration: const Duration(seconds: 1),
                                            backgroundColor:
                                                SpotifyColors.surfaceElevated,
                                          ),
                                        );
                                      }
                                    },
                                  ),

                                const SizedBox(width: 4),

                                // Aufklappen für Lautstärke & Transfer
                                IconButton(
                                  icon: Icon(
                                    isExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: SpotifyColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (isExpanded) {
                                        _expandedPlayerIds.remove(player.id);
                                      } else {
                                        _expandedPlayerIds.add(player.id);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              // Tappen auf die Zeile klappt die Steuerung auf (iPhone läuft ungestört weiter!)
                              setState(() {
                                if (isExpanded) {
                                  _expandedPlayerIds.remove(player.id);
                                } else {
                                  _expandedPlayerIds.add(player.id);
                                }
                              });
                            },
                          ),

                          // Erweiterte Steuerung: Einzellautstärke, Stummschaltung & Transfer
                          if (isExpanded && isAvail)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                children: [
                                  const Divider(
                                      color: SpotifyColors.borderSubtle,
                                      height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          player.isMuted
                                              ? Icons.volume_off_rounded
                                              : Icons.volume_up_rounded,
                                          color: player.isMuted
                                              ? Colors.redAccent
                                              : SpotifyColors.textSecondary,
                                          size: 20,
                                        ),
                                        tooltip: player.isMuted
                                            ? 'Stummschaltung aufheben'
                                            : 'Stummschalten',
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          prov.toggleMute(player);
                                        },
                                      ),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor: isSynced
                                                ? SpotifyColors.green
                                                : Colors.white70,
                                            inactiveTrackColor:
                                                SpotifyColors.sliderInactive,
                                            thumbColor: Colors.white,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                    enabledThumbRadius: 5),
                                            trackHeight: 3,
                                          ),
                                          child: Slider(
                                            value: player.volume.toDouble(),
                                            min: 0,
                                            max: 100,
                                            onChanged: (val) {
                                              prov.setPlayerVolume(
                                                  player, val.toInt());
                                            },
                                            onChangeEnd: (val) {
                                              prov.flushVolume(player.id);
                                            },
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${player.volume}%',
                                        style: const TextStyle(
                                          color: SpotifyColors.textSecondary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (!player.isLocal)
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: SpotifyColors.borderSubtle),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                              Icons.power_settings_new_rounded,
                                              size: 16),
                                          label: const Text('Power',
                                              style: TextStyle(fontSize: 11)),
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            prov.togglePlayerPower(player);
                                          },
                                        ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: SpotifyColors.green,
                                          side: BorderSide(
                                              color: SpotifyColors.green
                                                  .withValues(alpha: 0.5)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.tune_rounded,
                                            size: 16),
                                        label: const Text('DSP Equalizer',
                                            style: TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          prov.loadDspForPlayer(player.id);
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) =>
                                                const EqualizerSheet(),
                                          );
                                        },
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              SpotifyColors.surfaceElevated,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            side: const BorderSide(
                                                color: SpotifyColors.borderSubtle),
                                          ),
                                        ),
                                        icon: const Icon(
                                            Icons.swap_horiz_rounded,
                                            size: 16),
                                        label: const Text(
                                          'Hierhin wechseln',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.mediumImpact();
                                          prov.transferPlaybackTo(player);
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Wiedergabe übertragen auf: ${player.name}'),
                                              duration:
                                                  const Duration(seconds: 1),
                                              backgroundColor:
                                                  SpotifyColors.surfaceElevated,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
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
