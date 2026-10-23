class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final String? imageUrl;
  final String? uri;
  final String? previewUrl;
  final String? provider;
  bool isLiked;
  final String? lrcLyrics;
  final String? plainLyrics;
  final Map<String, dynamic>? rawSource;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    this.imageUrl,
    this.uri,
    this.previewUrl,
    this.provider,
    this.isLiked = false,
    this.lrcLyrics,
    this.plainLyrics,
    this.rawSource,
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
      'previewUrl': previewUrl,
      'provider': provider,
      'isLiked': isLiked,
      'lrcLyrics': lrcLyrics,
      'plainLyrics': plainLyrics,
      'rawSource': rawSource,
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
      previewUrl: json['previewUrl'] as String?,
      provider: json['provider'] as String?,
      isLiked: json['isLiked'] as bool? ?? false,
      lrcLyrics: json['lrcLyrics'] as String?,
      plainLyrics: json['plainLyrics'] as String?,
      rawSource: json['rawSource'] as Map<String, dynamic>?,
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
    String? previewUrl,
    String? provider,
    bool? isLiked,
    String? lrcLyrics,
    String? plainLyrics,
    Map<String, dynamic>? rawSource,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      imageUrl: imageUrl ?? this.imageUrl,
      uri: uri ?? this.uri,
      previewUrl: previewUrl ?? this.previewUrl,
      provider: provider ?? this.provider,
      isLiked: isLiked ?? this.isLiked,
      lrcLyrics: lrcLyrics ?? this.lrcLyrics,
      plainLyrics: plainLyrics ?? this.plainLyrics,
      rawSource: rawSource ?? this.rawSource,
    );
  }
}
