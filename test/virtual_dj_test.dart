import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/track.dart';
import 'package:music_assistant_app/models/user_profile.dart';
import 'package:music_assistant_app/models/virtual_dj_vibe.dart';
import 'package:music_assistant_app/services/smart_dj_curator.dart';
import 'package:music_assistant_app/widgets/profile_avatar.dart';

void main() {
  group('Profile & Avatar Tests', () {
    test('UserProfile copyWith updates avatarUrl and displayName correctly', () {
      const user = UserProfile(
        userId: 'user_123',
        username: 'alex',
        displayName: 'Alex',
        role: 'admin',
      );

      final updated = user.copyWith(
        displayName: 'Alex D.',
        avatarUrl: 'preset:dj_neon',
      );

      expect(updated.userId, equals('user_123'));
      expect(updated.username, equals('alex'));
      expect(updated.displayName, equals('Alex D.'));
      expect(updated.avatarUrl, equals('preset:dj_neon'));
      expect(updated.effectiveName, equals('Alex D.'));
    });

    test('ProfileAvatar contains curated preset collection', () {
      expect(ProfileAvatar.presets.isNotEmpty, isTrue);
      expect(ProfileAvatar.presets.containsKey('preset:dj_neon'), isTrue);
      expect(ProfileAvatar.presets.containsKey('preset:vinyl'), isTrue);
      expect(ProfileAvatar.presets.containsKey('preset:headphones'), isTrue);
      expect(ProfileAvatar.presets.containsKey('preset:rocker'), isTrue);
    });
  });

  group('Virtual DJ & Dynamic Island Tests', () {
    test('DjVibe provides all essential Spotify-style vibes with prompt templates', () {
      final vibes = DjVibe.allVibes;
      expect(vibes.length, greaterThanOrEqualTo(5));

      final allTime = vibes.firstWhere(
        (v) => v.category == DjVibeCategory.allTimeFavorites,
      );
      expect(allTime.title, contains('Allzeit-Favoriten'));
      expect(allTime.introPrompt, contains('{user}'));

      final rock = vibes.firstWhere(
        (v) => v.category == DjVibeCategory.rockClassics,
      );
      expect(rock.title, contains('Rock'));
      expect(rock.introPrompt, contains('{user}'));
    });
  });

  group('SmartDjCurator Music Selection Engine Tests', () {
    test('isEligibleMusicTrack excludes audiobooks, radio streams, and ultra-short skits', () {
      final audiobook1 = Track(
        id: 'ab1',
        title: 'Folge 216: Das Geheimnis im Jagdschloss (Teil 1)',
        artist: 'Die drei ???',
        album: 'Die drei ???',
        durationSeconds: 240,
      );
      final audiobook2 = Track(
        id: 'ab2',
        title: 'Kapitel 14: Die Falle',
        artist: 'TKKG',
        album: 'Hörspiel Edition',
        durationSeconds: 180,
      );
      final radioStream = Track(
        id: 'rad1',
        title: 'ROCK ANTENNE Hamburg',
        artist: 'Live Stream',
        album: 'Live Radio',
        durationSeconds: 300,
        uri: 'https://stream.rockantenne.hamburg/stream.mp3',
      );
      final skit = Track(
        id: 'sk1',
        title: 'Intro (Skit)',
        artist: 'Album Artist',
        album: 'New Album',
        durationSeconds: 45,
      );
      final legitimateSong = Track(
        id: 'song1',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        album: 'A Night at the Opera',
        durationSeconds: 354,
      );

      expect(SmartDjCurator.isEligibleMusicTrack(audiobook1), isFalse);
      expect(SmartDjCurator.isEligibleMusicTrack(audiobook2), isFalse);
      expect(SmartDjCurator.isEligibleMusicTrack(radioStream), isFalse);
      expect(SmartDjCurator.isEligibleMusicTrack(skit), isFalse);
      expect(SmartDjCurator.isEligibleMusicTrack(legitimateSong), isTrue);
    });

    test('scoreTrackForVibe accurately discriminates genres and avoids false positives', () {
      final taste = const UserTasteProfile(likedTrackIds: {'song_liked'});

      final rockSong = Track(
        id: 'rock1',
        title: 'Back in Black',
        artist: 'AC/DC',
        album: 'Back in Black',
        durationSeconds: 255,
        rawSource: {
          'metadata': {'genres': ['hard rock', 'classic rock']},
        },
      );

      final chillSong = Track(
        id: 'chill1',
        title: 'Weightless (Ambient Lo-Fi)',
        artist: 'Marconi Union',
        album: 'Ambient 1',
        durationSeconds: 480,
        rawSource: {
          'metadata': {'genres': ['ambient', 'chillout', 'lofi']},
        },
      );

      final partySong = Track(
        id: 'party1',
        title: 'One More Time (Club Mix)',
        artist: 'Daft Punk',
        album: 'Discovery',
        durationSeconds: 210,
        rawSource: {
          'metadata': {'genres': ['dance', 'house', 'electro']},
        },
      );

      // Rock Track sollte in Rock Classics hoch punkten, aber in Late Night Chill stark abfallen
      final rockScoreInRock = SmartDjCurator.scoreTrackForVibe(
        track: rockSong,
        vibe: DjVibeCategory.rockClassics,
        profile: taste,
      );
      final rockScoreInChill = SmartDjCurator.scoreTrackForVibe(
        track: rockSong,
        vibe: DjVibeCategory.lateNightChill,
        profile: taste,
      );
      expect(rockScoreInRock, greaterThan(70.0));
      expect(rockScoreInChill, lessThan(0.0));

      // Chill Track sollte in Late Night Chill hoch punkten, aber nicht in Party
      final chillScoreInChill = SmartDjCurator.scoreTrackForVibe(
        track: chillSong,
        vibe: DjVibeCategory.lateNightChill,
        profile: taste,
      );
      final chillScoreInParty = SmartDjCurator.scoreTrackForVibe(
        track: chillSong,
        vibe: DjVibeCategory.partyVibes,
        profile: taste,
      );
      expect(chillScoreInChill, greaterThan(70.0));
      expect(chillScoreInParty, lessThan(0.0));

      // Party Track sollte in Party Vibes glänzen
      final partyScoreInParty = SmartDjCurator.scoreTrackForVibe(
        track: partySong,
        vibe: DjVibeCategory.partyVibes,
        profile: taste,
      );
      expect(partyScoreInParty, greaterThan(70.0));
    });

    test('curateSet enforces artist spacing and prevents back-to-back repetitions', () {
      final taste = const UserTasteProfile();
      final pool = [
        Track(
          id: 'q1',
          title: 'Radio Ga Ga',
          artist: 'Queen',
          album: 'The Works',
          durationSeconds: 240,
          rawSource: {'metadata': {'genres': ['rock']}},
        ),
        Track(
          id: 'q2',
          title: 'We Will Rock You',
          artist: 'Queen',
          album: 'News of the World',
          durationSeconds: 150,
          rawSource: {'metadata': {'genres': ['rock']}},
        ),
        Track(
          id: 'p1',
          title: 'Comfortably Numb',
          artist: 'Pink Floyd',
          album: 'The Wall',
          durationSeconds: 380,
          rawSource: {'metadata': {'genres': ['rock']}},
        ),
        Track(
          id: 'd1',
          title: 'Smoke on the Water',
          artist: 'Deep Purple',
          album: 'Machine Head',
          durationSeconds: 340,
          rawSource: {'metadata': {'genres': ['rock']}},
        ),
      ];

      final set = SmartDjCurator.curateSet(
        pool: pool,
        vibe: DjVibeCategory.rockClassics,
        profile: taste,
        targetCount: 4,
      );

      expect(set.length, equals(4));
      // Verifiziere, dass Queen nicht direkt hintereinander kommt
      for (int i = 0; i < set.length - 1; i++) {
        if (set[i].artist == 'Queen') {
          expect(set[i + 1].artist, isNot(equals('Queen')));
        }
      }
    });

    test('curateCustomWishSet selects matching artist and mood for free-text prompt', () {
      final taste = const UserTasteProfile();
      final pool = [
        Track(
          id: 'kav1',
          title: 'Nightcall',
          artist: 'Kavinsky',
          album: 'OutRun',
          durationSeconds: 259,
          rawSource: {'metadata': {'genres': ['synthwave', 'electro']}},
        ),
        Track(
          id: 'moz1',
          title: 'Eine kleine Nachtmusik',
          artist: 'Mozart',
          album: 'Classics',
          durationSeconds: 300,
        ),
        Track(
          id: 'queen1',
          title: 'Under Pressure',
          artist: 'Queen',
          album: 'Hot Space',
          durationSeconds: 245,
          rawSource: {'metadata': {'genres': ['rock']}},
        ),
      ];

      final mix = SmartDjCurator.curateCustomWishSet(
        pool: pool,
        prompt: 'Etwas von Kavinsky Synthwave',
        profile: taste,
        targetCount: 2,
      );

      expect(mix.isNotEmpty, isTrue);
      expect(mix.first.artist, equals('Kavinsky'));
    });
  });
}
