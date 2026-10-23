import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spotify_colors.dart';

/// Interaktiver Audio-Waveform Scrubber & Visualizer im Adobe-Orange/Dark-Design.
/// Bietet 60/120-FPS butterweiche kontinuierliche Playhead-Interpolation,
/// dynamisch fließende Klangwellen-Animation und präzises Scrubbing per Finger.
class AudioWaveformScrubber extends StatefulWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final String trackKey;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration>? onScrubbing;

  const AudioWaveformScrubber({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    required this.trackKey,
    required this.onSeek,
    this.onScrubbing,
  });

  @override
  State<AudioWaveformScrubber> createState() => _AudioWaveformScrubberState();
}

class _AudioWaveformScrubberState extends State<AudioWaveformScrubber>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double? _dragFraction;
  int _lastHapticBar = -1;

  static const int _barCount = 48;
  late List<double> _waveformHeights;

  Duration _lastKnownPosition = Duration.zero;
  DateTime _lastPositionSyncTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _lastKnownPosition = widget.currentPosition;
    _lastPositionSyncTime = DateTime.now();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    if (widget.isPlaying) {
      _animCtrl.repeat();
    }
    _waveformHeights = _generateWaveform(widget.trackKey);
  }

  @override
  void didUpdateWidget(covariant AudioWaveformScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackKey != widget.trackKey) {
      _waveformHeights = _generateWaveform(widget.trackKey);
    }

    // Wenn sich die Position um mehr als 1.2s unterscheidet oder Play-Status wechselt,
    // Basis-Position synchronisieren
    final posDiff = (widget.currentPosition - _lastKnownPosition).inMilliseconds.abs();
    if (posDiff > 1200 || widget.isPlaying != oldWidget.isPlaying) {
      _lastKnownPosition = widget.currentPosition;
      _lastPositionSyncTime = DateTime.now();
    }

    if (widget.isPlaying && !_animCtrl.isAnimating) {
      _lastPositionSyncTime = DateTime.now();
      _animCtrl.repeat();
    } else if (!widget.isPlaying && _animCtrl.isAnimating) {
      _animCtrl.stop();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  /// Erzeugt eine reproduzierbare, musikalische Wellenform basierend auf dem Song-Titel
  List<double> _generateWaveform(String key) {
    final seed = key.hashCode.abs();
    final rng = math.Random(seed);
    final list = <double>[];

    for (int i = 0; i < _barCount; i++) {
      final t = i / _barCount;
      final envelope = math.sin(t * math.pi);
      final noise = rng.nextDouble() * 0.45 + 0.15;
      final harmonic = 0.25 * math.sin(t * 8 * math.pi);
      final height =
          (envelope * 0.65 + noise * 0.35 + harmonic).clamp(0.18, 1.0);
      list.add(height);
    }
    return list;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _handleSeek(double localX, double width) {
    final fraction = (localX / width).clamp(0.0, 1.0);
    setState(() {
      _dragFraction = fraction;
    });

    final barIndex = (fraction * _barCount).floor();
    if (barIndex != _lastHapticBar) {
      _lastHapticBar = barIndex;
      HapticFeedback.selectionClick();
    }

    final scrubPos = Duration(
      milliseconds: (widget.totalDuration.inMilliseconds * fraction).round(),
    );
    widget.onScrubbing?.call(scrubPos);
  }

  void _commitSeek() {
    if (_dragFraction != null) {
      final targetMs =
          (widget.totalDuration.inMilliseconds * _dragFraction!).round();
      final targetDur = Duration(milliseconds: targetMs);
      _lastKnownPosition = targetDur;
      _lastPositionSyncTime = DateTime.now();
      widget.onSeek(targetDur);
      HapticFeedback.lightImpact();
      setState(() {
        _dragFraction = null;
        _lastHapticBar = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.totalDuration.inMilliseconds;

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        // Kontinuierliche 60-FPS-Interpolation für flüssige Playhead-Bewegung
        final now = DateTime.now();
        final elapsedMs = widget.isPlaying
            ? now.difference(_lastPositionSyncTime).inMilliseconds
            : 0;
        final currentSmoothMs = totalMs > 0
            ? (_lastKnownPosition.inMilliseconds + elapsedMs).clamp(0, totalMs)
            : 0;

        final effectiveFraction = _dragFraction ??
            (totalMs > 0 ? (currentSmoothMs / totalMs).clamp(0.0, 1.0) : 0.0);

        final displayPos = _dragFraction != null
            ? Duration(milliseconds: (totalMs * _dragFraction!).round())
            : Duration(milliseconds: currentSmoothMs);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Interaktiver Wellenform-Container
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                const height = 48.0;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) =>
                      _handleSeek(details.localPosition.dx, width),
                  onHorizontalDragUpdate: (details) =>
                      _handleSeek(details.localPosition.dx, width),
                  onHorizontalDragEnd: (_) => _commitSeek(),
                  onHorizontalDragCancel: () {
                    setState(() {
                      _dragFraction = null;
                    });
                  },
                  onTapDown: (details) {
                    _handleSeek(details.localPosition.dx, width);
                    _commitSeek();
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Wellenform-Balken
                      SizedBox(
                        height: height,
                        width: width,
                        child: CustomPaint(
                          painter: _WaveformPainter(
                            heights: _waveformHeights,
                            progressFraction: effectiveFraction,
                            isPlaying: widget.isPlaying,
                            pulseValue: _animCtrl.value,
                            activeColor: SpotifyColors.orange,
                            inactiveColor: const Color(0xFF262626),
                            cursorColor: Colors.white,
                          ),
                        ),
                      ),

                      // Tooltip-Bubble beim Scrubben mit Finger
                      if (_dragFraction != null)
                        Positioned(
                          left: (width * effectiveFraction - 28)
                              .clamp(0.0, width - 56),
                          top: -28,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: SpotifyColors.orange,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: SpotifyColors.orange
                                      .withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _formatDuration(displayPos),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // Zeit-Anzeige (Aktuell / Verbleibend)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(displayPos),
                    style: const TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isPlaying)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: SpotifyColors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        _formatDuration(widget.totalDuration),
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> heights;
  final double progressFraction;
  final bool isPlaying;
  final double pulseValue;
  final Color activeColor;
  final Color inactiveColor;
  final Color cursorColor;

  _WaveformPainter({
    required this.heights,
    required this.progressFraction,
    required this.isPlaying,
    required this.pulseValue,
    required this.activeColor,
    required this.inactiveColor,
    required this.cursorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (heights.isEmpty) return;

    final barCount = heights.length;
    final totalSpacing = size.width * 0.35;
    final spacing = totalSpacing / (barCount - 1);
    final barWidth = (size.width - totalSpacing) / barCount;
    final cursorX = (progressFraction * size.width).clamp(0.0, size.width);

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    final cursorPaint = Paint()
      ..color = cursorColor
      ..style = PaintingStyle.fill;

    final cursorGlowPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (int i = 0; i < barCount; i++) {
      final barLeft = i * (barWidth + spacing);
      final barRight = barLeft + barWidth;
      final barCenterX = barLeft + barWidth / 2;
      var normalizedHeight = heights[i];

      // Sanft fließende kontinuierliche Sinuswelle bei Wiedergabe
      if (isPlaying) {
        final wavePhase = pulseValue * 2 * math.pi;
        final waveMotion = math.sin(wavePhase + (i * 0.32)) * 0.12;

        // Zusätzlicher Nah-Playhead-Puls für spürbare musikalische Lebendigkeit
        final distFromPlayhead = (cursorX - barCenterX).abs();
        final nearFactor = (1.0 - (distFromPlayhead / 48.0)).clamp(0.0, 1.0);
        final nearPulse =
            math.sin(wavePhase * 2 + (i * 0.2)) * 0.16 * nearFactor;

        normalizedHeight =
            (normalizedHeight + waveMotion + nearPulse).clamp(0.18, 1.0);
      }

      final barH = normalizedHeight * (size.height - 6);
      final y = (size.height - barH) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barLeft, y, barWidth, barH),
        Radius.circular(barWidth / 2),
      );

      // Sub-Pixel-Präzision bei der Balken-Färbung
      if (barRight <= cursorX) {
        canvas.drawRRect(rect, activePaint);
      } else if (barLeft >= cursorX) {
        canvas.drawRRect(rect, inactivePaint);
      } else {
        // Bar liegt exakt unter der Playhead-Nadel: Split-Clip
        canvas.save();
        canvas.clipRect(Rect.fromLTRB(0, 0, cursorX, size.height));
        canvas.drawRRect(rect, activePaint);
        canvas.restore();

        canvas.save();
        canvas.clipRect(Rect.fromLTRB(cursorX, 0, size.width, size.height));
        canvas.drawRRect(rect, inactivePaint);
        canvas.restore();
      }
    }

    // Playhead Cursor-Nadel mit 60-FPS-Sub-Pixel-Gleiten und Glow
    final cursorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH((cursorX - 1.5).clamp(0.0, size.width - 3.0), 0, 3.0,
          size.height),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(cursorRect, cursorGlowPaint);
    canvas.drawRRect(cursorRect, cursorPaint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return true; // 60-FPS continuous interpolation
  }
}
