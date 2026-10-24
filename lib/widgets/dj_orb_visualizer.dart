import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/spotify_colors.dart';

class DjOrbVisualizer extends StatefulWidget {
  final double size;
  final bool isSpeaking;
  final bool isPlaying;
  final List<Color>? accentColors;
  final VoidCallback? onTap;

  const DjOrbVisualizer({
    super.key,
    this.size = 200,
    this.isSpeaking = false,
    this.isPlaying = true,
    this.accentColors,
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
    final primaryAccent = (widget.accentColors != null && widget.accentColors!.isNotEmpty)
        ? widget.accentColors!.first
        : SpotifyColors.orange;
    final secondaryAccent = (widget.accentColors != null && widget.accentColors!.length > 1)
        ? widget.accentColors![1]
        : SpotifyColors.amber;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, _) {
          final val = _animCtrl.value;
          final pulse = math.sin(val * math.pi * 2) * (widget.isSpeaking ? 0.11 : 0.06) + 1.0;
          final rot = val * math.pi * 2;

          return SizedBox(
            width: widget.size * 1.28,
            height: widget.size * 1.28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Ripple Ring 2 (when speaking)
                if (widget.isSpeaking)
                  Transform.scale(
                    scale: 1.0 + ((val + 0.5) % 1.0) * 0.42,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: SpotifyColors.amber.withValues(
                            alpha: (1.0 - ((val + 0.5) % 1.0)) * 0.55,
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                // Outer Ripple Ring 1 (when speaking or playing)
                if (widget.isSpeaking || widget.isPlaying)
                  Transform.scale(
                    scale: 1.0 + (val % 1.0) * 0.32,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryAccent.withValues(
                            alpha: (1.0 - (val % 1.0)) * 0.65,
                          ),
                          width: 2.2,
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
                        color: primaryAccent.withValues(
                          alpha: widget.isSpeaking ? 0.65 : 0.35,
                        ),
                        blurRadius: 42,
                        spreadRadius: widget.isSpeaking ? 16 : 8,
                      ),
                      BoxShadow(
                        color: secondaryAccent.withValues(
                          alpha: widget.isSpeaking ? 0.50 : 0.22,
                        ),
                        blurRadius: 64,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          primaryAccent,
                          SpotifyColors.amber,
                          SpotifyColors.purple,
                          secondaryAccent,
                          SpotifyColors.orange,
                          primaryAccent,
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
                        const Color(0xFF14121A),
                        const Color(0xFF040406).withValues(alpha: 0.96),
                      ],
                      center: const Alignment(-0.2, -0.2),
                      radius: 0.85,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.85),
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
                              ? Icons.graphic_eq_rounded
                              : Icons.auto_awesome_rounded,
                          color: widget.isSpeaking
                              ? SpotifyColors.amber
                              : primaryAccent,
                          size: widget.size * 0.25,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.isSpeaking ? 'ON AIR' : 'DJ X',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: widget.size * 0.08,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
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
