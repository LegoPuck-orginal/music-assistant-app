class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String? imageUrl;
  final String? uri;
  bool isLiked;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    this.imageUrl,
    this.uri,
    this.isLiked = false,
  });

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'durationSeconds': durationSeconds,
      'imageUrl': imageUrl,
      'uri': uri,
      'isLiked': isLiked,
    };
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 180,
      imageUrl: json['imageUrl'] as String?,
      uri: json['uri'] as String?,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationSeconds,
    String? imageUrl,
    String? uri,
    bool? isLiked,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      imageUrl: imageUrl ?? this.imageUrl,
      uri: uri ?? this.uri,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
