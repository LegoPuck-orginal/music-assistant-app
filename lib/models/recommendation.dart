import 'track.dart';
import 'playlist.dart';

class RecommendationItem {
  final String id;
  final String name;
  final String mediaType; // 'track', 'artist', 'album', 'playlist'
  final String subtitle;
  final String? imageUrl;
  final String uri;
  final int durationSeconds;
  final String? audioPreviewUrl;
  final Map<String, dynamic> raw;

  const RecommendationItem({
    required this.id,
    required this.name,
    required this.mediaType,
    required this.subtitle,
    this.imageUrl,
    required this.uri,
    this.durationSeconds = 180,
    this.audioPreviewUrl,
    this.raw = const {},
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type']?.toString() ?? 'track';
    final name = json['name']?.toString() ?? 'Unbekannt';

    // Extract subtitle / artist
    String subtitle = '';
    if (json['artists'] != null && (json['artists'] as List).isNotEmpty) {
      final firstArtist = json['artists'][0];
      subtitle = firstArtist['name']?.toString() ?? '';
    } else if (json['artist'] != null) {
      subtitle = json['artist'].toString();
    } else if (json['album'] != null && json['album'] is Map) {
      subtitle = json['album']['name']?.toString() ?? '';
    } else if (mediaType == 'artist') {
      subtitle = 'Künstler';
    }

    // Extract image url
    String? imageUrl;
    if (json['metadata'] != null && json['metadata'] is Map) {
      final meta = json['metadata'] as Map;
      if (meta['images'] != null && (meta['images'] as List).isNotEmpty) {
        final img = meta['images'][0];
        imageUrl = img['path']?.toString();
      }
    }
    if (imageUrl == null && json['image'] != null && json['image'] is Map) {
      imageUrl = json['image']['path']?.toString();
    }
    if (imageUrl == null && json['album'] != null && json['album'] is Map) {
      final alb = json['album'] as Map;
      if (alb['image'] != null && alb['image'] is Map) {
        imageUrl = alb['image']['path']?.toString();
      }
    }

    // Extract duration
    final durNum = json['duration'] as num?;
    final dur = durNum?.round() ?? 180;

    // Extract preview
    String? preview;
    if (json['metadata'] != null && json['metadata'] is Map) {
      preview = json['metadata']['preview']?.toString();
    }

    return RecommendationItem(
      id: json['item_id']?.toString() ?? '',
      name: name,
      mediaType: mediaType,
      subtitle: subtitle,
      imageUrl: imageUrl,
      uri: json['uri']?.toString() ?? '',
      durationSeconds: dur,
      audioPreviewUrl: preview,
      raw: json,
    );
  }

  Track toTrack() {
    final prov = raw['provider']?.toString() ?? 'library';
    final effectiveUri = uri.isNotEmpty
        ? uri
        : (id.isNotEmpty ? '$prov://track/$id' : null);
    return Track(
      id: id,
      title: name,
      artist: subtitle.isNotEmpty ? subtitle : 'Unbekannter Künstler',
      album: raw['album'] != null && raw['album'] is Map
          ? (raw['album']['name']?.toString() ?? '')
          : '',
      durationSeconds: durationSeconds,
      imageUrl: imageUrl,
      uri: effectiveUri,
      provider: prov,
      rawSource: raw,
    );
  }

  Playlist toPlaylist() {
    return Playlist(
      id: id,
      name: name,
      owner: subtitle,
      trackCount: durationSeconds > 0 ? durationSeconds : 10,
      imageUrl: imageUrl,
      type: mediaType == 'artist' ? 'artist' : 'album',
    );
  }
}

class RecommendationRow {
  final String id;
  final String provider;
  final String title;
  final String? subtitle;
  final String? icon;
  final List<RecommendationItem> items;

  const RecommendationRow({
    required this.id,
    required this.provider,
    required this.title,
    this.subtitle,
    this.icon,
    this.items = const [],
  });

  RecommendationRow copyWith({
    List<RecommendationItem>? items,
  }) {
    return RecommendationRow(
      id: id,
      provider: provider,
      title: title,
      subtitle: subtitle,
      icon: icon,
      items: items ?? this.items,
    );
  }
}
