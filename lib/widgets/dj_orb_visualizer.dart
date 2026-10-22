import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/spotify_colors.dart';

class DjOrbVisualizer extends StatefulWidget {
  final double size;
  final bool isSpeaking;
  final bool isPlaying;
  final VoidCallback? onTap;

  const DjOrbVisualizer({
    super.key,
    this.size = 200,
    this.isSpeaking = false,
    this.isPlaying = true,
    this.onTap,
  });

  @override
  State<DjOrbVisualizer> createState() => _DjOrbVisualizerState();
}

class _DjOrbVisualizerState extends State<DjOrbVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant DjOrbVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _animCtrl.duration = const Duration(milliseconds: 1400);
      _animCtrl.repeat();
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _animCtrl.duration = const Duration(milliseconds: 3200);
      _animCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, _) {
          final val = _animCtrl.value;
          final pulse = math.sin(val * math.pi * 2) * 0.08 + 1.0;
          final rot = val * math.pi * 2;

          return SizedBox(
            width: widget.size * 1.3,
            height: widget.size * 1.3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Ripple Ring 2 (when speaking)
                if (widget.isSpeaking)
                  Transform.scale(
                    scale: 1.0 + ((val + 0.5) % 1.0) * 0.45,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: SpotifyColors.green.withValues(
                            alpha: (1.0 - ((val + 0.5) % 1.0)) * 0.5,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                // Outer Ripple Ring 1 (when speaking or playing)
                if (widget.isSpeaking || widget.isPlaying)
                  Transform.scale(
                    scale: 1.0 + (val % 1.0) * 0.35,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00F2FE).withValues(
                            alpha: (1.0 - (val % 1.0)) * 0.6,
                          ),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),

                // Glowing Ambient Background Blur
                Container(
                  width: widget.size * pulse,
                  height: widget.size * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F2FE).withValues(
                          alpha: widget.isSpeaking ? 0.65 : 0.35,
                        ),
                        blurRadius: 40,
                        spreadRadius: widget.isSpeaking ? 16 : 8,
                      ),
                      BoxShadow(
                        color: SpotifyColors.green.withValues(
                          alpha: widget.isSpeaking ? 0.55 : 0.25,
                        ),
                        blurRadius: 60,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),

                // Rotating Gradient Layer
                Transform.rotate(
                  angle: rot,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFF00F2FE),
                          Color(0xFF4FACFE),
                          Color(0xFF7F00FF),
                          Color(0xFFE100FF),
                          Color(0xFF1DB954),
                          Color(0xFF00F2FE),
                        ],
                      ),
                    ),
                  ),
                ),

                // Inner Morphing Dark Core with Radial Pulse
                Container(
                  width: widget.size * 0.82,
                  height: widget.size * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF0A0E17),
                        const Color(0xFF030712).withValues(alpha: 0.95),
                      ],
                      center: const Alignment(-0.2, -0.2),
                      radius: 0.85,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isSpeaking
                              ? Icons.graphic_eq
                              : Icons.auto_awesome,
                          color: widget.isSpeaking
                              ? SpotifyColors.green
                              : const Color(0xFF00F2FE),
                          size: widget.size * 0.26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isSpeaking ? 'DJ SPRICHT' : 'DJ X',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.size * 0.08,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
