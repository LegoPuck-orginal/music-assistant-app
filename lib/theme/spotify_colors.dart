import 'package:flutter/material.dart';

/// Modernes Adobe-inspiriertes Design-Farbschema (Creative Cloud Dark Canvas)
/// mit tiefstem OLED-Schwarz (#000000 / #080808) und Adobe-Signature-Orange (#FF5C00).
class SpotifyColors {
  // Tiefste OLED-Schwarztöne (Adobe Canvas & Backgrounds)
  static const Color pureBlack = Color(0xFF000000);
  static const Color background = Color(0xFF070707);
  static const Color surface = Color(0xFF101010);
  static const Color surfaceElevated = Color(0xFF161616);
  static const Color surfaceHighlight = Color(0xFF222222);

  // Adobe Creative Cloud Signature Orange Akzente
  static const Color orange = Color(0xFFFF5C00);
  static const Color orangeLight = Color(0xFFFF7A22);
  static const Color orangeDim = Color(0x28FF5C00);
  static const Color accent = Color(0xFFFF5C00);
  static const Color accentGradientStart = Color(0xFFFF5000);
  static const Color accentGradientEnd = Color(0xFFFF7D00);

  // Abwärtskompatible Aliase für existierende UI-Elemente
  static const Color green = Color(0xFFFF5C00);
  static const Color greenLight = Color(0xFFFF7A22);
  static const Color greenDim = Color(0x28FF5C00);

  // Adobe Typografie (hoher Kontrast & Klarheit)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA8A8A8);
  static const Color textMuted = Color(0xFF6E6E6E);

  // Status & Steuerungselemente
  static const Color borderSubtle = Color(0xFF1C1C1C);
  static const Color borderHighlight = Color(0xFF2E2E2E);
  static const Color heartActive = Color(0xFFFF5C00);
  static const Color sliderInactive = Color(0xFF2A2A2A);
  static const Color sliderActive = Color(0xFFFF5C00);

  // Adobe Genre- und Themenfarben
  static const List<Color> genreColors = [
    Color(0xFFFF5C00), // Adobe Orange
    Color(0xFF0066FF), // Adobe Blue / Photoshop
    Color(0xFFE02424), // Creative Crimson
    Color(0xFF8A3FFC), // Premier Purple
    Color(0xFFFF832B), // Illustrator Warm Orange
    Color(0xFF00C7FF), // Cyan Wave
    Color(0xFF333333), // Obsidian Charcoal
    Color(0xFFFF3366), // XD Pink
  ];
}
