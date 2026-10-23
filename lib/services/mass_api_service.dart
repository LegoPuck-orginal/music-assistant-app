import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/player_device.dart';
import '../models/playlist.dart';
import '../models/recommendation.dart';
import '../models/track.dart';

class MassApiService {
  String _serverUrl = 'http://homeassistant.local:8095';
  String _token = '';
  WebSocketChannel? _channel;
  bool _isConnected = false;
  int _messageId = 1;
  final Map<String, Completer<dynamic>> _pendingRequests = {};
  Timer? _reconnectTimer;

  // Stream controller for live updates (player state, queue, etc.)
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream controller when auth completes successfully
  final StreamController<void> _authenticatedController =
      StreamController<void>.broadcast();

  Map<String, dynamic>? _currentUser;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;
  Stream<void> get onAuthenticated => _authenticatedController.stream;
  bool get isConnected => _isConnected;
  String get serverUrl => _serverUrl;
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Prüft eigenständig, ob unter der angegebenen Server-URL ein erreichbarer Music Assistant Server läuft
  static Future<Map<String, dynamic>> testConnection(String url) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleanUrl.isEmpty) {
      return {
        'success': false,
        'error': 'Bitte gib eine Server-Adresse ein.',
      };
    }

    final wsUrl = '${cleanUrl.replaceFirst(RegExp(r'^http'), 'ws')}/ws';
    final completer = Completer<Map<String, dynamic>>();
    WebSocketChannel? testChannel;

    try {
      testChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (e) {
      return {
        'success': false,
        'error': 'Verbindung fehlgeschlagen ($e)',
      };
    }

    final timer = Timer(const Duration(milliseconds: 2500), () {
      if (!completer.isCompleted) {
        testChannel?.sink.close();
        completer.complete({
          'success': false,
          'error': 'Zeitüberschreitung (Timeout nach 2,5s). Server antwortet nicht.',
        });
      }
    });

    testChannel.stream.listen(
      (rawData) {
        try {
          final json = jsonDecode(rawData as String) as Map<String, dynamic>;
          if (json.containsKey('server_id')) {
            timer.cancel();
            testChannel?.sink.close();
            if (!completer.isCompleted) {
              final version = json['server_version']?.toString() ?? '2.x';
              final serverId = json['server_id']?.toString() ?? '';
              completer.complete({
                'success': true,
                'serverId': serverId,
                'serverVersion': version,
                'message': 'Music Assistant erreichbar (v$version)',
              });
            }
          }
        } catch (e) {
          timer.cancel();
          testChannel?.sink.close();
          if (!completer.isCompleted) {
            completer.complete({
              'success': false,
              'error': 'Ungültige Server-Antwort ($e)',
            });
          }
        }
      },
      onError: (err) {
        timer.cancel();
        testChannel?.sink.close();
        if (!completer.isCompleted) {
          completer.complete({
            'success': false,
            'error': 'Server nicht erreichbar ($err)',
          });
        }
      },
      onDone: () {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete({
            'success': false,
            'error': 'Verbindung wurde vom Server vorzeitig geschlossen.',
          });
        }
      },
    );

    return completer.future;
  }

  /// Durchsucht das lokale Netzwerk nach erreichbaren Music Assistant Instanzen
  static Future<List<String>> discoverLocalServers() async {
    final candidateHosts = [
      'http://homeassistant.local:8095',
      'http://mass.local:8095',
      'http://homeassistant:8095',
      'http://127.0.0.1:8095',
      'http://192.168.188.25:8095',
      'http://192.168.1.100:8095',
      'http://192.168.178.1:8095',
      'http://192.168.0.100:8095',
    ];

    final results = <String>[];
    await Future.wait(
      candidateHosts.map((host) async {
        try {
          final res = await testConnection(host);
          if (res['success'] == true) {
            results.add(host);
          }
        } catch (_) {}
      }),
    );

    return results;
  }

  void configure(String url, String token) {
    _serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _token = token.trim();
    connectWebSocket();
  }

  void logout() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    _isConnected = false;
    _token = '';
    _currentUser = null;
  }

  /// Meldet sich mit Benutzername und Passwort bei Music Assistant an und liefert
  /// das Access-Token sowie Benutzerdaten zurück.
  Future<Map<String, dynamic>> loginWithCredentials({
    required String serverUrl,
    required String username,
    required String password,
    String deviceName = 'iPhone',
  }) async {
    final cleanUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final wsUrl = '${cleanUrl.replaceFirst(RegExp(r'^http'), 'ws')}/ws';

    final completer = Completer<Map<String, dynamic>>();
    WebSocketChannel? tempChannel;

    try {
      tempChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (e) {
      throw Exception('Server unter $serverUrl nicht erreichbar ($e)');
    }

    final timer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        tempChannel?.sink.close();
        completer.completeError(
            Exception('Zeitüberschreitung beim Verbindungsaufbau zum Server'));
      }
    });

    final loginMsgId = 'auth_login_${DateTime.now().millisecondsSinceEpoch}';

    tempChannel.stream.listen(
      (rawData) {
        try {
          final json = jsonDecode(rawData as String) as Map<String, dynamic>;

          // Server ready -> auth/login senden
          if (json.containsKey('server_id')) {
            tempChannel!.sink.add(jsonEncode({
              'message_id': loginMsgId,
              'command': 'auth/login',
              'args': {
                'username': username,
                'password': password,
                'device_name': deviceName,
              },
            }));
            return;
          }

          if (json['message_id'] == loginMsgId) {
            timer.cancel();
            final res = json['result'] as Map<String, dynamic>? ?? {};
            if (res['success'] == true && res.containsKey('access_token')) {
              tempChannel?.sink.close();
              if (!completer.isCompleted) {
                completer.complete(res);
              }
            } else {
              tempChannel?.sink.close();
              if (!completer.isCompleted) {
                completer.completeError(
                    Exception(res['error'] ?? 'Ungültiger Benutzername oder Passwort'));
              }
            }
          }
        } catch (e) {
          timer.cancel();
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onError: (err) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
              Exception('Verbindung zum Server fehlgeschlagen ($err)'));
        }
      },
      onDone: () {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
              Exception('Verbindung zum Server wurde vorzeitig beendet.'));
        }
      },
    );

    return completer.future;
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
      if (result is Map && result.containsKey('user') && result['user'] is Map) {
        _currentUser = Map<String, dynamic>.from(result['user'] as Map);
      }
      _isConnected = true;
      _authenticatedController.add(null);
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

    // Timeout after 5 seconds
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      _pendingRequests.remove(id);
      throw TimeoutException('Command $command timed out');
    });
  }

  // --- Real API Endpoints ---

  /// Ruft alle Lautsprecher aus Music Assistant ab
  Future<List<PlayerDevice>> fetchPlayers() async {
    try {
      final res = await sendCommand('players/all');
      if (res is List) {
        final list = <PlayerDevice>[];
        for (final p in res) {
          final map = p as Map<String, dynamic>;
          final type = map['type']?.toString().toLowerCase() ?? '';
          // Filter out lights (Philips Hue synced lights in Sendspin)
          if (type == 'light') continue;

          final playerId = map['player_id']?.toString() ?? '';
          final name = map['display_name']?.toString() ??
              map['name']?.toString() ??
              'Player';
          final provider = map['provider']?.toString() ?? 'generic';
          final state = map['playback_state']?.toString() ??
              map['state']?.toString() ??
              'idle';
          final volume = (map['volume_level'] as num?)?.toInt() ?? 50;
          final isMuted = map['volume_muted'] as bool? ?? false;
          final available = map['available'] as bool? ?? true;
          final syncedTo = map['synced_to']?.toString();
          final groupChilds = (map['group_childs'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const <String>[];
          final canSyncWith = (map['can_sync_with'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const <String>[];

          final currentMedia = map['current_media'] as Map<String, dynamic>?;
          final currentTitle = currentMedia?['title']?.toString();
          final currentArtist = currentMedia?['artist']?.toString();
          final currentAlbum = currentMedia?['album']?.toString();
          final currentImageUrl = currentMedia?['image_url']?.toString();
          final currentDuration = (currentMedia?['duration'] as num?)?.toInt();
          final elapsedTime = (map['elapsed_time'] as num?)?.toInt();
          final currentUri = currentMedia?['uri']?.toString();

          list.add(PlayerDevice(
            id: playerId,
            name: name,
            type: _formatPlayerType(provider),
            volume: volume,
            isMuted: isMuted,
            state: state,
            isAvailable: available,
            syncedTo: syncedTo,
            groupChilds: groupChilds,
            canSyncWith: canSyncWith,
            currentTitle: currentTitle,
            currentArtist: currentArtist,
            currentAlbum: currentAlbum,
            currentImageUrl: currentImageUrl,
            currentDurationSeconds: currentDuration,
            elapsedTimeSeconds: elapsedTime,
            currentUri: currentUri,
          ));
        }
        return list;
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
        return res
            .map((p) => _parsePlaylist(p as Map<String, dynamic>,
                defaultType: 'playlist', defaultProvider: 'library'))
            .toList();
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
        return res
            .map((t) => _parseTrack(t as Map<String, dynamic>,
                defaultProvider: 'library'))
            .toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchLibraryTracks error: $e');
    }
    return [];
  }

  /// Ruft echte Podcasts aus der Music Assistant Bibliothek ab
  Future<List<Playlist>> fetchLibraryPodcasts({int limit = 50}) async {
    try {
      final res = await sendCommand('music/podcasts/library_items', {
        'limit': limit,
      });
      if (res is List) {
        return res
            .map((p) => _parsePodcast(p as Map<String, dynamic>,
                defaultProvider: 'library'))
            .toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchLibraryPodcasts error: $e');
    }
    return [];
  }

  /// Ruft echte Alben aus der Music Assistant Bibliothek ab
  Future<List<Playlist>> fetchLibraryAlbums({int limit = 50}) async {
    try {
      final res = await sendCommand('music/albums/library_items', {
        'limit': limit,
      });
      if (res is List) {
        return res
            .map((a) => _parsePlaylist(a as Map<String, dynamic>,
                defaultType: 'album', defaultProvider: 'library'))
            .toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchLibraryAlbums error: $e');
    }
    return [];
  }

  /// Ruft echte Künstler aus der Music Assistant Bibliothek ab
  Future<List<Playlist>> fetchLibraryArtists({int limit = 50}) async {
    try {
      final res = await sendCommand('music/artists/library_items', {
        'limit': limit,
      });
      if (res is List) {
        return res
            .map((a) => _parsePlaylist(a as Map<String, dynamic>,
                defaultType: 'artist', defaultProvider: 'library'))
            .toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchLibraryArtists error: $e');
    }
    return [];
  }

  /// Ruft Audio Preview Stream URL ab (für lokale iPhone Wiedergabe)
  Future<String?> fetchTrackPreviewUrl(Track track) async {
    try {
      final provider = track.provider ?? 'library';
      final res = await sendCommand('music/tracks/preview', {
        'provider_instance_id_or_domain': provider,
        'item_id': track.id,
      });
      if (res is String && res.isNotEmpty) {
        if (res.startsWith('http')) return res;
        return '$_serverUrl$res';
      }
    } catch (e) {
      debugPrint('[MassApi] fetchTrackPreviewUrl error: $e');
    }
    return null;
  }

  /// Ruft echte Songtexte (LRC oder Plain) direkt vom Music Assistant Server ab
  Future<String?> fetchTrackLyrics(Track track) async {
    try {
      final trackArg = track.rawSource ?? {
        'item_id': track.id,
        'name': track.title,
        'artists': [
          {'name': track.artist}
        ],
        'album': {'name': track.album},
        'duration': track.durationSeconds,
        'uri': track.uri,
        'provider': track.provider ?? 'library',
        'media_type': 'track',
      };
      final res = await sendCommand('metadata/get_track_lyrics', {
        'track': trackArg,
      });
      if (res is String && res.trim().isNotEmpty) return res;
      if (res is Map) {
        final lrc = res['lrc_lyrics']?.toString() ?? res['lrcLyrics']?.toString();
        if (lrc != null && lrc.trim().isNotEmpty) return lrc;
        final plain = res['lyrics']?.toString();
        if (plain != null && plain.trim().isNotEmpty) return plain;
      }
    } catch (e) {
      debugPrint('[MassApi] fetchTrackLyrics error: $e');
    }
    return null;
  }

  /// Ruft echte Songs einer Playlist, eines Albums oder Podcasts ab
  Future<List<Track>> fetchPlaylistTracks(Playlist playlist) async {
    try {
      final String cmd;
      if (playlist.type == 'album') {
        cmd = 'music/albums/album_tracks';
      } else if (playlist.type == 'podcast') {
        cmd = 'music/podcasts/podcast_episodes';
      } else if (playlist.type == 'artist') {
        cmd = 'music/artists/artist_tracks';
      } else {
        cmd = 'music/playlists/playlist_tracks';
      }
      final provider = playlist.provider ?? 'library';
      final res = await sendCommand(cmd, {
        'item_id': playlist.id,
        'provider_instance_id_or_domain': provider,
      });
      if (res is List) {
        return res
            .map((t) => _parseTrack(t as Map<String, dynamic>,
                defaultProvider: provider))
            .toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchPlaylistTracks error: $e');
    }
    return [];
  }

  /// Echte Suche über Music Assistant Server (Spotify, Radios, YouTube, Bibliothek)
  Future<Map<String, dynamic>> searchMusic(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) {
      return {
        'tracks': <Track>[],
        'playlists': <Playlist>[],
        'albums': <Playlist>[],
        'podcasts': <Playlist>[],
      };
    }
    try {
      final res = await sendCommand('music/search', {
        'search_query': query,
        'limit': limit,
      });

      if (res is Map<String, dynamic>) {
        final tracksList = <Track>[];
        if (res['tracks'] is List) {
          for (final t in res['tracks'] as List) {
            tracksList.add(_parseTrack(t as Map<String, dynamic>,
                defaultProvider: 'spotify'));
          }
        }

        final playlistsList = <Playlist>[];
        if (res['playlists'] is List) {
          for (final p in res['playlists'] as List) {
            playlistsList.add(_parsePlaylist(p as Map<String, dynamic>,
                defaultType: 'playlist', defaultProvider: 'spotify'));
          }
        }

        final albumsList = <Playlist>[];
        if (res['albums'] is List) {
          for (final a in res['albums'] as List) {
            albumsList.add(_parsePlaylist(a as Map<String, dynamic>,
                defaultType: 'album', defaultProvider: 'spotify'));
          }
        }

        final podcastsList = <Playlist>[];
        if (res['podcasts'] is List) {
          for (final pod in res['podcasts'] as List) {
            podcastsList.add(_parsePodcast(pod as Map<String, dynamic>,
                defaultProvider: 'spotify'));
          }
        }

        return {
          'tracks': tracksList,
          'playlists': playlistsList,
          'albums': albumsList,
          'podcasts': podcastsList,
        };
      }
    } catch (e) {
      debugPrint('[MassApi] searchMusic error: $e');
    }
    return {
      'tracks': <Track>[],
      'playlists': <Playlist>[],
      'albums': <Playlist>[],
      'podcasts': <Playlist>[],
    };
  }

  Track parseTrack(Map<String, dynamic> map,
          {String defaultProvider = 'library'}) =>
      _parseTrack(map, defaultProvider: defaultProvider);

  Track _parseTrack(Map<String, dynamic> map,
      {String defaultProvider = 'library'}) {
    final id = map['item_id']?.toString() ?? '';
    final title = map['name']?.toString() ?? 'Unbekannter Titel';

    String artistName = 'Unbekannter Künstler';
    if (map['artists'] is List && (map['artists'] as List).isNotEmpty) {
      artistName = (map['artists'] as List)
          .map((a) => a['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
    } else if (map['podcast'] is Map) {
      final pod = map['podcast'] as Map<String, dynamic>;
      artistName =
          pod['name']?.toString() ?? pod['publisher']?.toString() ?? 'Podcast';
    }

    String albumName = '';
    String? imageUrl;
    if (map['album'] is Map) {
      final albumMap = map['album'] as Map<String, dynamic>;
      albumName = albumMap['name']?.toString() ?? '';
      if (albumMap['image'] is Map) {
        imageUrl = albumMap['image']['path']?.toString();
      }
    } else if (map['podcast'] is Map) {
      final pod = map['podcast'] as Map<String, dynamic>;
      albumName = pod['name']?.toString() ?? '';
      if (pod['metadata'] is Map) {
        final meta = pod['metadata'] as Map<String, dynamic>;
        if (meta['images'] is List && (meta['images'] as List).isNotEmpty) {
          imageUrl = (meta['images'] as List).first['path']?.toString();
        }
      }
    }

    String? previewUrl;
    if (imageUrl == null && map['metadata'] is Map) {
      final meta = map['metadata'] as Map<String, dynamic>;
      if (meta['images'] is List && (meta['images'] as List).isNotEmpty) {
        imageUrl = (meta['images'] as List).first['path']?.toString();
      }
      previewUrl = meta['preview']?.toString();
    }

    final duration = (map['duration'] as num?)?.toInt() ?? 180;
    final isLiked = map['favorite'] as bool? ?? false;
    final realUri = map['uri']?.toString() ??
        (id.isNotEmpty ? 'library://track/$id' : previewUrl);
    final provider = map['provider']?.toString() ?? defaultProvider;

    String? lrcLyrics;
    String? plainLyrics;
    if (map['metadata'] is Map) {
      final meta = map['metadata'] as Map<String, dynamic>;
      lrcLyrics = meta['lrc_lyrics']?.toString() ?? meta['lrcLyrics']?.toString();
      plainLyrics = meta['lyrics']?.toString();
    } else {
      lrcLyrics = map['lrc_lyrics']?.toString() ?? map['lrcLyrics']?.toString();
      plainLyrics = map['lyrics']?.toString();
    }

    return Track(
      id: id,
      title: title,
      artist: artistName,
      album: albumName,
      durationSeconds: duration,
      imageUrl: imageUrl,
      uri: realUri,
      previewUrl: previewUrl,
      provider: provider,
      isLiked: isLiked,
      lrcLyrics: lrcLyrics,
      plainLyrics: plainLyrics,
      rawSource: map,
    );
  }

  Playlist _parsePodcast(Map<String, dynamic> map,
      {String defaultProvider = 'library'}) {
    final id = map['item_id']?.toString() ?? map['uri']?.toString() ?? '';
    final name = map['name']?.toString() ?? '';
    final owner = map['publisher']?.toString() ?? 'Podcast';
    final tracksCount = (map['total_episodes'] as num?)?.toInt() ?? 0;

    String? imageUrl;
    final metadata = map['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['images'] is List) {
      final images = metadata['images'] as List;
      if (images.isNotEmpty) {
        imageUrl = images.first['path']?.toString();
      }
    }

    final provider = map['provider']?.toString() ?? defaultProvider;

    return Playlist(
      id: id,
      name: name.isNotEmpty ? name : 'Podcast $id',
      owner: owner,
      trackCount: tracksCount,
      imageUrl: imageUrl,
      type: 'podcast',
      provider: provider,
    );
  }

  Playlist _parsePlaylist(Map<String, dynamic> map,
      {String defaultType = 'playlist', String defaultProvider = 'library'}) {
    final id = map['item_id']?.toString() ?? map['uri']?.toString() ?? '';
    final name = map['name']?.toString() ?? '';

    String owner = map['owner']?.toString() ?? 'Music Assistant';
    if (map['artists'] is List && (map['artists'] as List).isNotEmpty) {
      owner = (map['artists'] as List)
          .map((a) => a['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join(', ');
    }

    final tracksCount = (map['track_count'] as num?)?.toInt() ??
        (map['total_tracks'] as num?)?.toInt() ??
        0;

    String? imageUrl;
    final metadata = map['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['images'] is List) {
      final images = metadata['images'] as List;
      if (images.isNotEmpty) {
        imageUrl = images.first['path']?.toString();
      }
    }

    final provider = map['provider']?.toString() ?? defaultProvider;

    return Playlist(
      id: id,
      name: name.isNotEmpty ? name : 'Item $id',
      owner: owner,
      trackCount: tracksCount,
      imageUrl: imageUrl,
      type: defaultType,
      provider: provider,
    );
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
        'media': mediaUri,
        'option': 'replace',
      });

  /// Nahtlose Übergabe der Wiedergabe (Queue Transfer von einem Speaker zu einem anderen)
  Future<void> transferQueue(String sourceQueueId, String targetQueueId,
          {bool autoPlay = true}) =>
      sendCommand('player_queues/transfer', {
        'source_queue_id': sourceQueueId,
        'target_queue_id': targetQueueId,
        'auto_play': autoPlay,
      });

  /// Synchronisiert einen Lautsprecher mit einem Master-Lautsprecher (Multiroom-Gruppe)
  Future<void> syncPlayer(String playerId, String targetPlayerId) =>
      sendCommand('players/cmd/sync', {
        'player_id': playerId,
        'target_player': targetPlayerId,
      });

  /// Hebt die Multiroom-Synchronisierung eines Lautsprechers auf
  Future<void> unsyncPlayer(String playerId) =>
      sendCommand('players/cmd/unsync', {
        'player_id': playerId,
      });

  /// Power an/aus für einen Lautsprecher
  Future<void> setPower(String playerId, bool power) =>
      sendCommand('players/cmd/power', {
        'player_id': playerId,
        'power': power,
      });

  /// Einschlaftimer / Sleep Timer setzen (in Sekunden)
  Future<void> setSleepTimer(String playerId, int durationSeconds) =>
      sendCommand('players/sleep_timer/set', {
        'player_id': playerId,
        'duration': durationSeconds,
      });

  /// Einschlaftimer löschen
  Future<void> clearSleepTimer(String playerId) =>
      sendCommand('players/sleep_timer/clear', {
        'player_id': playerId,
      });

  /// Sprachansage / Announcement auf Lautsprecher abspielen
  Future<void> playAnnouncement(String playerId, String message) =>
      sendCommand('players/cmd/play_announcement', {
        'player_id': playerId,
        'message': message,
      });

  /// Überblenden / Crossfade aktivieren/deaktivieren
  Future<void> setCrossfade(String queueId, bool enabled) =>
      sendCommand('player_queues/crossfade', {
        'queue_id': queueId,
        'crossfade_enabled': enabled,
      });

  /// Don't stop the music (Automatische ähnliche Titel bei Queue-Ende)
  Future<void> setDontStopTheMusic(String queueId, bool enabled) =>
      sendCommand('player_queues/dont_stop_the_music', {
        'queue_id': queueId,
        'dont_stop_the_music_enabled': enabled,
      });

  /// Warteschlangen-Titel live vom Server abrufen
  Future<List<Track>> fetchQueueItems(String queueId,
      {int limit = 50, int offset = 0}) async {
    try {
      final res = await sendCommand('player_queues/items', {
        'queue_id': queueId,
        'limit': limit,
        'offset': offset,
      });
      if (res is List) {
        return res.map((item) {
          final map = item as Map<String, dynamic>;
          final mediaItem =
              map['media_item'] as Map<String, dynamic>? ?? map;
          return _parseTrack(mediaItem, defaultProvider: 'library');
        }).toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchQueueItems error: $e');
    }
    return [];
  }

  /// Einzelnen Titel aus der Warteschlange löschen
  Future<void> deleteQueueItem(String queueId, dynamic itemIdOrIndex) =>
      sendCommand('player_queues/delete_item', {
        'queue_id': queueId,
        'item_id_or_index': itemIdOrIndex,
      });

  /// Zu einem bestimmten Queue-Index springen
  Future<void> playQueueIndex(String queueId, int index) =>
      sendCommand('player_queues/play_index', {
        'queue_id': queueId,
        'index': index,
      });

  /// Warteschlange leeren
  Future<void> clearQueue(String queueId) =>
      sendCommand('player_queues/clear', {
        'queue_id': queueId,
      });

  /// DSP Presets vom Server abrufen
  Future<List<Map<String, dynamic>>> fetchDspPresets() async {
    final res = await sendCommand('config/dsp_presets/get');
    if (res is List) {
      return res.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  /// DSP Konfiguration für einen bestimmten Player abrufen
  Future<Map<String, dynamic>?> fetchPlayerDspConfig(String playerId) async {
    final res =
        await sendCommand('config/players/dsp/get', {'player_id': playerId});
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return null;
  }

  /// DSP Konfiguration für einen bestimmten Player speichern
  Future<Map<String, dynamic>?> savePlayerDspConfig(
      String playerId, Map<String, dynamic> config) async {
    final res = await sendCommand('config/players/dsp/save', {
      'player_id': playerId,
      'config': config,
    });
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return null;
  }

  /// DSP Preset auf einen Player anwenden
  Future<Map<String, dynamic>?> applyDSPPreset(
      String playerId, String presetId) async {
    final res = await sendCommand('config/players/dsp/apply_preset', {
      'player_id': playerId,
      'preset_id': presetId,
    });
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return null;
  }

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

  /// Schöne Fallback-Daten, falls der Server beim Kaltstart offline ist
  List<Playlist> getFallbackPlaylists() {
    final sampleTracks = getFallbackTracks();
    return [
      Playlist(
        id: 'fallback_1',
        name: 'Deine Lieblingshits',
        owner: 'Music Assistant',
        trackCount: sampleTracks.length,
        imageUrl:
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
        tracks: sampleTracks,
      ),
      Playlist(
        id: 'fallback_2',
        name: 'Rock & Alternative',
        owner: 'Sonos Hits',
        trackCount: 8,
        imageUrl:
            'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
        tracks: sampleTracks.reversed.toList(),
      ),
      Playlist(
        id: 'fallback_3',
        name: 'Lo-Fi Chill & Beats',
        owner: 'Homelab Studio',
        trackCount: 6,
        imageUrl:
            'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
        tracks: sampleTracks,
      ),
    ];
  }

  List<Track> getFallbackTracks() {
    const defaultStream =
        'https://stream.rockantenne.hamburg/rockantenne-hamburg/stream/mp3';
    return [
      Track(
        id: 'fallback_t1',
        title: '1000 mal berührt',
        artist: 'Die Zipfelbuben',
        album: 'Jetzt wird es heiss',
        durationSeconds: 184,
        imageUrl:
            'https://i.scdn.co/image/ab67616d0000b273a258468313208cf24cacab81',
        uri: defaultStream,
      ),
      Track(
        id: 'fallback_t2',
        title: 'ROCK ANTENNE Hamburg',
        artist: 'Live Stream',
        album: 'Rock Antenne',
        durationSeconds: 300,
        imageUrl:
            'https://static.mytuner-radio.net/media/tvos_radios/383/rock-antenne-hamburg.81109563.jpg',
        uri: defaultStream,
      ),
      Track(
        id: 'fallback_t3',
        title: 'Midnight City',
        artist: 'M83',
        album: 'Hurry Up, We\'re Dreaming',
        durationSeconds: 243,
        imageUrl:
            'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
        uri: defaultStream,
      ),
      Track(
        id: 'fallback_t4',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        durationSeconds: 200,
        imageUrl:
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
        uri: defaultStream,
      ),
    ];
  }

  /// Ruft alle Empfehlungskategorien von Music Assistant ab
  Future<List<Map<String, dynamic>>> fetchRecommendationCategories() async {
    try {
      final res = await sendCommand('music/recommendations');
      if (res is List) {
        return res
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchRecommendationCategories error: $e');
    }
    return [];
  }

  /// Ruft die Inhalte (Titel, Alben, Künstler) einer bestimmten Empfehlungszeile ab
  Future<List<Map<String, dynamic>>> fetchRecommendationItems(
      String provider, String itemId) async {
    try {
      final res = await sendCommand('music/recommendations/items', {
        'provider': provider,
        'item_id': itemId,
      });
      if (res is List) {
        return res
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('[MassApi] fetchRecommendationItems ($itemId) error: $e');
    }
    return [];
  }

  /// Lädt die Top-Empfehlungsreihen inklusive aller Inhalte parallel
  Future<List<RecommendationRow>> fetchFullRecommendations() async {
    final categories = await fetchRecommendationCategories();
    if (categories.isEmpty) return [];

    final preferredOrder = [
      'lastfm_recommendations_similar_tracks',
      'most_played_tracks',
      'lastfm_recommendations_similar_artists',
      'forgotten_tracks',
      'recently_played',
      'lastfm_recommendations_chart_top_tracks',
      'lastfm_recommendations_chart_top_artists',
    ];

    String translateTitle(String id, String defaultTitle) {
      switch (id) {
        case 'lastfm_recommendations_similar_tracks':
          return 'Ähnlich wie deine Favoriten';
        case 'most_played_tracks':
          return 'Deine Allzeit-Favoriten';
        case 'lastfm_recommendations_similar_artists':
          return 'Künstler für deinen Geschmack';
        case 'forgotten_tracks':
          return 'Vergessene Schätze wiederentdecken';
        case 'recently_played':
          return 'Kürzlich gehört';
        case 'lastfm_recommendations_chart_top_tracks':
          return 'Globale Top-Hits';
        case 'lastfm_recommendations_chart_top_artists':
          return 'Beliebteste Künstler weltweit';
        default:
          return defaultTitle;
      }
    }

    String? translateSubtitle(String id, String? defaultSub) {
      switch (id) {
        case 'lastfm_recommendations_similar_tracks':
          return 'Basierend auf deinen meistgehörten Titeln';
        case 'most_played_tracks':
          return 'Deine meistgestreamten Tracks';
        case 'lastfm_recommendations_similar_artists':
          return 'Inspiriert von deinen Lieblings-Künstlern';
        case 'forgotten_tracks':
          return 'Lange nicht mehr gehört – Zeit für ein Wiederhören';
        case 'recently_played':
          return 'Dort weitermachen, wo du aufgehört hast';
        case 'lastfm_recommendations_chart_top_tracks':
          return 'Aktuelle weltweite Chartstürmer';
        default:
          return defaultSub;
      }
    }

    final selectedCategories = <Map<String, dynamic>>[];
    for (final prefId in preferredOrder) {
      final match = categories.firstWhere(
        (c) => c['item_id'] == prefId,
        orElse: () => const {},
      );
      if (match.isNotEmpty) {
        selectedCategories.add(match);
      }
    }

    final rowsWithItems = await Future.wait(
      selectedCategories.take(5).map((cat) async {
        final itemId = cat['item_id']?.toString() ?? '';
        final provider = cat['provider']?.toString() ?? '';
        final rawTitle = cat['name']?.toString() ?? 'Empfehlungen';
        final rawSub = cat['subtitle']?.toString();
        final icon = cat['icon']?.toString();

        final rawItems = await fetchRecommendationItems(provider, itemId);
        final items = rawItems
            .map((itemJson) => RecommendationItem.fromJson(itemJson))
            .where((item) => item.name.isNotEmpty)
            .toList();

        return RecommendationRow(
          id: itemId,
          provider: provider,
          title: translateTitle(itemId, rawTitle),
          subtitle: translateSubtitle(itemId, rawSub),
          icon: icon,
          items: items,
        );
      }),
    );

    return rowsWithItems.where((row) => row.items.isNotEmpty).toList();
  }

  void dispose() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    _eventsController.close();
    _authenticatedController.close();
  }
}
