import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/album_card.dart';
import '../widgets/track_tile.dart';
import 'playlist_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  String _selectedCategory = 'Alle';

  static const List<Map<String, dynamic>> _genres = [
    {'name': 'Pop', 'color': Color(0xFFE13300), 'icon': Icons.star},
    {'name': 'Rock', 'color': Color(0xFF1E3264), 'icon': Icons.electric_bolt},
    {'name': 'Hip-Hop', 'color': Color(0xFF8D67AB), 'icon': Icons.mic},
    {'name': 'Dance & Electronic', 'color': Color(0xFFE8115B), 'icon': Icons.graphic_eq},
    {'name': 'Indie', 'color': Color(0xFF148A08), 'icon': Icons.park},
    {'name': 'Chill & Lo-Fi', 'color': Color(0xFF503750), 'icon': Icons.spa},
    {'name': 'Charts & Top 50', 'color': Color(0xFF0D73EC), 'icon': Icons.trending_up},
    {'name': 'Fokus & Ambient', 'color': Color(0xFFBC5900), 'icon': Icons.psychology},
    {'name': 'Gaming', 'color': Color(0xFF477D95), 'icon': Icons.sports_esports},
    {'name': 'Home Assistant Radio', 'color': Color(0xFFFF5C00), 'icon': Icons.home},
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, MusicProvider prov) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      prov.search(query);
    });
  }

  void _executeSearch(String query, MusicProvider prov) {
    _debounceTimer?.cancel();
    _searchCtrl.text = query;
    setState(() {});
    prov.search(query);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final query = prov.lastSearchQuery;
    final isSearching = prov.isSearching;
    final tracks = prov.searchResultsTracks;
    final playlists = prov.searchResultsPlaylists;
    final albums = prov.searchResultsAlbums;
    final podcasts = prov.searchResultsPodcasts;
    final hasResults =
        tracks.isNotEmpty || playlists.isNotEmpty || albums.isNotEmpty || podcasts.isNotEmpty;

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header "Suche" im Studio-Look
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: SpotifyColors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'KATALOG & SERVER-INDEX',
                          style: TextStyle(
                            color: SpotifyColors.orangeLight,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Suche',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Obsidian-Ember Studio Search Bar Input
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: SpotifyColors.obsidianCardGradient,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: SpotifyColors.orange.withValues(alpha: 0.45),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SpotifyColors.orange.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) => _executeSearch(val, prov),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    onChanged: (val) => _onSearchChanged(val, prov),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: SpotifyColors.orange,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: SpotifyColors.textSecondary,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                                prov.search('');
                              },
                            )
                          : null,
                      hintText:
                          'Songs, Künstler, Alben oder Hörbücher suchen...',
                      hintStyle: const TextStyle(
                        color: SpotifyColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

            // Loading Indicator
            if (isSearching)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(SpotifyColors.green),
                    ),
                  ),
                ),
              )
            // Query Active
            else if (query.isNotEmpty) ...[
              // Category Filter Chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      _categoryChip('Alle'),
                      const SizedBox(width: 8),
                      _categoryChip('Titel (${tracks.length})'),
                      const SizedBox(width: 8),
                      _categoryChip('Playlists (${playlists.length})'),
                      const SizedBox(width: 8),
                      _categoryChip('Alben (${albums.length})'),
                      const SizedBox(width: 8),
                      _categoryChip('Podcasts (${podcasts.length})'),
                    ],
                  ),
                ),
              ),

              // No results screen
              if (!hasResults)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.search_off,
                              size: 52, color: SpotifyColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'Keine Ergebnisse für "$query"',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Überprüfe die Schreibweise oder versuche einen anderen Begriff.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                // Playlists Row
                if ((_selectedCategory == 'Alle' ||
                        _selectedCategory.startsWith('Playlists')) &&
                    playlists.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Text(
                        'Playlists',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 195,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final p = playlists[index];
                          return AlbumCard(
                            playlist: p,
                            size: 140,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistDetailScreen(playlist: p),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Albums Row
                if ((_selectedCategory == 'Alle' ||
                        _selectedCategory.startsWith('Alben')) &&
                    albums.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Text(
                        'Alben',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 195,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: albums.length,
                        itemBuilder: (context, index) {
                          final a = albums[index];
                          return AlbumCard(
                            playlist: a,
                            size: 140,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistDetailScreen(playlist: a),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Podcasts Row
                if ((_selectedCategory == 'Alle' ||
                        _selectedCategory.startsWith('Podcasts')) &&
                    podcasts.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Text(
                        'Podcasts & Shows',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 195,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: podcasts.length,
                        itemBuilder: (context, index) {
                          final pod = podcasts[index];
                          return AlbumCard(
                            playlist: pod,
                            size: 140,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PlaylistDetailScreen(playlist: pod),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Tracks List
                if ((_selectedCategory == 'Alle' ||
                        _selectedCategory.startsWith('Titel')) &&
                    tracks.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Text(
                        'Songs',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = tracks[index];
                        return TrackTile(
                          track: track,
                          onTap: () {
                            prov.playTrack(track, newQueue: tracks);
                          },
                        );
                      },
                      childCount: tracks.length,
                    ),
                  ),
                ],
              ],
            ]
            // Default: Genre Explore Grid
            else ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: Text(
                    'Alles durchsuchen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final genre = _genres[index];
                      return _buildGenreCard(genre, prov);
                    },
                    childCount: _genres.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String title) {
    final categoryPrefix = title.split(' ').first;
    final isSelected = _selectedCategory == categoryPrefix;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedCategory = categoryPrefix;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
        decoration: BoxDecoration(
          gradient: isSelected ? SpotifyColors.emberGradient : null,
          color: isSelected ? null : SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? SpotifyColors.orangeLight
                : SpotifyColors.borderSubtle,
            width: 0.9,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreCard(Map<String, dynamic> genre, MusicProvider prov) {
    final baseColor = genre['color'] as Color;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final name = genre['name'] as String;
        _executeSearch(name, prov);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              baseColor.withValues(alpha: 0.92),
              Color.lerp(baseColor, Colors.black, 0.58) ?? Colors.black,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.9,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    genre['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'EXPLORE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: -6,
              bottom: -8,
              child: Transform.rotate(
                angle: 0.32,
                child: Icon(
                  genre['icon'] as IconData,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
