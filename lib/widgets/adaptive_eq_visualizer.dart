import 'dart:math';
import 'package:flutter/material.dart';
import '../models/adaptive_eq_settings.dart';
import '../theme/spotify_colors.dart';

class AdaptiveEqVisualizer extends StatefulWidget {
  final List<double> baselineGains; // 5 bands in dB
  final List<double> adaptiveDeltas; // 5 bands delta in dB
  final bool isAdaptiveEnabled;
  final AdaptiveEqMode mode;
  final String speakerName;
  final String? trackGenreHint;

  const AdaptiveEqVisualizer({
    super.key,
    required this.baselineGains,
    required this.adaptiveDeltas,
    required this.isAdaptiveEnabled,
    required this.mode,
    required this.speakerName,
    this.trackGenreHint,
  });

  @override
  State<AdaptiveEqVisualizer> createState() => _AdaptiveEqVisualizerState();
}

class _AdaptiveEqVisualizerState extends State<AdaptiveEqVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  String _getModeLabel() {
    switch (widget.mode) {
      case AdaptiveEqMode.auto:
        return 'VOLL-ADAPTIV (SMART)';
      case AdaptiveEqMode.dynamicLoudness:
        return 'FLETCHER-MUNSON LOUDNESS';
      case AdaptiveEqMode.genreDynamic:
        return 'AUTO-GENRE PROFILING';
      case AdaptiveEqMode.nightComfort:
        return 'NACHT-MODUS (BASS-SCHUTZ)';
      case AdaptiveEqMode.hearingProtection:
        return 'GEHÖRSCHUTZ / ANTI-FATIGUE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Container(
          height: 140,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isAdaptiveEnabled
                  ? SpotifyColors.green.withValues(alpha: 0.4)
                  : Colors.white12,
              width: 1.2,
            ),
            boxShadow: widget.isAdaptiveEnabled
                ? [
                    BoxShadow(
                      color: SpotifyColors.green.withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Status Row
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isAdaptiveEnabled
                          ? SpotifyColors.green
                          : Colors.grey,
                      boxShadow: widget.isAdaptiveEnabled
                          ? [
                              const BoxShadow(
                                color: SpotifyColors.green,
                                blurRadius: 6,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getModeLabel(),
                    style: TextStyle(
                      color: widget.isAdaptiveEnabled
                          ? SpotifyColors.green
                          : Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.speakerName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Frequency Response Spline Canvas
              Expanded(
                child: CustomPaint(
                  painter: _AdaptiveCurvePainter(
                    baselineGains: widget.baselineGains,
                    adaptiveDeltas: widget.adaptiveDeltas,
                    isAdaptiveEnabled: widget.isAdaptiveEnabled,
                    pulseAnim: _animCtrl.value,
                  ),
                  child: Container(),
                ),
              ),

              // Frequency Scale Labels
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('60Hz', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
                    Text('230Hz', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
                    Text('910Hz', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
                    Text('4kHz', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
                    Text('14kHz', style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdaptiveCurvePainter extends CustomPainter {
  final List<double> baselineGains;
  final List<double> adaptiveDeltas;
  final bool isAdaptiveEnabled;
  final double pulseAnim;

  _AdaptiveCurvePainter({
    required this.baselineGains,
    required this.adaptiveDeltas,
    required this.isAdaptiveEnabled,
    required this.pulseAnim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h * 0.5;

    // Zero dB Center Guideline
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);

    final numPoints = 5;
    final points = <Offset>[];
    final basePoints = <Offset>[];

    for (int i = 0; i < numPoints; i++) {
      final x = (w / (numPoints - 1)) * i;
      final base = (i < baselineGains.length) ? baselineGains[i] : 0.0;
      final delta = (isAdaptiveEnabled && i < adaptiveDeltas.length)
          ? adaptiveDeltas[i]
          : 0.0;

      // Pulse wave subtle breathing effect
      final pulse = isAdaptiveEnabled ? (sin(pulseAnim * pi * 2 + i) * 0.4) : 0.0;
      final totalGain = (base + delta + pulse).clamp(-12.0, 12.0);

      // Map -12dB ... +12dB to height
      final y = midY - (totalGain / 12.0) * (h * 0.44);
      points.add(Offset(x, y));

      final baseY = midY - (base / 12.0) * (h * 0.44);
      basePoints.add(Offset(x, baseY));
    }

    // 1. Draw Baseline Ghost Curve (if adaptive delta is active)
    if (isAdaptiveEnabled && adaptiveDeltas.any((d) => d.abs() > 0.1)) {
      final baseCurvePath = _computeSpline(basePoints);
      final ghostPaint = Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawPath(baseCurvePath, ghostPaint);
    }

    // 2. Draw Smooth Spline Path
    final curvePath = _computeSpline(points);

    // Gradient Fill under curve
    final fillPath = Path.from(curvePath)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isAdaptiveEnabled
          ? [
              SpotifyColors.green.withValues(alpha: 0.28),
              const Color(0xFF00F2FE).withValues(alpha: 0.05),
              Colors.transparent,
            ]
          : [
              Colors.white12,
              Colors.transparent,
            ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    // Dynamic Spline Stroke
    final strokePaint = Paint()
      ..shader = LinearGradient(
        colors: isAdaptiveEnabled
            ? [
                SpotifyColors.green,
                const Color(0xFF00F2FE),
                SpotifyColors.green,
              ]
            : [Colors.white70, Colors.white54],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(curvePath, strokePaint);

    // Draw Dynamic Frequency Nodes
    final nodePaint = Paint()
      ..color = isAdaptiveEnabled ? SpotifyColors.green : Colors.white
      ..style = PaintingStyle.fill;

    final haloPaint = Paint()
      ..color = isAdaptiveEnabled
          ? SpotifyColors.green.withValues(alpha: 0.3)
          : Colors.white24
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      canvas.drawCircle(pt, isAdaptiveEnabled ? 5.5 : 3.5, haloPaint);
      canvas.drawCircle(pt, isAdaptiveEnabled ? 3.0 : 2.0, nodePaint);
    }
  }

  Path _computeSpline(List<Offset> pts) {
    final path = Path();
    if (pts.isEmpty) return path;
    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _AdaptiveCurvePainter oldDelegate) {
    return true;
  }
}
