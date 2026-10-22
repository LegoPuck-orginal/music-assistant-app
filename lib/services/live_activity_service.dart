import 'dart:async';
import 'package:flutter/services.dart';
import '../providers/music_provider.dart';

/// Verwaltet die echte native Apple Dynamic Island und iOS Live Activities
class LiveActivityService {
  static const MethodChannel _channel =
      MethodChannel('de.timm.musicAssistantApp/live_activity');

  static final LiveActivityService instance = LiveActivityService._internal();
  factory LiveActivityService() => instance;
  LiveActivityService._internal();

  String _lastSignature = '';

  /// Synchronisiert den aktuellen Wiedergabestatus mit der echten Apple Dynamic Island
  Future<void> sync(MusicProvider provider) async {
    try {
      final track = provider.currentTrack;
      final isPlaying = provider.isPlaying;
      final isDjActive = provider.isDjActive;
      final isDjSpeaking = provider.isDjSpeaking;
      final speakerName = provider.activePlayer?.name ?? 'Sonos';
      final vibeTitle = provider.currentDjVibe.title;
      final speechText = provider.djSpeechText;

      // Wenn keine Wiedergabe und kein DJ aktiv ist, Live Activity beenden
      if (track == null && !isPlaying && !isDjActive && !isDjSpeaking) {
        if (_lastSignature.isNotEmpty) {
          _lastSignature = '';
          await _channel.invokeMethod('endActivity');
        }
        return;
      }

      final signature =
          '${track?.id}_${isPlaying}_${speakerName}_${vibeTitle}_${isDjSpeaking}_$speechText';
      if (signature == _lastSignature) {
        return;
      }
      _lastSignature = signature;

      final data = {
        'trackTitle': track?.title ?? 'Music Assistant',
        'artist': track?.artist ?? 'Spotify',
        'albumArtUrl': track?.imageUrl ?? '',
        'isPlaying': isPlaying,
        'speakerName': speakerName,
        'djVibe': vibeTitle,
        'isDjSpeaking': isDjSpeaking,
        'djSpeechText': speechText,
      };

      await _channel.invokeMethod('startOrUpdate', data);
    } catch (_) {
      // PlatformException auf Simulatoren / älteren iOS Versionen ignorieren
    }
  }

  /// Beendet die Live Activity auf der Dynamic Island
  Future<void> endActivity() async {
    try {
      _lastSignature = '';
      await _channel.invokeMethod('endActivity');
    } catch (_) {}
  }
}
