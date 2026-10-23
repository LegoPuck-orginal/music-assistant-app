import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/album_card.dart';
import '../widgets/audiobook_card.dart';
import '../widgets/downloads_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_edit_dialog.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/track_tile.dart';
import '../widgets/update_dialog.dart';
import 'audiobook_detail_screen.dart';
import 'playlist_detail_screen.dart';
import 'settings_screen.dart';
import 'virtual_dj_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedFilter = 'Alle';

  String _getGreeting(MusicProvider prov) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 5) {
      greeting = 'Gute Nacht';
    } else if (hour < 12) {
      greeting = 'Guten Morgen';
    } else if (hour < 18) {
      greeting = 'Guten Tag';
    } else {
      greeting = 'Guten Abend';
    }

    final name = prov.currentUser?.effectiveName;
    if (name != null && name.isNotEmpty && name != 'Gast-Hörer') {
      return '$greeting, ${name.split(' ').first}';
    }
    return greeting;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final allPlaylists = prov.playlists;

    final filteredPlaylists = _selectedFilter == 'Alle'
        ? allPlaylists
        : _selectedFilter == 'Musik'
            ? allPlaylists.where((p) => p.type != 'podcast').toList()
            : _selectedFilter == 'Podcasts'
                ? allPlaylists.where((p) => p.type == 'podcast').toList()
                : <Playlist>[];

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: CustomScrollView(
        slivers: [
          // Spotify Top Bar
          SliverAppBar(
            floating: true,
            backgroundColor: SpotifyColors.pureBlack,
            elevation: 0,
            leadingWidth: 50,
            leading: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Center(
                child: ProfileAvatar(
                  user: prov.currentUser,
                  radius: 17,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ProfileEditDialog.show(context);
                  },
                ),
              ),
            ),
            title: Text(
              _getGreeting(prov),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.campaign_outlined, color: Colors.white),
                tooltip: 'Durchsage an Lautsprecher',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAnnouncementDialog(context, prov);
                },
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                tooltip: 'Mitteilungen',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showNotificationsSheet(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                tooltip: 'Zuletzt gehört',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showHistorySheet(context, prov);
                },
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.white),
                    tooltip: 'Einstellungen',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  if (prov.hasUpdate)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SpotifyColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Update Banner (if an update is available)
          if (prov.hasUpdate && prov.updateInfo != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    UpdateDialog.show(context, prov.updateInfo!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: SpotifyColors.green.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.system_update_alt,
                            color: SpotifyColors.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Neues Update: v${prov.updateInfo!.latestVersion}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Text(
                          'Installieren',
                          style: TextStyle(
                            color: SpotifyColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            color: SpotifyColors.green, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Live Multiroom-Überwachung: Zeigt aktive Lautsprecher im Homelab & erlaubt Steuerung
          if (prov.otherPlayingPlayers.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: prov.otherPlayingPlayers.map((player) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: SpotifyColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: SpotifyColors.orange.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SpotifyColors.orange.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: SpotifyColors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.volume_up,
                              color: SpotifyColors.orange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        player.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: SpotifyColors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: SpotifyColors.orange
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'SPIELT GERADE',
                                        style: TextStyle(
                                          color: SpotifyColors.orange,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${player.currentTitle ?? "Wiedergabe aktiv"} • ${player.currentArtist ?? ""}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SpotifyColors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.touch_app, size: 14),
                            label: const Text(
                              'Steuern',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              prov.takeOverControl(player);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Steuerung übernommen für: ${player.name}'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: SpotifyColors.surfaceElevated,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Filter Chips
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildChip('Alle'),
                  const SizedBox(width: 8),
                  _buildChip('Musik'),
                  const SizedBox(width: 8),
                  _buildChip('Podcasts'),
                  const SizedBox(width: 8),
                  _buildChip('Hörbücher'),
                  const SizedBox(width: 8),
                  _buildChip('Heruntergeladen'),
                ],
              ),
            ),
          ),

          // Heruntergeladen View vs Regular Content
          if (_selectedFilter == 'Heruntergeladen') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: SpotifyColors.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          prov.isOfflineMode ? Icons.cloud_off : Icons.download_done,
                          color: SpotifyColors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prov.isOfflineMode
                                  ? 'Offline-Modus aktiv'
                                  : 'Offline-Downloads bereit',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${prov.downloadedTracks.length} Titel • ${prov.formattedDownloadedSize} belegt',
                              style: const TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: SpotifyColors.green,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const DownloadsSheet(),
                          );
                        },
                        child: const Text('Verwalten',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (prov.downloadedTracks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.download_for_offline_outlined,
                          size: 54,
                          color: SpotifyColors.textMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Keine Offline-Titel gefunden',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Lade Musik in Playlists oder Titeln herunter, um sie offline zu hören.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SpotifyColors.green,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const Icon(Icons.shuffle, size: 16),
                        label: const Text('Zufallswiedergabe',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          prov.playTrack(prov.downloadedTracks.first,
                              newQueue: prov.downloadedTracks);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = prov.downloadedTracks[index];
                    return TrackTile(
                      track: track,
                      index: index + 1,
                      onTap: () {
                        prov.playTrack(track, newQueue: prov.downloadedTracks);
                      },
                    );
                  },
                  childCount: prov.downloadedTracks.length,
                ),
              ),
            ],
          ] else ...[
            // Spotify Virtual AI DJ Card
            if (_selectedFilter != 'Podcasts')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _buildVirtualDjBanner(context, prov),
                ),
              ),

          if (filteredPlaylists.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        _selectedFilter == 'Podcasts'
                            ? Icons.podcasts
                            : Icons.music_off,
                        size: 52,
                        color: SpotifyColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Keine ${_selectedFilter == 'Podcasts' ? 'Podcasts' : 'Inhalte'} gefunden',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Füge in Music Assistant neue ${_selectedFilter == 'Podcasts' ? 'Podcasts' : 'Musik'} hinzu.',
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // 2x3 Quick Tiles ("Kürzlich gehört")
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: filteredPlaylists.take(6).length,
                  itemBuilder: (context, index) {
                    final p = filteredPlaylists[index];
                    return _buildQuickTile(context, p, prov);
                  },
                ),
              ),
            ),

            // Dynamic Recommendation Rows (Last.fm, Most Played, Similar Artists, Forgotten Tracks)
            if (_selectedFilter != 'Podcasts' && prov.recommendations.isNotEmpty) ...[
              for (final row in prov.recommendations) ...[
                SliverToBoxAdapter(
                  child: _buildRecommendationSectionHeader(
                    context,
                    row.title,
                    row.subtitle,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: row.items.isNotEmpty &&
                            row.items.first.mediaType == 'artist'
                        ? 165
                        : 210,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: row.items.length,
                      itemBuilder: (context, index) {
                        final item = row.items[index];
                        return RecommendationCard(
                          item: item,
                          contextItems: row.items,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ] else if (_selectedFilter != 'Podcasts' && prov.isLoadingRecommendations) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                SpotifyColors.green),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Lade Empfehlungen aus deinem Hörverlauf...',
                          style: TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Section: Hörspiele & Hörbücher (Die drei ???)
            if (_selectedFilter == 'Alle' || _selectedFilter == 'Hörbücher') ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  'Hörspiel-Klassiker: Die drei ???',
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 235,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: prov.audiobooks.length,
                    itemBuilder: (context, index) {
                      final ab = prov.audiobooks[index];
                      return AudiobookCard(
                        audiobook: ab,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AudiobookDetailScreen(audiobook: ab),
                            ),
                          );
                        },
                        onPlay: () {
                          prov.playAudiobook(ab);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            // Section: Deine Mediathek (Playlists & Alben)
            if (_selectedFilter != 'Hörbücher') ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  _selectedFilter == 'Podcasts'
                      ? 'Deine Podcasts & Shows (${prov.podcasts.length})'
                      : 'Deine Playlists & Favoriten',
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 215,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredPlaylists.length,
                    itemBuilder: (context, index) {
                      final p = filteredPlaylists[index];
                      return AlbumCard(
                        playlist: p,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: p),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],

            if (_selectedFilter != 'Podcasts' && prov.albums.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  context,
                  'Alben in deiner Mediathek',
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 215,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: prov.albums.length,
                    itemBuilder: (context, index) {
                      final p = prov.albums[index];
                      return AlbumCard(
                        playlist: p,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(playlist: p),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ],

          // Space for bottom MiniPlayer
          const SliverToBoxAdapter(
            child: SizedBox(height: 110),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualDjBanner(BuildContext context, MusicProvider prov) {
    final isDjActive = prov.isDjActive;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (!isDjActive) {
          prov.startVirtualDj();
        }
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VirtualDjScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF0D2538),
              Color(0xFF0B1E19),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDjActive
                ? const Color(0xFF00F2FE).withValues(alpha: 0.6)
                : const Color(0xFF1E3A8A).withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDjActive
                      ? const Color(0xFF00F2FE)
                      : const Color(0xFF38BDF8))
                  .withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Mini Glowing Pulsing DJ Orb Icon
            Container(
              width: 50,
              height: 50,
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
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0A0E17),
                  ),
                  child: Center(
                    child: Icon(
                      isDjActive ? Icons.graphic_eq : Icons.auto_awesome,
                      color: const Color(0xFF00F2FE),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          'KI-DJ',
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
                        isDjActive
                            ? 'Vibe: ${prov.currentDjVibe.title}'
                            : 'Dein persönlicher DJ',
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isDjActive
                        ? (prov.djSpeechText ?? 'Tippe für Moderation & Vibe')
                        : 'Bereit für deine Session? Mix & Sprachansage starten',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Green/Cyan Play Button
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F2FE), SpotifyColors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.black,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? SpotifyColors.green : SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTile(
      BuildContext context, Playlist playlist, MusicProvider prov) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: playlist),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              color: SpotifyColors.surfaceHighlight,
              child: playlist.imageUrl != null
                  ? Image.network(
                      playlist.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.music_note,
                        color: SpotifyColors.textSecondary,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.music_note,
                      color: SpotifyColors.textSecondary,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _buildRecommendationSectionHeader(
      BuildContext context, String title, [String? subtitle]) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null && subtitle.isNotEmpty) ...[
            Text(
              subtitle.toUpperCase(),
              style: const TextStyle(
                color: SpotifyColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Neuigkeiten & Mitteilungen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: SpotifyColors.surfaceHighlight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: SpotifyColors.green, size: 20),
                  ),
                  title: const Text('Music Assistant 2.10 ist online',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Alle Lautsprecher im Homelab sind betriebsbereit.',
                      style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHistorySheet(BuildContext context, MusicProvider prov) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  'Zuletzt gehört',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: prov.queue.take(8).length,
                  itemBuilder: (c, idx) {
                    final Track item = prov.queue[idx];
                    return ListTile(
                      leading: const Icon(Icons.music_note, color: SpotifyColors.green),
                      title: Text(item.title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: Text(item.artist,
                          style: const TextStyle(color: SpotifyColors.textSecondary)),
                      onTap: () {
                        prov.playTrack(item);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
}
