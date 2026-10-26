import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/album_card.dart';
import '../widgets/device_picker_sheet.dart';
import '../widgets/downloads_sheet.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_edit_dialog.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/track_tile.dart';
import '../widgets/update_dialog.dart';
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
          // Next-Gen Studio Command Top Bar
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leadingWidth: 52,
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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: prov.isServerConnected
                            ? SpotifyColors.orange
                            : Colors.amber,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: SpotifyColors.orange,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prov.activePlayer != null
                            ? 'STUDIO • ${prov.activePlayer!.name.toUpperCase()}'
                            : 'MUSIC ASSISTANT STUDIO',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SpotifyColors.orangeLight,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  _getGreeting(prov),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            actions: [
              // 1. Dezent platzierter KI-DJ
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        SpotifyColors.orange.withValues(alpha: 0.25),
                        Colors.deepPurple.withValues(alpha: 0.25),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: SpotifyColors.orangeLight, size: 18),
                ),
                tooltip: 'KI-DJ Radio',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VirtualDjScreen()),
                  );
                },
              ),
              // 2. Spotify Connect Geräte & Multiroom
              IconButton(
                icon: Icon(
                  prov.activePlayer?.isLocal == true
                      ? Icons.smartphone_rounded
                      : Icons.speaker_rounded,
                  color: prov.isPlaying ? SpotifyColors.green : Colors.white,
                  size: 22,
                ),
                tooltip: 'Geräte & Multiroom',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const DevicePickerSheet(),
                  );
                },
              ),
              // 3. Aufgeräumtes Overflow-Menü
              PopupMenuButton<String>(
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                    if (prov.hasUpdate)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: SpotifyColors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                color: SpotifyColors.surfaceElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: SpotifyColors.borderSubtle),
                ),
                onSelected: (val) {
                  HapticFeedback.lightImpact();
                  switch (val) {
                    case 'settings':
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                      break;
                    case 'history':
                      _showHistorySheet(context, prov);
                      break;
                    case 'announce':
                      _showAnnouncementDialog(context, prov);
                      break;
                    case 'notifications':
                      _showNotificationsSheet(context);
                      break;
                    case 'feedback':
                      FeedbackSheet.show(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings_outlined, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        const Text('Einstellungen', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                        if (prov.hasUpdate) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SpotifyColors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('UPDATE', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text('Zuletzt gehört', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'announce',
                    child: Row(
                      children: [
                        Icon(Icons.campaign_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text('Durchsage', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'notifications',
                    child: Row(
                      children: [
                        Icon(Icons.notifications_none_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text('Mitteilungen & Status', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'feedback',
                    child: Row(
                      children: [
                        Icon(Icons.bug_report_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text('Feedback & Support', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                      ],
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

          // Filter Chips (Musik-Fokus)
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

            // Section: Deine Mediathek (Playlists & Alben)
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

  Widget _buildChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7.5),
        decoration: BoxDecoration(
          gradient: isSelected ? SpotifyColors.emberGradient : null,
          color: isSelected ? null : SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? SpotifyColors.orangeLight
                : SpotifyColors.borderSubtle,
            width: 0.9,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: SpotifyColors.orange.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTile(
      BuildContext context, Playlist playlist, MusicProvider prov) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailScreen(playlist: playlist),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: SpotifyColors.obsidianCardGradient,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: SpotifyColors.borderSubtle,
            width: 0.9,
          ),
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
                        Icons.music_note_rounded,
                        color: SpotifyColors.orange,
                        size: 22,
                      ),
                    )
                  : const Icon(
                      Icons.music_note_rounded,
                      color: SpotifyColors.orange,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: SpotifyColors.orange,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: SpotifyColors.orange,
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(
                  color: SpotifyColors.orange,
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19.5,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationSectionHeader(
      BuildContext context, String title, [String? subtitle]) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 24,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: SpotifyColors.orange,
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(
                  color: SpotifyColors.orange,
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  Text(
                    subtitle.toUpperCase(),
                    style: const TextStyle(
                      color: SpotifyColors.orangeLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
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
        return Consumer<MusicProvider>(
          builder: (ctx, prov, _) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Systemstatus & Mitteilungen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          prov.refreshServerData();
                        },
                        icon: const Icon(Icons.sync,
                            size: 16, color: SpotifyColors.green),
                        label: const Text(
                          'Sync',
                          style: TextStyle(
                            color: SpotifyColors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: SpotifyColors.borderSubtle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: SpotifyColors.surfaceHighlight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        prov.isServerConnected
                            ? Icons.cloud_done
                            : Icons.cloud_off,
                        color: prov.isServerConnected
                            ? SpotifyColors.green
                            : Colors.amber,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      prov.isServerConnected
                          ? 'Music Assistant Server verbunden'
                          : 'Lokaler / Offline-Modus aktiv',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${prov.serverUrl} • ${prov.players.length} Wiedergabegeräte erkannt',
                      style: const TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 12),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: SpotifyColors.surfaceHighlight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.speaker_group,
                          color: SpotifyColors.green, size: 20),
                    ),
                    title: Text(
                      'Aktiver Ausgang: ${prov.activePlayer?.name ?? "iPhone"}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      prov.isPlaying
                          ? 'Spielt gerade: ${prov.currentTrack?.title ?? "Musik"}'
                          : 'Bereit für Multiroom-Streaming',
                      style: const TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: SpotifyColors.textSecondary),
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const DevicePickerSheet(),
                      );
                    },
                  ),
                  if (prov.hasActiveSleepTimer)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: SpotifyColors.surfaceHighlight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bedtime,
                            color: SpotifyColors.green, size: 20),
                      ),
                      title: Text(
                        'Einschlaftimer aktiv (${prov.formattedSleepTimerRemaining})',
                        style: const TextStyle(
                            color: SpotifyColors.green,
                            fontWeight: FontWeight.bold),
                      ),
                      trailing: TextButton(
                        onPressed: () => prov.clearSleepTimer(),
                        child: const Text('Stoppen',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ),
                ],
              ),
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
        return Consumer<MusicProvider>(
          builder: (ctx, liveProv, _) {
            final history = liveProv.recentlyPlayedTracks;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Zuletzt gehört',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (history.isNotEmpty)
                          TextButton(
                            onPressed: () => liveProv.clearRecentlyPlayed(),
                            child: const Text(
                              'Verlauf leeren',
                              style: TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(color: SpotifyColors.borderSubtle, height: 1),
                  Flexible(
                    child: history.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Noch keine kürzlich gehörten Titel.',
                                style: TextStyle(
                                    color: SpotifyColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: history.length,
                            itemBuilder: (c, idx) {
                              final Track item = history[idx];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    color: SpotifyColors.surfaceElevated,
                                    child: item.imageUrl != null
                                        ? Image.network(
                                            item.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(Icons.music_note,
                                                    color: SpotifyColors.green),
                                          )
                                        : const Icon(Icons.music_note,
                                            color: SpotifyColors.green),
                                  ),
                                ),
                                title: Text(item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(item.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: SpotifyColors.textSecondary)),
                                trailing: const Icon(Icons.play_circle_outline,
                                    color: SpotifyColors.green),
                                onTap: () {
                                  liveProv.playTrack(item);
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
