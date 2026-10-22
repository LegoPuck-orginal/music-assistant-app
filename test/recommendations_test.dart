import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/recommendation.dart';

void main() {
  group('Recommendation Models & Parsing Tests', () {
    test('RecommendationItem parses track media type correctly', () {
      final json = {
        'item_id': 'spotify://track/12345',
        'provider': 'spotify',
        'name': 'Moshpit',
        'media_type': 'track',
        'duration': 195,
        'artists': [
          {'name': 'Yu'}
        ],
        'album': {
          'name': 'Yu Album',
          'image': {'path': 'https://image.path/cover.jpg'}
        },
        'uri': 'spotify:track:12345',
      };

      final item = RecommendationItem.fromJson(json);

      expect(item.id, equals('spotify://track/12345'));
      expect(item.name, equals('Moshpit'));
      expect(item.mediaType, equals('track'));
      expect(item.subtitle, equals('Yu'));
      expect(item.durationSeconds, equals(195));
      expect(item.imageUrl, equals('https://image.path/cover.jpg'));
      expect(item.uri, equals('spotify:track:12345'));

      final track = item.toTrack();
      expect(track.id, equals(item.id));
      expect(track.title, equals('Moshpit'));
      expect(track.artist, equals('Yu'));
      expect(track.album, equals('Yu Album'));
      expect(track.durationSeconds, equals(195));
      expect(track.imageUrl, equals('https://image.path/cover.jpg'));
      expect(track.uri, equals('spotify:track:12345'));
      expect(track.provider, equals('spotify'));
    });

    test('RecommendationItem parses artist media type correctly', () {
      final json = {
        'item_id': 'artist_99',
        'provider': 'lastfm',
        'name': 'Guns N\' Roses',
        'media_type': 'artist',
        'metadata': {
          'images': [
            {'path': 'https://image.path/gnr.jpg'}
          ]
        },
      };

      final item = RecommendationItem.fromJson(json);

      expect(item.id, equals('artist_99'));
      expect(item.name, equals('Guns N\' Roses'));
      expect(item.mediaType, equals('artist'));
      expect(item.imageUrl, equals('https://image.path/gnr.jpg'));

      final playlist = item.toPlaylist();
      expect(playlist.id, equals('artist_99'));
      expect(playlist.name, equals('Guns N\' Roses'));
      expect(playlist.type, equals('artist'));
    });

    test('RecommendationRow parses row and maps German titles', () {
      final rowJson = {
        'item_id': 'most_played_tracks',
        'provider': 'builtin',
        'name': 'Most played tracks',
        'media_type': 'folder',
      };

      final items = [
        RecommendationItem.fromJson({
          'item_id': 'tr_1',
          'provider': 'spotify',
          'name': 'Track One',
          'media_type': 'track',
          'artists': [{'name': 'Artist A'}],
        }),
      ];

      final row = RecommendationRow(
        id: rowJson['item_id'] as String,
        provider: rowJson['provider'] as String,
        title: 'Deine Allzeit-Favoriten',
        subtitle: 'Am häufigsten von dir gespielt',
        items: items,
      );

      expect(row.id, equals('most_played_tracks'));
      expect(row.title, equals('Deine Allzeit-Favoriten'));
      expect(row.subtitle, equals('Am häufigsten von dir gespielt'));
      expect(row.items.length, equals(1));
      expect(row.items.first.name, equals('Track One'));
    });
  });
}
