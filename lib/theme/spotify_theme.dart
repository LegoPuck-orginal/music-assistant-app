import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'spotify_colors.dart';

class SpotifyTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SpotifyColors.pureBlack,
      canvasColor: SpotifyColors.pureBlack,
      cardColor: SpotifyColors.surface,
      dialogTheme: DialogThemeData(
        backgroundColor: SpotifyColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: SpotifyColors.borderHighlight, width: 0.9),
        ),
      ),
      dividerColor: SpotifyColors.borderSubtle,
      colorScheme: const ColorScheme.dark(
        primary: SpotifyColors.orange,
        onPrimary: Colors.black,
        secondary: SpotifyColors.orangeLight,
        onSecondary: Colors.black,
        surface: SpotifyColors.surface,
        onSurface: SpotifyColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: SpotifyColors.textPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: SpotifyColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.6,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SpotifyColors.pureBlack,
        selectedItemColor: SpotifyColors.orange,
        unselectedItemColor: SpotifyColors.textSecondary,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SpotifyColors.surfaceElevated,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: SpotifyColors.orange.withValues(alpha: 0.45),
            width: 0.9,
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
