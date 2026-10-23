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
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../services/virtual_dj_service.dart';
import '../services/watch_service.dart';

class MusicProvider extends ChangeNotifier {
  final MassApiService _api = MassApiService();
  final StorageService _storage = StorageService();
  final AudioPlayer _localAudioPlayer = AudioPlayer();
  final UpdateService _updateService = UpdateService();
  final DownloadService _downloadService = DownloadService();

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
  List<Playlist> _podcasts = [];
  List<Playlist> _albums = [];
  List<Playlist> _artists = [];
  final List<Audiobook> _audiobooks = Audiobook.sampleAudiobooks;
  List<PlayerDevice> _players = [];
  PlayerDevice? _activePlayer;
  Set<String> _likedTrackIds = {};
  Timer? _positionTimer;
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

  void toggleDjVoice() {
    _isDjVoiceEnabled = !_isDjVoiceEnabled;
    notifyListeners();
  }

  Future<void> updateDjVoiceSettings(DjVoiceSettings newSettings) async {
    _djVoiceSettings = newSettings;
    await _storage.saveDjVoiceSettings(newSettings);
    notifyListeners();
  }

  Future<void> previewDjVoice() async {
    final userName = _currentUser?.effectiveName.split(' ').first ?? 'Tim';
    await _djService.previewVoice(_djVoiceSettings, userName);
  }

  MusicProvider() {
    // Populate with fallback data immediately so UI never shows a blank screen
    _playlists = _api.getFallbackPlaylists();
    _queue = _api.getFallbackTracks();
    if (_queue.isNotEmpty) {
      _currentTrack = _queue.first;
      _totalDuration = Duration(seconds: _currentTrack!.durationSeconds);
    }
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
    await setActivePlayer(player);
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
  String get appVersion => '1.10.8';
  UserProfile? get currentUser => _currentUser;
  bool get isLoggingIn => _isLoggingIn;
  String? get loginError => _loginError;
  AppUpdateInfo? get updateInfo => _updateInfo;
  bool get isCheckingForUpdates => _isCheckingForUpdates;
  bool get hasUpdate => _updateInfo?.hasUpdate ?? false;

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
    }
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
    return _updateInfo ?? AppUpdateInfo.noUpdate(currentVersion: '1.10.8');
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

      refreshServerData();

      // Aktive Überwachung aller Lautsprecher im 4-Sekunden-Takt
      _playerPollTimer?.cancel();
      _playerPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
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
      final remotePlayers = await _api.fetchPlayers();
      if (remotePlayers.isEmpty) return;

