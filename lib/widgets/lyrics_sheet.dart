import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../services/lyrics_service.dart';
import '../theme/spotify_colors.dart';

/// Spotify-Style Karaoke & Synced Lyrics Sheet.
/// Zeigt zeitgenaue Liedtexte an, scrollt automatisch mit der Musik
/// und erlaubt das Antippen jeder Zeile, um direkt dorthin zu springen.
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

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    final res = await _lyricsService.getLyricsForTrack(widget.track);
    if (mounted) {
      setState(() {
        _lines = res;
        _isLoading = false;
      });
    }
  }

  void _scrollToActiveLine(int index) {
    if (_userIsScrolling || !_scrollController.hasClients || index < 0) return;

    // Jede Zeile ist ca. 56px hoch
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
    final newIndex = _lyricsService.findCurrentLineIndex(_lines, prov.currentPosition);

    if (newIndex != _currentLineIndex) {
      _currentLineIndex = newIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(_currentLineIndex);
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF161616),
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
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Songinfo & Karaoke Live Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: SpotifyColors.green.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: SpotifyColors.green.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: SpotifyColors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text(
                                    'SONGTEXT LIVE',
                                    style: TextStyle(
                                      color: SpotifyColors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
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
                        color: SpotifyColors.green,
                      ),
                    )
                  : _lines.isEmpty
                      ? const Center(
                          child: Text(
                            'Kein Songtext verfügbar',
                            style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 14,
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
                                splashColor: SpotifyColors.green.withValues(alpha: 0.15),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
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
                                                color: SpotifyColors.green.withValues(alpha: 0.35),
                                                blurRadius: 16,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isActive)
                                          Container(
                                            width: 4,
                                            height: 24,
                                            margin: const EdgeInsets.only(right: 12, top: 3),
                                            decoration: BoxDecoration(
                                              color: SpotifyColors.green,
                                              borderRadius: BorderRadius.circular(2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: SpotifyColors.green.withValues(alpha: 0.6),
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
