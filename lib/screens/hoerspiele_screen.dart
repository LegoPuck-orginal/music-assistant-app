import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'audiobook_detail_screen.dart';

class HoerspieleScreen extends StatefulWidget {
  const HoerspieleScreen({super.key});

  @override
  State<HoerspieleScreen> createState() => _HoerspieleScreenState();
}

class _HoerspieleScreenState extends State<HoerspieleScreen> {
  String _selectedSeries = 'Alle';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final allAudiobooks = prov.audiobooks;

    // Filter by series & search query
    var filtered = allAudiobooks.where((ab) {
      if (_selectedSeries != 'Alle' &&
          !ab.series.toLowerCase().contains(_selectedSeries.toLowerCase())) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesTitle = ab.title.toLowerCase().contains(q);
        final matchesSeries = ab.series.toLowerCase().contains(q);
        final matchesEpisode = 'folge ${ab.episodeNumber}'.contains(q);
        final matchesNarrator = ab.narrator.toLowerCase().contains(q);
        if (!matchesTitle && !matchesSeries && !matchesEpisode && !matchesNarrator) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: CustomScrollView(
        slivers: [
          // Sleek Header
          SliverAppBar(
            floating: true,
            pinned: false,
            backgroundColor: SpotifyColors.pureBlack,
            elevation: 0,
            title: const Row(
              children: [
                Icon(Icons.headphones_rounded, color: SpotifyColors.orange, size: 24),
                SizedBox(width: 10),
                Text(
                  'Hörspiele',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
                tooltip: 'Hörspiel suchen',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchCtrl.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ),
            ],
          ),

          // In-Screen Search Bar
          if (_isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: SpotifyColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: SpotifyColors.orange.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, color: SpotifyColors.orange, size: 20),
                      hintText: 'Hörspiel, Folge oder Serie suchen...',
                      hintStyle: TextStyle(color: SpotifyColors.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ),

          // Filter Chips for Series
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildSeriesChip('Alle'),
                  const SizedBox(width: 8),
                  _buildSeriesChip('Die drei ???'),
                  const SizedBox(width: 8),
                  _buildSeriesChip('TKKG'),
                  const SizedBox(width: 8),
                  _buildSeriesChip('Sherlock Holmes'),
                ],
              ),
            ),
          ),

          // Banner: Beliebte Hörspiele
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        SpotifyColors.orange.withValues(alpha: 0.22),
                        SpotifyColors.surfaceElevated,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SpotifyColors.orange.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: SpotifyColors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.theater_comedy_rounded,
                          color: SpotifyColors.orange,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hörspiel-Bibliothek',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${allAudiobooks.length} Folgen verfügbar • Volle Kapitelübersicht',
                              style: const TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Episodes Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _selectedSeries == 'Alle'
                    ? 'Alle Folgen (${filtered.length})'
                    : '$_selectedSeries (${filtered.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // Grid / List of Hörspiele
          if (filtered.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'Keine Hörspiele gefunden',
                    style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final ab = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AudiobookDetailScreen(audiobook: ab),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: SpotifyColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: SpotifyColors.borderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ab.imageUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 64,
                                    height: 64,
                                    color: SpotifyColors.surface,
                                    child: const Icon(Icons.headphones, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: SpotifyColors.orange.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'FOLGE ${ab.episodeNumber}',
                                        style: const TextStyle(
                                          color: SpotifyColors.orange,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      ab.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${ab.series} • ${ab.formattedDuration} • ${ab.chapters.length} Teile',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: SpotifyColors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: SpotifyColors.orange,
                                  size: 34,
                                ),
                                tooltip: 'Abspielen',
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  prov.playAudiobook(ab);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 90),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesChip(String series) {
    final isSelected = _selectedSeries == series;
    return FilterChip(
      label: Text(series),
      selected: isSelected,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedSeries = series;
        });
      },
      backgroundColor: SpotifyColors.surfaceElevated,
      selectedColor: SpotifyColors.orange,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? SpotifyColors.orange : SpotifyColors.borderSubtle,
        width: 0.8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
