import 'track.dart';

/// Repräsentiert einen lokal auf dem Gerät gespeicherten Musiktitel
class DownloadedTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String? imageUrl;
  final String localFilePath;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final String? provider;

  DownloadedTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    this.imageUrl,
    required this.localFilePath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    this.provider,
  });

  /// Konvertiert diesen heruntergeladenen Titel in ein reguläres Track-Objekt mit lokaler Dateiquelle
  Track toTrack() {
    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      durationSeconds: durationSeconds,
      imageUrl: imageUrl,
      uri: localFilePath,
      provider: provider ?? 'offline',
    );
  }

  factory DownloadedTrack.fromTrack({
    required Track track,
    required String localFilePath,
    required int fileSizeBytes,
  }) {
    return DownloadedTrack(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationSeconds: track.durationSeconds,
      imageUrl: track.imageUrl,
      localFilePath: localFilePath,
      fileSizeBytes: fileSizeBytes,
      downloadedAt: DateTime.now(),
      provider: track.provider,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationSeconds': durationSeconds,
      'imageUrl': imageUrl,
      'localFilePath': localFilePath,
      'fileSizeBytes': fileSizeBytes,
      'downloadedAt': downloadedAt.toIso8601String(),
      'provider': provider,
    };
  }

  factory DownloadedTrack.fromJson(Map<String, dynamic> json) {
    return DownloadedTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 180,
      imageUrl: json['imageUrl'] as String?,
      localFilePath: json['localFilePath'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.tryParse(json['downloadedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      provider: json['provider'] as String?,
    );
  }

  String get formattedSize {
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
