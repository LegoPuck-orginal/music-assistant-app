import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../providers/music_provider.dart';
import '../services/lyrics_service.dart';
import '../theme/spotify_colors.dart';

/// Darstellungsmodus für die Buchstabe-für-Buchstabe (Letter-by-Letter) Lyrics
enum LyricsDisplayMode {
  /// Jeder Buchstabe springt, skaliert und leuchtet beim Singen einzeln in Adobe-Orange auf
  letterPop,

  /// Buchstabe-für-Buchstabe Live-Buchstabieren mit leuchtendem Neon-Cursor (▋) & Wort-HUD
  letterTypewriter,

  /// Großer zentrierter Kino-Stage-Modus mit fließendem Buchstaben-Sweep
  cinemaStage,
}

/// Episches 60fps Buchstabe-für-Buchstabe (Letter-by-Letter) Karaoke & Synced Lyrics Sheet
/// im Tiefschwarz / Adobe-Orange Design.
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

class _LyricsSheetState extends State<LyricsSheet>
    with SingleTickerProviderStateMixin {
  final LyricsService _lyricsService = LyricsService();
  final ScrollController _scrollController = ScrollController();

  List<LyricLine> _lines = [];
  final List<GlobalKey> _lineKeys = [];
  bool _isLoading = true;
  int _currentLineIndex = -1;
  bool _userIsScrolling = false;
  String? _lastTrackId;
  bool _initialLoaded = false;

  LyricsDisplayMode _displayMode = LyricsDisplayMode.letterPop;
  bool _showSyncTuner = false;

  // 60fps Sub-Frame Position Interpolation für butterweiches Buchstabieren
  late final Ticker _ticker;
  final Stopwatch _anchorWatch = Stopwatch();
  Duration _lastProviderPosition = Duration.zero;
  Duration _smoothPosition = Duration.zero;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_wasPlaying && _lines.isNotEmpty) {
      final deltaMs = _anchorWatch.elapsedMilliseconds.clamp(0, 1200);
      final interpolated =
          _lastProviderPosition + Duration(milliseconds: deltaMs);
      if ((interpolated.inMilliseconds - _smoothPosition.inMilliseconds).abs() >=
          12) {
        setState(() {
          _smoothPosition = interpolated;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialLoaded) {
      _initialLoaded = true;
      final prov = context.read<MusicProvider>();
      final activeTrack = prov.currentTrack ?? widget.track;
      _syncPositionAnchor(prov.currentPosition, prov.isPlaying);
      _loadLyrics(activeTrack, prov: prov);
    }
  }

  void _syncPositionAnchor(Duration providerPos, bool isPlaying) {
    final posChanged = (providerPos.inMilliseconds -
                _lastProviderPosition.inMilliseconds)
            .abs() >
        20;
    if (posChanged || isPlaying != _wasPlaying) {
      _lastProviderPosition = providerPos;
      _smoothPosition = providerPos;
      _wasPlaying = isPlaying;
      _anchorWatch.reset();
      if (isPlaying) {
        _anchorWatch.start();
      } else {
        _anchorWatch.stop();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _anchorWatch.stop();
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
        _lineKeys
          ..clear()
          ..addAll(List.generate(res.length, (_) => GlobalKey()));
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentLineIndex >= 0) {
          _scrollToActiveLine(_currentLineIndex);
        }
      });
    }
  }

  void _scrollToActiveLine(int index) {
    if (_userIsScrolling || index < 0 || index >= _lines.length) return;

    if (index < _lineKeys.length) {
      final ctx = _lineKeys[index].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.34,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }

    if (!_scrollController.hasClients) return;
    const itemHeight = 76.0;
    final targetOffset = (index * itemHeight) - 180.0;
    final clamped = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final activeTrack = prov.currentTrack ?? widget.track;

    _syncPositionAnchor(prov.currentPosition, prov.isPlaying);

    if (_lastTrackId != null && _lastTrackId != activeTrack.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadLyrics(activeTrack, prov: prov);
      });
    }

    final effectivePosition = _lyricsService.applySyncOffset(_smoothPosition);
    final newIndex =
        _lyricsService.findCurrentLineIndex(_lines, effectivePosition);

    if (newIndex != _currentLineIndex) {
      _currentLineIndex = newIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToActiveLine(_currentLineIndex);
      });
    }

    final activeSnapshot = (_currentLineIndex >= 0 &&
            _currentLineIndex < _lines.length)
        ? _lyricsService.getLineSnapshot(
            _lines,
            _currentLineIndex,
            effectivePosition,
          )
        : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.94,
      decoration: const BoxDecoration(
        color: Color(0xFF050505),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Epischer dynamischer Ambient-Spotlight-Hintergrund im Adobe-Orange-Look
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.25),
                    radius: 1.15,
                    colors: [
                      SpotifyColors.orange.withValues(alpha: 0.16),
                      const Color(0xFF120804).withValues(alpha: 0.85),
                      const Color(0xFF050505),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            top: true,
            bottom: true,
            child: Column(
              children: [
                // Drag-Griff
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    margin: const EdgeInsets.only(top: 10, bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Header mit Track-Info, Sync-Feintuning & Schließen
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  SpotifyColors.orange.withValues(alpha: 0.35),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: SpotifyColors.surfaceHighlight,
                            child: activeTrack.imageUrl != null
                                ? Image.network(
                                    activeTrack.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: SpotifyColors.orange
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: SpotifyColors.orange
                                          .withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'LIVE BUCHSTABIERT',
                                    style: TextStyle(
                                      color: SpotifyColors.orange,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    activeTrack.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
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
                      // Sync-Offset Button
                      IconButton(
                        tooltip: 'Buchstaben-Timing feinabstimmen',
                        icon: Icon(
                          Icons.tune_rounded,
                          color: _showSyncTuner ||
                                  _lyricsService.syncOffsetMs != 0
                              ? SpotifyColors.orange
                              : Colors.white70,
                          size: 21,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _showSyncTuner = !_showSyncTuner;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 24),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Modus-Umschalter: Buchstaben-Puls | Buchstabieren ▋ | Kino-Fokus
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      _buildModeChip(
                        mode: LyricsDisplayMode.letterPop,
                        icon: Icons.auto_awesome,
                        label: 'Buchstaben-Puls',
                      ),
                      const SizedBox(width: 8),
                      _buildModeChip(
                        mode: LyricsDisplayMode.letterTypewriter,
                        icon: Icons.spellcheck_rounded,
                        label: 'Buchstabieren ▋',
                      ),
                      const SizedBox(width: 8),
                      _buildModeChip(
                        mode: LyricsDisplayMode.cinemaStage,
                        icon: Icons.theaters_rounded,
                        label: 'Kino-Fokus',
                      ),
                    ],
                  ),
                ),

                // Optionaler Sync-Tuner für Millisekunden-genaue Anpassung
                if (_showSyncTuner) _buildSyncTunerBar(),

                // Live-Buchstabier-HUD: Zeigt das aktuell gesungene Wort Buchstabe für Buchstabe oben an!
                if (!_isLoading &&
                    _lines.isNotEmpty &&
                    activeSnapshot != null &&
                    activeSnapshot.activeWord.isNotEmpty)
                  _buildLiveSpellingHud(activeSnapshot),

                const SizedBox(height: 4),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),

                // Haupt-Lyrics-Bühne
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: SpotifyColors.orange,
                          ),
                        )
                      : _lines.isEmpty
                          ? _buildEmptyLyricsState(activeTrack, prov)
                          : NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is ScrollStartNotification &&
                                    notification.dragDetails != null) {
                                  _userIsScrolling = true;
                                } else if (notification
                                    is ScrollEndNotification) {
                                  Future.delayed(const Duration(seconds: 3),
                                      () {
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
                                  horizontal: 22,
                                  vertical: 44,
                                ),
                                itemCount: _lines.length,
                                itemBuilder: (context, index) {
                                  final line = _lines[index];
                                  final isActive = index == _currentLineIndex;
                                  final isPast = index < _currentLineIndex;
                                  final isNext = index == _currentLineIndex + 1;

                                  // Prüfe ob vor dieser Zeile ein Instrumental-Einsatz-Countdown läuft
                                  final showCountdown =
                                      _shouldShowVocalCountdown(
                                          index, effectivePosition);
                                  final countdownProgress = showCountdown
                                      ? _computeCountdownProgress(
                                          index, effectivePosition)
                                      : 0.0;

                                  return Container(
                                    key: index < _lineKeys.length
                                        ? _lineKeys[index]
                                        : null,
                                    margin: EdgeInsets.symmetric(
                                      vertical: isActive ? 10 : 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: _displayMode ==
                                              LyricsDisplayMode.cinemaStage
                                          ? CrossAxisAlignment.center
                                          : CrossAxisAlignment.start,
                                      children: [
                                        if (showCountdown)
                                          _buildVocalCountdownIndicator(
                                              countdownProgress,
                                              line.timestamp -
                                                  effectivePosition),
                                        InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            prov.seekTo(line.timestamp);
                                            _syncPositionAnchor(
                                                line.timestamp, prov.isPlaying);
                                            setState(() {
                                              _currentLineIndex = index;
                                              _userIsScrolling = false;
                                            });
                                            _scrollToActiveLine(index);
                                          },
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          splashColor: SpotifyColors.orange
                                              .withValues(alpha: 0.18),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 240),
                                            curve: Curves.easeOutCubic,
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isActive ? 16 : 10,
                                              vertical: isActive ? 14 : 8,
                                            ),
                                            decoration: isActive
                                                ? BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        SpotifyColors.orange
                                                            .withValues(
                                                                alpha: 0.16),
                                                        SpotifyColors.orange
                                                            .withValues(
                                                                alpha: 0.04),
                                                        Colors.transparent,
                                                      ],
                                                      begin:
                                                          Alignment.centerLeft,
                                                      end:
                                                          Alignment.centerRight,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: Border.all(
                                                      color: SpotifyColors
                                                          .orange
                                                          .withValues(
                                                              alpha: 0.45),
                                                      width: 1.1,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: SpotifyColors
                                                            .orange
                                                            .withValues(
                                                                alpha: 0.14),
                                                        blurRadius: 24,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  )
                                                : null,
                                            child: isActive &&
                                                    activeSnapshot != null
                                                ? _buildActiveEpicLine(
                                                    line, activeSnapshot)
                                                : _buildInactiveLine(
                                                    line,
                                                    isPast: isPast,
                                                    isNext: isNext,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                ),

                // Kompakter Live-Player-Footer zum Steuern ohne Schließen der Lyrics
                _buildBottomTransportBar(prov, activeSnapshot),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Baut die aktive Zeile mit Buchstabe-für-Buchstabe (Letter-by-Letter) Animation!
  Widget _buildActiveEpicLine(LyricLine line, LyricLineSnapshot snapshot) {
    final centerAlign = _displayMode == LyricsDisplayMode.cinemaStage;
    final baseFontSize = centerAlign ? 26.0 : 23.0;

    return Column(
      crossAxisAlignment:
          centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (_displayMode == LyricsDisplayMode.letterTypewriter)
          _buildTypewriterSpelledLine(snapshot, baseFontSize, centerAlign)
        else
          _buildCharacterPopLine(snapshot, baseFontSize, centerAlign),

        const SizedBox(height: 10),

        // Laser-Fortschrittsbalken + Buchstaben-Zähler unter der aktiven Zeile
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 3.5,
                  child: LinearProgressIndicator(
                    value: snapshot.lineProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      SpotifyColors.orange,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(snapshot.activeCharIndex + 1).clamp(0, snapshot.chars.length)}/${snapshot.chars.length}',
              style: TextStyle(
                color: SpotifyColors.orange.withValues(alpha: 0.9),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Modus 1 & 3: Jeder einzelne Buchstabe wird mit eigenem Fortschritt, Glow,
  /// vertikalem Pop-Impuls und Laser-Punkt unter dem aktiven Buchstaben gerendert!
  Widget _buildCharacterPopLine(
    LyricLineSnapshot snapshot,
    double baseFontSize,
    bool centerAlign,
  ) {
    final spans = <InlineSpan>[];

    for (final chState in snapshot.chars) {
      final p = chState.progress;
      final isCurrent = chState.isCurrentActiveLetter ||
          (p > 0.0 && p < 1.0);
      final isSung = p >= 1.0;

      if (chState.char == ' ') {
        spans.add(TextSpan(
          text: ' ',
          style: TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.w800,
          ),
        ));
        continue;
      }

      // Sinus-Impuls für den Moment, in dem der Buchstabe gesungen wird
      final popWave = isCurrent
          ? math.sin((p.clamp(0.15, 0.85)) * math.pi)
          : 0.0;
      final liftY = isCurrent ? (-4.0 * popWave) : (isSung ? -0.6 : 0.0);
      final scale = isCurrent ? (1.0 + 0.16 * popWave) : 1.0;

      final Color letterColor;
      if (isCurrent) {
        letterColor = Color.lerp(
              SpotifyColors.orange,
              const Color(0xFFFFB380),
              popWave,
            ) ??
            SpotifyColors.orange;
      } else if (isSung) {
        letterColor = Colors.white;
      } else {
        letterColor = Colors.white.withValues(alpha: 0.26);
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Transform.translate(
            offset: Offset(0, liftY),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chState.char,
                    style: TextStyle(
                      color: letterColor,
                      fontSize: baseFontSize,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                      shadows: isCurrent
                          ? [
                              const Shadow(
                                color: SpotifyColors.orange,
                                blurRadius: 18,
                              ),
                              Shadow(
                                color: SpotifyColors.orange
                                    .withValues(alpha: 0.85),
                                blurRadius: 8,
                              ),
                            ]
                          : isSung
                              ? [
                                  Shadow(
                                    color: SpotifyColors.orange
                                        .withValues(alpha: 0.45),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                    ),
                  ),
                  // Kleiner glühender Laser-Funke direkt unter dem aktiv buchstabierten Buchstaben
                  Container(
                    width: isCurrent ? 5.0 : 0.0,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? SpotifyColors.orange
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: isCurrent
                          ? [
                              const BoxShadow(
                                color: SpotifyColors.orange,
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RichText(
      textAlign: centerAlign ? TextAlign.center : TextAlign.start,
      text: TextSpan(children: spans),
    );
  }

  /// Modus 2 („Buchstabieren ▋“): Buchstabe für Buchstabe Live-Typewriter mit
  /// leuchtendem Adobe-Orange-Cursor `▋` direkt hinter dem aktuellen Buchstaben!
  Widget _buildTypewriterSpelledLine(
    LyricLineSnapshot snapshot,
    double baseFontSize,
    bool centerAlign,
  ) {
    final spelled = snapshot.spelledText;
    final remaining = snapshot.remainingText;

    // Der letzte bereits enthüllte Buchstabe leuchtet kräftig in Adobe-Orange
    final String completedPrefix =
        spelled.length > 1 ? spelled.substring(0, spelled.length - 1) : '';
    final String activeLastChar =
        spelled.isNotEmpty ? spelled.substring(spelled.length - 1) : '';

    return RichText(
      textAlign: centerAlign ? TextAlign.center : TextAlign.start,
      text: TextSpan(
        style: TextStyle(
          fontSize: baseFontSize,
          fontWeight: FontWeight.w900,
          height: 1.32,
        ),
        children: [
          if (completedPrefix.isNotEmpty)
            TextSpan(
              text: completedPrefix,
              style: TextStyle(
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: SpotifyColors.orange.withValues(alpha: 0.45),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          if (activeLastChar.isNotEmpty)
            TextSpan(
              text: activeLastChar,
              style: const TextStyle(
                color: SpotifyColors.orange,
                shadows: [
                  Shadow(
                    color: SpotifyColors.orange,
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          // Leuchtender Adobe-Orange Buchstabier-Cursor
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              width: 3.5,
              height: baseFontSize * 0.95,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: SpotifyColors.orange,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(
                    color: SpotifyColors.orange,
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          if (remaining.isNotEmpty)
            TextSpan(
              text: remaining,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.16),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  /// Live-Buchstabier-HUD oberhalb der Liste: Zeigt das aktuell gesungene Wort
  /// Buchstabe für Buchstabe aufgeschlüsselt an (z. B. `F · A · N · T · A · S · Y`).
  Widget _buildLiveSpellingHud(LyricLineSnapshot snapshot) {
    final word = snapshot.activeWord;
    final spelledLen = snapshot.activeWordSpelled.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SpotifyColors.orange.withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            color: SpotifyColors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Text(
            'WORT:',
            style: TextStyle(
              color: SpotifyColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(word.length, (i) {
                  final ch = word[i].toUpperCase();
                  final isSung = i < spelledLen;
                  final isCurrent = i == spelledLen - 1;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? SpotifyColors.orange
                          : isSung
                              ? SpotifyColors.orange.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isCurrent
                            ? Colors.white
                            : isSung
                                ? SpotifyColors.orange.withValues(alpha: 0.6)
                                : Colors.white12,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      ch,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.black
                            : isSung
                                ? Colors.white
                                : Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveLine(
    LyricLine line, {
    required bool isPast,
    required bool isNext,
  }) {
    final centerAlign = _displayMode == LyricsDisplayMode.cinemaStage;
    return Text(
      line.text,
      textAlign: centerAlign ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: isNext
            ? Colors.white.withValues(alpha: 0.62)
            : isPast
                ? Colors.white.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.24),
        fontSize: isNext ? 18.5 : 17.0,
        fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
        height: 1.35,
      ),
    );
  }

  bool _shouldShowVocalCountdown(int index, Duration pos) {
    if (index < 0 || index >= _lines.length) return false;
    final lineStart = _lines[index].timestamp;
    final remainingMs = (lineStart - pos).inMilliseconds;
    if (remainingMs <= 0 || remainingMs > 3500) return false;

    if (index == 0) {
      return lineStart.inMilliseconds >= 2500;
    }
    final prevEnd = _lines[index - 1].computeVocalEndTimestamp(
      nextLineTimestamp: lineStart,
    );
    final instrumentalGapMs = (lineStart - prevEnd).inMilliseconds;
    return instrumentalGapMs >= 2000;
  }

  double _computeCountdownProgress(int index, Duration pos) {
    final lineStart = _lines[index].timestamp;
    final remainingMs = (lineStart - pos).inMilliseconds.clamp(0, 3500);
    return 1.0 - (remainingMs / 3500.0);
  }

  Widget _buildVocalCountdownIndicator(double progress, Duration remaining) {
    final secs = (remaining.inMilliseconds / 1000.0).clamp(0.0, 9.9);
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6, top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int dot = 0; dot < 3; dot++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: progress >= ((dot + 1) / 3.2)
                    ? SpotifyColors.orange
                    : Colors.white24,
                boxShadow: progress >= ((dot + 1) / 3.2)
                    ? const [
                        BoxShadow(
                          color: SpotifyColors.orange,
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
          const SizedBox(width: 4),
          Text(
            'Einsatz in ${secs.toStringAsFixed(1)}s',
            style: const TextStyle(
              color: SpotifyColors.orange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required LyricsDisplayMode mode,
    required IconData icon,
    required String label,
  }) {
    final selected = _displayMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _displayMode = mode;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? SpotifyColors.orange.withValues(alpha: 0.2)
                : const Color(0xFF141414),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? SpotifyColors.orange
                  : SpotifyColors.borderSubtle,
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? SpotifyColors.orange
                    : SpotifyColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : SpotifyColors.textSecondary,
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncTunerBar() {
    final offsetSec = (_lyricsService.syncOffsetMs / 1000.0);
    final sign = offsetSec > 0 ? '+' : '';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SpotifyColors.borderHighlight),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              color: SpotifyColors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Buchstaben-Sync: $sign${offsetSec.toStringAsFixed(2)}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildSyncStepBtn('-0.2s', -200),
          const SizedBox(width: 6),
          if (_lyricsService.syncOffsetMs != 0) ...[
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _lyricsService.resetSyncOffset();
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          _buildSyncStepBtn('+0.2s', 200),
        ],
      ),
    );
  }

  Widget _buildSyncStepBtn(String label, int deltaMs) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _lyricsService.adjustSyncOffset(deltaMs);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: SpotifyColors.orange.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: SpotifyColors.orange.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: SpotifyColors.orange,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLyricsState(Track activeTrack, MusicProvider prov) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: SpotifyColors.orange.withValues(alpha: 0.12),
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
                _lyricsService.clearCacheForTrack(activeTrack);
                _loadLyrics(activeTrack, prov: prov);
              },
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
              label: const Text('Erneut suchen',
                  style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: SpotifyColors.borderHighlight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTransportBar(
      MusicProvider prov, LyricLineSnapshot? snapshot) {
    final totalSec = prov.totalDuration.inSeconds;
    final posSec = _smoothPosition.inSeconds.clamp(0, math.max(1, totalSec));
    final songProgress =
        totalSec > 0 ? (posSec / totalSec).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        border: Border(
          top: BorderSide(color: SpotifyColors.borderSubtle, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: songProgress,
              minHeight: 3,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                SpotifyColors.orange,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatDuration(_smoothPosition),
                style: const TextStyle(
                  color: SpotifyColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.skip_previous_rounded,
                    color: Colors.white, size: 28),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  prov.previous();
                },
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  prov.togglePlayPause();
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SpotifyColors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SpotifyColors.orange.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    prov.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.skip_next_rounded,
                    color: Colors.white, size: 28),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  prov.next();
                },
              ),
              const Spacer(),
              Text(
                _formatDuration(prov.totalDuration),
                style: const TextStyle(
                  color: SpotifyColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

/// Live-Karaoke-Vorschaukarte für das `NowPlayingSheet`:
/// Buchstabiert die aktuelle Songtext-Zeile live Buchstabe für Buchstabe direkt
/// auf dem Haupt-Player-Bildschirm!
class LiveLyricsPreviewCard extends StatefulWidget {
  final Track track;
  final VoidCallback onTap;

  const LiveLyricsPreviewCard({
    super.key,
    required this.track,
    required this.onTap,
  });

  @override
  State<LiveLyricsPreviewCard> createState() => _LiveLyricsPreviewCardState();
}

class _LiveLyricsPreviewCardState extends State<LiveLyricsPreviewCard>
    with SingleTickerProviderStateMixin {
  final LyricsService _lyricsService = LyricsService();
  List<LyricLine> _lines = [];
  String? _loadedTrackKey;

  late final Ticker _ticker;
  final Stopwatch _watch = Stopwatch();
  Duration _anchorPos = Duration.zero;
  Duration _smoothPos = Duration.zero;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!mounted || !_wasPlaying || _lines.isEmpty) return;
      final deltaMs = _watch.elapsedMilliseconds.clamp(0, 1200);
      final nextPos = _anchorPos + Duration(milliseconds: deltaMs);
      if ((nextPos.inMilliseconds - _smoothPos.inMilliseconds).abs() >= 20) {
        setState(() {
          _smoothPos = nextPos;
        });
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _watch.stop();
    super.dispose();
  }

  void _ensureLoaded(Track track, MusicProvider prov) {
    final key = '${track.artist}__${track.title}';
    if (_loadedTrackKey == key) return;
    _loadedTrackKey = key;
    _lyricsService.getLyricsForTrack(track, api: prov.api).then((res) {
      if (mounted && _loadedTrackKey == key) {
        setState(() {
          _lines = res;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final activeTrack = prov.currentTrack ?? widget.track;
    _ensureLoaded(activeTrack, prov);

    if ((prov.currentPosition.inMilliseconds - _anchorPos.inMilliseconds)
                .abs() >
            25 ||
        prov.isPlaying != _wasPlaying) {
      _anchorPos = prov.currentPosition;
      _smoothPos = prov.currentPosition;
      _wasPlaying = prov.isPlaying;
      _watch.reset();
      if (prov.isPlaying) {
        _watch.start();
      } else {
        _watch.stop();
      }
    }

    final effectivePos = _lyricsService.applySyncOffset(_smoothPos);
    final idx = _lyricsService.findCurrentLineIndex(_lines, effectivePos);
    final hasActiveLyrics = _lines.isNotEmpty && idx >= 0 && idx < _lines.length;
    final snapshot = hasActiveLyrics
        ? _lyricsService.getLineSnapshot(_lines, idx, effectivePos)
        : null;
    final nextLineText =
        (hasActiveLyrics && idx + 1 < _lines.length) ? _lines[idx + 1].text : null;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A120E),
              const Color(0xFF121212),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasActiveLyrics
                ? SpotifyColors.orange.withValues(alpha: 0.45)
                : SpotifyColors.borderSubtle,
            width: 0.9,
          ),
          boxShadow: hasActiveLyrics
              ? [
                  BoxShadow(
                    color: SpotifyColors.orange.withValues(alpha: 0.1),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: SpotifyColors.orange.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.lyrics_rounded,
                color: SpotifyColors.orange,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasActiveLyrics && snapshot != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMiniSpelledLine(snapshot),
                        if (nextLineText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            nextLineText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.38),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    )
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Songtext & Live-Karaoke',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Tippen für Buchstabe-für-Buchstabe Vollbild',
                          style: TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.open_in_full_rounded,
              color: SpotifyColors.orange,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSpelledLine(LyricLineSnapshot snapshot) {
    final spelled = snapshot.spelledText;
    final remaining = snapshot.remainingText;
    final prefix =
        spelled.length > 1 ? spelled.substring(0, spelled.length - 1) : '';
    final activeChar =
        spelled.isNotEmpty ? spelled.substring(spelled.length - 1) : '';

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: const TextStyle(color: Colors.white),
            ),
          if (activeChar.isNotEmpty)
            TextSpan(
              text: activeChar,
              style: const TextStyle(
                color: SpotifyColors.orange,
                shadows: [
                  Shadow(color: SpotifyColors.orange, blurRadius: 10),
                ],
              ),
            ),
          const TextSpan(
            text: '▋',
            style: TextStyle(
              color: SpotifyColors.orange,
              fontSize: 12,
            ),
          ),
          if (remaining.isNotEmpty)
            TextSpan(
              text: remaining,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
