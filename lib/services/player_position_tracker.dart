import 'dart:math' as math;

/// Single source of truth for "what elapsed-time is each queue at, right now".
///
/// Ported from the official Music Assistant Kotlin Multiplatform client (PlayerPositionTracker.kt).
/// Anchors are written when WebSocket events (`queue_time_updated`, `queue_updated`,
/// `player_updated`) arrive from the server.
/// Continuous smooth wall-clock interpolation computes the exact sub-second playhead
/// position without timer jitter or drift.
class PlayerPositionAnchor {
  final double elapsedSec;
  final int wallMs;
  final bool isPlaying;
  final double? durationSec;
  final double speed;

  const PlayerPositionAnchor({
    required this.elapsedSec,
    required this.wallMs,
    required this.isPlaying,
    this.durationSec,
    this.speed = 1.0,
  });

  /// Position right now: anchor + speed-scaled wall-time since anchor (capped at duration).
  double effectiveNow() {
    if (!isPlaying) return elapsedSec;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final deltaSec = math.max(0.0, (nowMs - wallMs) / 1000.0) * speed;
    final advanced = elapsedSec + deltaSec;
    if (durationSec != null && durationSec! > 0) {
      return math.min(advanced, durationSec!);
    }
    return advanced;
  }
}

class PlayerPositionTracker {
  final Map<String, PlayerPositionAnchor> _anchors = {};

  /// Server-anchored update.
  void setAnchor({
    required String queueId,
    required double elapsedSec,
    bool? isPlaying,
    double? durationSec,
    double? speed,
  }) {
    final current = _anchors[queueId];
    _anchors[queueId] = PlayerPositionAnchor(
      elapsedSec: math.max(0.0, elapsedSec),
      wallMs: DateTime.now().millisecondsSinceEpoch,
      isPlaying: isPlaying ?? current?.isPlaying ?? false,
      durationSec: durationSec ?? current?.durationSec,
      speed: speed ?? current?.speed ?? 1.0,
    );
  }

  /// Play/pause transition. Snapshots the current interpolated position
  /// so pause/resume doesn't jump forward or backward.
  void setPlaying(String queueId, bool isPlaying) {
    final current = _anchors[queueId];
    if (current == null) {
      _anchors[queueId] = PlayerPositionAnchor(
        elapsedSec: 0.0,
        wallMs: DateTime.now().millisecondsSinceEpoch,
        isPlaying: isPlaying,
      );
      return;
    }
    final snapshotted = current.effectiveNow();
    _anchors[queueId] = PlayerPositionAnchor(
      elapsedSec: snapshotted,
      wallMs: DateTime.now().millisecondsSinceEpoch,
      isPlaying: isPlaying,
      durationSec: current.durationSec,
      speed: current.speed,
    );
  }

  /// Returns current position in seconds as a double.
  double getPosition(String queueId) {
    final anchor = _anchors[queueId];
    if (anchor == null) return 0.0;
    return anchor.effectiveNow();
  }

  /// Returns current position as a Duration.
  Duration getPositionDuration(String queueId) {
    final sec = getPosition(queueId);
    return Duration(milliseconds: (sec * 1000).round());
  }

  bool hasAnchor(String queueId) => _anchors.containsKey(queueId);

  void clear(String queueId) => _anchors.remove(queueId);

  void clearAll() => _anchors.clear();
}
