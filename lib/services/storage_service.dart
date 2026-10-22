import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyServerUrl = 'mass_server_url';
  static const String _keyActivePlayer = 'mass_active_player';
  static const String _keyLikedTracks = 'mass_liked_tracks';

  Future<String> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl) ?? 'http://192.168.188.25:8095';
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
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
}
