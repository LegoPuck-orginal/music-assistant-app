import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/adaptive_eq_settings.dart';
import '../models/app_update_info.dart';
import '../models/audiobook.dart';
import '../models/dj_voice_settings.dart';
import '../models/dsp_models.dart';
import '../models/equalizer_settings.dart';
import '../models/player_device.dart';
import '../models/playlist.dart';
import '../models/recommendation.dart';
import '../models/track.dart';
import '../models/user_profile.dart';
import '../models/virtual_dj_vibe.dart';
import '../services/download_service.dart';
import '../services/apple_now_playing_service.dart';
import '../services/live_activity_service.dart';
import '../services/mass_api_service.dart';
import '../services/ollama_service.dart';
import '../services/player_position_tracker.dart';
import '../services/smart_dj_curator.dart';
import '../services/storage_service.dart';
import '../services/sendspin_player_service.dart';
import '../services/update_service.dart';
import '../services/virtual_dj_service.dart';
import '../services/watch_service.dart';

class MusicProvider extends ChangeNotifier {
  final MassApiService _api = MassApiService();
  final StorageService _storage = StorageService();
  final AudioPlayer _localAudioPlayer = AudioPlayer();
  AudioPlayer get localAudioPlayer => _localAudioPlayer;
  final SendspinPlayerService _sendspinService = SendspinPlayerService();
  final UpdateService _updateService = UpdateService();
  final DownloadService _downloadService = DownloadService();
  final PlayerPositionTracker _positionTracker = PlayerPositionTracker();

  bool _isOfflineMode = false;
  AppUpdateInfo? _updateInfo;
  bool _isCheckingForUpdates = false;

