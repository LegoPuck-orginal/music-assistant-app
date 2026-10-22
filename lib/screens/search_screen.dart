import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

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
    {'name': 'Home Assistant Radio', 'color': Color(0xFF1DB954), 'icon': Icons.home},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();

    // Collect all tracks across playlists for search
    final allTracks = <Track>[];
    for (final p in prov.playlists) {
      for (final t in p.tracks) {
        if (!allTracks.any((x) => x.id == t.id)) {
          allTracks.add(t);
        }
      }
    }

    final searchResults = _query.trim().isEmpty
        ? <Track>[]
        : allTracks.where((t) {
            final q = _query.toLowerCase();
            return t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q) ||
                t.album.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header "Suche"
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  'Suche',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),

            // Search Bar Input
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.black, fontSize: 15),
                    onChanged: (val) {
                      setState(() {
                        _query = val;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.black54),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.black54),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _query = '';
                                });
                              },
                            )
                          : null,
                      hintText: 'Was möchtest du hören?',
                      hintStyle: const TextStyle(
                        color: Colors.black54,
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

            // Content: Results or Genre Grid
            if (_query.trim().isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Ergebnisse für "$_query" (${searchResults.length})',
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (searchResults.isEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: SpotifyColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'Keine Titel gefunden',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Versuche es mit einem anderen Suchbegriff.',
                            style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = searchResults[index];
                      return TrackTile(
                        track: track,
                        onTap: () {
                          prov.playTrack(track, newQueue: searchResults);
                        },
                      );
                    },
                    childCount: searchResults.length,
                  ),
                ),
              ],
            ] else ...[
              // Default: Alles durchsuchen (Genre Grid)
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
                      return _buildGenreCard(genre);
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

  Widget _buildGenreCard(Map<String, dynamic> genre) {
    return Container(
      decoration: BoxDecoration(
        color: genre['color'] as Color,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              genre['name'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(
            right: -8,
            bottom: -8,
            child: Transform.rotate(
              angle: 0.35,
              child: Icon(
                genre['icon'] as IconData,
                size: 54,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
