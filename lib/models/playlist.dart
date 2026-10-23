import 'track.dart';

class Playlist {
  final String id;
  final String name;
  final String owner;
  int trackCount;
  final String? imageUrl;
  final String type; // playlist, album, artist, mix
  final String? provider;
  List<Track> tracks;

  Playlist({
    required this.id,
    required this.name,
    required this.owner,
    required this.trackCount,
    this.imageUrl,
    this.type = 'playlist',
    this.provider,
    List<Track>? tracks,
  }) : tracks = tracks != null ? List<Track>.from(tracks) : <Track>[];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner': owner,
      'trackCount': trackCount,
      'imageUrl': imageUrl,
      'type': type,
      'provider': provider,
      'tracks': tracks.map((t) => t.toJson()).toList(),
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'] as List?;
    final parsedTracks = rawTracks != null
        ? rawTracks
            .whereType<Map>()
            .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <Track>[];
    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Playlist',
      owner: json['owner'] as String? ?? 'Du',
      trackCount: (json['trackCount'] as num?)?.toInt() ?? parsedTracks.length,
      imageUrl: json['imageUrl'] as String?,
      type: json['type'] as String? ?? 'playlist',
      provider: json['provider'] as String?,
      tracks: parsedTracks,
    );
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? owner,
    int? trackCount,
    String? imageUrl,
    String? type,
    String? provider,
    List<Track>? tracks,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      owner: owner ?? this.owner,
      trackCount: trackCount ?? this.trackCount,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      provider: provider ?? this.provider,
      tracks: tracks != null ? List<Track>.from(tracks) : List<Track>.from(this.tracks),
    );
  }
}