  Track? _currentTrack;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 3, seconds: 30);
  bool _isShuffle = false;
  int _repeatMode = 0; // 0 = off, 1 = all, 2 = one

  List<Track> _queue = [];
  int _queueIndex = 0;
  List<Playlist> _playlists = [];
  List<Playlist> _customPlaylists = [];
  List<Playlist> _podcasts = [];
  List<Playlist> _albums = [];
  List<Playlist> _artists = [];
  final List<Audiobook> _audiobooks = Audiobook.sampleAudiobooks;
  List<PlayerDevice> _players = [];
  PlayerDevice? _activePlayer;
  Set<String> _likedTrackIds = {};
  List<Track> _recentlyPlayedTracks = [];
  bool _allowLocalPlayback = true;
  bool _losslessStreaming = true;
  bool _crossfadeEnabled = true;
  bool _dontStopTheMusic = true;
  DateTime? _sleepTimerEndTime;
  Timer? _sleepTimerCountdown;
  DateTime? _lastPlayCommandTime;
  Timer? _positionTimer;
  Timer? _positionTicker;
  Timer? _playerPollTimer;
  final Map<String, int> _pendingTargetVolumes = {};
  final Map<String, Timer> _volumeDebounceTimers = {};
  final Map<String, DateTime> _lastVolumeSentTimes = {};
  Timer? _adaptiveEqDebounceTimer;
  String _serverUrl = 'http://homeassistant.local:8095';
  String _authToken = '';
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  bool _hasCompletedWelcomeGuide = false;
  UserProfile? _currentUser;
  bool _isLoggingIn = false;
  String? _loginError;
  EqualizerSettings _equalizerSettings = EqualizerSettings();
  AdaptiveEqSettings _adaptiveEqSettings = const AdaptiveEqSettings();
  DspConfig? _dspConfig;
  List<DspPreset> _dspPresets = [];
  bool _isLoadingDsp = false;
  String? _dspError;
  StreamSubscription? _eventsSubscription;
  StreamSubscription? _authSubscription;

  // Search Results
  List<Track> _searchResultsTracks = [];
  List<Playlist> _searchResultsPlaylists = [];
  List<Playlist> _searchResultsAlbums = [];
  List<Playlist> _searchResultsPodcasts = [];
  bool _isSearching = false;
  String _lastSearchQuery = '';

  // Recommendations
  List<RecommendationRow> _recommendations = [];
  bool _isLoadingRecommendations = false;

  List<Playlist> get playlists => _playlists;
  List<Playlist> get podcasts => _podcasts;
  List<Playlist> get albums => _albums;
  List<Playlist> get artists => _artists;
  List<Audiobook> get audiobooks => _audiobooks;
  List<RecommendationRow> get recommendations => _recommendations;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  List<Track> get searchResultsTracks => _searchResultsTracks;
  List<Playlist> get searchResultsPlaylists => _searchResultsPlaylists;
  List<Playlist> get searchResultsAlbums => _searchResultsAlbums;
  List<Playlist> get searchResultsPodcasts => _searchResultsPodcasts;
  bool get isSearching => _isSearching;
  String get lastSearchQuery => _lastSearchQuery;

  // Virtual DJ & Dynamic Island State
  final VirtualDjService _djService = VirtualDjService();
  DjVoiceSettings _djVoiceSettings = const DjVoiceSettings();
  List<Track> _libraryTracks = [];
  final Set<String> _djPlayedTrackIds = {};
  int _djTracksSinceLastModeration = 0;
  String? _lastDjCustomPrompt;
  bool _isDjActive = false;
  bool _isDjSpeaking = false;
  bool _isDjVoiceEnabled = true;
  DjVibe _currentDjVibe = DjVibe.allVibes.first;
  String? _djSpeechText;
  Timer? _djSpeechTimer;
  StreamSubscription? _djSpeechSub;

  DjVoiceSettings get djVoiceSettings => _djVoiceSettings;
  bool get isDjActive => _isDjActive;
  bool get isDjSpeaking => _isDjSpeaking;
  bool get isDjVoiceEnabled => _isDjVoiceEnabled;
  DjVibe get currentDjVibe => _currentDjVibe;
  String? get djSpeechText => _djSpeechText;
  String? get lastDjCustomPrompt => _lastDjCustomPrompt;

  void toggleDjVoice() {
    _isDjVoiceEnabled = !_isDjVoiceEnabled;
    if (!_isDjVoiceEnabled && _isDjSpeaking) {
      unawaited(skipDjSpeech());
    }
    notifyListeners();
  }

  Future<void> updateDjVoiceSettings(DjVoiceSettings newSettings) async {
    _djVoiceSettings = newSettings;
    await _storage.saveDjVoiceSettings(newSettings);
    notifyListeners();
  }

  Future<void> previewDjVoice() async {
    final userName = _currentUser?.effectiveName.split(' ').first ?? 'Musikfreund';
    await _djService.previewVoice(_djVoiceSettings, userName);
  }

  String? _savedActivePlayerId;

  MusicProvider() {
    // Populate with fallback data immediately so UI never shows a blank screen
    _playlists = _api.getFallbackPlaylists();
    _queue = _api.getFallbackTracks();
    _libraryTracks = List.from(_queue);
    // Standardmäßig keinen Track vorwählen, damit unten im MiniPlayer kein ungewollter Song erscheint!
    _currentTrack = null;
    _totalDuration = Duration.zero;
    final localIPhone = PlayerDevice.localIPhone(isSelected: true);
    _players = [localIPhone];
    _activePlayer = localIPhone;
  }

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  bool get isShuffle => _isShuffle;
  int get repeatMode => _repeatMode;
  List<Track> get queue => _queue;
  List<PlayerDevice> get players => _players;
  PlayerDevice? get activePlayer => _activePlayer;

  /// Findet andere Lautsprecher im Netzwerk, die gerade aktiv Musik spielen
  List<PlayerDevice> get otherPlayingPlayers =>
      _players.where((p) => !p.isSelected && p.isPlaying && p.hasActiveTrack).toList();

  /// Übernimmt die aktive Steuerung eines Lautsprechers, der gerade Musik abspielt
  Future<void> takeOverControl(PlayerDevice player) async {
    await setActivePlayer(player, isTakeover: true);
    if (player.hasActiveTrack) {
      _currentTrack = Track(
        id: player.id,
        title: player.currentTitle!,
        artist: player.currentArtist ?? '',
        album: player.currentAlbum ?? '',
        imageUrl: player.currentImageUrl,
        durationSeconds: player.currentDurationSeconds ?? 180,
        uri: player.currentUri,
        isLiked: _likedTrackIds.contains(player.id),
      );
      _totalDuration = Duration(seconds: player.currentDurationSeconds ?? 180);
      _currentPosition = Duration(seconds: player.elapsedTimeSeconds ?? 0);
      _isPlaying = (player.state == 'playing');
      _startPositionTimer();
    }
    await loadServerQueue();
    notifyListeners();
  }
  MassApiService get api => _api;
  bool get isServerConnected => _api.isConnected;
  String get serverUrl => _serverUrl;
  String get authToken => _authToken;
  EqualizerSettings get equalizerSettings => _equalizerSettings;
  AdaptiveEqSettings get adaptiveEqSettings => _adaptiveEqSettings;
  DspConfig? get dspConfig => _dspConfig;

  List<double> get currentAdaptiveDeltas =>
      _adaptiveEqSettings.calculateCorrections(
        volume: _activePlayer?.volume ?? 50,
        currentTrack: _currentTrack,
        activePlayer: _activePlayer,
      );
  List<DspPreset> get dspPresets => _dspPresets;
  bool get isLoadingDsp => _isLoadingDsp;
  String? get dspError => _dspError;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasCompletedWelcomeGuide => _hasCompletedWelcomeGuide;
  String get appVersion => '1.11.6';
  UserProfile? get currentUser => _currentUser;
  bool get isLoggingIn => _isLoggingIn;
  String? get loginError => _loginError;
  AppUpdateInfo? get updateInfo => _updateInfo;
  bool get isCheckingForUpdates => _isCheckingForUpdates;
  bool get hasUpdate => _updateInfo?.hasUpdate ?? false;

  bool get allowLocalPlayback => _allowLocalPlayback;
  bool get losslessStreaming => _losslessStreaming;
  bool get crossfadeEnabled => _crossfadeEnabled;
  bool get dontStopTheMusic => _dontStopTheMusic;

  List<Track> get recentlyPlayedTracks => _recentlyPlayedTracks.isNotEmpty
      ? _recentlyPlayedTracks
      : _queue.take(10).toList();

  /// Alle als Favorit / Lieblingssong markierten Titel (aus Queue, Bibliothek, Playlists, Verlauf & Downloads)
  List<Track> get likedTracks {
    final Map<String, Track> map = {};
    void consider(Track t) {
      final liked = t.isLiked || _likedTrackIds.contains(t.id);
      if (liked) {
        t.isLiked = true;
        final key = t.id.isNotEmpty ? t.id : '${t.title}_${t.artist}';
        map.putIfAbsent(key, () => t);
      }
    }

    if (_currentTrack != null) consider(_currentTrack!);
    for (final t in _queue) {
      consider(t);
    }
    for (final p in _playlists) {
      for (final t in p.tracks) {
        consider(t);
      }
    }
    for (final p in _customPlaylists) {
      for (final t in p.tracks) {
        consider(t);
      }
    }
    for (final t in _recentlyPlayedTracks) {
      consider(t);
    }
    for (final t in downloadedTracks) {
      consider(t);
    }
    final list = map.values.toList();
    final likedList = _likedTrackIds.toList();
    list.sort((a, b) {
      final idxA = likedList.indexOf(a.id);
      final idxB = likedList.indexOf(b.id);
      if (idxA != -1 && idxB != -1) {
        return idxB.compareTo(idxA);
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  Duration? get sleepTimerRemaining {
    if (_sleepTimerEndTime == null) return null;
    final diff = _sleepTimerEndTime!.difference(DateTime.now());
    if (diff.isNegative) return null;
    return diff;
  }

  bool get hasActiveSleepTimer => sleepTimerRemaining != null;

  String? get formattedSleepTimerRemaining {
    final rem = sleepTimerRemaining;
    if (rem == null) return null;
    final mins = rem.inMinutes;
    final secs = rem.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> setAllowLocalPlayback(bool value) async {
    _allowLocalPlayback = value;
    await _storage.saveAllowLocalPlayback(value);
    if (!value && _activePlayer?.isLocal == true) {
      await _localAudioPlayer.pause();
      _isPlaying = false;
      final remote = _players.where((p) => !p.isLocal && p.isAvailable).firstOrNull;
      if (remote != null) {
        await setActivePlayer(remote);
      }
    }
    notifyListeners();
  }

  Future<void> setLosslessStreaming(bool value) async {
    _losslessStreaming = value;
    await _storage.saveLosslessStreaming(value);
    notifyListeners();
  }

  Future<void> setCrossfadeEnabled(bool value) async {
    _crossfadeEnabled = value;
    await _storage.saveCrossfadeEnabled(value);
    notifyListeners();
    if (_activePlayer != null && !_activePlayer!.isLocal && _api.isConnected) {
      try {
        await _api.setCrossfade(_activePlayer!.id, value);
      } catch (e) {
        debugPrint('[MusicProvider] setCrossfadeEnabled error: $e');
      }
    }
  }

  Future<void> setDontStopTheMusic(bool value) async {
    _dontStopTheMusic = value;
    await _storage.saveDontStopTheMusic(value);
    notifyListeners();
    if (_activePlayer != null && !_activePlayer!.isLocal && _api.isConnected) {
      try {
        await _api.setDontStopTheMusic(_activePlayer!.id, value);
      } catch (e) {
        debugPrint('[MusicProvider] setDontStopTheMusic error: $e');
      }
    }
  }

  void _recordRecentlyPlayed(Track track) {
    _recentlyPlayedTracks.removeWhere(
      (t) => t.id == track.id || (t.title == track.title && t.artist == track.artist),
    );
    _recentlyPlayedTracks.insert(0, track);
    if (_recentlyPlayedTracks.length > 25) {
      _recentlyPlayedTracks = _recentlyPlayedTracks.sublist(0, 25);
    }
    _storage.saveRecentlyPlayedTracks(_recentlyPlayedTracks);
  }

  Future<void> clearRecentlyPlayed() async {
    _recentlyPlayedTracks.clear();
    await _storage.saveRecentlyPlayedTracks([]);
    notifyListeners();
  }

  Future<void> completeWelcomeGuide() async {
    _hasCompletedWelcomeGuide = true;
    await _storage.setWelcomeGuideCompleted(true);
    notifyListeners();
  }

  Future<void> resetWelcomeGuide() async {
    _hasCompletedWelcomeGuide = false;
    await _storage.setWelcomeGuideCompleted(false);
    notifyListeners();
  }

  /// Prüft eigenständig, ob ein Server erreichbar ist
  Future<Map<String, dynamic>> testServerConnection([String? url]) async {
    return await MassApiService.testConnection(url ?? _serverUrl);
  }

  /// Sucht automatisch nach Music Assistant Instanzen im lokalen WLAN
  Future<List<String>> discoverLocalServers() async {
    return await MassApiService.discoverLocalServers();
  }

  // Offline Mode & Downloads
  bool get isOfflineMode => _isOfflineMode;
  void setOfflineMode(bool enabled) {
    _isOfflineMode = enabled;
    notifyListeners();
  }
  void toggleOfflineMode() => setOfflineMode(!_isOfflineMode);

  List<Track> get downloadedTracks =>
      _downloadService.downloadedTracks.map((dt) => dt.toTrack()).toList();
  bool isTrackDownloaded(String trackId) => _downloadService.isDownloaded(trackId);
  bool isTrackDownloading(String trackId) => _downloadService.isDownloading(trackId);
  double? getDownloadProgress(String trackId) => _downloadService.getProgress(trackId);
  int get totalDownloadedBytes => _downloadService.getTotalSizeBytes();
  String get formattedDownloadedSize => _downloadService.getFormattedTotalSize();

  Future<bool> downloadTrack(Track track) async {
    final res = await _downloadService.downloadTrack(
      track,
      serverUrl: _serverUrl,
      token: _authToken,
    );
    notifyListeners();
    return res;
  }

  Future<void> downloadPlaylist(Playlist playlist) async {
    await _downloadService.downloadPlaylist(
      playlist,
      playlist.tracks,
      serverUrl: _serverUrl,
      token: _authToken,
    );
    notifyListeners();
  }

  Future<bool> removeDownload(String trackId) async {
    final res = await _downloadService.removeDownload(trackId);
    notifyListeners();
    return res;
  }

  Future<void> clearAllDownloads() async {
    await _downloadService.clearAllDownloads();
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      _hasCompletedWelcomeGuide = await _storage.hasCompletedWelcomeGuide();
      _serverUrl = await _storage.loadServerUrl();
      final token = await _storage.loadAuthToken();
      _currentUser = await _storage.loadUserProfile();
      final isGuest = await _storage.loadIsGuest();
      _likedTrackIds = await _storage.loadLikedTrackIds();
      _equalizerSettings = await _storage.loadEqualizerSettings();
      _adaptiveEqSettings = await _storage.loadAdaptiveEqSettings();
      _djVoiceSettings = await _storage.loadDjVoiceSettings();
      _allowLocalPlayback = await _storage.loadAllowLocalPlayback();
      _losslessStreaming = await _storage.loadLosslessStreaming();
      _crossfadeEnabled = await _storage.loadCrossfadeEnabled();
      _dontStopTheMusic = await _storage.loadDontStopTheMusic();
      _savedActivePlayerId = await _storage.loadActivePlayerId();
      _customPlaylists = await _storage.loadCustomPlaylists();
      _recentlyPlayedTracks = await _storage.loadRecentlyPlayedTracks();

      for (final t in _queue) {
        if (_likedTrackIds.contains(t.id)) t.isLiked = true;
      }
      if (_customPlaylists.isNotEmpty) {
        final existingIds = _playlists.map((p) => p.id).toSet();
        for (final cp in _customPlaylists.reversed) {
          if (!existingIds.contains(cp.id)) {
            _playlists.insert(0, cp);
          }
        }
      }

      if (token != null && token.isNotEmpty) {
        _authToken = token;
        _isAuthenticated = true;
      } else if (isGuest) {
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      debugPrint('[MusicProvider] Storage init error: $e');
    }

    // Setup local audio player listeners
    try {
      _setupLocalAudioPlayer();
    } catch (e) {
      debugPrint('[MusicProvider] AudioPlayer setup error: $e');
    }

    // Initialize downloads
    try {
      await _downloadService.init();
      _downloadService.addListener(notifyListeners);
    } catch (e) {
      debugPrint('[MusicProvider] DownloadService init error: $e');
    }

    _isInitialized = true;
    try {
      WatchService.instance.init(this);
      WatchService.instance.syncState(this);
    } catch (_) {}
    try {
      AppleNowPlayingService.instance.initialize(this);
      AppleNowPlayingService.instance.sync(this);
    } catch (_) {}
    notifyListeners();

    // Check silently for updates in background
    checkForUpdates();

    // Connect to server and refresh data asynchronously in background
    if (_isAuthenticated && _authToken.isNotEmpty) {
      _connectAndRefresh();
    } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      // Automatische Erkennung im Heimnetz, falls ein Server im lokalen Netz erreichbar ist
      _tryAutoConnectLocalServer();
    }
  }

  Future<void> _tryAutoConnectLocalServer() async {
    try {
      final savedToken = await _storage.loadAuthToken();
      if (savedToken == null || savedToken.isEmpty) return;
      final discovered = await discoverLocalServers();
      if (discovered.isNotEmpty) {
        _serverUrl = discovered.first;
        _authToken = savedToken;
        _isAuthenticated = true;
        await _storage.saveServerUrl(_serverUrl);
        _connectAndRefresh();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MusicProvider] _tryAutoConnectLocalServer error: $e');
    }
  }

  @visibleForTesting
  PlayerDevice? selectPreferredRealSpeaker(
    List<PlayerDevice> candidates, {
    String? savedPlayerId,
  }) =>
      _selectPreferredRealSpeaker(candidates, savedPlayerId: savedPlayerId);

  @visibleForTesting
  String resolveTrackMediaUri(Track track) => _resolveTrackMediaUri(track);

  /// Wählt den besten echten Music Assistant Netzwerk-Lautsprecher aus (niemals local_iphone bevorzugen)
  PlayerDevice? _selectPreferredRealSpeaker(
    List<PlayerDevice> candidates, {
    String? savedPlayerId,
  }) {
    final realSpeakers = candidates
        .where((p) => !p.isLocal && !p.id.startsWith('hue-'))
        .toList();
    if (realSpeakers.isEmpty) return null;

    // 1. Aktuell spielender Lautsprecher
    for (final p in realSpeakers) {
      if (p.isPlaying && p.isAvailable) return p;
    }

    // 2. Gespeicherter echter Lautsprecher (niemals 'local_iphone')
    final effectiveSaved = savedPlayerId ?? _savedActivePlayerId;
    if (effectiveSaved != null &&
        effectiveSaved.isNotEmpty &&
        effectiveSaved != 'local_iphone') {
      for (final p in realSpeakers) {
        if (p.id == effectiveSaved && p.isAvailable) return p;
      }
    }

    // 3. Dynamischer Profil-Lautsprecher (falls Raumname zum angemeldeten Benutzerprofil passt)
    final profileFirst = _currentUser?.effectiveName.split(' ').first.toLowerCase();
    if (profileFirst != null && profileFirst.isNotEmpty) {
      for (final p in realSpeakers) {
        if (p.isAvailable && p.name.toLowerCase().contains(profileFirst)) {
          return p;
        }
      }
    }

    // 4. Erster verfügbarer echter Netzwerk-Lautsprecher
    for (final p in realSpeakers) {
      if (p.isAvailable) return p;
    }

    // 5. Fallback auf ersten echten Lautsprecher
    return realSpeakers.first;
  }

  /// Löst die saubere, vollständige Music Assistant URI für einen Track auf (keine 30s-Previews!)
  String _resolveTrackMediaUri(Track track) {
    final rawUri = track.rawSource?['uri']?.toString();
    if (rawUri != null &&
        rawUri.isNotEmpty &&
        !rawUri.contains('p.scdn.co/mp3-preview') &&
        !rawUri.contains('rockantenne.hamburg')) {
      return rawUri;
    }
    final uri = track.uri;
    if (uri != null &&
        uri.isNotEmpty &&
        !uri.contains('p.scdn.co/mp3-preview') &&
        !uri.contains('rockantenne.hamburg') &&
        !_isImageUrl(uri)) {
      return uri;
    }
    final prov = (track.provider != null && track.provider!.isNotEmpty)
        ? track.provider!
        : 'library';
    return '$prov://track/${track.id}';
  }

  /// Prüft GitHub auf verfügbare Updates
  Future<AppUpdateInfo> checkForUpdates({String? currentVersionOverride}) async {
    _isCheckingForUpdates = true;
    notifyListeners();

    try {
      _updateInfo = await _updateService.checkForUpdate(
        currentVersionOverride: currentVersionOverride,
      );
    } catch (e) {
      debugPrint('[MusicProvider] checkForUpdates error: $e');
    } finally {
      _isCheckingForUpdates = false;
      notifyListeners();
    }
    return _updateInfo ?? AppUpdateInfo.noUpdate(currentVersion: '1.11.6');
  }

  void _connectAndRefresh() {
    try {
      _authSubscription?.cancel();
      _authSubscription = _api.onAuthenticated.listen((_) {
        debugPrint(
            '[MusicProvider] Authenticated with Music Assistant! Synchronizing players and library...');
        if (_api.currentUser != null) {
          _currentUser = UserProfile.fromJson(_api.currentUser!);
          _storage.saveUserProfile(_currentUser!);
          notifyListeners();
        }
        refreshServerData();
      });

      _eventsSubscription?.cancel();
      _eventsSubscription = _api.events.listen(_handleServerEvent);

      _api.configure(_serverUrl, _authToken);
      unawaited(_initSendspinPlayer());

      if (_api.isConnected) {
        refreshServerData();
      } else if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
        // Falls gespeicherte Server-URL (z. B. homeassistant.local) nicht auflöst, automatisch im LAN suchen
        Future.delayed(const Duration(milliseconds: 2200), () async {
          if (!_api.isConnected && _isAuthenticated) {
            final discovered = await discoverLocalServers();
            if (discovered.isNotEmpty && discovered.first != _serverUrl) {
              debugPrint(
                  '[MusicProvider] Switching to discovered server ${discovered.first}');
              _serverUrl = discovered.first;
              await _storage.saveServerUrl(_serverUrl);
              _api.configure(_serverUrl, _authToken);
              unawaited(_initSendspinPlayer());
            }
          }
        });
      }

      // Kontinuierliche, flüssige Taktung der Live-Position auf Basis der echten Server-Anker
      _positionTicker?.cancel();
      _positionTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (_isPlaying && _activePlayer != null && !_activePlayer!.isLocal) {
          final effectiveDuration =
              _positionTracker.getPositionDuration(_activePlayer!.id);
          if ((effectiveDuration.inMilliseconds - _currentPosition.inMilliseconds).abs() >= 100) {
            _currentPosition = effectiveDuration;
            notifyListeners();
          }
        }
      });

      // Aktive Überwachung aller Lautsprecher im 3-Sekunden-Takt (Multiroom & Remote Status)
      _playerPollTimer?.cancel();
      _playerPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (_api.isConnected && _isAuthenticated) {
          await _pollPlayersStatus();
        }
      });
    } catch (e) {
      debugPrint('[MusicProvider] Background connect error: $e');
    }
  }

  bool _isVolumeRecentlyAdjusted(String playerId) {
    if (_volumeDebounceTimers.containsKey(playerId)) return true;
    final lastSent = _lastVolumeSentTimes[playerId];
    if (lastSent != null &&
        DateTime.now().difference(lastSent) < const Duration(milliseconds: 500)) {
      return true;
    }
    return false;
  }

  /// Fragt im Hintergrund aktiv den Status aller Lautsprecher ab, um aktive Wiedergabe sofort zu erkennen
  Future<void> _pollPlayersStatus() async {
    try {
      final remotePlayersFuture = _api.fetchPlayers();
      final remoteQueuesFuture = _api.fetchPlayerQueues();
      final results = await Future.wait([remotePlayersFuture, remoteQueuesFuture]);
      final remotePlayers = results[0] as List<PlayerDevice>;
      final remoteQueues = results[1] as List<Map<String, dynamic>>;

      if (remotePlayers.isEmpty) return;

      final Map<String, Map<String, dynamic>> queueMap = {};
      for (final q in remoteQueues) {
        final qId = q['queue_id']?.toString();
        if (qId != null) queueMap[qId] = q;
      }

      bool changed = false;
      PlayerDevice? activePlayingDevice;

      for (final rp in remotePlayers) {
        final q = queueMap[rp.id];
        String effectiveState = rp.state;
        String? effectiveTitle = rp.currentTitle;
        String? effectiveArtist = rp.currentArtist;
        String? effectiveAlbum = rp.currentAlbum;
        String? effectiveImageUrl = rp.currentImageUrl;
        int? effectiveDuration = rp.currentDurationSeconds;
        int? effectiveElapsed = rp.elapsedTimeSeconds;

        if (q != null) {
          final qState = q['state']?.toString();
          if (qState != null && qState.isNotEmpty) effectiveState = qState;

          final qElapsed = (q['elapsed_time'] as num?)?.toDouble();
          if (qElapsed != null) {
            effectiveElapsed = qElapsed.round();
            _positionTracker.setAnchor(
              queueId: rp.id,
              elapsedSec: qElapsed,
              isPlaying: (effectiveState == 'playing'),
              durationSec: (q['duration'] as num?)?.toDouble(),
            );
          }

          final currentItem = q['current_item'] as Map<dynamic, dynamic>?;
          if (currentItem != null) {
            final cMap = Map<String, dynamic>.from(currentItem);
            final cDur = (cMap['duration'] as num?)?.toInt();
            if (cDur != null && cDur > 0) effectiveDuration = cDur;

            final mediaItem = cMap['media_item'] as Map<dynamic, dynamic>?;
            if (mediaItem != null) {
              final parsed = _api.parseTrack(Map<String, dynamic>.from(mediaItem));
              effectiveTitle = parsed.title;
              effectiveArtist = parsed.artist;
              effectiveAlbum = parsed.album;
              effectiveImageUrl = parsed.imageUrl ??
                  _api.resolveImageUrl(cMap['image']) ??
                  effectiveImageUrl;
            } else {
              final parsedFallback = _parseQueueItemFallback(cMap);
              effectiveTitle = parsedFallback.title;
              effectiveArtist = parsedFallback.artist;
              effectiveAlbum = parsedFallback.album;
              effectiveImageUrl = parsedFallback.imageUrl ?? effectiveImageUrl;
            }
          }
        }

        final isAdjusting = _isVolumeRecentlyAdjusted(rp.id);
        final idx = _players.indexWhere((p) => p.id == rp.id);
        final effectiveVolume = isAdjusting
            ? ((idx != -1) ? _players[idx].volume : rp.volume)
            : rp.volume;

        final rpEffective = rp.copyWith(
          state: effectiveState,
          volume: effectiveVolume,
          currentTitle: effectiveTitle,
          currentArtist: effectiveArtist,
          currentAlbum: effectiveAlbum,
          currentImageUrl: effectiveImageUrl,
          currentDurationSeconds: effectiveDuration,
          elapsedTimeSeconds: effectiveElapsed,
        );

        if (rpEffective.isPlaying && activePlayingDevice == null) {
          activePlayingDevice = rpEffective;
        }

        if (idx != -1) {
          final existing = _players[idx];
          if (existing.state != rpEffective.state ||
              existing.currentTitle != rpEffective.currentTitle ||
              (!isAdjusting && existing.volume != rpEffective.volume) ||
              existing.syncedTo != rpEffective.syncedTo) {
            _players[idx] = rpEffective.copyWith(isSelected: existing.isSelected);
            changed = true;
          }
        } else {
          _players.insert(0, rpEffective);
          changed = true;
        }
      }

      final isPlayStarting = _lastPlayCommandTime != null &&
          DateTime.now().difference(_lastPlayCommandTime!) <
              const Duration(seconds: 5);

      // Falls aktuell noch kein Player gewählt ist oder noch initial local_iphone aktiv ist:
      // Bevorzuge den gespeicherten Lautsprecher des Nutzers (nur falls nicht explizit local_iphone gewählt wurde)
      if (_activePlayer == null ||
          (_activePlayer!.isLocal &&
              _savedActivePlayerId != null &&
              _savedActivePlayerId != 'local_iphone')) {
        final preferred = _selectPreferredRealSpeaker(_players, savedPlayerId: _savedActivePlayerId);
        if (preferred != null) {
          _activePlayer = preferred.copyWith(isSelected: true);
          for (int i = 0; i < _players.length; i++) {
            _players[i] = _players[i].copyWith(isSelected: _players[i].id == _activePlayer!.id);
          }
          await _storage.saveActivePlayerId(_activePlayer!.id);
          changed = true;
        }
      }

      // Falls aktuell kein Lautsprecher aktiv spielt, aber im Haus Musik läuft: Automatisch ankoppeln!
      if (activePlayingDevice != null &&
          (_activePlayer == null || !_activePlayer!.isPlaying) &&
          !isPlayStarting) {
        _activePlayer = activePlayingDevice.copyWith(isSelected: true);
        for (final p in _players) {
          p.isSelected = (p.id == _activePlayer!.id);
        }
        _isPlaying = true;
        if (activePlayingDevice.hasActiveTrack) {
          _currentTrack = Track(
            id: activePlayingDevice.id,
            title: activePlayingDevice.currentTitle!,
            artist: activePlayingDevice.currentArtist ?? '',
            album: activePlayingDevice.currentAlbum ?? '',
            durationSeconds: activePlayingDevice.currentDurationSeconds ?? 180,
            imageUrl: activePlayingDevice.currentImageUrl,
            uri: activePlayingDevice.currentUri,
            isLiked: _likedTrackIds.contains(activePlayingDevice.id),
          );
          _totalDuration = Duration(
              seconds: activePlayingDevice.currentDurationSeconds ?? 180);
        }
        if (activePlayingDevice.elapsedTimeSeconds != null) {
          _currentPosition =
              Duration(seconds: activePlayingDevice.elapsedTimeSeconds!);
        }
        changed = true;
      } else if (_activePlayer != null && !isPlayStarting) {
        // Falls der aktive Lautsprecher läuft, dessen Werte nachführen
        final matching = _players.firstWhere((p) => p.id == _activePlayer!.id,
            orElse: () => _activePlayer!);
        _activePlayer = matching.copyWith(isSelected: true);
        if (matching.hasActiveTrack &&
            (_currentTrack == null || _currentTrack!.title != matching.currentTitle)) {
          _currentTrack = Track(
            id: matching.id,
            title: matching.currentTitle!,
            artist: matching.currentArtist ?? '',
            album: matching.currentAlbum ?? '',
            durationSeconds: matching.currentDurationSeconds ?? 180,
            imageUrl: matching.currentImageUrl,
            uri: matching.currentUri,
            isLiked: _likedTrackIds.contains(matching.id),
          );
          _totalDuration =
              Duration(seconds: matching.currentDurationSeconds ?? 180);
          changed = true;
        }
        if (matching.isPlaying != _isPlaying) {
          _isPlaying = matching.isPlaying;
          changed = true;
        }
      }

      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MusicProvider] _pollPlayersStatus error: $e');
    }
  }

  /// Meldet sich mit Benutzername und Passwort am Music Assistant Server an
  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    _isLoggingIn = true;
    _loginError = null;
    notifyListeners();

    try {
      final res = await _api.loginWithCredentials(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );

      final token = res['access_token'] as String;
      _authToken = token;
      _serverUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');

      if (res.containsKey('user') && res['user'] is Map) {
        _currentUser =
            UserProfile.fromJson(Map<String, dynamic>.from(res['user'] as Map));
        await _storage.saveUserProfile(_currentUser!);
      }

      await _storage.saveServerUrl(_serverUrl);
      await _storage.saveAuthToken(_authToken);
      await _storage.saveIsGuest(false);

      _isAuthenticated = true;
      _isLoggingIn = false;

      _connectAndRefresh();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[MusicProvider] Login error: $e');
      _loginError = e.toString().replaceFirst('Exception: ', '');
      _isLoggingIn = false;
      notifyListeners();
      return false;
    }
  }

  /// Ermöglicht es, die App als Gast/Offline auszuprobieren
  Future<void> continueAsGuest() async {
    _currentUser = const UserProfile(
      userId: 'guest',
      username: 'Gast-Hörer',
      displayName: 'Gast-Hörer',
      role: 'guest',
    );
    _isAuthenticated = true;
    await _storage.saveIsGuest(true);
    notifyListeners();
  }

  /// Meldet das Benutzerkonto ab und löscht gespeicherte Tokens
  Future<void> logout() async {
    _api.logout();
    _isAuthenticated = false;
    _currentUser = null;
    _authToken = '';
    await _storage.clearSession();
    notifyListeners();
  }

  /// Prüft, ob Audio lokal auf dem iPhone (über Lautsprecher/AirPods) abgespielt wird
  bool get isLocalPlayback =>
      _activePlayer == null || _activePlayer!.isLocal || !_api.isConnected;

  void _setupLocalAudioPlayer() {
    try {
      AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[MusicProvider] setAudioContext error: $e');
    }

    // Native iOS Audio-Session Listener (Unterbrechungen durch Siri/Anrufe & Kopfhörer-Trennung)
    const MethodChannel('de.timm.musicAssistantApp/audio_session')
        .setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onInterruptionBegan':
          debugPrint('[MusicProvider] iOS Audio Interruption began');
          if (isLocalPlayback && _isPlaying) {
            await _localAudioPlayer.pause();
            _isPlaying = false;
            notifyListeners();
          }
          break;
        case 'onInterruptionEnded':
          final shouldResume =
              (call.arguments as Map?)?['shouldResume'] as bool? ?? false;
          debugPrint(
              '[MusicProvider] iOS Audio Interruption ended (shouldResume: $shouldResume)');
          if (isLocalPlayback && shouldResume && _currentTrack != null) {
            await _localAudioPlayer.resume();
            _isPlaying = true;
            notifyListeners();
          }
          break;
        case 'onRouteChangePause':
          debugPrint(
              '[MusicProvider] iOS Audio Route changed (Kopfhörer getrennt) -> Pause');
          if (isLocalPlayback && _isPlaying) {
            await _localAudioPlayer.pause();
            _isPlaying = false;
            notifyListeners();
          }
          break;
      }
    });

    _localAudioPlayer.onPlayerStateChanged.listen((state) {
      if (isLocalPlayback) {
        final newPlaying = (state == PlayerState.playing);
        if (_isPlaying != newPlaying) {
          _isPlaying = newPlaying;
          notifyListeners();
        }
      }
    });

    _localAudioPlayer.onPositionChanged.listen((pos) {
      if (isLocalPlayback) {
        _currentPosition = pos;
        notifyListeners();
      }
    });

    _localAudioPlayer.onDurationChanged.listen((dur) {
      if (isLocalPlayback && dur.inSeconds > 0) {
        _totalDuration = dur;
        notifyListeners();
      }
    });

    _localAudioPlayer.onPlayerComplete.listen((_) {
      if (isLocalPlayback) {
        if (_repeatMode == 2) {
          seekTo(Duration.zero);
          _localAudioPlayer.resume();
        } else {
          next();
        }
      }
    });
  }

  Track _parseQueueItemFallback(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Unbekannter Titel';
    final duration = (item['duration'] as num?)?.toInt() ?? 180;
    String? imageUrl;
    String artistName = 'Unbekannter Künstler';
    String albumName = '';

    final streamDetails = item['streamdetails'] as Map<dynamic, dynamic>?;
    if (streamDetails != null) {
      final meta = streamDetails['stream_metadata'] as Map<dynamic, dynamic>?;
      if (meta != null) {
        if (meta['artist'] != null) artistName = meta['artist'].toString();
        if (meta['album'] != null) albumName = meta['album'].toString();
        if (meta['image_url'] != null) imageUrl = meta['image_url'].toString();
      }
    }

    if (imageUrl == null && item['image'] != null) {
      imageUrl = _api.resolveImageUrl(item['image']);
    } else if (imageUrl != null) {
      imageUrl = _api.resolveImageUrl(imageUrl) ?? imageUrl;
    }

    return Track(
      id: item['queue_item_id']?.toString() ?? 'remote_track',
      title: name,
      artist: artistName,
      album: albumName,
      durationSeconds: duration,
      imageUrl: imageUrl,
      uri: item['uri']?.toString(),
    );
  }

  void _handleServerEvent(Map<String, dynamic> event) {
    try {
      final eventName = event['event']?.toString();
      final dynamic rawData = event['data'];
      final objectId = event['object_id']?.toString();

      // 1. Live Sub-Sekunden Positions-Sync direkt vom Music Assistant Server
      if (eventName == 'queue_time_updated') {
        final queueId = objectId ?? (rawData is Map ? rawData['queue_id']?.toString() : null);
        final double? elapsedSec = (rawData is num)
            ? rawData.toDouble()
            : double.tryParse(rawData?.toString() ?? '');
        if (queueId != null && elapsedSec != null) {
          final isThisActive = _activePlayer?.id == queueId;
          _positionTracker.setAnchor(
            queueId: queueId,
            elapsedSec: elapsedSec,
            isPlaying: isThisActive ? _isPlaying : null,
          );
          if (isThisActive) {
            _currentPosition = Duration(milliseconds: (elapsedSec * 1000).round());
            notifyListeners();
          }
        }
        return;
      }

      // 2. Queue Updates (Songwechsel, Queue-Fortschritt, Playback State)
      if (eventName == 'queue_updated' && rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final queueId = data['queue_id']?.toString() ?? objectId;
        final state = data['state']?.toString();
        final isQueuePlaying = (state == 'playing');
        final currentItem = data['current_item'] as Map<dynamic, dynamic>?;
        final elapsed = (data['elapsed_time'] as num?)?.toDouble();

        Track? track;
        double? trackDuration;
        if (currentItem != null) {
          final currentMap = Map<String, dynamic>.from(currentItem);
          trackDuration = (currentMap['duration'] as num?)?.toDouble();
          final mediaItem = currentMap['media_item'] as Map<dynamic, dynamic>?;
          if (mediaItem != null) {
            final parsed =
                _api.parseTrack(Map<String, dynamic>.from(mediaItem));
            final fallbackImg = _api.resolveImageUrl(currentMap['image']);
            track = (parsed.imageUrl == null && fallbackImg != null)
                ? Track(
                    id: parsed.id,
                    title: parsed.title,
                    artist: parsed.artist,
                    album: parsed.album,
                    durationSeconds: parsed.durationSeconds,
                    imageUrl: fallbackImg,
                    uri: parsed.uri,
                    previewUrl: parsed.previewUrl,
                    provider: parsed.provider,
                    isLiked: parsed.isLiked,
                    lrcLyrics: parsed.lrcLyrics,
                    plainLyrics: parsed.plainLyrics,
                    rawSource: parsed.rawSource,
                  )
                : parsed;
          } else {
            track = _parseQueueItemFallback(currentMap);
          }
        }

        if (queueId != null && elapsed != null) {
          _positionTracker.setAnchor(
            queueId: queueId,
            elapsedSec: elapsed,
            isPlaying: state != null ? isQueuePlaying : null,
            durationSec: trackDuration,
          );
        }

        if (queueId != null) {
          final pIdx = _players.indexWhere((p) => p.id == queueId);
          if (pIdx != -1) {
            final p = _players[pIdx];
            _players[pIdx] = p.copyWith(
              state: state ?? p.state,
              currentTitle: track?.title ?? p.currentTitle,
              currentArtist: track?.artist ?? p.currentArtist,
              currentAlbum: track?.album ?? p.currentAlbum,
              currentImageUrl: track?.imageUrl ?? p.currentImageUrl,
              currentDurationSeconds: trackDuration?.round() ?? track?.durationSeconds ?? p.currentDurationSeconds,
              elapsedTimeSeconds: elapsed?.round() ?? p.elapsedTimeSeconds,
            );
          }
        }

        final shouldAdopt = _activePlayer == null ||
            _activePlayer!.id == queueId ||
            (!_activePlayer!.isPlaying && isQueuePlaying);

        if (shouldAdopt && queueId != null) {
          if (_activePlayer?.id != queueId) {
            final matching = _players.firstWhere(
              (p) => p.id == queueId,
              orElse: () => PlayerDevice(
                id: queueId,
                name: queueId,
                type: 'Speaker',
              ),
            );
            _activePlayer = matching.copyWith(isSelected: true);
          }
          if (state != null) {
            _isPlaying = isQueuePlaying;
            _positionTracker.setPlaying(queueId, isQueuePlaying);
          }
          if (data['shuffle_enabled'] is bool) {
            _isShuffle = data['shuffle_enabled'] as bool;
          }
          if (data['repeat_mode'] is String) {
            final rm = data['repeat_mode'] as String;
            _repeatMode = rm == 'all' ? 1 : (rm == 'one' ? 2 : 0);
          }
          if (data['crossfade_enabled'] is bool) {
            _crossfadeEnabled = data['crossfade_enabled'] as bool;
          }
          if (data['dont_stop_the_music_enabled'] is bool) {
            _dontStopTheMusic = data['dont_stop_the_music_enabled'] as bool;
          }
          if (track != null) {
            final previousTrack = _currentTrack;
            if (_likedTrackIds.contains(track.id)) track.isLiked = true;
            _currentTrack = track;
            _recordRecentlyPlayed(track);
            if (trackDuration != null && trackDuration > 0) {
              _totalDuration = Duration(seconds: trackDuration.round());
            } else if (track.durationSeconds > 0) {
              _totalDuration = Duration(seconds: track.durationSeconds);
            }
            if (previousTrack != null &&
                previousTrack.id != track.id &&
                _isDjActive &&
                _isDjVoiceEnabled &&
                !_isDjSpeaking) {
              _djPlayedTrackIds.add(track.id);
              _djTracksSinceLastModeration++;
              if (_djTracksSinceLastModeration >= 3) {
                _djTracksSinceLastModeration = 0;
                unawaited(_moderateAutoTransition(previousTrack, track));
              }
            }
          }
          if (elapsed != null) {
            _currentPosition = Duration(milliseconds: (elapsed * 1000).round());
          }
          notifyListeners();
        }
        return;
      }

      // 3. Player Updates (Lautstärke, Power, Status)
      if (eventName == 'player_updated' && rawData is Map) {
        final data = Map<String, dynamic>.from(rawData);
        final playerId = data['player_id']?.toString() ?? objectId;
        final state = data['playback_state']?.toString() ?? data['state']?.toString();
        final volume = (data['volume_level'] as num?)?.toInt();
        final syncedTo = data['synced_to']?.toString();
        final groupChilds = (data['group_childs'] as List?)
            ?.map((e) => e.toString())
            .toList();

        final currentMedia = data['current_media'] as Map<dynamic, dynamic>?;
        final currentTitle = currentMedia?['title']?.toString();
        final currentArtist = currentMedia?['artist']?.toString();
        final currentAlbum = currentMedia?['album']?.toString();
        final currentImageUrl = currentMedia?['image_url']?.toString();
        final currentDuration = (currentMedia?['duration'] as num?)?.toInt();
        final elapsedTime = (data['elapsed_time'] as num?)?.toDouble() ??
            (currentMedia?['elapsed_time'] as num?)?.toDouble();
        final currentUri = currentMedia?['uri']?.toString();

        final isAdjusting = playerId != null && _isVolumeRecentlyAdjusted(playerId);

        for (int i = 0; i < _players.length; i++) {
          if (_players[i].id == playerId) {
            final effectiveVolume =
                isAdjusting ? _players[i].volume : (volume ?? _players[i].volume);
            _players[i] = _players[i].copyWith(
              volume: effectiveVolume,
              state: state,
              syncedTo: syncedTo,
              groupChilds: groupChilds,
              currentTitle: currentTitle ?? _players[i].currentTitle,
              currentArtist: currentArtist ?? _players[i].currentArtist,
              currentAlbum: currentAlbum ?? _players[i].currentAlbum,
              currentImageUrl: currentImageUrl ?? _players[i].currentImageUrl,
              currentDurationSeconds: currentDuration ?? _players[i].currentDurationSeconds,
              elapsedTimeSeconds: elapsedTime?.round() ?? _players[i].elapsedTimeSeconds,
              currentUri: currentUri ?? _players[i].currentUri,
            );
          }
        }

        final isNowPlaying = (state == 'playing');
        if (playerId != null && state != null) {
          _positionTracker.setPlaying(playerId, isNowPlaying);
        }

        final shouldAdopt = _activePlayer == null ||
            _activePlayer!.id == playerId ||
            (!_activePlayer!.isPlaying && isNowPlaying);

        if (shouldAdopt && playerId != null) {
          if (_activePlayer?.id != playerId) {
            final matching = _players.firstWhere(
              (p) => p.id == playerId,
              orElse: () => PlayerDevice(
                id: playerId,
                name: playerId,
                type: 'Speaker',
              ),
            );
            _activePlayer = matching.copyWith(isSelected: true);
          }
          if (state != null) {
            _isPlaying = isNowPlaying;
          }
          final effectiveVolume =
              isAdjusting ? _activePlayer!.volume : (volume ?? _activePlayer!.volume);
          _activePlayer = _activePlayer!.copyWith(
            volume: effectiveVolume,
            state: state,
            syncedTo: syncedTo,
            groupChilds: groupChilds,
            currentTitle: currentTitle ?? _activePlayer!.currentTitle,
            currentArtist: currentArtist ?? _activePlayer!.currentArtist,
            currentAlbum: currentAlbum ?? _activePlayer!.currentAlbum,
            currentImageUrl: currentImageUrl ?? _activePlayer!.currentImageUrl,
            currentDurationSeconds: currentDuration ?? _activePlayer!.currentDurationSeconds,
            elapsedTimeSeconds: elapsedTime?.round() ?? _activePlayer!.elapsedTimeSeconds,
            currentUri: currentUri ?? _activePlayer!.currentUri,
          );

          if (currentTitle != null && currentTitle.isNotEmpty) {
            final resolvedImg = _api.resolveImageUrl(currentImageUrl) ??
                _activePlayer!.currentImageUrl ??
                _currentTrack?.imageUrl;
            final sameTitle = _currentTrack?.title == currentTitle;
            _currentTrack = Track(
              id: sameTitle ? (_currentTrack?.id ?? playerId) : playerId,
              title: currentTitle,
              artist: currentArtist ?? (_currentTrack?.artist ?? ''),
              album: currentAlbum ?? (_currentTrack?.album ?? ''),
              durationSeconds:
                  currentDuration ?? (_currentTrack?.durationSeconds ?? 180),
              imageUrl: resolvedImg,
              uri: currentUri ?? _currentTrack?.uri,
              isLiked: _likedTrackIds
                  .contains(sameTitle ? (_currentTrack?.id ?? playerId) : playerId),
              lrcLyrics: sameTitle ? _currentTrack?.lrcLyrics : null,
              plainLyrics: sameTitle ? _currentTrack?.plainLyrics : null,
            );
            _totalDuration = Duration(
                seconds:
                    currentDuration ?? (_currentTrack?.durationSeconds ?? 180));
          }

          if (elapsedTime != null) {
            _positionTracker.setAnchor(
              queueId: playerId,
              elapsedSec: elapsedTime,
              isPlaying: isNowPlaying,
              durationSec: currentDuration?.toDouble(),
            );
            _currentPosition = Duration(milliseconds: (elapsedTime * 1000).round());
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[MusicProvider] Event handler error: $e');
    }
  }

  Future<void> refreshServerData() async {
    try {
      // 1. Fetch real players and queues from server in parallel
      final resultsPlayers = await Future.wait([
        _api.fetchPlayers(),
        _api.fetchPlayerQueues(),
      ]);
      final remotePlayers = resultsPlayers[0] as List<PlayerDevice>;
      final remoteQueues = resultsPlayers[1] as List<Map<String, dynamic>>;

      final Map<String, Map<String, dynamic>> queueMap = {};
      for (final q in remoteQueues) {
        final qId = q['queue_id']?.toString();
        if (qId != null) queueMap[qId] = q;
      }

      final List<PlayerDevice> enrichedPlayers = [];
      PlayerDevice? activelyPlaying;

      for (final rp in remotePlayers) {
        final q = queueMap[rp.id];
        String effectiveState = rp.state;
        String? effectiveTitle = rp.currentTitle;
        String? effectiveArtist = rp.currentArtist;
        String? effectiveAlbum = rp.currentAlbum;
        String? effectiveImageUrl = rp.currentImageUrl;
        int? effectiveDuration = rp.currentDurationSeconds;
        int? effectiveElapsed = rp.elapsedTimeSeconds;

        if (q != null) {
          final qState = q['state']?.toString();
          if (qState != null && qState.isNotEmpty) effectiveState = qState;

          final qElapsed = (q['elapsed_time'] as num?)?.toDouble();
          if (qElapsed != null) {
            effectiveElapsed = qElapsed.round();
            _positionTracker.setAnchor(
              queueId: rp.id,
              elapsedSec: qElapsed,
              isPlaying: (effectiveState == 'playing'),
              durationSec: (q['duration'] as num?)?.toDouble(),
            );
          }

          final currentItem = q['current_item'] as Map<dynamic, dynamic>?;
          if (currentItem != null) {
            final cMap = Map<String, dynamic>.from(currentItem);
            final cDur = (cMap['duration'] as num?)?.toInt();
            if (cDur != null && cDur > 0) effectiveDuration = cDur;

            final mediaItem = cMap['media_item'] as Map<dynamic, dynamic>?;
            if (mediaItem != null) {
              final parsed = _api.parseTrack(Map<String, dynamic>.from(mediaItem));
              effectiveTitle = parsed.title;
              effectiveArtist = parsed.artist;
              effectiveAlbum = parsed.album;
              effectiveImageUrl = parsed.imageUrl ??
                  _api.resolveImageUrl(cMap['image']) ??
                  effectiveImageUrl;
            } else {
              final parsedFallback = _parseQueueItemFallback(cMap);
              effectiveTitle = parsedFallback.title;
              effectiveArtist = parsedFallback.artist;
              effectiveAlbum = parsedFallback.album;
              effectiveImageUrl = parsedFallback.imageUrl ?? effectiveImageUrl;
            }
          }
        }

        final p = rp.copyWith(
          state: effectiveState,
          currentTitle: effectiveTitle,
          currentArtist: effectiveArtist,
          currentAlbum: effectiveAlbum,
          currentImageUrl: effectiveImageUrl,
          currentDurationSeconds: effectiveDuration,
          elapsedTimeSeconds: effectiveElapsed,
        );
        enrichedPlayers.add(p);

        if (p.isPlaying && activelyPlaying == null) {
          activelyPlaying = p;
        }
      }

      for (final p in enrichedPlayers) {
        if (p.type == 'Sendspin' ||
            (p.name.toLowerCase().contains('iphone') && p.id != 'local_iphone') ||
            p.id == _sendspinService.clientId) {
          _sendspinService.serverPlayerId = p.id;
          debugPrint('[MusicProvider] Sendspin iPhone Player registriert mit ID: ${p.id}');
          break;
        }
      }

      final localIPhone = PlayerDevice.localIPhone(
        isSelected: false,
        volume: 60,
      );

      // Put real Multiroom network speakers first
      _players = [
        ...enrichedPlayers,
        if (_allowLocalPlayback) localIPhone,
      ];

      // Priorität 1: Ein Lautsprecher spielt gerade aktiv im Netzwerk
      if (activelyPlaying != null) {
        _activePlayer = activelyPlaying.copyWith(isSelected: true);
        _isPlaying = true;
        _currentTrack = Track(
          id: activelyPlaying.id,
          title: activelyPlaying.currentTitle ?? 'Wiedergabe',
          artist: activelyPlaying.currentArtist ?? '',
          album: activelyPlaying.currentAlbum ?? '',
          durationSeconds: activelyPlaying.currentDurationSeconds ?? 180,
          imageUrl: activelyPlaying.currentImageUrl,
          uri: activelyPlaying.currentUri,
          isLiked: _likedTrackIds.contains(activelyPlaying.id),
        );
        _totalDuration = Duration(
            seconds: activelyPlaying.currentDurationSeconds ?? 180);
        if (activelyPlaying.elapsedTimeSeconds != null) {
          _currentPosition =
              Duration(seconds: activelyPlaying.elapsedTimeSeconds!);
        }
        await _storage.saveActivePlayerId(_activePlayer!.id);
      } else if (enrichedPlayers.isNotEmpty) {
        // Priorität 2: Gespeicherter echter Lautsprecher oder erster verfügbarer Raum-Lautsprecher
        // WICHTIG: Niemals 'local_iphone' bevorzugen, wenn echte Netzwerk-Lautsprecher verfügbar sind!
        final savedPlayerId = await _storage.loadActivePlayerId();
        final preferred = _selectPreferredRealSpeaker(
          enrichedPlayers,
          savedPlayerId: savedPlayerId,
        );
        _activePlayer = preferred ?? enrichedPlayers.first;
        if (_activePlayer != null && !_activePlayer!.isLocal) {
          await _storage.saveActivePlayerId(_activePlayer!.id);
        }

        if (_activePlayer != null && _activePlayer!.hasActiveTrack) {
          _currentTrack = Track(
            id: _activePlayer!.id,
            title: _activePlayer!.currentTitle!,
            artist: _activePlayer!.currentArtist ?? '',
            album: _activePlayer!.currentAlbum ?? '',
            durationSeconds: _activePlayer!.currentDurationSeconds ?? 180,
            imageUrl: _activePlayer!.currentImageUrl,
            uri: _activePlayer!.currentUri,
            isLiked: _likedTrackIds.contains(_activePlayer!.id),
          );
          _totalDuration = Duration(
              seconds: _activePlayer!.currentDurationSeconds ?? 180);
          _isPlaying = _activePlayer!.isPlaying;
          if (_activePlayer!.elapsedTimeSeconds != null) {
            _currentPosition =
                Duration(seconds: _activePlayer!.elapsedTimeSeconds!);
          }
        }
      } else {
        // Nur falls gar keine Server-Lautsprecher geladen wurden (z. B. noch nicht verbunden):
        // _activePlayer nicht als 'local_iphone' in SharedPreferences speichern!
        _activePlayer ??= localIPhone;
      }

      for (final p in _players) {
        p.isSelected = (p.id == _activePlayer?.id);
      }

      if (_activePlayer != null) {
        final activeQ = queueMap[_activePlayer!.id];
        if (activeQ != null) {
          if (activeQ['shuffle_enabled'] is bool) {
            _isShuffle = activeQ['shuffle_enabled'] as bool;
          }
          if (activeQ['repeat_mode'] is String) {
            final rm = activeQ['repeat_mode'] as String;
            _repeatMode = rm == 'all' ? 1 : (rm == 'one' ? 2 : 0);
          }
          if (activeQ['crossfade_enabled'] is bool) {
            _crossfadeEnabled = activeQ['crossfade_enabled'] as bool;
          }
          if (activeQ['dont_stop_the_music_enabled'] is bool) {
            _dontStopTheMusic = activeQ['dont_stop_the_music_enabled'] as bool;
          }
        }
      }

      // 2. Fetch real library tracks, playlists, podcasts, albums, artists and favorites in parallel
      final results = await Future.wait([
        _api.fetchLibraryPlaylists(limit: 50),
        _api.fetchLibraryPodcasts(limit: 50),
        _api.fetchLibraryAlbums(limit: 50),
        _api.fetchLibraryArtists(limit: 50),
        _api.fetchLibraryTracks(limit: 100),
        _api.fetchFavoriteTracks(limit: 100),
        _api.fetchRecentlyPlayedItems(limit: 50),
      ]);

      final libraryPlaylists = results[0] as List<Playlist>;
      final libraryPodcasts = results[1] as List<Playlist>;
      final libraryAlbums = results[2] as List<Playlist>;
      final libraryArtists = results[3] as List<Playlist>;
      final libraryTracks = results[4] as List<Track>;
      final favoriteTracks = results[5] as List<Track>;
      final recentItems = results[6] as List<Track>;

      _podcasts = libraryPodcasts;
      _albums = libraryAlbums;
      _artists = libraryArtists;

      final serverPlaylistIds = libraryPlaylists.map((p) => p.id).toSet();
      final customOnly = _customPlaylists
          .where((cp) => !serverPlaylistIds.contains(cp.id))
          .toList();

      _playlists = [
        ...customOnly,
        ...libraryPlaylists,
        ...libraryPodcasts,
        ...libraryAlbums,
        ...libraryArtists,
      ];

      // Favoriten registrieren
      for (final t in favoriteTracks) {
        _likedTrackIds.add(t.id);
        t.isLiked = true;
      }

      // Kürzlich gespielte Titel vom Server einpflegen
      if (recentItems.isNotEmpty) {
        final existingRecent = _recentlyPlayedTracks.map((t) => t.id).toSet();
        for (final r in recentItems) {
          if (!existingRecent.contains(r.id)) {
            _recentlyPlayedTracks.add(r);
          }
        }
      }

      final combinedTracks = <String, Track>{};
      for (final t in libraryTracks) {
        combinedTracks[t.id] = t;
      }
      for (final t in favoriteTracks) {
        combinedTracks[t.id] = t;
      }

      if (combinedTracks.isNotEmpty) {
        for (final t in combinedTracks.values) {
          if (t.isLiked) _likedTrackIds.add(t.id);
          if (_likedTrackIds.contains(t.id)) t.isLiked = true;
        }
        _libraryTracks = combinedTracks.values.toList();
        _queue = _libraryTracks;
        if (_currentTrack == null) {
          _currentTrack = _libraryTracks.first;
          _totalDuration = Duration(seconds: _currentTrack!.durationSeconds);
        }
      }

      if (_activePlayer != null) {
        loadDspForPlayer(_activePlayer!.id);
      }

      // 3. Fetch awesome recommendations (Last.fm, Most Played, Forgotten Tracks)
      loadRecommendations();

      notifyListeners();
    } catch (e) {
      debugPrint('[MusicProvider] refreshServerData error: $e');
    }
  }

  /// Lädt personalisierte Empfehlungen vom Music Assistant Server
  Future<void> loadRecommendations() async {
    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      final rows = await _api.fetchFullRecommendations();
      if (rows.isNotEmpty) {
        _recommendations = rows;
      }
    } catch (e) {
      debugPrint('[MusicProvider] loadRecommendations error: $e');
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  /// Aktualisiert das Benutzerprofil (Anzeigename & Profilbild/Avatar)
  Future<void> updateUserProfile({String? displayName, String? avatarUrl}) async {
    if (_currentUser == null) {
      _currentUser = UserProfile(
        userId: 'local_user',
        username: 'user',
        displayName: displayName ?? 'Music Assistant Hörer',
        avatarUrl: avatarUrl,
      );
    } else {
      _currentUser = _currentUser!.copyWith(
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
    }
    await _storage.saveUserProfile(_currentUser!);
    notifyListeners();
  }

  /// Baut einen deduplizierten, musik-hygienisch sauberen Gesamt-Pool aller verfügbaren Songs für den KI-DJ.
  /// Filtert automatisch Hörspiele, Audiobooks, Radiostreams und Jingles heraus.
  List<Track> _buildDjTrackPool() {
    final Map<String, Track> byKey = {};
    void addTrack(Track t) {
      if (t.id.isEmpty) return;
      if (!SmartDjCurator.isEligibleMusicTrack(t)) return;
      final key = '${t.title.toLowerCase().trim()}_${t.artist.toLowerCase().trim()}';
      byKey.putIfAbsent(key, () => t);
      byKey[t.id] = t;
    }

    // 1. Echte Empfehlungs-Zeilen vom Server
    for (final row in _recommendations) {
      for (final item in row.items) {
        if (item.mediaType == 'track' || item.mediaType.isEmpty) {
          addTrack(item.toTrack());
        }
      }
    }

    // 2. Bibliothek & Kürzlich gespielte Titel
    for (final t in _libraryTracks) {
      addTrack(t);
    }
    for (final t in _recentlyPlayedTracks) {
      addTrack(t);
    }
    for (final t in _queue) {
      addTrack(t);
    }

    // 3. Songs aus Musik-Playlists (Podcasts/Hörbücher ignorieren)
    for (final pl in _playlists) {
      if (pl.type != 'podcast') {
        for (final t in pl.tracks) {
          addTrack(t);
        }
      }
    }

    // 4. Offline Downloads
    for (final t in downloadedTracks) {
      addTrack(t);
    }

    final pool = byKey.values.toSet().toList();
    for (final t in pool) {
      if (_likedTrackIds.contains(t.id)) t.isLiked = true;
    }
    return pool;
  }

  /// Startet den virtuellen Spotify KI-DJ
  Future<void> startVirtualDj({DjVibeCategory? category}) async {
    _isDjActive = true;
    final targetCategory = category ?? DjVibeCategory.allTimeFavorites;
    await switchDjVibe(category: targetCategory, isInitial: true);
  }

  /// Wechselt die Musikstimmung (Vibe) des virtuellen DJs mit genrespezifischer Multi-Faktor-Kuratierung.
  Future<void> switchDjVibe({DjVibeCategory? category, bool isInitial = false}) async {
    _isDjActive = true;
    _lastDjCustomPrompt = null;
    final vibes = DjVibe.allVibes;
    final DjVibe chosenVibe;

    if (category != null) {
      chosenVibe = vibes.firstWhere((v) => v.category == category, orElse: () => vibes.first);
    } else {
      final curIdx = vibes.indexWhere((v) => v.category == _currentDjVibe.category);
      final nextIdx = (curIdx + 1) % vibes.length;
      chosenVibe = vibes[nextIdx];
    }
    _currentDjVibe = chosenVibe;

    final fullPool = _buildDjTrackPool();

    // 1. Dynamisches Geschmacksprofil des Hörers aggregieren
    final tasteProfile = UserTasteProfile.build(
      likedTracks: likedTracks,
      recentlyPlayed: _recentlyPlayedTracks,
      playlists: _playlists,
      sessionPlayedIds: _djPlayedTrackIds,
    );

    // 2. Prüfen, wie viele echte qualitative Treffer für den Vibe vorhanden sind
    int strongMatches = 0;
    for (final t in fullPool) {
      final s = SmartDjCurator.scoreTrackForVibe(
        track: t,
        vibe: chosenVibe.category,
        profile: tasteProfile,
        currentTrackId: _currentTrack?.id,
      );
      if (s >= 35.0) strongMatches++;
    }

    // 3. Falls die Mediathek zu wenige Vibe-Titel hat, live über Music Assistant anreichern
    if (strongMatches < 8 && _api.isConnected) {
      try {
        final query = _getSearchQueryForVibe(chosenVibe.category, tasteProfile);
        if (query.isNotEmpty) {
          final res = await _api.searchMusic(query, limit: 25)
              .timeout(const Duration(milliseconds: 2500));
          final found = (res['tracks'] as List<Track>?) ?? [];
          for (final t in found) {
            if (SmartDjCurator.isEligibleMusicTrack(t)) {
              fullPool.add(t);
            }
          }
        }
      } catch (e) {
        debugPrint('[MusicProvider] switchDjVibe server enrichment error: $e');
      }
    }

    // 4. Multi-Faktor-Scoring & DJ-Fluss-Sequenzierung (verhindert doppelte Künstler/Alben)
    final vibeTracks = SmartDjCurator.curateSet(
      pool: fullPool,
      vibe: chosenVibe.category,
      profile: tasteProfile,
      currentTrackId: _currentTrack?.id,
      currentArtist: _currentTrack?.artist,
      targetCount: 20,
    );

    final previousTrack = _currentTrack;
    final nextTrack = vibeTracks.isNotEmpty ? vibeTracks.first : null;
    if (nextTrack != null) {
      _djPlayedTrackIds.add(nextTrack.id);
    }
    _djTracksSinceLastModeration = 0;

    // Sofort die Musik starten, damit keine Latenz entsteht
    if (vibeTracks.isNotEmpty) {
      unawaited(playTrack(vibeTracks.first, newQueue: vibeTracks));
    }

    final userName = _currentUser?.effectiveName.split(' ').first ?? 'Musikfreund';
    final speech = await _djService.composeDjSpeech(
      settings: _djVoiceSettings,
      vibe: chosenVibe,
      userName: userName,
      nextTrack: nextTrack,
      previousTrack: isInitial ? null : previousTrack,
      fallbackServerUrl: _serverUrl,
    );

    await speakDjCommentary(speech);
  }

  String _getSearchQueryForVibe(DjVibeCategory vibe, UserTasteProfile profile) {
    final topArtist = profile.artistAffinities.entries.isNotEmpty
        ? (profile.artistAffinities.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key
        : '';

    switch (vibe) {
      case DjVibeCategory.allTimeFavorites:
        return topArtist.isNotEmpty ? topArtist : 'Top Hits';
      case DjVibeCategory.rockClassics:
        return 'Rock Alternative Classics';
      case DjVibeCategory.partyVibes:
        return 'Dance Party Hits Club';
      case DjVibeCategory.lateNightChill:
        return 'Chill Lo-Fi Ambient Relax';
      case DjVibeCategory.forgottenGems:
        return 'Nostalgia Hits 90s 2000s';
      case DjVibeCategory.artistDiscoveries:
        return topArtist.isNotEmpty ? '$topArtist radio' : 'Discover Weekly';
    }
  }

  /// Erfüllt einen freien Musik- oder Stimmungswunsch des Nutzers im KI-DJ
  /// mit semantischer Keyword-Analyse, optionalem KI-LLM-Parsing und Live-Suche.
  Future<void> askDjCustomPrompt(String userPrompt) async {
    final trimmed = userPrompt.trim();
    if (trimmed.isEmpty) return;

    _isDjActive = true;
    _lastDjCustomPrompt = trimmed;
    final lower = trimmed.toLowerCase();

    // Passenden visuellen Vibe ableiten
    if (lower.contains('chill') ||
        lower.contains('ruhig') ||
        lower.contains('entspann') ||
        lower.contains('nacht') ||
        lower.contains('schlaf')) {
      _currentDjVibe = DjVibe.allVibes.firstWhere(
        (v) => v.category == DjVibeCategory.lateNightChill,
      );
    } else if (lower.contains('rock') ||
        lower.contains('gitarre') ||
        lower.contains('metal') ||
        lower.contains('punk') ||
        lower.contains('laut')) {
      _currentDjVibe = DjVibe.allVibes.firstWhere(
        (v) => v.category == DjVibeCategory.rockClassics,
      );
    } else if (lower.contains('party') ||
        lower.contains('tanz') ||
        lower.contains('energie') ||
        lower.contains('laune') ||
        lower.contains('beat')) {
      _currentDjVibe = DjVibe.allVibes.firstWhere(
        (v) => v.category == DjVibeCategory.partyVibes,
      );
    } else if (lower.contains('neu') ||
        lower.contains('entdeck') ||
        lower.contains('überrasch')) {
      _currentDjVibe = DjVibe.allVibes.firstWhere(
        (v) => v.category == DjVibeCategory.artistDiscoveries,
      );
    } else if (lower.contains('alt') ||
        lower.contains('nostalgie') ||
        lower.contains('früher') ||
        lower.contains('schätz')) {
      _currentDjVibe = DjVibe.allVibes.firstWhere(
        (v) => v.category == DjVibeCategory.forgottenGems,
      );
    } else if (lower.contains('favorit') || lower.contains('liebling')) {
      _currentDjVibe = DjVibe.allVibes.firstWhere(
        (v) => v.category == DjVibeCategory.allTimeFavorites,
      );
    }

    final candidatePool = _buildDjTrackPool();

    // 1. Sprachmodell-gestützte Intent-Erkennung für gezielte Such-Seeds
    List<String> aiSeeds = [];
    if (_djVoiceSettings.enableOllamaLlm) {
      try {
        aiSeeds = await OllamaService().parseMusicWishWithAi(
          host: _djVoiceSettings.ollamaHost,
          model: _djVoiceSettings.ollamaModel,
          userWish: trimmed,
          fallbackServerUrl: _serverUrl,
        ).timeout(const Duration(milliseconds: 2000), onTimeout: () => []);
      } catch (e) {
        debugPrint('[MusicProvider] parseMusicWishWithAi error: $e');
      }
    }

    // 2. Music Assistant Server mit dem Nutzerwunsch und KI-Seeds durchsuchen
    if (_api.isConnected) {
      try {
        final queriesToSearch = {trimmed, ...aiSeeds};
        for (final q in queriesToSearch.take(3)) {
          final res = await _api.searchMusic(q, limit: 20)
              .timeout(const Duration(milliseconds: 2200));
          final found = (res['tracks'] as List<Track>?) ?? [];
          for (final t in found) {
            if (SmartDjCurator.isEligibleMusicTrack(t)) {
              candidatePool.add(t);
            }
          }
        }
      } catch (e) {
        debugPrint('[MusicProvider] askDjCustomPrompt live search error: $e');
      }
    }

    final tasteProfile = UserTasteProfile.build(
      likedTracks: likedTracks,
      recentlyPlayed: _recentlyPlayedTracks,
      playlists: _playlists,
      sessionPlayedIds: _djPlayedTrackIds,
    );

    // 3. SmartDjCurator: Bewertet alle Titel (lokal + Server-Suchtreffer) und ordnet sie optimal an
    final curated = SmartDjCurator.curateCustomWishSet(
      pool: candidatePool,
      prompt: trimmed,
      profile: tasteProfile,
      currentTrackId: _currentTrack?.id,
      currentArtist: _currentTrack?.artist,
      targetCount: 20,
    );

    final nextTrack = curated.isNotEmpty ? curated.first : _currentTrack;
    if (nextTrack != null) {
      _djPlayedTrackIds.add(nextTrack.id);
    }
    _djTracksSinceLastModeration = 0;

    if (curated.isNotEmpty) {
      unawaited(playTrack(curated.first, newQueue: curated));
    }

    final userName = _currentUser?.effectiveName.split(' ').first ?? 'Musikfreund';
    final speech = await _djService.composeDjSpeech(
      settings: _djVoiceSettings,
      vibe: _currentDjVibe,
      userName: userName,
      nextTrack: nextTrack,
      customUserPrompt: trimmed,
      fallbackServerUrl: _serverUrl,
    );

    await speakDjCommentary(speech);
  }

  /// Moderiert den aktuell laufenden Song auf Knopfdruck neu an
  Future<void> triggerDjModerationNow() async {
    _isDjActive = true;
    final userName = _currentUser?.effectiveName.split(' ').first ?? 'Musikfreund';
    final speech = await _djService.composeDjSpeech(
      settings: _djVoiceSettings,
      vibe: _currentDjVibe,
      userName: userName,
      nextTrack: _currentTrack,
      customUserPrompt: _lastDjCustomPrompt,
      fallbackServerUrl: _serverUrl,
    );
    await speakDjCommentary(speech);
  }

  /// Automatische Radio-Überleitung nach jedem 3. Song im aktiven DJ-Modus
  Future<void> _moderateAutoTransition(Track previousTrack, Track nextTrack) async {
    final userName = _currentUser?.effectiveName.split(' ').first ?? 'Musikfreund';
    final speech = await _djService.composeDjSpeech(
      settings: _djVoiceSettings,
      vibe: _currentDjVibe,
      userName: userName,
      nextTrack: nextTrack,
      previousTrack: previousTrack,
      fallbackServerUrl: _serverUrl,
    );
    await speakDjCommentary(speech);
  }

  /// Überspringt die laufende DJ-Sprachansage sofort und stellt die Musiklautstärke wieder her
  Future<void> skipDjSpeech() async {
    _djSpeechTimer?.cancel();
    _djSpeechSub?.cancel();
    await _djService.stop();
    _isDjSpeaking = false;
    if (_preDuckingVolume != null) {
      await setVolume(_preDuckingVolume!);
      _preDuckingVolume = null;
    }
    notifyListeners();
  }

  int? _preDuckingVolume;

  /// Lässt den virtuellen DJ sprechen (TTS, Ollama, Ducking & Dynamic Island)
  Future<void> speakDjCommentary(String text) async {
    _djSpeechTimer?.cancel();
    _djSpeechSub?.cancel();
    _isDjSpeaking = true;
    _djSpeechText = text;
    notifyListeners();

    void finishSpeech() {
      _djSpeechTimer?.cancel();
      _djSpeechSub?.cancel();
      if (!_isDjSpeaking && _preDuckingVolume == null) return;
      _isDjSpeaking = false;
      if (_preDuckingVolume != null) {
        final restoreVol = _preDuckingVolume!;
        _preDuckingVolume = null;
        unawaited(setVolume(restoreVol));
      }
      notifyListeners();
    }

    // Listener VOR dem Start registrieren, damit schnelle Completion-Events nie verloren gehen
    _djSpeechSub = _djService.onSpeechCompleted.listen((_) {
      finishSpeech();
    });

    // Sicherheits-Timeout basierend auf der Satzlänge
    final estSeconds = (text.length / 12.5).clamp(4.5, 14.0);
    _djSpeechTimer = Timer(
      Duration(milliseconds: (estSeconds * 1000).toInt()),
      finishSpeech,
    );

    // Ducking: Musiklautstärke sanft absenken während der Ansage
    if (_djVoiceSettings.enableDucking && _activePlayer != null) {
      _preDuckingVolume ??= _activePlayer!.volume;
      if (_preDuckingVolume! > _djVoiceSettings.duckingVolumePercent) {
        await setVolume(_djVoiceSettings.duckingVolumePercent);
      }
    }

    // Sprachausgabe über die konfigurierte Engine
    if (_isDjVoiceEnabled) {
      await _djService.speakCommentary(
        text: text,
        settings: _djVoiceSettings,
        activeRemotePlayerId: _activePlayer?.id,
        onMassAnnounce: (id, msg) => _api.playAnnouncement(id, msg),
      );
    } else {
      // Wenn Stimme stummgeschaltet ist, Text für 4 Sekunden einblenden ohne Audio-Ducking
      if (_preDuckingVolume != null) {
        final restoreVol = _preDuckingVolume!;
        _preDuckingVolume = null;
        unawaited(setVolume(restoreVol));
      }
    }
  }

  /// Spielt einen empfohlenen Titel ab und reiht die restlichen Empfehlungen ein
  Future<void> playRecommendationItem(
    RecommendationItem item, {
    List<RecommendationItem>? contextItems,
  }) async {
    final track = item.toTrack();
    List<Track>? newQueue;
    if (contextItems != null && contextItems.isNotEmpty) {
      newQueue = contextItems
          .where((i) => i.mediaType == 'track' || i.mediaType.isEmpty)
          .map((i) => i.toTrack())
          .toList();
    }
    await playTrack(track, newQueue: newQueue);
  }

  /// Startet die Wiedergabe eines Hörbuchs / Hörspiels (z. B. Die drei ???)
  /// Spielt ein Hörbuch / Hörspiel ab und reiht alle Kapitel lückenlos in die Warteschlange ein
  Future<void> playAudiobook(Audiobook book, {int chapterIndex = 0, Track? chapter}) async {
    if (book.chapters.isEmpty) return;
    int idx = chapterIndex;
    if (chapter != null) {
      final found = book.chapters.indexWhere((c) => c.id == chapter.id);
      if (found != -1) idx = found;
    }
    idx = idx.clamp(0, book.chapters.length - 1);
    final targetChapter = book.chapters[idx];
    await playTrack(targetChapter, newQueue: List<Track>.from(book.chapters));
  }

  Future<void> playTrack(Track track,
      {List<Track>? newQueue, bool radioMode = false}) async {
    _lastPlayCommandTime = DateTime.now();
    if (_likedTrackIds.contains(track.id)) track.isLiked = true;
    _currentTrack = track;
    _isPlaying = true;
    _currentPosition = Duration.zero;
    _totalDuration = Duration(seconds: track.durationSeconds);
    _recordRecentlyPlayed(track);

    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = List<Track>.from(newQueue);
      _queueIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_queueIndex == -1) _queueIndex = 0;
    } else {
      final existingIdx = _queue.indexWhere((t) => t.id == track.id);
      if (existingIdx != -1) {
        _queueIndex = existingIdx;
      } else {
        _queue.add(track);
        _queueIndex = _queue.length - 1;
      }
    }

    // Falls noch überhaupt kein Lautsprecher initialisiert ist, den bevorzugten ermitteln
    // (Auswahl des Nutzers auf dem iPhone wird strikt respektiert und NIEMALS ungefragt überschrieben!)
    if (_activePlayer == null) {
      if (_api.isConnected &&
          !_players.any((p) => !p.isLocal && p.isAvailable)) {
        try {
          final fetched = await _api.fetchPlayers();
          if (fetched.isNotEmpty) {
            final local = _players.where((p) => p.isLocal).toList();
            _players = [...fetched, ...local];
          }
        } catch (e) {
          debugPrint('[MusicProvider] fetchPlayers in playTrack error: $e');
        }
      }
      final preferred = _selectPreferredRealSpeaker(_players, savedPlayerId: _savedActivePlayerId);
      if (preferred != null) {
        _activePlayer = preferred.copyWith(isSelected: true);
        for (final p in _players) {
          p.isSelected = (p.id == _activePlayer!.id);
        }
        await _storage.saveActivePlayerId(_activePlayer!.id);
      } else if (_players.isNotEmpty) {
        _activePlayer = _players.first;
      }
    }

    if (_activePlayer != null && !_activePlayer!.isLocal) {
      _positionTracker.setAnchor(
        queueId: _activePlayer!.id,
        elapsedSec: 0.0,
        isPlaying: true,
        durationSec: track.durationSeconds.toDouble(),
      );
    }

    notifyListeners();

    if (_adaptiveEqSettings.isEnabled) {
      _syncAdaptiveEqWithDsp();
    }

    // 1. Lokale Offline-Downloads prüfen
    if (_downloadService.isDownloaded(track.id)) {
      final dt = _downloadService.getDownloadedTrack(track.id);
      if (dt != null && File(dt.localFilePath).existsSync()) {
        if (_isOfflineMode || isLocalPlayback) {
          _positionTimer?.cancel();
          try {
            final vol = (_activePlayer?.volume ?? 60) / 100.0;
            await _localAudioPlayer.setVolume(vol);
            await _localAudioPlayer.stop();
            await _localAudioPlayer.play(DeviceFileSource(dt.localFilePath));
            return;
          } catch (e) {
            debugPrint('[MusicProvider] Offline play error: $e');
          }
        }
      }
    }

    // 2. Wiedergabe: Sendspin iPhone Player oder echter Music Assistant Lautsprecher (Volle Songlänge!)
    final targetPlayerId = _effectiveActivePlayerId;
    if (_api.isConnected && targetPlayerId != null) {
      // Echte Music Assistant Wiedergabe via Sendspin oder Netzwerk-Lautsprecher (Volle Songlänge!)
      await _localAudioPlayer.stop();
      if (isLocalPlayback || _activePlayer?.type == 'Sendspin') {
        await _sendspinService.unlock();
      }
      unawaited(AppleNowPlayingService.instance.sync(this, force: true));
      _startPositionTimer();
      final mediaUri = _resolveTrackMediaUri(track);
      try {
        // Zuerst den gewählten Song einzeln mit 'replace' starten -> startet sofort in voller Länge!
        await _api.playMedia(
          targetPlayerId,
          mediaUri,
          option: 'replace',
          radioMode: radioMode,
        );

        // Falls eine Liste (Album, Playlist, Hörbuch) übergeben wurde, die nachfolgenden Titel nahtlos anhängen
        if (!radioMode && newQueue != null && newQueue.length > 1) {
          final startIdx = newQueue.indexWhere((t) => t.id == track.id);
          final afterTracks = startIdx != -1 && startIdx + 1 < newQueue.length
              ? newQueue.sublist(startIdx + 1)
              : <Track>[];
          if (afterTracks.isNotEmpty) {
            final nextUris =
                afterTracks.take(25).map(_resolveTrackMediaUri).toList();
            unawaited(
              _api
                  .playMedia(
                    targetPlayerId,
                    nextUris,
                    option: 'add',
                  )
                  .catchError((e) {
                debugPrint('[MusicProvider] Background queue add error: $e');
              }),
            );
          }
        }
      } catch (e) {
        debugPrint('[MusicProvider] Remote playMedia error: $e');
        if (e is! TimeoutException) {
          try {
            await _api.playerPlay(targetPlayerId);
          } catch (_) {}
        }
      }
    } else {
      // Lokaler Fallback (nur falls kein Server verbunden ist oder gar keine Sendspin/Netzwerk-Lautsprecher existieren)
      _positionTimer?.cancel();
      try {
        String? playUrl;

        // Falls Track bereits eine direkte Audio-Stream-URL hat (z. B. Radio/Hörbuch)
        if (track.uri != null &&
            track.uri!.startsWith('http') &&
            !track.uri!.contains('p.scdn.co/mp3-preview') &&
            !_isImageUrl(track.uri!)) {
          playUrl = track.uri;
        }

        // Falls mit Server verbunden, Stream-Endpunkt bevorzugen
        if (playUrl == null && _api.isConnected) {
          playUrl = await _api.fetchTrackPreviewUrl(track);
        }

        // Falls Track eine direkte Stream-URI hat (z. B. Webradio/Hörspiel)
        if (playUrl == null &&
            track.uri != null &&
            track.uri!.startsWith('http') &&
            !_isImageUrl(track.uri!)) {
          playUrl = track.uri;
        }

        if (playUrl != null &&
            playUrl.startsWith('http') &&
            !_isImageUrl(playUrl)) {
          final vol = (_activePlayer?.volume ?? 60) / 100.0;
          await _localAudioPlayer.setVolume(vol);
          await _localAudioPlayer.stop();
          if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
            await _localAudioPlayer.play(UrlSource(playUrl));
          } else {
            _startPositionTimer();
          }
        } else {
          _startPositionTimer();
        }
      } catch (e) {
        debugPrint('[MusicProvider] Local play error: $e');
        _startPositionTimer();
      }
    }
  }

  /// Startet das Song-Radio (Endlos-Mix ähnlicher Titel) für einen Track
  Future<void> startTrackRadio(Track track) async {
    await playTrack(track, radioMode: true);
  }

  /// Reiht einen einzelnen Track direkt als nächsten Titel in die Warteschlange ein
  Future<void> playNext(Track track) async {
    await enqueueTracks([track], playNext: true);
  }

  /// Fügt einen einzelnen Track ans Ende der Warteschlange an
  Future<void> addToQueue(Track track) async {
    await enqueueTracks([track], playNext: false);
  }

  /// Fügt eine Liste von Tracks zur Warteschlange hinzu (als Nächstes oder am Ende)
  Future<void> enqueueTracks(List<Track> tracks, {bool playNext = false}) async {
    if (tracks.isEmpty) return;
    if (playNext && _queue.isNotEmpty) {
      final insertIdx = (_queueIndex + 1).clamp(0, _queue.length);
      _queue.insertAll(insertIdx, tracks);
    } else {
      _queue.addAll(tracks);
    }
    notifyListeners();

    if (!isLocalPlayback && _activePlayer != null && _api.isConnected) {
      try {
        final uris = tracks.map(_resolveTrackMediaUri).toList();
        await _api.playMedia(
          _activePlayer!.id,
          uris,
          option: playNext ? 'next' : 'add',
        );
      } catch (e) {
        debugPrint('[MusicProvider] enqueueTracks remote error: $e');
      }
    }
  }

  /// Erstellt eine neue Playlist (auf dem Music Assistant Server + lokal persistent)
  Future<Playlist> createPlaylist(String name) async {
    final trimmed = name.trim();
    Playlist? created;
    if (_api.isConnected) {
      created = await _api.createPlaylist(trimmed);
    }
    created ??= Playlist(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmed,
      owner: _currentUser?.effectiveName ?? 'Du',
      trackCount: 0,
      type: 'playlist',
      provider: 'library',
      tracks: [],
    );

    _customPlaylists.removeWhere((p) => p.id == created!.id);
    _customPlaylists.insert(0, created);
    await _storage.saveCustomPlaylists(_customPlaylists);

    _playlists.removeWhere((p) => p.id == created!.id);
    _playlists.insert(0, created);
    notifyListeners();
    return created;
  }

  /// Fügt einen Track zu einer Playlist hinzu (auf dem Server + lokal persistent)
  Future<bool> addTrackToPlaylist(Playlist playlist, Track track) async {
    final alreadyExists = playlist.tracks.any((t) => t.id == track.id);
    if (!alreadyExists) {
      playlist.tracks.add(track);
      playlist.trackCount = playlist.tracks.length;
    }

    final customIdx = _customPlaylists.indexWhere((p) => p.id == playlist.id);
    if (customIdx != -1) {
      _customPlaylists[customIdx] = playlist;
    } else {
      _customPlaylists.insert(0, playlist);
    }
    await _storage.saveCustomPlaylists(_customPlaylists);
    notifyListeners();

    if (_api.isConnected && !playlist.id.startsWith('custom_') && !playlist.id.startsWith('fallback_')) {
      try {
        final uri = track.uri ?? 'library://track/${track.id}';
        await _api.addTracksToPlaylist(playlist.id, [uri]);
      } catch (e) {
        debugPrint('[MusicProvider] addTrackToPlaylist server error: $e');
      }
    }
    return !alreadyExists;
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.contains('unsplash.com') ||
        lower.contains('scdn.co/image') ||
        lower.contains('mytuner-radio.net');
  }

  String? get _effectiveActivePlayerId {
    if (!isLocalPlayback && _activePlayer != null) {
      return _activePlayer!.id;
    }
    final sendspinId = _sendspinService.serverPlayerId ??
        _players.firstWhere(
          (p) =>
              (p.type == 'Sendspin' ||
                  p.name.toLowerCase().contains('iphone')) &&
              p.id != 'local_iphone',
          orElse: () => PlayerDevice.localIPhone(),
        ).id;
    return sendspinId != 'local_iphone' ? sendspinId : null;
  }

  Future<void> _initSendspinPlayer() async {
    if (_serverUrl.isEmpty) return;
    try {
      await _sendspinService.initialize(
        serverUrl: _serverUrl,
        clientName: 'Dieses iPhone',
      );
    } catch (e) {
      debugPrint('[MusicProvider] Sendspin Init Fehler: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue.first);
      return;
    }

    _isPlaying = !_isPlaying;
    notifyListeners();

    final effPlayerId = _effectiveActivePlayerId;
    if (effPlayerId != null && _api.isConnected) {
      if (_isPlaying) {
        _startPositionTimer();
        if (isLocalPlayback || _activePlayer?.type == 'Sendspin') {
          await _sendspinService.unlock();
          await _sendspinService.sendCommand('play');
        }
        await _api.playerPlay(effPlayerId);
      } else {
        _positionTimer?.cancel();
        if (isLocalPlayback || _activePlayer?.type == 'Sendspin') {
          await _sendspinService.sendCommand('pause');
        }
        await _api.playerPause(effPlayerId);
      }
    } else if (isLocalPlayback) {
      if (_isPlaying) {
        if (_localAudioPlayer.source == null &&
            _currentTrack != null &&
            !kIsWeb &&
            !Platform.environment.containsKey('FLUTTER_TEST')) {
          await playTrack(_currentTrack!);
        } else {
          await _localAudioPlayer.resume();
        }
      } else {
        await _localAudioPlayer.pause();
        _positionTimer?.cancel();
      }
    } else if (_activePlayer != null) {
      if (_isPlaying) {
        _startPositionTimer();
        await _api.playerPlay(_activePlayer!.id);
      } else {
        _positionTimer?.cancel();
        await _api.playerPause(_activePlayer!.id);
      }
    }
  }

  Future<void> next() async {
    final effPlayerId = _effectiveActivePlayerId;
    if (effPlayerId != null && _api.isConnected) {
      try {
        await _api.playerNext(effPlayerId);
        return;
      } catch (e) {
        debugPrint('[MusicProvider] Remote playerNext fallback: $e');
      }
    }

    if (_queue.isEmpty) return;
    if (_queueIndex < _queue.length - 1) {
      _queueIndex++;
    } else if (_repeatMode == 1) {
      _queueIndex = 0; // Repeat all
    } else {
      _isPlaying = false;
      _positionTimer?.cancel();
      await _localAudioPlayer.stop();
      notifyListeners();
      return;
    }

    await playTrack(_queue[_queueIndex]);
  }

  Future<void> previous() async {
    if (_currentPosition.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }

    final effPlayerId = _effectiveActivePlayerId;
    if (effPlayerId != null && _api.isConnected) {
      try {
        await _api.playerPrevious(effPlayerId);
        return;
      } catch (e) {
        debugPrint('[MusicProvider] Remote playerPrevious fallback: $e');
      }
    }

    if (_queue.isEmpty) return;
    if (_queueIndex > 0) {
      _queueIndex--;
    } else {
      _queueIndex = _queue.length - 1;
    }

    await playTrack(_queue[_queueIndex]);
  }

  Future<void> seekTo(Duration position) async {
    _currentPosition = position;
    final effPlayerId = _effectiveActivePlayerId;
    if (effPlayerId != null) {
      _positionTracker.setAnchor(
        queueId: effPlayerId,
        elapsedSec: position.inMilliseconds / 1000.0,
        isPlaying: _isPlaying,
        durationSec: _totalDuration.inSeconds.toDouble(),
      );
    }
    notifyListeners();

    if (effPlayerId != null && _api.isConnected) {
      try {
        await _api.playerSeek(effPlayerId, position.inSeconds);
      } catch (e) {
        debugPrint('[MusicProvider] Remote seek error: $e');
      }
    } else if (isLocalPlayback) {
      try {
        await _localAudioPlayer.seek(position);
      } catch (e) {
        debugPrint('[MusicProvider] Local seek error: $e');
      }
    }

    AppleNowPlayingService.instance
        .syncSeek(position.inMilliseconds / 1000.0);
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      _api.playerShuffle(_activePlayer!.id, _isShuffle);
    }
    notifyListeners();
  }

  void cycleRepeat() {
    _repeatMode = (_repeatMode + 1) % 3;
    final modeStr = _repeatMode == 0
        ? 'off'
        : _repeatMode == 1
            ? 'all'
            : 'one';
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      _api.playerRepeat(_activePlayer!.id, modeStr);
    }
    notifyListeners();
  }

  Future<void> toggleLike(Track track) async {
    track.isLiked = !track.isLiked;
    if (track.isLiked) {
      _likedTrackIds.add(track.id);
    } else {
      _likedTrackIds.remove(track.id);
    }

    if (_currentTrack?.id == track.id) {
      _currentTrack!.isLiked = track.isLiked;
    }
    for (final t in _queue) {
      if (t.id == track.id) t.isLiked = track.isLiked;
    }
    for (final p in _playlists) {
      for (final t in p.tracks) {
        if (t.id == track.id) t.isLiked = track.isLiked;
      }
    }
    for (final t in _recentlyPlayedTracks) {
      if (t.id == track.id) t.isLiked = track.isLiked;
    }

    await _storage.saveLikedTrackIds(_likedTrackIds);
    notifyListeners();

    if (_api.isConnected) {
      try {
        if (track.isLiked) {
          final uri = track.uri ?? 'library://track/${track.id}';
          await _api.addFavorite(uri);
        } else {
          await _api.removeFavorite(track.id, mediaType: 'track');
        }
      } catch (e) {
        debugPrint('[MusicProvider] toggleLike server sync error: $e');
      }
    }
  }

  Future<void> setActivePlayer(PlayerDevice player, {bool isTakeover = false}) async {
    final oldPlayer = _activePlayer;
    final wasPlaying = _isPlaying;

    if (oldPlayer?.isLocal == true && !player.isLocal) {
      // Vom iPhone auf externen Lautsprecher wechseln
      await _localAudioPlayer.stop();
      _isPlaying = false;
      notifyListeners();

      if (wasPlaying && _currentTrack != null) {
        final mediaUri = _resolveTrackMediaUri(_currentTrack!);
        try {
          await _api.playMedia(player.id, mediaUri);
          _isPlaying = true;
        } catch (e) {
          debugPrint('[MusicProvider] playMedia on switch error: $e');
          await _api.playerPlay(player.id);
          _isPlaying = true;
        }
      }
    } else if (oldPlayer != null && !oldPlayer.isLocal && player.isLocal) {
      // Vom externen Lautsprecher auf iPhone wechseln
      try {
        await _api.playerPause(oldPlayer.id);
      } catch (e) {
        debugPrint('[MusicProvider] pause old player error: $e');
      }
      if (wasPlaying && _currentTrack != null) {
        await playTrack(_currentTrack!);
      }
    } else if (wasPlaying &&
        oldPlayer != null &&
        !oldPlayer.isLocal &&
        !player.isLocal &&
        oldPlayer.id != player.id &&
        !isTakeover &&
        !player.isPlaying) {
      // Zwischen zwei externen Lautsprechern wechseln:
      // Nur transferQueue aufrufen, wenn das Ziel nicht schon selbst abspielt und kein Takeover ist!
      try {
        await _api.transferQueue(oldPlayer.id, player.id, autoPlay: true);
        await _api.playerPlay(player.id);
      } catch (e) {
        debugPrint('[MusicProvider] transferQueue error: $e');
        if (_currentTrack != null) {
          final mediaUri = _resolveTrackMediaUri(_currentTrack!);
          await _api.playMedia(player.id, mediaUri);
        }
      }
    }

    for (int i = 0; i < _players.length; i++) {
      final isNowSelected = (_players[i].id == player.id);
      _players[i] = _players[i].copyWith(isSelected: isNowSelected);
    }
    _activePlayer = player.copyWith(isSelected: true);

    if (!player.isLocal) {
      _savedActivePlayerId = player.id;
      await _storage.saveActivePlayerId(player.id);
    } else {
      _savedActivePlayerId = 'local_iphone';
      await _storage.saveActivePlayerId(null);
    }

    if (player.hasActiveTrack) {
      _currentTrack = Track(
        id: player.id,
        title: player.currentTitle!,
        artist: player.currentArtist ?? '',
        album: player.currentAlbum ?? '',
        imageUrl: player.currentImageUrl,
        durationSeconds: player.currentDurationSeconds ?? 180,
        uri: player.currentUri,
        isLiked: _likedTrackIds.contains(player.id),
      );
      _totalDuration = Duration(seconds: player.currentDurationSeconds ?? 180);
      _currentPosition = Duration(seconds: player.elapsedTimeSeconds ?? 0);
      _isPlaying = player.isPlaying;
      _positionTracker.setAnchor(
        queueId: player.id,
        elapsedSec: (player.elapsedTimeSeconds ?? 0).toDouble(),
        isPlaying: _isPlaying,
        durationSec: (player.currentDurationSeconds ?? 180).toDouble(),
      );
    }
    notifyListeners();
    loadDspForPlayer(player.id);
  }

  /// Synchronisiert einen Lautsprecher mit dem aktuell aktiven Lautsprecher (Multiroom)
  /// Die Wiedergabe auf dem iPhone läuft dabei nahtlos parallel weiter!
  Future<void> syncSpeakerWithActive(PlayerDevice speaker) async {
    final leaderId = _effectiveActivePlayerId;
    if (leaderId == null || leaderId.isEmpty || speaker.id == leaderId) return;
    try {
      await _api.syncPlayer(speaker.id, leaderId);
      await refreshServerData();
    } catch (e) {
      debugPrint('[MusicProvider] syncSpeakerWithActive error: $e');
    }
  }

  /// Hebt die Gruppensynchronisierung für einen Lautsprecher auf
  Future<void> unsyncSpeaker(PlayerDevice speaker) async {
    try {
      await _api.unsyncPlayer(speaker.id);
      await refreshServerData();
    } catch (e) {
      debugPrint('[MusicProvider] unsyncSpeaker error: $e');
    }
  }

  /// Überträgt die primäre Wiedergabe gezielt auf einen anderen Lautsprecher
  Future<void> transferPlaybackTo(PlayerDevice target) async {
    if (_activePlayer?.id == target.id) return;
    await setActivePlayer(target);
  }

  Future<void> setVolume(int vol) async {
    if (_activePlayer != null) {
      final clamped = vol.clamp(0, 100);
      _activePlayer!.volume = clamped;
      if (_activePlayer!.isLocal) {
        await _sendspinService.setVolume(clamped);
        final sendspinId = _sendspinService.serverPlayerId;
        if (sendspinId != null && _api.isConnected) {
          _dispatchThrottledVolume(sendspinId, clamped);
        }
        await _localAudioPlayer.setVolume(clamped / 100.0);
      } else {
        _dispatchThrottledVolume(_activePlayer!.id, clamped);
      }
      notifyListeners();
      if (_adaptiveEqSettings.isEnabled) {
        _scheduleAdaptiveEqSync();
      }
    }
  }

  /// Setzt die Lautstärke eines spezifischen Lautsprechers (z. B. in einer Multiroom-Gruppe)
  Future<void> setPlayerVolume(PlayerDevice player, int vol) async {
    final clamped = vol.clamp(0, 100);
    player.volume = clamped;
    if (player.isLocal) {
      await _sendspinService.setVolume(clamped);
      final sendspinId = _sendspinService.serverPlayerId;
      if (sendspinId != null && _api.isConnected) {
        _dispatchThrottledVolume(sendspinId, clamped);
      }
      await _localAudioPlayer.setVolume(clamped / 100.0);
    } else {
      _dispatchThrottledVolume(player.id, clamped);
    }
    notifyListeners();
  }

  /// Sendet sofort den ausstehenden Lautstärkebefehl (z. B. beim Loslassen des Sliders onChangeEnd)
  void flushVolume(String playerId) {
    _volumeDebounceTimers[playerId]?.cancel();
    _volumeDebounceTimers.remove(playerId);
    final pending = _pendingTargetVolumes[playerId];
    if (pending != null) {
      _sendVolumeCommand(playerId, pending);
    }
  }

  void _dispatchThrottledVolume(String playerId, int volume) {
    _pendingTargetVolumes[playerId] = volume;
    final now = DateTime.now();
    final lastSent = _lastVolumeSentTimes[playerId] ?? DateTime.fromMillisecondsSinceEpoch(0);
    final elapsed = now.difference(lastSent);
    const throttleWindow = Duration(milliseconds: 80);

    if (elapsed >= throttleWindow) {
      _volumeDebounceTimers[playerId]?.cancel();
      _volumeDebounceTimers.remove(playerId);
      _sendVolumeCommand(playerId, volume);
    } else {
      if (_volumeDebounceTimers[playerId] == null) {
        final waitTime = throttleWindow - elapsed;
        _volumeDebounceTimers[playerId] = Timer(waitTime, () {
          _volumeDebounceTimers.remove(playerId);
          final pending = _pendingTargetVolumes[playerId];
          if (pending != null) {
            _sendVolumeCommand(playerId, pending);
          }
        });
      }
    }
  }

  void _sendVolumeCommand(String playerId, int volume) {
    _lastVolumeSentTimes[playerId] = DateTime.now();
    _api.playerVolume(playerId, volume).catchError((e) {
      debugPrint('[MusicProvider] sendVolumeCommand error for $playerId: $e');
    });
  }

  void _scheduleAdaptiveEqSync() {
    _adaptiveEqDebounceTimer?.cancel();
    _adaptiveEqDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (_adaptiveEqSettings.isEnabled) {
        _syncAdaptiveEqWithDsp();
      }
    });
  }

  Future<void> toggleMute(PlayerDevice player) async {
    player.isMuted = !player.isMuted;
    if (player.isLocal) {
      await _sendspinService.setMuted(player.isMuted);
      final sendspinId = _sendspinService.serverPlayerId;
      if (sendspinId != null && _api.isConnected) {
        await _api.playerMute(sendspinId, player.isMuted);
      }
      await _localAudioPlayer
          .setVolume(player.isMuted ? 0.0 : player.volume / 100.0);
    } else {
      await _api.playerMute(player.id, player.isMuted);
    }
    notifyListeners();
  }

  Future<void> togglePlayerPower(PlayerDevice player) async {
    final isCurrentlyOn = player.state != 'idle';
    if (!player.isLocal) {
      await _api.setPower(player.id, !isCurrentlyOn);
      player.state = isCurrentlyOn ? 'idle' : 'paused';
      notifyListeners();
    }
  }

  Future<void> setSleepTimer(Duration duration) async {
    _sleepTimerCountdown?.cancel();
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimerCountdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerEndTime == null) {
        timer.cancel();
        return;
      }
      if (DateTime.now().isAfter(_sleepTimerEndTime!)) {
        timer.cancel();
        _sleepTimerEndTime = null;
        if (_isPlaying) {
          togglePlayPause();
        } else {
          notifyListeners();
        }
      } else {
        notifyListeners();
      }
    });
    notifyListeners();

    if (_activePlayer != null && !_activePlayer!.isLocal && _api.isConnected) {
      try {
        await _api.setSleepTimer(_activePlayer!.id, duration.inSeconds);
      } catch (e) {
        debugPrint('[MusicProvider] setSleepTimer server error: $e');
      }
    }
  }

  Future<void> clearSleepTimer() async {
    _sleepTimerCountdown?.cancel();
    _sleepTimerCountdown = null;
    _sleepTimerEndTime = null;
    notifyListeners();

    if (_activePlayer != null && !_activePlayer!.isLocal && _api.isConnected) {
      try {
        await _api.clearSleepTimer(_activePlayer!.id);
      } catch (e) {
        debugPrint('[MusicProvider] clearSleepTimer server error: $e');
      }
    }
  }

  Future<void> sendAnnouncement(String message, {String? targetPlayerId}) async {
    final playerId = targetPlayerId ?? _activePlayer?.id;
    if (playerId != null && playerId != 'local_iphone') {
      await _api.playAnnouncement(playerId, message);
    }
  }

  Future<void> loadServerQueue() async {
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      final items = await _api.fetchQueueItems(_activePlayer!.id);
      if (items.isNotEmpty) {
        _queue = items;
        notifyListeners();
      }
    }
  }

  Future<void> removeFromQueue(int index) async {
    if (index >= 0 && index < _queue.length) {
      if (_activePlayer != null && !_activePlayer!.isLocal) {
        await _api.deleteQueueItem(_activePlayer!.id, index);
      }
      _queue.removeAt(index);
      if (_queueIndex >= _queue.length) {
        _queueIndex = _queue.length - 1;
      }
      notifyListeners();
    }
  }

  Future<void> jumpToQueueIndex(int index) async {
    if (index >= 0 && index < _queue.length) {
      _queueIndex = index;
      await playTrack(_queue[index]);
    }
  }

  Future<void> clearCurrentQueue() async {
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      await _api.clearQueue(_activePlayer!.id);
    }
    _queue.clear();
    _currentTrack = null;
    _isPlaying = false;
    notifyListeners();
  }

  // --- DSP & Equalizer Controls (Direct Music Assistant Connection) ---

  Future<void> loadDspForPlayer([String? playerId]) async {
    final targetId = playerId ?? _activePlayer?.id;
    if (targetId == null) return;

    _isLoadingDsp = true;
    _dspError = null;
    notifyListeners();

    try {
      // 1. Presets vom Server laden
      final presetsRaw = await _api.fetchDspPresets();
      _dspPresets = presetsRaw.map((p) => DspPreset.fromJson(p)).toList();

      // 2. Player DSP Konfiguration laden
      final configRaw = await _api.fetchPlayerDspConfig(targetId);
      if (configRaw != null) {
        _dspConfig = DspConfig.fromJson(configRaw);
      } else {
        _dspConfig = DspConfig.defaultFlat();
      }

      // Sync mit lokalem EqualizerSettings
      if (_dspConfig != null) {
        _equalizerSettings.isEnabled = _dspConfig!.enabled;
        if (_dspConfig!.presetId != null) {
          final matched = _dspPresets.firstWhere(
            (p) => p.presetId == _dspConfig!.presetId,
            orElse: () => DspPreset(
              presetId: _dspConfig!.presetId!,
              name: 'Individuell',
              config: _dspConfig!,
            ),
          );
          _equalizerSettings.currentPreset = matched.name;
        }
      }
    } catch (e) {
      debugPrint('[MusicProvider] loadDspForPlayer error: $e');
      _dspError = e.toString();
      _dspConfig ??= DspConfig.defaultFlat();
    } finally {
      _isLoadingDsp = false;
      notifyListeners();
    }
  }

  Future<void> updateAdaptiveEqSettings(AdaptiveEqSettings newSettings) async {
    _adaptiveEqSettings = newSettings;
    await _storage.saveAdaptiveEqSettings(newSettings);
    notifyListeners();
    _syncAdaptiveEqWithDsp();
  }

  void _syncAdaptiveEqWithDsp() {
    if (!_adaptiveEqSettings.isEnabled || _dspConfig == null) return;
    final deltas = currentAdaptiveDeltas;
    final peq = _dspConfig!.parametricEqFilter;
    if (peq == null || peq.bands.isEmpty) return;

    final updatedBands = List<DspBand>.from(peq.bands);
    bool hasMeaningfulGainChange = false;
    for (int i = 0; i < updatedBands.length && i < deltas.length; i++) {
      final baseGain = (i < _equalizerSettings.bandGains.length)
          ? _equalizerSettings.bandGains[i]
          : updatedBands[i].gain;
      final effectiveGain = (baseGain + deltas[i]).clamp(-12.0, 12.0);
      if ((updatedBands[i].gain - effectiveGain).abs() > 0.05) {
        hasMeaningfulGainChange = true;
      }
      updatedBands[i] = updatedBands[i].copyWith(gain: effectiveGain);
    }

    if (!hasMeaningfulGainChange) return;

    final updatedFilters = List<DspFilter>.from(_dspConfig!.filters);
    final peqIndex = updatedFilters.indexWhere((f) => f.type == 'parametric_eq');
    if (peqIndex != -1) {
      updatedFilters[peqIndex] = peq.copyWith(bands: updatedBands);
      _dspConfig = _dspConfig!.copyWith(filters: updatedFilters);
      saveCurrentDspConfig();
    }
  }

  Future<void> toggleDspEnabled(bool enabled) async {
    _dspConfig ??= DspConfig.defaultFlat();
    _dspConfig = _dspConfig!.copyWith(enabled: enabled);
    _equalizerSettings.isEnabled = enabled;
    await _storage.saveEqualizerSettings(_equalizerSettings);
    notifyListeners();

    if (_activePlayer != null && !_activePlayer!.isLocal) {
      try {
        final res = await _api.savePlayerDspConfig(
            _activePlayer!.id, _dspConfig!.toJson());
        if (res != null) {
          _dspConfig = DspConfig.fromJson(res);
        }
      } catch (e) {
        debugPrint('[MusicProvider] toggleDspEnabled error: $e');
      }
      notifyListeners();
    }
  }

  Future<void> applyDspPreset(DspPreset preset) async {
    _isLoadingDsp = true;
    notifyListeners();

    try {
      if (_activePlayer != null && !_activePlayer!.isLocal) {
        final res =
            await _api.applyDSPPreset(_activePlayer!.id, preset.presetId);
        if (res != null) {
          _dspConfig = DspConfig.fromJson(res);
        } else {
          final saveRes = await _api.savePlayerDspConfig(
            _activePlayer!.id,
            preset.config
                .copyWith(enabled: true, presetId: preset.presetId)
                .toJson(),
          );
          if (saveRes != null) {
            _dspConfig = DspConfig.fromJson(saveRes);
          } else {
            _dspConfig = preset.config
                .copyWith(enabled: true, presetId: preset.presetId);
          }
        }
      } else {
        _dspConfig =
            preset.config.copyWith(enabled: true, presetId: preset.presetId);
      }
      _equalizerSettings.currentPreset = preset.name;
      _equalizerSettings.isEnabled = true;
      await _storage.saveEqualizerSettings(_equalizerSettings);
    } catch (e) {
      debugPrint('[MusicProvider] applyDspPreset error: $e');
    } finally {
      _isLoadingDsp = false;
      notifyListeners();
    }
  }

  void updateDspBandGain(int bandIndex, double gain) {
    _dspConfig ??= DspConfig.defaultFlat();

    final currentFilters = List<DspFilter>.from(_dspConfig!.filters);
    final peqIndex =
        currentFilters.indexWhere((f) => f.type == 'parametric_eq');

    if (peqIndex != -1) {
      final peq = currentFilters[peqIndex];
      final bands = List<DspBand>.from(peq.bands);
      if (bandIndex >= 0 && bandIndex < bands.length) {
        bands[bandIndex] = bands[bandIndex].copyWith(gain: gain);
        currentFilters[peqIndex] = peq.copyWith(bands: bands);
      }
    } else {
      final defaultCfg = DspConfig.defaultFlat();
      final defaultFilter = defaultCfg.parametricEqFilter!;
      final bands = List<DspBand>.from(defaultFilter.bands);
      if (bandIndex >= 0 && bandIndex < bands.length) {
        bands[bandIndex] = bands[bandIndex].copyWith(gain: gain);
      }
      currentFilters.add(defaultFilter.copyWith(bands: bands));
    }

    _dspConfig = _dspConfig!.copyWith(
      filters: currentFilters,
      presetId: null,
    );
    notifyListeners();
  }

  void updateDspPreamp(double preamp) {
    _dspConfig ??= DspConfig.defaultFlat();

    final currentFilters = List<DspFilter>.from(_dspConfig!.filters);
    final peqIndex =
        currentFilters.indexWhere((f) => f.type == 'parametric_eq');

    if (peqIndex != -1) {
      currentFilters[peqIndex] =
          currentFilters[peqIndex].copyWith(preamp: preamp);
    } else {
      final defaultCfg = DspConfig.defaultFlat();
      final defaultFilter = defaultCfg.parametricEqFilter!;
      currentFilters.add(defaultFilter.copyWith(preamp: preamp));
    }

    _dspConfig = _dspConfig!.copyWith(
      filters: currentFilters,
      presetId: null,
    );
    notifyListeners();
  }

  Future<void> saveCurrentDspConfig() async {
    if (_activePlayer == null || _dspConfig == null || _activePlayer!.isLocal) {
      return;
    }
    try {
      final res = await _api.savePlayerDspConfig(
          _activePlayer!.id, _dspConfig!.toJson());
      if (res != null) {
        _dspConfig = DspConfig.fromJson(res);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MusicProvider] saveCurrentDspConfig error: $e');
    }
  }

  Future<void> resetDspToFlat() async {
    _dspConfig ??= DspConfig.defaultFlat();

    final currentFilters = List<DspFilter>.from(_dspConfig!.filters);
    final peqIndex =
        currentFilters.indexWhere((f) => f.type == 'parametric_eq');

    if (peqIndex != -1) {
      final peq = currentFilters[peqIndex];
      final resetBands = peq.bands.map((b) => b.copyWith(gain: 0.0)).toList();
      currentFilters[peqIndex] = peq.copyWith(bands: resetBands, preamp: 0.0);
    }

    _dspConfig = _dspConfig!.copyWith(
      filters: currentFilters,
      presetId: null,
    );
    _equalizerSettings.applyPreset('Flat');
    await _storage.saveEqualizerSettings(_equalizerSettings);
    notifyListeners();

    await saveCurrentDspConfig();
  }

  Future<void> setEqualizerEnabled(bool enabled) => toggleDspEnabled(enabled);

  Future<void> setEqualizerPreset(String presetName) async {
    final matchedPreset = _dspPresets.firstWhere(
      (p) => p.name.toLowerCase() == presetName.toLowerCase(),
      orElse: () => DspPreset(
        presetId: presetName.toLowerCase(),
        name: presetName,
        config: _dspConfig ?? DspConfig.defaultFlat(),
      ),
    );
    await applyDspPreset(matchedPreset);
  }

  Future<void> setEqualizerBandGain(int index, double gain) async {
    updateDspBandGain(index, gain);
    await saveCurrentDspConfig();
  }

  Future<void> updateServerSettings(String url, String token) async {
    _serverUrl = url;
    _authToken = token;
    await _storage.saveServerUrl(url);
    await _storage.saveAuthToken(token);
    _api.configure(url, token);
    unawaited(_initSendspinPlayer());
    await refreshServerData();
    notifyListeners();
  }

  /// Führt eine echte Suche über Music Assistant aus (Spotify, Radios, Mediathek)
  Future<void> search(String query) async {
    _lastSearchQuery = query.trim();
    if (_lastSearchQuery.isEmpty) {
      _searchResultsTracks = [];
      _searchResultsPlaylists = [];
      _searchResultsAlbums = [];
      _searchResultsPodcasts = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final res = await _api.searchMusic(_lastSearchQuery);
      _searchResultsTracks = (res['tracks'] as List<Track>?) ?? [];
      _searchResultsPlaylists = (res['playlists'] as List<Playlist>?) ?? [];
      _searchResultsAlbums = (res['albums'] as List<Playlist>?) ?? [];
      _searchResultsPodcasts = (res['podcasts'] as List<Playlist>?) ?? [];
    } catch (e) {
      debugPrint('[MusicProvider] search error: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Lädt die Tracks einer Playlist oder eines Albums nach, falls noch leer
  Future<void> loadPlaylistTracks(Playlist playlist) async {
    if (playlist.tracks.isNotEmpty) return;
    try {
      final tracks = await _api.fetchPlaylistTracks(playlist);
      playlist.tracks.clear();
      playlist.tracks.addAll(tracks);
      notifyListeners();
    } catch (e) {
      debugPrint('[MusicProvider] loadPlaylistTracks error: $e');
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    // Bei lokaler iPhone-Wiedergabe wird die exakte Position direkt von AVPlayer gemeldet.
    if (isLocalPlayback) return;

    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Nur Zähler für UI-Anzeige aktualisieren, wenn Spielzeit bekannt ist.
      // Der Music Assistant Server steuert den echten Songwechsel selbst – NIEMALS softwareseitig vorzeitig skippen!
      if (_isPlaying &&
          _totalDuration.inSeconds > 0 &&
          _currentPosition < _totalDuration) {
        _currentPosition += const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    try {
      WatchService.instance.syncState(this);
    } catch (_) {}
    try {
      LiveActivityService.instance.sync(this);
    } catch (_) {}
    try {
      AppleNowPlayingService.instance.sync(this);
    } catch (_) {}
  }

  @override
  void dispose() {
    _adaptiveEqDebounceTimer?.cancel();
    for (final timer in _volumeDebounceTimers.values) {
      timer.cancel();
    }
    _volumeDebounceTimers.clear();
    _djSpeechTimer?.cancel();
    _djSpeechSub?.cancel();
    _djService.dispose();
    _downloadService.removeListener(notifyListeners);
    _authSubscription?.cancel();
    _eventsSubscription?.cancel();
    _positionTimer?.cancel();
    _positionTicker?.cancel();
    _playerPollTimer?.cancel();
    _sleepTimerCountdown?.cancel();
    _localAudioPlayer.dispose();
    _api.dispose();
    try {
      AppleNowPlayingService.instance.clear();
    } catch (_) {}
    super.dispose();
  }
}
