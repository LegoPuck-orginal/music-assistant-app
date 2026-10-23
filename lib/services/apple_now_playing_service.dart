import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../providers/music_provider.dart';

/// Steuert die native Apple MediaPlayer Integration (`MPNowPlayingInfoCenter` & `MPRemoteCommandCenter`).
/// Aktiviert automatisch:
/// - Die echte iOS Dynamic Island mit animierten Audio-Wellen und Album-Cover
/// - Die native Apple Watch "Jetzt läuft"-Anzeige mit Lautstärke über die Digital Crown
/// - Den nativen iOS Sperrbildschirm-Player und das Kontrollzentrum
/// - Remote-Befehle von AirPods und Bluetooth-Kopfhörern
class AppleNowPlayingService {
  static const MethodChannel _channel =
      MethodChannel('de.timm.musicAssistantApp/apple_now_playing');

  static final AppleNowPlayingService instance =
      AppleNowPlayingService._internal();
  factory AppleNowPlayingService() => instance;
  AppleNowPlayingService._internal();

  MusicProvider? _provider;
  bool _initialized = false;
  String _lastSignature = '';

  /// Initialisiert den Listener für Apple Remote Commands (Apple Watch Crown, AirPods, Sperrbildschirm)
  void initialize(MusicProvider provider) {
    _provider = provider;
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      final p = _provider;
      if (p == null) return;

      if (call.method == 'onRemoteCommand') {
        final args = call.arguments as Map<dynamic, dynamic>? ?? {};
        final action = args['action'] as String?;

        switch (action) {
          case 'play':
            if (!p.isPlaying) {
              p.togglePlayPause();
            }
            break;
          case 'pause':
            if (p.isPlaying) {
              p.togglePlayPause();
            }
            break;
          case 'togglePlayPause':
            p.togglePlayPause();
            break;
          case 'next':
            p.next();
            break;
          case 'previous':
            p.previous();
            break;
          case 'seek':
            final posSec = (args['positionSeconds'] as num?)?.toDouble() ?? 0.0;
            p.seekTo(Duration(milliseconds: (posSec * 1000).round()));
            break;
          case 'skipForward':
            final interval = (args['interval'] as num?)?.toInt() ?? 15;
            final current = p.currentPosition;
            p.seekTo(current + Duration(seconds: interval));
            break;
          case 'skipBackward':
            final interval = (args['interval'] as num?)?.toInt() ?? 15;
            final current = p.currentPosition;
            final target = current - Duration(seconds: interval);
            p.seekTo(target < Duration.zero ? Duration.zero : target);
            break;
        }
      }
    });
  }

  /// Synchronisiert den aktuellen Track & Status mit Apple MediaPlayer
  Future<void> sync(MusicProvider provider) async {
    _provider = provider;
    try {
      final track = provider.currentTrack;
      final isPlaying = provider.isPlaying;

      if (track == null && !isPlaying) {
        if (_lastSignature.isNotEmpty) {
          _lastSignature = '';
          await _channel.invokeMethod('clearNowPlaying');
        }
        return;
      }

      final posSeconds = provider.currentPosition.inMilliseconds / 1000.0;
      final durSeconds = provider.totalDuration.inMilliseconds / 1000.0;
      final title = track?.title ?? 'Music Assistant';
      final artist = track?.artist ?? 'Unbekannter Interpret';
      final album = track?.album ?? 'Music Assistant';
      final artUrl = track?.imageUrl ?? '';

      final signature =
          '$title-$artist-$album-$isPlaying-${durSeconds.toInt()}';
      if (signature != _lastSignature) {
        _lastSignature = signature;
      }

      await _channel.invokeMethod('updateNowPlaying', {
        'title': title,
        'artist': artist,
        'album': album,
        'durationSeconds': durSeconds,
        'positionSeconds': posSeconds,
        'isPlaying': isPlaying,
        'artworkUrl': artUrl,
      });
    } catch (e) {
      debugPrint('[AppleNowPlayingService] sync error: $e');
    }
  }

  /// Leert die Now-Playing-Anzeige
  Future<void> clear() async {
    try {
      _lastSignature = '';
      await _channel.invokeMethod('clearNowPlaying');
    } catch (_) {}
  }
}
