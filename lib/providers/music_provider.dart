import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/app_update_info.dart';
import '../models/dsp_models.dart';
import '../models/equalizer_settings.dart';
import '../models/player_device.dart';
import '../models/playlist.dart';
import '../models/recommendation.dart';
import '../models/track.dart';
import '../models/user_profile.dart';
import '../models/virtual_dj_vibe.dart';
import '../services/mass_api_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';

class MusicProvider extends ChangeNotifier {
  final MassApiService _api = MassApiService();
  final StorageService _storage = StorageService();
  final AudioPlayer _localAudioPlayer = AudioPlayer();
  final UpdateService _updateService = UpdateService();

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
  List<PlayerDevice> _players = [];
  PlayerDevice? _activePlayer;
  Set<String> _likedTrackIds = {};
  Timer? _positionTimer;
  String _serverUrl = 'http://192.168.188.25:8095';
  String _authToken = StorageService.defaultToken;
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  UserProfile? _currentUser;
  bool _isLoggingIn = false;
  String? _loginError;
  EqualizerSettings _equalizerSettings = EqualizerSettings();
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
  List<RecommendationRow> get recommendations => _recommendations;
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  List<Track> get searchResultsTracks => _searchResultsTracks;
  List<Playlist> get searchResultsPlaylists => _searchResultsPlaylists;
  List<Playlist> get searchResultsAlbums => _searchResultsAlbums;
  List<Playlist> get searchResultsPodcasts => _searchResultsPodcasts;
  bool get isSearching => _isSearching;
  String get lastSearchQuery => _lastSearchQuery;

  // Virtual DJ & Dynamic Island State
  bool _isDjActive = false;
  bool _isDjSpeaking = false;
  bool _isDjVoiceEnabled = true;
  DjVibe _currentDjVibe = DjVibe.allVibes.first;
  String? _djSpeechText;
  bool _isDynamicIslandExpanded = false;
  Timer? _djSpeechTimer;

  bool get isDjActive => _isDjActive;
  bool get isDjSpeaking => _isDjSpeaking;
  bool get isDjVoiceEnabled => _isDjVoiceEnabled;
  DjVibe get currentDjVibe => _currentDjVibe;
  String? get djSpeechText => _djSpeechText;
  bool get isDynamicIslandExpanded => _isDynamicIslandExpanded;

  void setDynamicIslandExpanded(bool val) {
    _isDynamicIslandExpanded = val;
    notifyListeners();
  }

