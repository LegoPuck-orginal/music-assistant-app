import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/player_device.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class MassApiService {
  String _serverUrl = 'http://192.168.188.25:8095';
  String _token = '';
  WebSocketChannel? _channel;
  bool _isConnected = false;
  int _messageId = 1;
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  Timer? _reconnectTimer;

  // Stream controller for live updates (player state, queue, etc.)
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  bool get isConnected => _isConnected;
  String get serverUrl => _serverUrl;

  void configure(String url, String token) {
    _serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _token = token.trim();
    connectWebSocket();
  }

  void connectWebSocket() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();

    final wsUrl = '${_serverUrl.replaceFirst(RegExp(r'^http'), 'ws')}/ws';
    debugPrint('[MassApi] Connecting to WebSocket: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        _onMessageReceived,
        onDone: () {
          debugPrint('[MassApi] WebSocket connection closed.');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (err) {
          debugPrint('[MassApi] WebSocket error: $err');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[MassApi] WebSocket exception: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _onMessageReceived(dynamic rawData) {
    try {
      final json = jsonDecode(rawData as String) as Map<String, dynamic>;

      // Server welcome message triggers authentication
      if (json.containsKey('server_id')) {
        debugPrint('[MassApi] Server info received. Sending auth...');
        _sendAuth();
        return;
      }

      // Check if response matches pending command request
      final messageId = json['message_id']?.toString();
      if (messageId != null && _pendingRequests.containsKey(messageId)) {
        final completer = _pendingRequests.remove(messageId);
        if (json.containsKey('error_code')) {
          completer?.completeError(
              Exception('${json['details']} (code: ${json['error_code']})'));
        } else {
          completer?.complete(json['result']);
        }
        return;
      }

      // Broadcast events (player_updated, queue_updated, etc.)
      if (json.containsKey('event')) {
        _eventsController.add(json);
      }
    } catch (e) {
      debugPrint('[MassApi] Message parsing error: $e');
    }
  }

  void _sendAuth() {
    if (_token.isEmpty) {
      debugPrint('[MassApi] No auth token provided, skipping auth.');
      return;
    }
    sendCommand('auth', {'token': _token}).then((result) {
      debugPrint('[MassApi] Authenticated successfully with Music Assistant!');
      _isConnected = true;
    }).catchError((err) {
      debugPrint('[MassApi] Auth error: $err');
      _isConnected = false;
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (!_isConnected) {
        connectWebSocket();
      }
    });
  }

  /// Sendet ein JSON-RPC-Kommando über den WebSocket an Music Assistant
  Future<dynamic> sendCommand(String command,
      [Map<String, dynamic>? args]) async {
    final id = (_messageId++).toString();
    final payload = {
      'message_id': id,
      'command': command,
      'args': ?args,
    };

    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    if (_channel != null) {
      _channel!.sink.add(jsonEncode(payload));
    } else {
      completer.completeError(Exception('WebSocket is not connected'));
    }

    // Timeout after 6 seconds
    return completer.future.timeout(const Duration(seconds: 6), onTimeout: () {
      _pendingRequests.remove(id);
      throw TimeoutException('Command $command timed out');
    });
  }

  // --- Real API Endpoints ---

  /// Ruft alle verfügbaren Player (Sonos, AirPlay, Chromecast etc.) ab
  Future<List<PlayerDevice>> fetchPlayers() async {
    try {
      final res = await sendCommand('players/all');
      if (res is List) {
        return res.map((p) {
          final map = p as Map<String, dynamic>;
          final playerId = map['player_id']?.toString() ?? '';
          final name = map['name']?.toString() ?? 'Player';
          final provider = map['provider']?.toString() ?? 'generic';
          final state = map['playback_state']?.toString() ??
              map['state']?.toString() ??
              'idle';
          final volume = (map['volume_level'] as num?)?.toInt() ?? 50;
          final isMuted = map['volume_muted'] as bool? ?? false;

          return PlayerDevice(
            id: playerId,
            name: name,
            type: _formatPlayerType(provider),
            volume: volume,
            isMuted: isMuted,
            state: state,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchPlayers error: $e');
    }
    return [];
  }

  /// Ruft echte Playlists aus der Music Assistant Bibliothek ab
  Future<List<Playlist>> fetchLibraryPlaylists({int limit = 50}) async {
    try {
      final res = await sendCommand('music/playlists/library_items', {
        'limit': limit,
      });
      if (res is List) {
        return res.map((p) {
          final map = p as Map<String, dynamic>;
          final id = map['item_id']?.toString() ?? map['uri']?.toString() ?? '';
          final name = map['name']?.toString() ?? '';
          final owner = map['owner']?.toString() ?? 'Music Assistant';
          final tracksCount = (map['track_count'] as num?)?.toInt() ?? 0;

          // Thumbnail image
          String? imageUrl;
          final metadata = map['metadata'] as Map<String, dynamic>?;
          if (metadata != null && metadata['images'] is List) {
            final images = metadata['images'] as List;
            if (images.isNotEmpty) {
              imageUrl = images.first['path']?.toString();
            }
          }

          return Playlist(
            id: id,
            name: name.isNotEmpty ? name : 'Playlist $id',
            owner: owner,
            trackCount: tracksCount,
            imageUrl: imageUrl,
            type: 'playlist',
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchLibraryPlaylists error: $e');
    }
    return [];
  }

  /// Ruft echte Songs aus der Music Assistant Bibliothek ab
  Future<List<Track>> fetchLibraryTracks({int limit = 100}) async {
    try {
      final res = await sendCommand('music/tracks/library_items', {
        'limit': limit,
      });
      if (res is List) {
        return res.map((t) {
          final map = t as Map<String, dynamic>;
          final id = map['item_id']?.toString() ?? '';
          final title = map['name']?.toString() ?? 'Unbekannter Titel';

          // Artist
          String artistName = 'Unbekannter Künstler';
          if (map['artists'] is List && (map['artists'] as List).isNotEmpty) {
            artistName = (map['artists'] as List)
                .map((a) => a['name']?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .join(', ');
          }

          // Album
          String albumName = '';
          String? imageUrl;
          if (map['album'] is Map) {
            final albumMap = map['album'] as Map<String, dynamic>;
            albumName = albumMap['name']?.toString() ?? '';
            if (albumMap['image'] is Map) {
              imageUrl = albumMap['image']['path']?.toString();
            }
          }

          if (imageUrl == null && map['metadata'] is Map) {
            final meta = map['metadata'] as Map<String, dynamic>;
            if (meta['images'] is List && (meta['images'] as List).isNotEmpty) {
              imageUrl = (meta['images'] as List).first['path']?.toString();
            }
          }

          final duration = (map['duration'] as num?)?.toInt() ?? 180;
          final isLiked = map['favorite'] as bool? ?? false;
          final uri = map['uri']?.toString();

          return Track(
            id: id,
            title: title,
            artist: artistName,
            album: albumName,
            durationSeconds: duration,
            imageUrl: imageUrl,
            uri: uri,
            isLiked: isLiked,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchLibraryTracks error: $e');
    }
    return [];
  }

  /// Ruft Audio Preview Stream URL ab (für lokale iPhone Wiedergabe)
  Future<String?> fetchTrackPreviewUrl(Track track) async {
    try {
      final res = await sendCommand('music/tracks/preview', {
        'provider_instance_id_or_domain': 'library',
        'item_id': track.id,
      });
      if (res is String && res.isNotEmpty) {
        return res;
      }
    } catch (e) {
      debugPrint('[MassApi] fetchTrackPreviewUrl error: $e');
    }
    return null;
  }

  // --- Real Player Control Commands ---

  Future<void> playerPlay(String playerId) =>
      sendCommand('players/cmd/play', {'player_id': playerId});

  Future<void> playerPause(String playerId) =>
      sendCommand('players/cmd/pause', {'player_id': playerId});

  Future<void> playerPlayPause(String playerId) =>
      sendCommand('players/cmd/play_pause', {'player_id': playerId});

  Future<void> playerNext(String playerId) =>
      sendCommand('players/cmd/next', {'player_id': playerId});

  Future<void> playerPrevious(String playerId) =>
      sendCommand('players/cmd/previous', {'player_id': playerId});

  Future<void> playerSeek(String playerId, int seconds) =>
      sendCommand('players/cmd/seek', {'player_id': playerId, 'position': seconds});

  Future<void> playerVolume(String playerId, int volume) =>
      sendCommand('players/cmd/volume_set',
          {'player_id': playerId, 'volume_level': volume.clamp(0, 100)});

  Future<void> playerMute(String playerId, bool muted) =>
      sendCommand('players/cmd/volume_mute',
          {'player_id': playerId, 'muted': muted});

  Future<void> playerShuffle(String playerId, bool shuffle) =>
      sendCommand('players/cmd/shuffle',
          {'player_id': playerId, 'shuffle_enabled': shuffle});

  Future<void> playerRepeat(String playerId, String mode) =>
      sendCommand('players/cmd/repeat',
          {'player_id': playerId, 'repeat_mode': mode});

  /// Spielt einen Track oder eine Playlist auf einem Music Assistant Player ab
  Future<void> playMedia(String playerId, String mediaUri) =>
      sendCommand('player_queues/play_media', {
        'queue_id': playerId,
        'media': [mediaUri],
      });

  /// Equalizer / DSP Preset anwenden
  Future<void> applyDSPPreset(String playerId, String presetId) =>
      sendCommand('config/players/dsp/apply_preset', {
        'player_id': playerId,
        'preset_id': presetId,
      });

  String _formatPlayerType(String provider) {
    final p = provider.toLowerCase();
    if (p.contains('sonos')) return 'Sonos';
    if (p.contains('airplay') || p.contains('apple')) return 'AirPlay';
    if (p.contains('chromecast') || p.contains('cast') || p.contains('shield')) {
      return 'Chromecast';
    }
    if (p.contains('sendspin') || p.contains('companion')) return 'Companion';
    if (p.contains('universal')) return 'Universal';
    return provider.toUpperCase();
  }

  void dispose() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    _eventsController.close();
  }
}
