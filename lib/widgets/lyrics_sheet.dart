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
  /// Flüssiger Buchstabe-für-Buchstabe Glow-Sweep ohne Layout-Springen
  letterPop,

  /// Buchstabe-für-Buchstabe Live-Buchstabieren mit leuchtendem Neon-Cursor (▋)
  letterTypewriter,

  /// Großer zentrierter Kino-Stage-Modus mit fließendem Buchstaben-Sweep
  cinemaStage,
}

/// 60fps Buchstabe-für-Buchstabe (Letter-by-Letter) Karaoke & Synced Lyrics Sheet
/// im Obsidian / Neon-Ember Studio-Design.
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

  // Monotone 60fps Sub-Frame Position Interpolation ohne Rückwärts-Sprünge
  late final Ticker _ticker;
  final Stopwatch _anchorWatch = Stopwatch();
  Duration _anchorPosition = Duration.zero;
  Duration _lastSeenProviderPosition = Duration.zero;
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
      final deltaMs = _anchorWatch.elapsedMilliseconds.clamp(0, 2500);
      final candidate = _anchorPosition + Duration(milliseconds: deltaMs);
      // Monoton vorwärts laufen lassen, damit grobe Server-Sekunden-Updates nie ruckeln
      final nextMs = math.max(_smoothPosition.inMilliseconds, candidate.inMilliseconds);
      if ((nextMs - _smoothPosition.inMilliseconds).abs() >= 14) {
        setState(() {
          _smoothPosition = Duration(milliseconds: nextMs);
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
      _syncPositionAnchor(prov.currentPosition, prov.isPlaying, force: true);
      _loadLyrics(activeTrack, prov: prov);
    }
  }

  void _syncPositionAnchor(
    Duration providerPos,
    bool isPlaying, {
    bool force = false,
  }) {
    final playChanged = isPlaying != _wasPlaying;
    final providerDelta =
        (providerPos.inMilliseconds - _lastSeenProviderPosition.inMilliseconds).abs();

    if (!force && !playChanged && providerDelta < 15) {
      return;
    }

    _lastSeenProviderPosition = providerPos;
    _wasPlaying = isPlaying;

    final driftFromSmooth =
        providerPos.inMilliseconds - _smoothPosition.inMilliseconds;

    if (force ||
        playChanged ||
        driftFromSmooth.abs() > 950 ||
        providerPos.inMilliseconds == 0) {
      // Echter Seek, Songstart oder große Abweichung -> hart synchronisieren
      _anchorPosition = providerPos;
      _smoothPosition = providerPos;
      _anchorWatch.reset();
    } else if (driftFromSmooth > 0) {
      // Provider ist leicht voraus -> Anker sanft vorziehen ohne Rückwärtssprung
      _anchorPosition = providerPos;
      _smoothPosition = providerPos;
      _anchorWatch.reset();
    } else {
      // Provider-Wert liegt leicht hinter unserer flüssigen Interpolation (z.B. gerundete Sekunde):
      // Kein Rückwärtssprung! Wir behalten _smoothPosition als neuen Anker.
      _anchorPosition = _smoothPosition;
      _anchorWatch.reset();
    }

    if (isPlaying) {
      if (!_anchorWatch.isRunning) _anchorWatch.start();
    } else {
      _anchorWatch.stop();
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
      _lastTrackId = activeTrack.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncPositionAnchor(Duration.zero, prov.isPlaying, force: true);
          _loadLyrics(activeTrack, prov: prov);
        }
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
        color: Color(0xFF050507),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          // Ambient-Spotlight-Hintergrund im Obsidian/Ember-Look
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
                      SpotifyColors.orange.withValues(alpha: 0.14),
                      const Color(0xFF100805).withValues(alpha: 0.85),
                      const Color(0xFF050507),
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

                // Clean Header mit Track-Info, Sync-Feintuning & Schließen (ohne störendes Wort-Badge oben)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  SpotifyColors.orange.withValues(alpha: 0.3),
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
                            Text(
                              activeTrack.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeTrack.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: SpotifyColors.textSecondary,
                                fontSize: 12.5,
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

                // Modus-Umschalter: Studio-Glow | Buchstabieren ▋ | Kino-Fokus
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

                const SizedBox(height: 6),
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
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 40,
                                ),
                                itemCount: _lines.length,
                                itemBuilder: (context, index) {
                                  final line = _lines[index];
                                  final isActive = index == _currentLineIndex;
                                  final isPast = index < _currentLineIndex;
                                  final isNext = index == _currentLineIndex + 1;

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
                                      vertical: isActive ? 8 : 3,
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
                                              line.timestamp,
                                              prov.isPlaying,
                                              force: true,
                                            );
                                            setState(() {
                                              _currentLineIndex = index;
                                              _userIsScrolling = false;
                                            });
                                            _scrollToActiveLine(index);
                                          },
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          splashColor: SpotifyColors.orange
                                              .withValues(alpha: 0.16),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 260),
                                            curve: Curves.easeOutCubic,
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isActive ? 16 : 12,
                                              vertical: isActive ? 14 : 9,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: isActive
                                                  ? LinearGradient(
                                                      colors: [
                                                        SpotifyColors.orange
                                                            .withValues(
                                                                alpha: 0.14),
                                                        SpotifyColors.orange
                                                            .withValues(
                                                                alpha: 0.03),
                                                        Colors.transparent,
                                                      ],
                                                      begin:
                                                          Alignment.centerLeft,
                                                      end:
                                                          Alignment.centerRight,
                                                    )
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isActive
                                                    ? SpotifyColors.orange
                                                        .withValues(alpha: 0.42)
                                                    : Colors.transparent,
                                                width: 1.0,
                                              ),
                                            ),
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

  /// Baut die aktive Zeile mit butterweicher Buchstabe-für-Buchstabe Animation
  /// ohne WidgetSpan-Umbruchfehler!
  Widget _buildActiveEpicLine(LyricLine line, LyricLineSnapshot snapshot) {
    final centerAlign = _displayMode == LyricsDisplayMode.cinemaStage;
    final baseFontSize = centerAlign ? 24.5 : 22.0;

    return Column(
      crossAxisAlignment:
          centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (_displayMode == LyricsDisplayMode.letterTypewriter)
          _buildTypewriterSpelledLine(snapshot, baseFontSize, centerAlign)
        else
          _buildSmoothCharacterGlowLine(snapshot, baseFontSize, centerAlign),

        const SizedBox(height: 10),

        // Feiner Laser-Fortschrittsbalken unter der aktiven Zeile
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 3.0,
            child: LinearProgressIndicator(
              value: snapshot.lineProgress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.10),
              valueColor: const AlwaysStoppedAnimation<Color>(
                SpotifyColors.orange,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Modus 1 & 3: Reines natives TextSpan-Rendering pro Buchstabe!
  /// Dadurch bleiben alle Wortgrenzen zu 100% erhalten (kein Umbruch mitten im Wort)
  /// und die Buchstaben gleiten mit 60fps butterweich von gedimmt -> Neon-Ember -> Weiß!
  Widget _buildSmoothCharacterGlowLine(
    LyricLineSnapshot snapshot,
    double baseFontSize,
    bool centerAlign,
  ) {
    final spans = <TextSpan>[];

    for (final chState in snapshot.chars) {
      final p = chState.progress.clamp(0.0, 1.0);
      final isCurrent = chState.isCurrentActiveLetter || (p > 0.0 && p < 1.0);
      final isSung = p >= 1.0;

      final Color letterColor;
      List<Shadow>? shadows;

      if (isCurrent) {
        final glowIntensity = math.sin(p * math.pi).clamp(0.2, 1.0);
        letterColor = Color.lerp(
              Colors.white.withValues(alpha: 0.45),
              SpotifyColors.orange,
              p.clamp(0.3, 1.0),
            ) ??
            SpotifyColors.orange;
        shadows = [
          Shadow(
            color: SpotifyColors.orange.withValues(alpha: 0.85 * glowIntensity),
            blurRadius: 14,
          ),
          Shadow(
            color: SpotifyColors.amber.withValues(alpha: 0.55 * glowIntensity),
            blurRadius: 6,
          ),
        ];
      } else if (isSung) {
        letterColor = Colors.white;
        shadows = [
          Shadow(
            color: SpotifyColors.orange.withValues(alpha: 0.32),
            blurRadius: 8,
          ),
        ];
      } else {
        letterColor = Colors.white.withValues(alpha: 0.28);
      }

      spans.add(
        TextSpan(
          text: chState.char,
          style: TextStyle(
            color: letterColor,
            fontSize: baseFontSize,
            fontWeight: FontWeight.w800,
            height: 1.32,
            shadows: shadows,
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
  /// reinem TextSpan-Cursor `▋`, damit Wörter niemals zerrissen werden!
  Widget _buildTypewriterSpelledLine(
    LyricLineSnapshot snapshot,
    double baseFontSize,
    bool centerAlign,
  ) {
    final spelled = snapshot.spelledText;
    final remaining = snapshot.remainingText;

    final String completedPrefix =
        spelled.length > 1 ? spelled.substring(0, spelled.length - 1) : '';
    final String activeLastChar =
        spelled.isNotEmpty ? spelled.substring(spelled.length - 1) : '';

    return RichText(
      textAlign: centerAlign ? TextAlign.center : TextAlign.start,
      text: TextSpan(
        style: TextStyle(
          fontSize: baseFontSize,
          fontWeight: FontWeight.w800,
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
                    color: SpotifyColors.orange.withValues(alpha: 0.35),
                    blurRadius: 10,
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
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
          const TextSpan(
            text: '▋',
            style: TextStyle(
              color: SpotifyColors.orange,
              shadows: [
                Shadow(
                  color: SpotifyColors.orange,
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          if (remaining.isNotEmpty)
            TextSpan(
              text: remaining,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.22),
                fontWeight: FontWeight.w700,
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
            ? Colors.white.withValues(alpha: 0.64)
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
              width: 8,
              height: 8,
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
                : const Color(0xFF141418),
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
        color: const Color(0xFF16161C),
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
        color: Color(0xFF0A0A0E),
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
  Duration _lastProviderPos = Duration.zero;
  Duration _smoothPos = Duration.zero;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!mounted || !_wasPlaying || _lines.isEmpty) return;
      final deltaMs = _watch.elapsedMilliseconds.clamp(0, 2500);
      final candidate = _anchorPos + Duration(milliseconds: deltaMs);
      final nextMs = math.max(_smoothPos.inMilliseconds, candidate.inMilliseconds);
      if ((nextMs - _smoothPos.inMilliseconds).abs() >= 20) {
        setState(() {
          _smoothPos = Duration(milliseconds: nextMs);
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
    _anchorPos = Duration.zero;
    _smoothPos = Duration.zero;
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

    final playChanged = prov.isPlaying != _wasPlaying;
    final providerDelta =
        (prov.currentPosition.inMilliseconds - _lastProviderPos.inMilliseconds).abs();
    if (playChanged || providerDelta > 25) {
      _lastProviderPos = prov.currentPosition;
      _wasPlaying = prov.isPlaying;
      final drift = prov.currentPosition.inMilliseconds - _smoothPos.inMilliseconds;
      if (playChanged || drift.abs() > 950 || prov.currentPosition.inMilliseconds == 0) {
        _anchorPos = prov.currentPosition;
        _smoothPos = prov.currentPosition;
        _watch.reset();
      } else if (drift > 0) {
        _anchorPos = prov.currentPosition;
        _smoothPos = prov.currentPosition;
        _watch.reset();
      } else {
        _anchorPos = _smoothPos;
        _watch.reset();
      }
      if (prov.isPlaying) {
        if (!_watch.isRunning) _watch.start();
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
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1A120E),
              Color(0xFF121216),
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
                          'Tippen für Vollbild-Songtext',
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
