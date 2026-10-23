import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/spotify_colors.dart';

/// Interaktiver Audio-Waveform Scrubber & Visualizer im Spotify-Design.
/// Ersetzt den flachen Fortschrittsbalken durch dynamische Klangwellen-Balken,
/// die in Echtzeit pulsieren und direkt mit dem Finger gescrubbt werden können.
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
  late AnimationController _pulseCtrl;
  double? _dragFraction;
  int _lastHapticBar = -1;

  static const int _barCount = 48;
  late List<double> _waveformHeights;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isPlaying) {
      _pulseCtrl.repeat(reverse: true);
    }
    _waveformHeights = _generateWaveform(widget.trackKey);
  }

  @override
  void didUpdateWidget(covariant AudioWaveformScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackKey != widget.trackKey) {
      _waveformHeights = _generateWaveform(widget.trackKey);
    }
    if (widget.isPlaying && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isPlaying && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  /// Erzeugt eine reproduzierbare, musikalische Wellenform basierend auf dem Song-Titel
  List<double> _generateWaveform(String key) {
    final seed = key.hashCode.abs();
    final rng = math.Random(seed);
    final list = <double>[];

    for (int i = 0; i < _barCount; i++) {
      final t = i / _barCount;
      // Musikalischer Bogen: Leiser Einstieg, Steigerung im Refrain, Outro
      final envelope = math.sin(t * math.pi);
      final noise = rng.nextDouble() * 0.45 + 0.15;
      final harmonic = 0.25 * math.sin(t * 8 * math.pi);
      final height = (envelope * 0.65 + noise * 0.35 + harmonic).clamp(0.18, 1.0);
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
      final targetMs = (widget.totalDuration.inMilliseconds * _dragFraction!).round();
      widget.onSeek(Duration(milliseconds: targetMs));
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
    final effectiveFraction = _dragFraction ??
        (totalMs > 0
            ? (widget.currentPosition.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0);

    final displayPos = _dragFraction != null
        ? Duration(milliseconds: (totalMs * _dragFraction!).round())
        : widget.currentPosition;

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
              onHorizontalDragStart: (details) => _handleSeek(details.localPosition.dx, width),
              onHorizontalDragUpdate: (details) => _handleSeek(details.localPosition.dx, width),
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
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, child) {
                  return Stack(
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
                            pulseValue: _pulseCtrl.value,
                            activeColor: SpotifyColors.green,
                            inactiveColor: const Color(0xFF3E3E3E),
                            cursorColor: Colors.white,
                          ),
                        ),
                      ),

                      // Tooltip-Bubble beim Scrubben mit Finger
                      if (_dragFraction != null)
                        Positioned(
                          left: (width * effectiveFraction - 28).clamp(0.0, width - 56),
                          top: -26,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: SpotifyColors.green,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: SpotifyColors.green.withValues(alpha: 0.4),
                                  blurRadius: 8,
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
                  );
                },
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
                        color: SpotifyColors.green,
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
    final activeIndex = (progressFraction * barCount).floor();

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    final cursorPaint = Paint()
      ..color = cursorColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);
      var normalizedHeight = heights[i];

      // Dynamischer Puls-Effekt rund um den aktuellen Playhead
      if (isPlaying) {
        final distFromPlayhead = (i - activeIndex).abs();
        if (distFromPlayhead < 4) {
          final factor = (4 - distFromPlayhead) / 4.0;
          final pulse = math.sin((pulseValue * math.pi) + (i * 0.4)) * 0.22;
          normalizedHeight = (normalizedHeight + pulse * factor).clamp(0.15, 1.0);
        }
      }

      final barH = normalizedHeight * (size.height - 6);
      final y = (size.height - barH) / 2;
      final isPast = i <= activeIndex;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rect, isPast ? activePaint : inactivePaint);

      // Playhead Cursor-Nadel an der aktuellen Position
      if (i == activeIndex) {
        final cursorRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + (barWidth - 2.5) / 2, 0, 2.5, size.height),
          const Radius.circular(1.5),
        );
        canvas.drawRRect(cursorRect, cursorPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progressFraction != progressFraction ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.heights != heights;
  }
}
