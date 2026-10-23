import 'dart:async';
import 'package:flutter/services.dart';
import '../providers/music_provider.dart';

/// Verwaltet die Synchronisierung und Fernsteuerung zwischen iOS und der Apple Watch
class WatchService {
  static const MethodChannel _channel =
      MethodChannel('de.timm.musicAssistantApp/watch');

  static final WatchService instance = WatchService._internal();
  factory WatchService() => instance;
  WatchService._internal();

  MusicProvider? _provider;
  bool _isInitialized = false;
  String _lastSyncedSignature = '';
  String _lastNonVolumeSignature = '';
  Timer? _watchDebounceTimer;
  DateTime _lastWatchSyncTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Registriert den MusicProvider und initialisiert den MethodChannel-Handler
  void init(MusicProvider provider) {
    _provider = provider;
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Verarbeitet Befehle, die von der Apple Watch über WatchConnectivity eingehen
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final prov = _provider;
    if (prov == null) return null;

    if (call.method == 'onWatchAction') {
      final args = call.arguments is Map ? (call.arguments as Map) : {};
      final action = args['action'] as String?;

      switch (action) {
        case 'togglePlayPause':
          await prov.togglePlayPause();
          break;

        case 'next':
          await prov.next();
          break;

        case 'previous':
          await prov.previous();
          break;

        case 'setVolume':
          final vol = (args['volume'] as num?)?.round();
          if (vol != null) {
            await prov.setVolume(vol);
          }
          break;

        case 'selectSpeaker':
          final speakerId = args['speakerId'] as String?;
          if (speakerId != null) {
            final player = prov.players
                .where((p) => p.id == speakerId)
                .firstOrNull;
            if (player != null) {
              await prov.setActivePlayer(player);
            }
          }
          break;

        case 'switchDjVibe':
          await prov.switchDjVibe();
          break;

        case 'triggerDjSpeech':
          await prov.switchDjVibe(category: prov.currentDjVibe.category);
          break;
      }
    }
    return null;
  }

  /// Sendet den aktuellen Wiedergabestatus an die Apple Watch (mit Signatur-Cache gegen Übertragungs-Spam)
  Future<void> syncState(MusicProvider provider) async {
    try {
      final currentTrack = provider.currentTrack;
      final selectedPlayer = provider.activePlayer;
      final isPlaying = provider.isPlaying;
      final volume = selectedPlayer?.volume ?? 50;
      final vibeTitle = provider.currentDjVibe.title;

      final nonVolumeSignature =
          '${currentTrack?.uri}_${isPlaying}_${selectedPlayer?.id}_$vibeTitle';
      final fullSignature = '${nonVolumeSignature}_$volume';

      if (fullSignature == _lastSyncedSignature) {
        return;
      }

      // Wenn sich nur die Lautstärke geändert hat, drosseln wir die Übertragung an die Watch auf max. 3x/Sekunde
      final isOnlyVolumeChange =
          (nonVolumeSignature == _lastNonVolumeSignature && _lastSyncedSignature.isNotEmpty);
      _lastNonVolumeSignature = nonVolumeSignature;
      _lastSyncedSignature = fullSignature;

      if (isOnlyVolumeChange) {
        final elapsed = DateTime.now().difference(_lastWatchSyncTime);
        const minInterval = Duration(milliseconds: 350);
        if (elapsed < minInterval) {
          _watchDebounceTimer?.cancel();
          _watchDebounceTimer = Timer(minInterval - elapsed, () {
            _dispatchSync(provider);
          });
          return;
        }
      }

      _watchDebounceTimer?.cancel();
      await _dispatchSync(provider);
    } catch (_) {
      // PlatformException auf Simulatoren oder Nicht-iOS Umgebungen ignorieren
    }
  }

  Future<void> _dispatchSync(MusicProvider provider) async {
    try {
      _lastWatchSyncTime = DateTime.now();
      final currentTrack = provider.currentTrack;
      final selectedPlayer = provider.activePlayer;
      final isPlaying = provider.isPlaying;
      final volume = selectedPlayer?.volume ?? 50;
      final vibeTitle = provider.currentDjVibe.title;

      final speakersData = provider.players.map((p) => {
        'id': p.id,
        'name': p.name,
        'volume': p.volume,
        'isAvailable': p.isAvailable,
      }).toList();

      final state = {
        'trackTitle': currentTrack?.title ?? 'Keine Wiedergabe',
        'artist': currentTrack?.artist ?? 'Music Assistant',
        'album': currentTrack?.album ?? '',
        'imageUrl': currentTrack?.imageUrl ?? '',
        'isPlaying': isPlaying,
        'volume': volume,
        'activeSpeakerName': selectedPlayer?.name ?? 'Sonos',
        'activeSpeakerId': selectedPlayer?.id ?? '',
        'speakers': speakersData,
        'currentDjVibe': vibeTitle,
        'isDjActive': provider.isDjActive,
      };

      await _channel.invokeMethod('syncState', state);
    } catch (_) {
      // PlatformException auf Simulatoren oder Nicht-iOS Umgebungen ignorieren
    }
  }

  /// Prüft, ob WatchConnectivity vom Gerät unterstützt wird
  Future<bool> isSupported() async {
    try {
      final res = await _channel.invokeMethod<bool>('isSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prüft, ob eine Apple Watch gekoppelt ist
  Future<bool> isPaired() async {
    try {
      final res = await _channel.invokeMethod<bool>('isPaired');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
