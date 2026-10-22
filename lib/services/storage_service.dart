import 'package:shared_preferences/shared_preferences.dart';
import '../models/equalizer_settings.dart';

class StorageService {
  static const String _keyServerUrl = 'mass_server_url';
  static const String _keyAuthToken = 'mass_auth_token';
  static const String _keyActivePlayer = 'mass_active_player';
  static const String _keyLikedTracks = 'mass_liked_tracks';
  static const String _keyEqEnabled = 'mass_eq_enabled';
  static const String _keyEqPreset = 'mass_eq_preset';
  static const String _keyEqBands = 'mass_eq_bands';

  // Default Admin Token from local system
  static const String defaultToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJqQVBSWElJMUVBa2hBVVNTODEwYVhLU2ZhaWhwQmY1anlzcnJUQ1RQUnpRIiwianRpIjoiYy1KNjdBMklRRTUyeGY4U3dYOXYyREI4VUlMSEg5S1VESi1qOVV5S0tNOCIsImlhdCI6MTc5MDQyNjA3MywiZXhwIjoxODIxOTYyMDczLCJ1c2VybmFtZSI6InRpbS1tIiwicm9sZSI6ImFkbWluIiwidG9rZW5fbmFtZSI6Imxlbm92by1sZWdpb25lIiwiaXNfbG9uZ19saXZlZCI6dHJ1ZX0.UNJl7eX_ycLgIjK0tP6WBZeuE8EoWejNn3BA0yiX_k4';

  Future<String> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl) ?? 'http://192.168.188.25:8095';
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
  }

  Future<String> loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAuthToken) ?? defaultToken;
  }

  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthToken, token);
  }

  Future<String?> loadActivePlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyActivePlayer);
  }

  Future<void> saveActivePlayerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActivePlayer, id);
  }

  Future<Set<String>> loadLikedTrackIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyLikedTracks) ?? [];
    return list.toSet();
  }

  Future<void> saveLikedTrackIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyLikedTracks, ids.toList());
  }

  Future<EqualizerSettings> loadEqualizerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_keyEqEnabled) ?? true;
    final preset = prefs.getString(_keyEqPreset) ?? 'Flat';
    final bandsList = prefs.getStringList(_keyEqBands);
    List<double> bands = [0.0, 0.0, 0.0, 0.0, 0.0];
    if (bandsList != null && bandsList.length == 5) {
      bands = bandsList.map((e) => double.tryParse(e) ?? 0.0).toList();
    }
    return EqualizerSettings(
      isEnabled: isEnabled,
      currentPreset: preset,
      bandGains: bands,
    );
  }

  Future<void> saveEqualizerSettings(EqualizerSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEqEnabled, settings.isEnabled);
    await prefs.setString(_keyEqPreset, settings.currentPreset);
    await prefs.setStringList(
      _keyEqBands,
      settings.bandGains.map((e) => e.toString()).toList(),
    );
  }
}
