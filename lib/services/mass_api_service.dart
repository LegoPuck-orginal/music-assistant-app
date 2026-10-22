import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/player_device.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class MassApiService {
  String _serverUrl = 'http://192.168.188.25:8095';
  WebSocketChannel? _channel;
  bool _isConnected = false;
  int _messageId = 1;
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;
  String get serverUrl => _serverUrl;

  void configure(String url) {
    _serverUrl = url.trim().endsWith('/')
        ? url.trim().substring(0, url.trim().length - 1)
        : url.trim();
    connectWebSocket();
  }

  /// Stellt die WebSocket-Verbindung zu Music Assistant her
  void connectWebSocket({Function()? onStateChanged}) {
    _channel?.sink.close();
    _isConnected = false;

    final wsUrl = _serverUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsUrl/ws');

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      onStateChanged?.call();

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
          onStateChanged?.call();
        },
        onDone: () {
          _isConnected = false;
          onStateChanged?.call();
          _scheduleReconnect(onStateChanged);
        },
        onError: (_) {
          _isConnected = false;
          onStateChanged?.call();
          _scheduleReconnect(onStateChanged);
        },
      );
    } catch (_) {
      _isConnected = false;
      onStateChanged?.call();
      _scheduleReconnect(onStateChanged);
    }
  }

  void _scheduleReconnect(Function()? onStateChanged) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connectWebSocket(onStateChanged: onStateChanged);
    });
  }

  void _handleMessage(dynamic rawMessage) {
    try {
      final json = jsonDecode(rawMessage.toString()) as Map<String, dynamic>;
      final messageId = json['message_id'];

      if (messageId != null && _pendingRequests.containsKey(messageId)) {
        final completer = _pendingRequests.remove(messageId);
        completer?.complete(json['result']);
      }
    } catch (_) {}
  }

  /// Sendet ein RPC-Kommando über den WebSocket an Music Assistant
  Future<dynamic> sendCommand(String cmd, [Map<String, dynamic>? args]) async {
    final id = _messageId++;
    final payload = {
      'message_id': id,
      'cmd': cmd,
      'args': ?args,
    };

    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(payload));
    } else {
      completer.complete(null);
    }

    // Timeout nach 3 Sekunden
    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
  }

  /// Prüft die HTTP-Erreichbarkeit von Music Assistant
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$_serverUrl/');
      final res = await http.get(uri).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Holt alle Player/Speaker aus Music Assistant
  Future<List<PlayerDevice>> fetchPlayers() async {
    try {
      final res = await sendCommand('players/all');
      if (res is List) {
        return res.map((p) {
          final map = p as Map<String, dynamic>;
          return PlayerDevice(
            id: map['player_id']?.toString() ?? 'unknown',
            name: map['name']?.toString() ?? 'Player',
            type: map['type']?.toString() ?? 'Speaker',
            volume: (map['volume_level'] as num? ?? 40).toInt(),
            isMuted: map['powered'] == false,
            state: map['state']?.toString() ?? 'idle',
          );
        }).toList();
      }
    } catch (_) {}

    // Fallback Mock-Player falls Server noch initialisiert oder offline
    return [
      PlayerDevice(id: 'sonos_wohnzimmer', name: 'Wohnzimmer (Sonos Era 300)', type: 'Sonos', volume: 45, isSelected: true),
      PlayerDevice(id: 'airplay_kueche', name: 'Küche (HomePod Mini)', type: 'AirPlay', volume: 30),
      PlayerDevice(id: 'chromecast_office', name: 'Büro (Studio Speaker)', type: 'Chromecast', volume: 55),
      PlayerDevice(id: 'phone_local', name: 'Dieses iPhone (Lautsprecher)', type: 'Local', volume: 70),
    ];
  }

  /// Wiedergabe auf einem Player steuern
  Future<void> playerPlay(String playerId) async {
    await sendCommand('players/cmd/play', {'player_id': playerId});
  }

  Future<void> playerPause(String playerId) async {
    await sendCommand('players/cmd/pause', {'player_id': playerId});
  }

  Future<void> playerNext(String playerId) async {
    await sendCommand('players/cmd/next', {'player_id': playerId});
  }

  Future<void> playerPrevious(String playerId) async {
    await sendCommand('players/cmd/previous', {'player_id': playerId});
  }

  Future<void> playerVolume(String playerId, int volume) async {
    await sendCommand('players/cmd/volume_set', {'player_id': playerId, 'volume_level': volume});
  }

  /// Initialer Demo/Offline-Katalog mit echter Spotify-Struktur
  List<Playlist> getSamplePlaylists() {
    return [
      Playlist(
        id: 'top_hits',
        name: 'Today\'s Top Hits',
        owner: 'Music Assistant Curated',
        trackCount: 50,
        imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
        tracks: [
          Track(id: 't1', title: 'Starboy', artist: 'The Weeknd, Daft Punk', album: 'Starboy', durationSeconds: 230, imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300&q=80'),
          Track(id: 't2', title: 'Blinding Lights', artist: 'The Weeknd', album: 'After Hours', durationSeconds: 200, imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&q=80'),
          Track(id: 't3', title: 'Midnight City', artist: 'M83', album: 'Hurry Up, We\'re Dreaming', durationSeconds: 243, imageUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&q=80'),
          Track(id: 't4', title: 'Get Lucky', artist: 'Daft Punk, Pharrell Williams', album: 'Random Access Memories', durationSeconds: 248, imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300&q=80'),
          Track(id: 't5', title: 'Stargazing', artist: 'Travis Scott', album: 'ASTROWORLD', durationSeconds: 271, imageUrl: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=300&q=80'),
        ],
      ),
      Playlist(
        id: 'electronic_focus',
        name: 'Deep Techno & Focus',
        owner: 'Dein Server',
        trackCount: 38,
        imageUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&q=80',
        tracks: [
          Track(id: 't6', title: 'Solaris', artist: 'Kiasmos', album: 'Blurred', durationSeconds: 312, imageUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=300&q=80'),
          Track(id: 't7', title: 'Opus', artist: 'Eric Prydz', album: 'Opus', durationSeconds: 558, imageUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300&q=80'),
          Track(id: 't8', title: 'Glue', artist: 'Bicep', album: 'Bicep', durationSeconds: 269, imageUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&q=80'),
        ],
      ),
      Playlist(
        id: 'rock_classics',
        name: 'Rock Legends Classics',
        owner: 'Music Assistant FLAC',
        trackCount: 42,
        imageUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
        tracks: [
          Track(id: 't9', title: 'Sultans of Swing', artist: 'Dire Straits', album: 'Dire Straits', durationSeconds: 348, imageUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=300&q=80'),
          Track(id: 't10', title: 'Comfortably Numb', artist: 'Pink Floyd', album: 'The Wall', durationSeconds: 382, imageUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&q=80'),
        ],
      ),
      Playlist(
        id: 'chill_beats',
        name: 'Lofi & Ambient Chill',
        owner: 'Dein Server',
        trackCount: 65,
        imageUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
        tracks: [
          Track(id: 't11', title: 'Snowman', artist: 'Wun Two', album: 'Rio', durationSeconds: 142, imageUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=300&q=80'),
        ],
      ),
    ];
  }

  void dispose() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
  }
}
