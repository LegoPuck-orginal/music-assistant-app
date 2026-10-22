import 'track.dart';

class Playlist {
  final String id;
  final String name;
  final String owner;
  final int trackCount;
  final String? imageUrl;
  final String type; // playlist, album, artist, mix
  List<Track> tracks;

  Playlist({
    required this.id,
    required this.name,
    required this.owner,
    required this.trackCount,
    this.imageUrl,
    this.type = 'playlist',
    List<Track>? tracks,
  }) : tracks = tracks != null ? List<Track>.from(tracks) : <Track>[];

  Playlist copyWith({
    String? id,
    String? name,
    String? owner,
    int? trackCount,
    String? imageUrl,
    String? type,
    List<Track>? tracks,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      owner: owner ?? this.owner,
      trackCount: trackCount ?? this.trackCount,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      tracks: tracks != null ? List<Track>.from(tracks) : List<Track>.from(this.tracks),
    );
  }
}
