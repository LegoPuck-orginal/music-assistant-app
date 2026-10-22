import 'package:flutter/material.dart';

/// Spotify-Design Farbschema mit OLED-Schwarz (#000000 / #121212)
/// und Spotify-Signature Grün (#1DB954).
class SpotifyColors {
  // Hintergründe
  static const Color pureBlack = Color(0xFF000000);
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF181818);
  static const Color surfaceElevated = Color(0xFF242424);
  static const Color surfaceHighlight = Color(0xFF2A2A2A);

  // Spotify Signature Akzent
  static const Color green = Color(0xFF1DB954);
  static const Color greenLight = Color(0xFF1ED760);
  static const Color greenDim = Color(0x221DB954);

  // Typografie
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF727272);

  // Status & Steuerung
  static const Color borderSubtle = Color(0xFF282828);
  static const Color heartActive = Color(0xFF1DB954);
  static const Color sliderInactive = Color(0xFF4D4D4D);
  static const Color sliderActive = Color(0xFFFFFFFF);

  // Spotify Genre-Farben (für die Suchkacheln)
  static const List<Color> genreColors = [
    Color(0xFFE13300), // Pop / Orange-Rot
    Color(0xFF1E3264), // Rock / Dunkelblau
    Color(0xFF8D67AB), // Hip-Hop / Lila
    Color(0xFFE8115B), // Dance / Pink
    Color(0xFF148A08), // Indie / Grün
    Color(0xFFBC5900), // R&B / Braun-Orange
    Color(0xFF503750), // Chill / Violett
    Color(0xFF0D73EC), // Charts / Blau
  ];
}
