import 'package:shared_preferences/shared_preferences.dart';
import '../models/adaptive_eq_settings.dart';
import '../models/dj_voice_settings.dart';
import '../models/equalizer_settings.dart';
import '../models/user_profile.dart';

class StorageService {
  static const String _keyServerUrl = 'mass_server_url';
  static const String _keyAuthToken = 'mass_auth_token';
  static const String _keyActivePlayer = 'mass_active_player';
  static const String _keyLikedTracks = 'mass_liked_tracks';
  static const String _keyEqEnabled = 'mass_eq_enabled';
  static const String _keyEqPreset = 'mass_eq_preset';
  static const String _keyEqBands = 'mass_eq_bands';
  static const String _keyUsername = 'mass_username';
  static const String _keyDisplayName = 'mass_display_name';
  static const String _keyUserRole = 'mass_user_role';
  static const String _keyUserId = 'mass_user_id';
  static const String _keyAvatarUrl = 'mass_avatar_url';
  static const String _keyIsGuest = 'mass_is_guest';
  static const String _keyWelcomeGuideCompleted = 'mass_welcome_guide_completed';

  // Standardmäßiger lokaler Entwickler-Token (optional für Tests)
  static const String defaultAdminToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJqQVBSWElJMUVBa2hBVVNTODEwYVhLU2ZhaWhwQmY1anlzcnJUQ1RQUnpRIiwianRpIjoiYy1KNjdBMklRRTUyeGY4U3dYOXYyREI4VUlMSEg5S1VESi1qOVV5S0tNOCIsImlhdCI6MTc5MDQyNjA3MywiZXhwIjoxODIxOTYyMDczLCJ1c2VybmFtZSI6InRpbS1tIiwicm9sZSI6ImFkbWluIiwidG9rZW5fbmFtZSI6Imxlbm92by1sZWdpb25lIiwiaXNfbG9uZ19saXZlZCI6dHJ1ZX0.UNJl7eX_ycLgIjK0tP6WBZeuE8EoWejNn3BA0yiX_k4';

  Future<bool> hasCompletedWelcomeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWelcomeGuideCompleted) ?? false;
  }

  Future<void> setWelcomeGuideCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWelcomeGuideCompleted, completed);
  }

  Future<String> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServerUrl) ?? 'http://homeassistant.local:8095';
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
  }

  Future<String?> loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAuthToken);
  }

  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthToken, token);
  }

  Future<UserProfile?> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername);
    if (username == null || username.isEmpty) return null;
    return UserProfile(
      userId: prefs.getString(_keyUserId) ?? '',
      username: username,
      displayName: prefs.getString(_keyDisplayName),
      role: prefs.getString(_keyUserRole) ?? 'user',
      avatarUrl: prefs.getString(_keyAvatarUrl),
    );
  }

  Future<void> saveUserProfile(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, user.username);
    if (user.displayName != null) {
      await prefs.setString(_keyDisplayName, user.displayName!);
    }
    await prefs.setString(_keyUserRole, user.role);
    await prefs.setString(_keyUserId, user.userId);
    if (user.avatarUrl != null) {
      await prefs.setString(_keyAvatarUrl, user.avatarUrl!);
    } else {
      await prefs.remove(_keyAvatarUrl);
    }
  }

  Future<bool> loadIsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsGuest) ?? false;
  }

  Future<void> saveIsGuest(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, isGuest);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyDisplayName);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyIsGuest);
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

  static const String _keyDjVoiceSettings = 'mass_dj_voice_settings';

  Future<DjVoiceSettings> loadDjVoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyDjVoiceSettings);
    if (str != null && str.isNotEmpty) {
      return DjVoiceSettings.fromJsonString(str);
    }
    return const DjVoiceSettings();
  }

  Future<void> saveDjVoiceSettings(DjVoiceSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDjVoiceSettings, settings.toJsonString());
  }

  static const String _keyAdaptiveEqSettings = 'mass_adaptive_eq_settings';

  Future<AdaptiveEqSettings> loadAdaptiveEqSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyAdaptiveEqSettings);
    if (str != null && str.isNotEmpty) {
      return AdaptiveEqSettings.fromJsonString(str);
    }
    return const AdaptiveEqSettings();
  }

  Future<void> saveAdaptiveEqSettings(AdaptiveEqSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAdaptiveEqSettings, settings.toJsonString());
  }
}
