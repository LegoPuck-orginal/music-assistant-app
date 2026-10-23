import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/track.dart';
import 'package:music_assistant_app/services/lyrics_service.dart';
import 'package:music_assistant_app/widgets/audio_waveform_scrubber.dart';

void main() {
  group('Lyrics & Audio Waveform Tests', () {
    final lyricsService = LyricsService();

    test('LyricsService provides synchronized lyrics for Die drei ???', () async {
      final track = Track(
        id: 'ddf_test_1',
        title: 'Der Super-Papagei',
        artist: 'Die drei ???',
        album: 'Folge 1',
        durationSeconds: 180,
      );

      final lines = await lyricsService.getLyricsForTrack(track);
      expect(lines.isNotEmpty, isTrue);
      expect(lines.first.text, contains('Titelmelodie'));

      // Check timestamp seeking
      final idxAt0 = lyricsService.findCurrentLineIndex(lines, const Duration(seconds: 2));
      expect(idxAt0, 0);

      final idxAt25 = lyricsService.findCurrentLineIndex(lines, const Duration(seconds: 25));
      expect(idxAt25, 3);
    });

    test('LyricsService generates dynamic lyrics for regular tracks', () async {
      final track = Track(
        id: 'generic_track_1',
        title: 'Neon Nights',
        artist: 'Synth Master',
        album: 'Cyberpunk 2026',
        durationSeconds: 240,
      );

      final lines = await lyricsService.getLyricsForTrack(track);
      expect(lines.length, greaterThan(8));
      expect(lines[1].text, contains('Neon Nights'));
      expect(lines[2].text, contains('Synth Master'));
    });

    test('LyricsService parses standard timestamped LRC format correctly', () {
      const sampleLrc = '''
[00:09.65] The club isn't the best place to find a lover
[00:12.10] So the bar is where I go
[01:05.50] I'm in love with the shape of you
''';
      final lines = lyricsService.parseLrc(sampleLrc);
      expect(lines.length, equals(3));
      expect(lines[0].timestamp, equals(const Duration(seconds: 9, milliseconds: 650)));
      expect(lines[0].text, equals("The club isn't the best place to find a lover"));
      expect(lines[1].timestamp, equals(const Duration(seconds: 12, milliseconds: 100)));
      expect(lines[2].timestamp, equals(const Duration(minutes: 1, seconds: 5, milliseconds: 500)));
      expect(lines[2].text, equals("I'm in love with the shape of you"));
    });

    testWidgets('AudioWaveformScrubber renders and triggers seek callback',
        (WidgetTester tester) async {
      Duration? seekTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: AudioWaveformScrubber(
                  currentPosition: const Duration(seconds: 60),
                  totalDuration: const Duration(seconds: 180),
                  isPlaying: true,
                  trackKey: 'test_track_key',
                  onSeek: (pos) {
                    seekTarget = pos;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AudioWaveformScrubber), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('3:00'), findsOneWidget);

      // Tap on the middle of the waveform (should seek to ~50% or ~90s)
      await tester.tap(find.byType(AudioWaveformScrubber));
      await tester.pump();

      expect(seekTarget, isNotNull);
    });
  });
}
