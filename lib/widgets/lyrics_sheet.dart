import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../services/lyrics_service.dart';
import '../theme/spotify_colors.dart';

/// Spotify-Style Karaoke & Synced Lyrics Sheet im modernen Adobe-Orange-Design.
/// Unterstützt zeitgestempeltes Auto-Scrolling, Zeilen-Springen per Fingertipp
/// und automatische Synchronisation mit dem echten Wiedergabefortschritt.
class LyricsSheet extends StatefulWidget {
  final Track track;

  const LyricsSheet({
    super.key,
    required this.track,
  });

  static Future<void> show(BuildContext context, Track track) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LyricsSheet(track: track),
    );
  }

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  final LyricsService _lyricsService = LyricsService();
  final ScrollController _scrollController = ScrollController();

  List<LyricLine> _lines = [];
  bool _isLoading = true;
  int _currentLineIndex = -1;
  bool _userIsScrolling = false;
  String? _lastTrackId;
  bool _initialLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoaded) {
      _initialLoaded = true;
      final prov = context.read<MusicProvider>();
      final activeTrack = prov.currentTrack ?? widget.track;
      _loadLyrics(activeTrack, prov: prov);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics(Track track, {MusicProvider? prov}) async {
    _lastTrackId = track.id;
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final api = prov?.api;
    final res = await _lyricsService.getLyricsForTrack(track, api: api);
    if (mounted) {
      setState(() {
        _lines = res;
        _isLoading = false;
      });
    }
  }

  void _scrollToActiveLine(int index) {
    if (_userIsScrolling || !_scrollController.hasClients || index < 0) return;

    const itemHeight = 60.0;
    final targetOffset = (index * itemHeight) - 180.0;
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final activeTrack = prov.currentTrack ?? widget.track;

    if (_lastTrackId != null && _lastTrackId != activeTrack.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLyrics(activeTrack, prov: prov);
      });
    }

    final newIndex =
        _lyricsService.findCurrentLineIndex(_lines, prov.currentPosition);

    if (newIndex != _currentLineIndex) {
      _currentLineIndex = newIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(_currentLineIndex);
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            // Drag-Griff
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header mit Track-Info & Schließen
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: SpotifyColors.surfaceHighlight,
                      child: activeTrack.imageUrl != null
                          ? Image.network(
                              activeTrack.imageUrl!,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeTrack.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeTrack.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: SpotifyColors.borderSubtle, height: 1),

            // Lyrics List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: SpotifyColors.orange,
                      ),
                    )
                  : _lines.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: SpotifyColors.orange
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lyrics_outlined,
                                    color: SpotifyColors.orange,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Kein Songtext verfügbar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Für „${activeTrack.title}“ von „${activeTrack.artist}“ konnte weder auf Music Assistant noch im globalen Lyrics-Katalog ein Songtext gefunden werden.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: SpotifyColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _lyricsService
                                        .clearCacheForTrack(activeTrack);
                                    _loadLyrics(activeTrack, prov: prov);
                                  },
                                  icon: const Icon(Icons.refresh,
                                      size: 16, color: Colors.white),
                                  label: const Text('Erneut suchen',
                                      style: TextStyle(color: Colors.white)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: SpotifyColors.borderHighlight),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollStartNotification &&
                                notification.dragDetails != null) {
                              _userIsScrolling = true;
                            } else if (notification is ScrollEndNotification) {
                              Future.delayed(const Duration(seconds: 3), () {
                                if (mounted) {
                                  _userIsScrolling = false;
                                }
                              });
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            itemCount: _lines.length,
                            itemBuilder: (context, index) {
                              final line = _lines[index];
                              final isActive = index == _currentLineIndex;
                              final isPast = index < _currentLineIndex;

                              return InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  prov.seekTo(line.timestamp);
                                  setState(() {
                                    _currentLineIndex = index;
                                  });
                                  _scrollToActiveLine(index);
                                },
                                borderRadius: BorderRadius.circular(8),
                                splashColor: SpotifyColors.orange
                                    .withValues(alpha: 0.15),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 250),
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : isPast
                                              ? const Color(0xFF888888)
                                              : const Color(0xFF4A4A4A),
                                      fontSize: isActive ? 22 : 18,
                                      fontWeight: isActive
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      height: 1.35,
                                      shadows: isActive
                                          ? [
                                              BoxShadow(
                                                color: SpotifyColors.orange
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 16,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (isActive)
                                          Container(
                                            width: 4,
                                            height: 24,
                                            margin: const EdgeInsets.only(
                                                right: 12, top: 3),
                                            decoration: BoxDecoration(
                                              color: SpotifyColors.orange,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: SpotifyColors.orange
                                                      .withValues(alpha: 0.6),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(line.text),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