  void toggleDjVoice() {
    _isDjVoiceEnabled = !_isDjVoiceEnabled;
    notifyListeners();
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
  bool get isServerConnected => _api.isConnected;
  String get serverUrl => _serverUrl;
  String get authToken => _authToken;
  EqualizerSettings get equalizerSettings => _equalizerSettings;
  DspConfig? get dspConfig => _dspConfig;
  List<DspPreset> get dspPresets => _dspPresets;
  bool get isLoadingDsp => _isLoadingDsp;
  String? get dspError => _dspError;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  UserProfile? get currentUser => _currentUser;
  bool get isLoggingIn => _isLoggingIn;
  String? get loginError => _loginError;
  AppUpdateInfo? get updateInfo => _updateInfo;
  bool get isCheckingForUpdates => _isCheckingForUpdates;
  bool get hasUpdate => _updateInfo?.hasUpdate ?? false;

  Future<void> initialize() async {
    try {
      _serverUrl = await _storage.loadServerUrl();
      final token = await _storage.loadAuthToken();
      _currentUser = await _storage.loadUserProfile();
      final isGuest = await _storage.loadIsGuest();
      _likedTrackIds = await _storage.loadLikedTrackIds();
      _equalizerSettings = await _storage.loadEqualizerSettings();

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

    _isInitialized = true;
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
    return _updateInfo ?? AppUpdateInfo.noUpdate(currentVersion: '1.2.0');
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
    } catch (e) {
      debugPrint('[MusicProvider] Background connect error: $e');
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

  void _setupLocalAudioPlayer() {
    try {
      AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
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

    _localAudioPlayer.onPlayerStateChanged.listen((state) {
      if (_activePlayer?.isLocal == true) {
        _isPlaying = (state == PlayerState.playing);
        notifyListeners();
      }
    });

    _localAudioPlayer.onPositionChanged.listen((pos) {
      if (_activePlayer?.isLocal == true) {
        _currentPosition = pos;
        notifyListeners();
      }
    });

    _localAudioPlayer.onDurationChanged.listen((dur) {
      if (_activePlayer?.isLocal == true && dur.inSeconds > 0) {
        _totalDuration = dur;
        notifyListeners();
      }
    });

    _localAudioPlayer.onPlayerComplete.listen((_) {
      if (_activePlayer?.isLocal == true) {
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

        // Update matching player in list
        for (final p in _players) {
          if (p.id == playerId) {
            if (volume != null) p.volume = volume;
            if (state != null) p.state = state;
          }
        }

        // If active player is the updated external player, update playback state
        if (_activePlayer != null && _activePlayer!.id == playerId) {
          if (state != null) {
            _isPlaying = (state == 'playing');
          }
          if (volume != null) {
            _activePlayer!.volume = volume;
          }

          // If media metadata is attached
          final currentMedia = data['current_media'] as Map<String, dynamic>?;
          if (currentMedia != null) {
            final title = currentMedia['title']?.toString();
            final artist = currentMedia['artist']?.toString() ?? '';
            final album = currentMedia['album']?.toString() ?? '';
            final img = currentMedia['image_url']?.toString();
            if (title != null && title.isNotEmpty) {
              _currentTrack = Track(
                id: playerId ?? 'remote',
                title: title,
                artist: artist,
                album: album,
                durationSeconds:
                    (currentMedia['duration'] as num?)?.toInt() ?? 180,
                imageUrl: img,
                isLiked: _likedTrackIds.contains(playerId),
              );
            }
          }
          notifyListeners();
        }
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
        userId: 'tim_id',
        username: 'tim-m',
        displayName: displayName,
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

    // Sprachansage formulieren
    final userName = _currentUser?.effectiveName.split(' ').first ?? 'Tim';
    final rawSpeech = chosenVibe.introPrompt.replaceAll('{user}', userName);

    // DJ-Kommentar sprechen und Dynamic Island öffnen
    await speakDjCommentary(rawSpeech);

    // Wiedergabe starten
    if (vibeTracks.isNotEmpty) {
      await playTrack(vibeTracks.first, newQueue: vibeTracks);
    }
  }

  /// Lässt den virtuellen DJ sprechen (TTS & Dynamic Island)
  Future<void> speakDjCommentary(String text) async {
    _djSpeechTimer?.cancel();
    _isDjSpeaking = true;
    _djSpeechText = text;
    _isDynamicIslandExpanded = true;
    notifyListeners();

    // Sprachausgabe über den aktiven Raum-Lautsprecher via Music Assistant TTS
    if (_isDjVoiceEnabled && _activePlayer != null) {
      sendAnnouncement(text);
    }

    // Dynamic Island nach 5,5 Sekunden automatisch wieder einklappen
    _djSpeechTimer = Timer(const Duration(milliseconds: 5500), () {
      _isDjSpeaking = false;
      _isDynamicIslandExpanded = false;
      notifyListeners();
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

    // Check if active player is local iPhone or network speaker
    if (_activePlayer != null && _activePlayer!.isLocal) {
      // Local iPhone Playback
      _positionTimer?.cancel();
      try {
        final previewUrl = await _api.fetchTrackPreviewUrl(track);
        final playUrl = previewUrl ?? track.uri ?? track.imageUrl;
        if (playUrl != null && playUrl.startsWith('http')) {
          await _localAudioPlayer.setVolume(_activePlayer!.volume / 100.0);
          await _localAudioPlayer.play(UrlSource(playUrl));
        } else {
          _startPositionTimer();
        }
      } catch (e) {
        debugPrint('[MusicProvider] Local play error: $e');
        _startPositionTimer();
      }
    } else if (_activePlayer != null) {
      // External Network Player (Sonos, AirPlay, etc.)
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

  Future<void> togglePlayPause() async {
    if (_currentTrack == null && _queue.isNotEmpty) {
      await playTrack(_queue.first);
      return;
    }

    _isPlaying = !_isPlaying;
    notifyListeners();

    if (_activePlayer != null && _activePlayer!.isLocal) {
      if (_isPlaying) {
        await _localAudioPlayer.resume();
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
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      await _api.playerNext(_activePlayer!.id);
    }
  }

  Future<void> previous() async {
    if (_currentPosition.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }

    if (_queue.isEmpty) return;
    if (_queueIndex > 0) {
      _queueIndex--;
    } else {
      _queueIndex = _queue.length - 1;
    }

    await playTrack(_queue[_queueIndex]);
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      await _api.playerPrevious(_activePlayer!.id);
    }
  }

  Future<void> seekTo(Duration position) async {
    _currentPosition = position;
    notifyListeners();

    if (_activePlayer != null && _activePlayer!.isLocal) {
      await _localAudioPlayer.seek(position);
    } else if (_activePlayer != null) {
      await _api.playerSeek(_activePlayer!.id, position.inSeconds);
    }
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
    if (_activePlayer?.isLocal == true && !player.isLocal) {
      await _localAudioPlayer.stop();
    }

    // Seamless Queue Transfer if music was playing on an external speaker and transferring to another external speaker
    if (_isPlaying &&
        oldPlayer != null &&
        !oldPlayer.isLocal &&
        !player.isLocal &&
        oldPlayer.id != player.id) {
      try {
        await _api.transferQueue(oldPlayer.id, player.id, autoPlay: true);
      } catch (e) {
        debugPrint('[MusicProvider] transferQueue error: $e');
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

  Future<void> setVolume(int vol) async {
    if (_activePlayer != null) {
      _activePlayer!.volume = vol.clamp(0, 100);
      if (_activePlayer!.isLocal) {
        await _localAudioPlayer.setVolume(_activePlayer!.volume / 100.0);
      } else {
        await _api.playerVolume(_activePlayer!.id, _activePlayer!.volume);
      }
      notifyListeners();
    }
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
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPlaying && _currentPosition < _totalDuration) {
        _currentPosition += const Duration(seconds: 1);
        notifyListeners();
      } else if (_currentPosition >= _totalDuration) {
        if (_repeatMode == 2) {
          seekTo(Duration.zero);
        } else {
          next();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _eventsSubscription?.cancel();
    _positionTimer?.cancel();
    _localAudioPlayer.dispose();
    _api.dispose();
    super.dispose();
  }
}
