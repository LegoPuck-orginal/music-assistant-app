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
      dialogTheme: const DialogThemeData(
        backgroundColor: SpotifyColors.surfaceElevated,
      ),
      dividerColor: SpotifyColors.borderSubtle,
      colorScheme: const ColorScheme.dark(
        primary: SpotifyColors.orange,
        onPrimary: Colors.white,
        secondary: SpotifyColors.orangeLight,
        onSecondary: Colors.white,
        surface: SpotifyColors.surface,
        onSurface: SpotifyColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SpotifyColors.pureBlack,
        foregroundColor: SpotifyColors.textPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: SpotifyColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: SpotifyColors.pureBlack,
        selectedItemColor: SpotifyColors.orange,
        unselectedItemColor: SpotifyColors.textSecondary,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: SpotifyColors.surfaceElevated,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