      bool changed = false;
      for (final rp in remotePlayers) {
        final idx = _players.indexWhere((p) => p.id == rp.id);
        final isAdjusting = _isVolumeRecentlyAdjusted(rp.id);
        final effectiveVolume = isAdjusting
            ? ((idx != -1) ? _players[idx].volume : rp.volume)
            : rp.volume;
        final rpEffective = rp.copyWith(volume: effectiveVolume);

        if (idx != -1) {
          final existing = _players[idx];
          if (existing.state != rp.state ||
              existing.currentTitle != rp.currentTitle ||
              (!isAdjusting && existing.volume != rp.volume) ||
              existing.syncedTo != rp.syncedTo) {
            _players[idx] = rpEffective.copyWith(isSelected: existing.isSelected);
            changed = true;
          }
        } else {
          _players.insert(0, rpEffective);
          changed = true;
        }

        // Falls dies der aktive Lautsprecher ist, Titel & Position angleichen
        if (_activePlayer?.id == rp.id) {
          _activePlayer = rpEffective.copyWith(isSelected: true);
          if (rp.hasActiveTrack && _currentTrack?.title != rp.currentTitle) {
            _currentTrack = Track(
              id: rp.id,
              title: rp.currentTitle!,
              artist: rp.currentArtist ?? '',
              album: rp.currentAlbum ?? '',
              durationSeconds: rp.currentDurationSeconds ?? 180,
              imageUrl: rp.currentImageUrl,
              uri: rp.currentUri,
              isLiked: _likedTrackIds.contains(rp.id),
            );
            _totalDuration = Duration(seconds: rp.currentDurationSeconds ?? 180);
            changed = true;
          }
          if (rp.isPlaying != _isPlaying) {
            _isPlaying = rp.isPlaying;
            changed = true;
          }
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
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
              AVAudioSessionOptions.allowBluetoothA2DP,
              AVAudioSessionOptions.allowAirPlay,
            },
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

  void _handleServerEvent(Map<String, dynamic> event) {
    try {
      final eventName = event['event']?.toString();
      final data = event['data'] as Map<String, dynamic>?;

      if (eventName == 'player_updated' && data != null) {
        final playerId = data['player_id']?.toString();
        final state = data['playback_state']?.toString() ??
            data['state']?.toString();
        final volume = (data['volume_level'] as num?)?.toInt();
        final syncedTo = data['synced_to']?.toString();
        final groupChilds = (data['group_childs'] as List?)
            ?.map((e) => e.toString())
            .toList();

        final currentMedia = data['current_media'] as Map<String, dynamic>?;
        final currentTitle = currentMedia?['title']?.toString();
        final currentArtist = currentMedia?['artist']?.toString();
        final currentAlbum = currentMedia?['album']?.toString();
        final currentImageUrl = currentMedia?['image_url']?.toString();
        final currentDuration = (currentMedia?['duration'] as num?)?.toInt();
        final elapsedTime = (data['elapsed_time'] as num?)?.toInt();
        final currentUri = currentMedia?['uri']?.toString();

        // Update matching player in list with full playback metadata
        final isAdjusting = playerId != null && _isVolumeRecentlyAdjusted(playerId);
        for (int i = 0; i < _players.length; i++) {
          if (_players[i].id == playerId) {
            final effectiveVolume = isAdjusting ? _players[i].volume : (volume ?? _players[i].volume);
            _players[i] = _players[i].copyWith(
              volume: effectiveVolume,
              state: state,
              syncedTo: syncedTo,
              groupChilds: groupChilds,
              currentTitle: currentTitle,
              currentArtist: currentArtist,
              currentAlbum: currentAlbum,
              currentImageUrl: currentImageUrl,
              currentDurationSeconds: currentDuration,
              elapsedTimeSeconds: elapsedTime,
              currentUri: currentUri,
            );
          }
        }

        // If active player is the updated external player, update playback state
        if (_activePlayer != null && _activePlayer!.id == playerId) {
          if (state != null) {
            _isPlaying = (state == 'playing');
          }
          final effectiveVolume = isAdjusting ? _activePlayer!.volume : (volume ?? _activePlayer!.volume);
          _activePlayer = _activePlayer!.copyWith(
            volume: effectiveVolume,
            state: state,
            syncedTo: syncedTo,
            groupChilds: groupChilds,
            currentTitle: currentTitle,
            currentArtist: currentArtist,
            currentAlbum: currentAlbum,
            currentImageUrl: currentImageUrl,
            currentDurationSeconds: currentDuration,
            elapsedTimeSeconds: elapsedTime,
            currentUri: currentUri,
          );

          if (currentTitle != null && currentTitle.isNotEmpty) {
            _currentTrack = Track(
              id: playerId ?? 'remote',
              title: currentTitle,
              artist: currentArtist ?? '',
              album: currentAlbum ?? '',
              durationSeconds: currentDuration ?? 180,
              imageUrl: currentImageUrl,
              uri: currentUri,
              isLiked: _likedTrackIds.contains(playerId),
            );
            _totalDuration = Duration(seconds: currentDuration ?? 180);
          }
          if (elapsedTime != null) {
            _currentPosition = Duration(seconds: elapsedTime);
          }
        }
        notifyListeners();
      }

      if (eventName == 'queue_updated' && data != null) {
        final queueId = data['queue_id']?.toString();
        if (_activePlayer != null && _activePlayer!.id == queueId) {
          final currentItem = data['current_item'] as Map<String, dynamic>?;
          if (currentItem != null) {
            final mediaItem = currentItem['media_item'] as Map<String, dynamic>? ?? currentItem;
            _currentTrack = _api.parseTrack(mediaItem, defaultProvider: 'library');
            final dur = (currentItem['duration'] as num?)?.toInt() ?? _currentTrack!.durationSeconds;
            _totalDuration = Duration(seconds: dur);
          }
          final state = data['state']?.toString();
          if (state != null) {
            _isPlaying = (state == 'playing');
          }
          final elapsedTime = (data['elapsed_time'] as num?)?.toInt();
          if (elapsedTime != null) {
            _currentPosition = Duration(seconds: elapsedTime);
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
      // 1. Fetch real players from server
      final remotePlayers = await _api.fetchPlayers();
      final localIPhone = PlayerDevice.localIPhone(
        isSelected: false,
        volume: 60,
      );

      // Put real Multiroom network speakers first
      _players = [...remotePlayers, localIPhone];

      final savedPlayerId = await _storage.loadActivePlayerId();
      if (savedPlayerId != null) {
        final match = _players.firstWhere(
          (p) => p.id == savedPlayerId,
          orElse: () => _players.first,
        );
        _activePlayer = match;
      } else {
        // Auto-select Tim's room speaker if available, or first active/available remote player
        PlayerDevice? preferred;
        for (final p in remotePlayers) {
          if (p.isAvailable && p.name.toLowerCase().contains('tim')) {
            preferred = p;
            break;
          }
        }
        preferred ??= remotePlayers.firstWhere(
          (p) => p.isAvailable && p.state == 'playing',
          orElse: () => remotePlayers.firstWhere(
            (p) => p.isAvailable,
            orElse: () => localIPhone,
          ),
        );
        _activePlayer = preferred;
        if (_activePlayer != null) {
          await _storage.saveActivePlayerId(_activePlayer!.id);
        }
      }

      for (final p in _players) {
        p.isSelected = (p.id == _activePlayer!.id);
      }

      // 2. Fetch real library tracks, playlists, podcasts, albums, artists in parallel
      final results = await Future.wait([
        _api.fetchLibraryPlaylists(limit: 50),
        _api.fetchLibraryPodcasts(limit: 50),
        _api.fetchLibraryAlbums(limit: 50),
        _api.fetchLibraryArtists(limit: 50),
        _api.fetchLibraryTracks(limit: 100),
      ]);

      final libraryPlaylists = results[0] as List<Playlist>;
      final libraryPodcasts = results[1] as List<Playlist>;
      final libraryAlbums = results[2] as List<Playlist>;
      final libraryArtists = results[3] as List<Playlist>;
      final libraryTracks = results[4] as List<Track>;

      _podcasts = libraryPodcasts;
      _albums = libraryAlbums;
      _artists = libraryArtists;

      _playlists = [
        ...libraryPlaylists,
        ...libraryPodcasts,
        ...libraryAlbums,
        ...libraryArtists,
      ];

      if (libraryTracks.isNotEmpty) {
        for (final t in libraryTracks) {
          if (_likedTrackIds.contains(t.id)) t.isLiked = true;
        }
        _queue = libraryTracks;
        _currentTrack ??= libraryTracks.first;
        _totalDuration = Duration(seconds: _currentTrack!.durationSeconds);
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

  /// Startet den virtuellen Spotify KI-DJ
  Future<void> startVirtualDj({DjVibeCategory? category}) async {
    _isDjActive = true;
    final targetCategory = category ?? DjVibeCategory.allTimeFavorites;
    await switchDjVibe(category: targetCategory, isInitial: true);
  }

  /// Wechselt die Musikstimmung (Vibe) des virtuellen DJs
  Future<void> switchDjVibe({DjVibeCategory? category, bool isInitial = false}) async {
    _isDjActive = true;
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

    // Songs passend zur Stimmung ermitteln
    List<Track> vibeTracks = [];

    switch (chosenVibe.category) {
      case DjVibeCategory.allTimeFavorites:
        final mostPlayedRow = _recommendations.where((r) => r.id.contains('most_played')).firstOrNull;
        if (mostPlayedRow != null && mostPlayedRow.items.isNotEmpty) {
          vibeTracks = mostPlayedRow.items.where((i) => i.mediaType == 'track' || i.mediaType.isEmpty).map((i) => i.toTrack()).toList();
        }
        break;

      case DjVibeCategory.rockClassics:
        final rockRow = _recommendations.where((r) => r.id.contains('similar_tracks')).firstOrNull;
        if (rockRow != null && rockRow.items.isNotEmpty) {
          vibeTracks = rockRow.items.where((i) => i.mediaType == 'track' || i.mediaType.isEmpty).map((i) => i.toTrack()).toList();
        }
        break;

      case DjVibeCategory.forgottenGems:
        final forgottenRow = _recommendations.where((r) => r.id.contains('forgotten')).firstOrNull;
        if (forgottenRow != null && forgottenRow.items.isNotEmpty) {
          vibeTracks = forgottenRow.items.where((i) => i.mediaType == 'track' || i.mediaType.isEmpty).map((i) => i.toTrack()).toList();
        }
        break;

      case DjVibeCategory.artistDiscoveries:
        final discRow = _recommendations.where((r) => r.id.contains('similar_artists')).firstOrNull;
        if (discRow != null && discRow.items.isNotEmpty) {
          vibeTracks = discRow.items.where((i) => i.mediaType == 'track' || i.mediaType.isEmpty).map((i) => i.toTrack()).toList();
        }
        break;

      case DjVibeCategory.partyVibes:
        vibeTracks = _queue.where((t) =>
            t.title.toLowerCase().contains('zipfelbuben') ||
            t.artist.toLowerCase().contains('feine sahne') ||
            t.title.toLowerCase().contains('berührt') ||
            t.durationSeconds < 240).toList();
        break;

      case DjVibeCategory.lateNightChill:
        vibeTracks = _queue.reversed.take(15).toList();
        break;
    }

    if (vibeTracks.isEmpty && _queue.isNotEmpty) {
      vibeTracks = List.from(_queue);
    }

    // Sprachansage formulieren (per lokalem Ollama LLM oder dynamischem Template)
    final userName = _currentUser?.effectiveName.split(' ').first ?? 'Tim';
    final nextTrack = vibeTracks.isNotEmpty ? vibeTracks.first : null;

    final speech = await _djService.composeDjSpeech(
      settings: _djVoiceSettings,
      vibe: chosenVibe,
      userName: userName,
      nextTrack: nextTrack,
    );

    // DJ-Kommentar sprechen und Dynamic Island öffnen
    await speakDjCommentary(speech);

    // Wiedergabe starten
    if (vibeTracks.isNotEmpty) {
      await playTrack(vibeTracks.first, newQueue: vibeTracks);
    }
  }

  int? _preDuckingVolume;

  /// Lässt den virtuellen DJ sprechen (TTS, Ollama, Ducking & Dynamic Island)
  Future<void> speakDjCommentary(String text) async {
    _djSpeechTimer?.cancel();
    _djSpeechSub?.cancel();
    _isDjSpeaking = true;
    _djSpeechText = text;
    notifyListeners();

    // Ducking: Musiklautstärke absenken während der Ansage
    if (_djVoiceSettings.enableDucking && _isPlaying && _activePlayer != null) {
      _preDuckingVolume ??= _activePlayer!.volume;
      await setVolume(_djVoiceSettings.duckingVolumePercent);
    }

    // Sprachausgabe über die konfigurierte Engine
    if (_isDjVoiceEnabled) {
      await _djService.speakCommentary(
        text: text,
        settings: _djVoiceSettings,
        activeRemotePlayerId: _activePlayer?.id,
        onMassAnnounce: (id, msg) => _api.playAnnouncement(id, msg),
      );
    }

    void finishSpeech() {
      _djSpeechTimer?.cancel();
      _djSpeechSub?.cancel();
      _isDjSpeaking = false;
      if (_preDuckingVolume != null) {
        setVolume(_preDuckingVolume!);
        _preDuckingVolume = null;
      }
      notifyListeners();
    }

    // Basierend auf Textlänge berechnen oder auf Event warten
    final estSeconds = (text.length / 14.0).clamp(4.0, 10.0);
    _djSpeechTimer = Timer(
      Duration(milliseconds: (estSeconds * 1000).toInt()),
      finishSpeech,
    );

    _djSpeechSub = _djService.onSpeechCompleted.listen((_) {
      finishSpeech();
    });
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

  Future<void> playTrack(Track track, {List<Track>? newQueue}) async {
    _currentTrack = track;
    _isPlaying = true;
    _currentPosition = Duration.zero;
    _totalDuration = Duration(seconds: track.durationSeconds);

    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = newQueue;
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

    if (_activePlayer == null && _players.isNotEmpty) {
      _activePlayer = _players.firstWhere(
        (p) => !p.isLocal && p.isAvailable,
        orElse: () => _players.first,
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

    // 2. Wiedergabe: Lokales iPhone vs Remote-Lautsprecher
    if (isLocalPlayback) {
      _positionTimer?.cancel();
      try {
        String? playUrl;

        // Falls Track bereits eine direkte Audio-Stream-URL hat (z. B. Radio/Hörbuch)
        if (track.uri != null &&
            track.uri!.startsWith('http') &&
            !_isImageUrl(track.uri!)) {
          playUrl = track.uri;
        }

        // Falls mit Server verbunden, Stream/Preview-Endpunkt abrufen
        if (playUrl == null && _api.isConnected) {
          playUrl = await _api.fetchTrackPreviewUrl(track);
          playUrl ??=
              '${_api.serverUrl}/api/stream?track_id=${Uri.encodeComponent(track.id)}';
        }

        // Zuverlässiger Fallback-Stream, falls kein Server aktiv ist
        if (playUrl == null || _isImageUrl(playUrl)) {
          playUrl =
              'https://stream.rockantenne.hamburg/rockantenne-hamburg/stream/mp3';
        }

        if (playUrl.startsWith('http') && !_isImageUrl(playUrl)) {
          final vol = (_activePlayer?.volume ?? 60) / 100.0;
          await _localAudioPlayer.setVolume(vol);
          await _localAudioPlayer.stop();
          await _localAudioPlayer.play(UrlSource(playUrl));
        } else {
          _startPositionTimer();
        }
      } catch (e) {
        debugPrint('[MusicProvider] Local play error: $e');
        _startPositionTimer();
      }
    } else if (_activePlayer != null) {
      // Externer Netzwerk-Lautsprecher (Sonos, AirPlay, etc.)
      await _localAudioPlayer.stop();
      _startPositionTimer();
      final mediaUri = track.uri ?? 'library://track/${track.id}';
      try {
        await _api.playMedia(_activePlayer!.id, mediaUri);
      } catch (e) {
        debugPrint('[MusicProvider] Remote playMedia error: $e');
        await _api.playerPlay(_activePlayer!.id);
      }
    }
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

  Future<void> togglePlayPause() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue.first);
      return;
    }

    _isPlaying = !_isPlaying;
    notifyListeners();

    if (isLocalPlayback) {
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
    if (!isLocalPlayback && _activePlayer != null && _api.isConnected) {
      try {
        await _api.playerNext(_activePlayer!.id);
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

    if (!isLocalPlayback && _activePlayer != null && _api.isConnected) {
      try {
        await _api.playerPrevious(_activePlayer!.id);
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
    notifyListeners();

    if (isLocalPlayback) {
      try {
        await _localAudioPlayer.seek(position);
      } catch (e) {
        debugPrint('[MusicProvider] Local seek error: $e');
      }
    } else if (_activePlayer != null) {
      try {
        await _api.playerSeek(_activePlayer!.id, position.inSeconds);
      } catch (e) {
        debugPrint('[MusicProvider] Remote seek error: $e');
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
    await _storage.saveLikedTrackIds(_likedTrackIds);
    notifyListeners();
  }

  Future<void> setActivePlayer(PlayerDevice player) async {
    final oldPlayer = _activePlayer;
    final wasPlaying = _isPlaying;

    if (oldPlayer?.isLocal == true && !player.isLocal) {
      // Vom iPhone auf externen Lautsprecher wechseln
      await _localAudioPlayer.stop();
      _isPlaying = false;
      notifyListeners();

      if (wasPlaying && _currentTrack != null) {
        final mediaUri = _currentTrack!.uri ?? 'library://track/${_currentTrack!.id}';
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
        oldPlayer.id != player.id) {
      // Zwischen zwei externen Lautsprechern wechseln
      try {
        await _api.transferQueue(oldPlayer.id, player.id, autoPlay: true);
        await _api.playerPlay(player.id);
      } catch (e) {
        debugPrint('[MusicProvider] transferQueue error: $e');
        if (_currentTrack != null) {
          final mediaUri = _currentTrack!.uri ?? 'library://track/${_currentTrack!.id}';
          await _api.playMedia(player.id, mediaUri);
        }
      }
    }

    for (final p in _players) {
      p.isSelected = (p.id == player.id);
    }
    _activePlayer = player;
    await _storage.saveActivePlayerId(player.id);
    notifyListeners();
    loadDspForPlayer(player.id);
  }

  /// Synchronisiert einen Lautsprecher mit dem aktuell aktiven Lautsprecher (Multiroom)
  Future<void> syncSpeakerWithActive(PlayerDevice speaker) async {
    if (_activePlayer == null || _activePlayer!.isLocal || speaker.isLocal) return;
    try {
      await _api.syncPlayer(speaker.id, _activePlayer!.id);
      await refreshServerData();
    } catch (e) {
      debugPrint('[MusicProvider] syncSpeakerWithActive error: $e');
    }
  }

  /// Hebt die Gruppensynchronisierung für einen Lautsprecher auf
  Future<void> unsyncSpeaker(PlayerDevice speaker) async {
    if (speaker.isLocal) return;
    try {
      await _api.unsyncPlayer(speaker.id);
      await refreshServerData();
    } catch (e) {
      debugPrint('[MusicProvider] unsyncSpeaker error: $e');
    }
  }

  Future<void> setVolume(int vol) async {
    if (_activePlayer != null) {
      final clamped = vol.clamp(0, 100);
      _activePlayer!.volume = clamped;
      if (_activePlayer!.isLocal) {
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
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      await _api.setSleepTimer(_activePlayer!.id, duration.inSeconds);
    }
  }

  Future<void> clearSleepTimer() async {
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      await _api.clearSleepTimer(_activePlayer!.id);
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
      if (_activePlayer != null && !_activePlayer!.isLocal) {
        await _api.playQueueIndex(_activePlayer!.id, index);
      }
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
    _playerPollTimer?.cancel();
    _localAudioPlayer.dispose();
    _api.dispose();
    try {
      AppleNowPlayingService.instance.clear();
    } catch (_) {}
    super.dispose();
  }
}
