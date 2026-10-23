import 'package:flutter/material.dart';

/// Next-Gen Adobe Studio Obsidian & Neon Ember Design-System (v2.0 Redesign):
/// Tiefstes OLED-Schwarz (#000000), geschichtete Obsidian-Glasflächen (#0C0C10 / #131319)
/// und leuchtendes Adobe-Signature-Orange (#FF5C00 -> #FF8833).
class SpotifyColors {
  // Tiefste OLED-Schwarztöne & Obsidian-Glasflächen
  static const Color pureBlack = Color(0xFF000000);
  static const Color background = Color(0xFF040406);
  static const Color surface = Color(0xFF0C0C10);
  static const Color surfaceElevated = Color(0xFF13131A);
  static const Color surfaceHighlight = Color(0xFF1D1D27);
  static const Color surfaceGlass = Color(0xCC14141C);

  // Adobe Creative Studio Signature Orange & Ember Akzente
  static const Color orange = Color(0xFFFF5C00);
  static const Color orangeLight = Color(0xFFFF8533);
  static const Color orangeNeon = Color(0xFFFF6E1A);
  static const Color orangeDim = Color(0x28FF5C00);
  static const Color accent = Color(0xFFFF5C00);
  static const Color accentGradientStart = Color(0xFFFF4D00);
  static const Color accentGradientEnd = Color(0xFFFF8800);

  // Abwärtskompatible Aliase
  static const Color green = Color(0xFFFF5C00);
  static const Color greenLight = Color(0xFFFF8533);
  static const Color greenDim = Color(0x28FF5C00);

  // Studio-Typografie (maximaler OLED-Kontrast)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA2A2B0);
  static const Color textMuted = Color(0xFF646474);

  // Präzise Hairline-Rahmen & Steuerungselemente
  static const Color borderSubtle = Color(0xFF1E1E28);
  static const Color borderHighlight = Color(0xFF2E2E3D);
  static const Color heartActive = Color(0xFFFF5C00);
  static const Color sliderInactive = Color(0xFF262632);
  static const Color sliderActive = Color(0xFFFF5C00);

  // Wiederverwendbare Studio-Farbverläufe
  static const LinearGradient emberGradient = LinearGradient(
    colors: [Color(0xFFFF4D00), Color(0xFFFF8524)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient obsidianCardGradient = LinearGradient(
    colors: [Color(0xFF171720), Color(0xFF0E0E14)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emberHeroGradient = LinearGradient(
    colors: [Color(0xFF281105), Color(0xFF130B08), Color(0xFF0A0A0E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration glassCard({
    double radius = 16,
    bool activeBorder = false,
    bool glow = false,
  }) {
    return BoxDecoration(
      gradient: obsidianCardGradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: activeBorder
            ? orange.withValues(alpha: 0.55)
            : borderSubtle,
        width: activeBorder ? 1.2 : 0.9,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: orange.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  // Adobe Studio Genre-Farben
  static const List<Color> genreColors = [
    Color(0xFFFF5C00), // Adobe Ember Orange
    Color(0xFF0066FF), // Studio Cobalt Blue
    Color(0xFFE02424), // Cinema Crimson
    Color(0xFF8A3FFC), // Premiere Violet
    Color(0xFFFF832B), // After Effects Amber
    Color(0xFF00C7FF), // Audition Cyan Wave
    Color(0xFF2B2B36), // Obsidian Slate
    Color(0xFFFF2E63), // Creative Magenta
  ];
}
