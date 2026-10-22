import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/user_profile.dart';
import 'package:music_assistant_app/models/virtual_dj_vibe.dart';
import 'package:music_assistant_app/widgets/profile_avatar.dart';

void main() {
  group('Profile & Avatar Tests', () {
    test('UserProfile copyWith updates avatarUrl and displayName correctly', () {
      const user = UserProfile(
        userId: 'tim_123',
        username: 'tim-m',
        displayName: 'Tim',
        role: 'admin',
      );

      final updated = user.copyWith(
        displayName: 'Tim M.',
        avatarUrl: 'preset:dj_neon',
      );

      expect(updated.userId, equals('tim_123'));
      expect(updated.username, equals('tim-m'));
      expect(updated.displayName, equals('Tim M.'));
      expect(updated.avatarUrl, equals('preset:dj_neon'));
      expect(updated.effectiveName, equals('Tim M.'));
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
}
