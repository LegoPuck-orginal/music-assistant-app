import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/equalizer_settings.dart';
import '../models/player_device.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/mass_api_service.dart';
import '../services/storage_service.dart';

class MusicProvider extends ChangeNotifier {
  final MassApiService _api = MassApiService();
  final StorageService _storage = StorageService();
  final AudioPlayer _localAudioPlayer = AudioPlayer();

  Track? _currentTrack;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 3, seconds: 30);
  bool _isShuffle = false;
  int _repeatMode = 0; // 0 = off, 1 = all, 2 = one

  List<Track> _queue = [];
  int _queueIndex = 0;
  List<Playlist> _playlists = [];
  List<PlayerDevice> _players = [];
  PlayerDevice? _activePlayer;
  Set<String> _likedTrackIds = {};
  Timer? _positionTimer;
  String _serverUrl = 'http://192.168.188.25:8095';
  String _authToken = StorageService.defaultToken;
  EqualizerSettings _equalizerSettings = EqualizerSettings();
  StreamSubscription? _eventsSubscription;

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
  List<Playlist> get playlists => _playlists;
  List<PlayerDevice> get players => _players;
  PlayerDevice? get activePlayer => _activePlayer;
  bool get isServerConnected => _api.isConnected;
  String get serverUrl => _serverUrl;
  String get authToken => _authToken;
  EqualizerSettings get equalizerSettings => _equalizerSettings;

  Future<void> initialize() async {
    try {
      _serverUrl = await _storage.loadServerUrl();
      _authToken = await _storage.loadAuthToken();
      _likedTrackIds = await _storage.loadLikedTrackIds();
      _equalizerSettings = await _storage.loadEqualizerSettings();
    } catch (e) {
      debugPrint('[MusicProvider] Storage init error: $e');
    }

    // Setup local audio player listeners
    try {
      _setupLocalAudioPlayer();
    } catch (e) {
      debugPrint('[MusicProvider] AudioPlayer setup error: $e');
    }

    notifyListeners();

    // Connect to server and refresh data asynchronously in background
    _connectAndRefresh();
  }

  void _connectAndRefresh() {
    try {
      _api.configure(_serverUrl, _authToken);

      _eventsSubscription?.cancel();
      _eventsSubscription = _api.events.listen(_handleServerEvent);

      refreshServerData();
    } catch (e) {
      debugPrint('[MusicProvider] Background connect error: $e');
    }
  }

  void _setupLocalAudioPlayer() {
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
    } catch (e) {
      debugPrint('[MusicProvider] Event handler error: $e');
    }
  }

  Future<void> refreshServerData() async {
    try {
      // 1. Fetch real players
      final remotePlayers = await _api.fetchPlayers();
      final localIPhone = PlayerDevice.localIPhone(
        isSelected: _activePlayer?.isLocal ?? true,
        volume: _activePlayer?.isLocal == true ? _activePlayer!.volume : 60,
      );

      _players = [localIPhone, ...remotePlayers];

      final savedPlayerId = await _storage.loadActivePlayerId();
      if (savedPlayerId != null) {
        final match = _players.firstWhere(
          (p) => p.id == savedPlayerId,
          orElse: () => localIPhone,
        );
        _activePlayer = match;
      } else {
        _activePlayer ??= localIPhone;
      }

      for (final p in _players) {
        p.isSelected = (p.id == _activePlayer!.id);
      }

      // 2. Fetch real library tracks
      final libraryTracks = await _api.fetchLibraryTracks(limit: 100);

      // 3. Fetch real library playlists
      final libraryPlaylists = await _api.fetchLibraryPlaylists(limit: 50);

      if (libraryTracks.isNotEmpty) {
        for (final t in libraryTracks) {
          if (_likedTrackIds.contains(t.id)) t.isLiked = true;
        }
        _queue = libraryTracks;
        _currentTrack ??= libraryTracks.first;
        _totalDuration = Duration(seconds: _currentTrack!.durationSeconds);
      }

      if (libraryPlaylists.isNotEmpty) {
        // Attach tracks to playlists if empty
        for (final p in libraryPlaylists) {
          if (p.tracks.isEmpty) {
            p.tracks.addAll(libraryTracks.take(15));
          }
        }
        _playlists = libraryPlaylists;
      } else if (libraryTracks.isNotEmpty) {
        // Create a default playlist from all tracks
        _playlists = [
          Playlist(
            id: 'all_tracks',
            name: 'Deine Mediathek',
            owner: 'Music Assistant',
            trackCount: libraryTracks.length,
            imageUrl: libraryTracks.first.imageUrl,
            tracks: libraryTracks,
          ),
        ];
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[MusicProvider] refreshServerData error: $e');
    }
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
    if (_activePlayer?.isLocal == true && !player.isLocal) {
      await _localAudioPlayer.stop();
    }

    for (final p in _players) {
      p.isSelected = (p.id == player.id);
    }
    _activePlayer = player;
    await _storage.saveActivePlayerId(player.id);
    notifyListeners();
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

  // --- Equalizer Controls ---

  Future<void> setEqualizerEnabled(bool enabled) async {
    _equalizerSettings.isEnabled = enabled;
    await _storage.saveEqualizerSettings(_equalizerSettings);
    _syncEqualizerToHardware();
    notifyListeners();
  }

  Future<void> setEqualizerPreset(String presetName) async {
    _equalizerSettings.applyPreset(presetName);
    await _storage.saveEqualizerSettings(_equalizerSettings);
    _syncEqualizerToHardware();
    notifyListeners();
  }

  Future<void> setEqualizerBandGain(int index, double gain) async {
    _equalizerSettings.setBandGain(index, gain);
    await _storage.saveEqualizerSettings(_equalizerSettings);
    _syncEqualizerToHardware();
    notifyListeners();
  }

  void _syncEqualizerToHardware() {
    if (_activePlayer != null && !_activePlayer!.isLocal) {
      _api.applyDSPPreset(
          _activePlayer!.id, _equalizerSettings.currentPreset.toLowerCase());
    }
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
    _eventsSubscription?.cancel();
    _positionTimer?.cancel();
    _localAudioPlayer.dispose();
    _api.dispose();
    super.dispose();
  }
}
