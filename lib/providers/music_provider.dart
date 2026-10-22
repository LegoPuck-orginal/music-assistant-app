import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/player_device.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/mass_api_service.dart';
import '../services/storage_service.dart';

class MusicProvider extends ChangeNotifier {
  final MassApiService _api = MassApiService();
  final StorageService _storage = StorageService();

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

  Future<void> initialize() async {
    _serverUrl = await _storage.loadServerUrl();
    _likedTrackIds = await _storage.loadLikedTrackIds();
    _playlists = _api.getSamplePlaylists();

    // Mark liked tracks
    for (final p in _playlists) {
      for (final t in p.tracks) {
        if (_likedTrackIds.contains(t.id)) {
          t.isLiked = true;
        }
      }
    }

    _players = await _api.fetchPlayers();
    if (_players.isNotEmpty) {
      _activePlayer = _players.first;
    }

    // Default Track for demo
    if (_playlists.isNotEmpty && _playlists.first.tracks.isNotEmpty) {
      _currentTrack = _playlists.first.tracks.first;
      _queue = _playlists.first.tracks;
      _totalDuration = Duration(seconds: _currentTrack!.durationSeconds);
    }

    _api.configure(_serverUrl);
    notifyListeners();
  }

  void playTrack(Track track, {List<Track>? newQueue}) {
    _currentTrack = track;
    _isPlaying = true;
    _currentPosition = Duration.zero;
    _totalDuration = Duration(seconds: track.durationSeconds);

    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = newQueue;
      _queueIndex = _queue.indexWhere((t) => t.id == track.id);
      if (_queueIndex == -1) _queueIndex = 0;
    }

    _startPositionTimer();

    if (_activePlayer != null) {
      _api.playerPlay(_activePlayer!.id);
    }

    notifyListeners();
  }

  void togglePlayPause() {
    if (_currentTrack == null && _queue.isNotEmpty) {
      playTrack(_queue.first);
      return;
    }

    _isPlaying = !_isPlaying;

    if (_isPlaying) {
      _startPositionTimer();
      if (_activePlayer != null) _api.playerPlay(_activePlayer!.id);
    } else {
      _positionTimer?.cancel();
      if (_activePlayer != null) _api.playerPause(_activePlayer!.id);
    }

    notifyListeners();
  }

  void next() {
    if (_queue.isEmpty) return;
    if (_queueIndex < _queue.length - 1) {
      _queueIndex++;
    } else if (_repeatMode == 1) {
      _queueIndex = 0; // Repeat all
    } else {
      _isPlaying = false;
      _positionTimer?.cancel();
      notifyListeners();
      return;
    }

    playTrack(_queue[_queueIndex]);
    if (_activePlayer != null) _api.playerNext(_activePlayer!.id);
  }

  void previous() {
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

    playTrack(_queue[_queueIndex]);
    if (_activePlayer != null) _api.playerPrevious(_activePlayer!.id);
  }

  void seekTo(Duration position) {
    _currentPosition = position;
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    _repeatMode = (_repeatMode + 1) % 3;
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

  void setActivePlayer(PlayerDevice player) {
    for (final p in _players) {
      p.isSelected = (p.id == player.id);
    }
    _activePlayer = player;
    _storage.saveActivePlayerId(player.id);
    notifyListeners();
  }

  void setVolume(int vol) {
    if (_activePlayer != null) {
      _activePlayer!.volume = vol.clamp(0, 100);
      _api.playerVolume(_activePlayer!.id, _activePlayer!.volume);
      notifyListeners();
    }
  }

  Future<void> updateServerUrl(String url) async {
    _serverUrl = url;
    await _storage.saveServerUrl(url);
    _api.configure(url);
    _players = await _api.fetchPlayers();
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
    _positionTimer?.cancel();
    _api.dispose();
    super.dispose();
  }
}
