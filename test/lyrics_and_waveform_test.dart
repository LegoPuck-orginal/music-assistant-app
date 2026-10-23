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
      expect(idxAt25, 5); // Line at 22s ("Wir übernehmen jeden Fall!")
    });

    test('LyricsService extracts embedded lrcLyrics directly from track', () async {
      final track = Track(
        id: 'track_with_meta_lyrics',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        album: 'Divide',
        durationSeconds: 233,
        lrcLyrics: '''
[00:09.65] The club isn't the best place to find a lover
[00:12.10] So the bar is where I go
[01:05.50] I'm in love with the shape of you
''',
      );

      final lines = await lyricsService.getLyricsForTrack(track);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals("The club isn't the best place to find a lover"));
      expect(lines[2].text, equals("I'm in love with the shape of you"));
    });

    test('LyricsService does not fabricate fake generic lyrics when song has no lyrics', () async {
      final track = Track(
        id: 'unknown_local_synth',
        title: 'Unreleased Track XYZ 999999',
        artist: 'NonExistentArtistXYZ123456789',
        album: 'No Album',
        durationSeconds: 120,
      );

      final lines = await lyricsService.getLyricsForTrack(track);
      // Honesty guarantee: No fake "Spüre den Rhythmus" lyrics!
      expect(lines.isEmpty, isTrue);
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

    test('Letter-by-letter (Buchstabe für Buchstabe) snapshot spells out characters accurately', () {
      const sampleLrc = '''
[00:10.00] Hallo Welt
[00:14.00] Nächste Zeile
''';
      final lines = lyricsService.parseLrc(sampleLrc);
      expect(lines.length, equals(2));

      // Am Zeilenstart (10.00s): 0% Fortschritt
      final snapStart = lyricsService.getLineSnapshot(
        lines,
        0,
        const Duration(seconds: 10),
      );
      expect(snapStart.lineProgress, equals(0.0));
      expect(snapStart.spelledText, isEmpty);
      expect(snapStart.remainingText, equals('Hallo Welt'));

      // Mitten im Singen der Zeile (10.55s): Teilweise buchstabiert
      final snapMid = lyricsService.getLineSnapshot(
        lines,
        0,
        const Duration(seconds: 10, milliseconds: 550),
      );
      expect(snapMid.lineProgress, greaterThan(0.2));
      expect(snapMid.lineProgress, lessThan(0.9));
      expect(snapMid.spelledText.isNotEmpty, isTrue);
      expect(snapMid.spelledText + snapMid.remainingText, equals('Hallo Welt'));
      expect(snapMid.activeCharIndex, greaterThanOrEqualTo(0));
      expect(snapMid.activeWord, anyOf(equals('Hallo'), equals('Welt')));

      // Am Ende der Zeile (13.80s): Vollständig buchstabiert
      final snapEnd = lyricsService.getLineSnapshot(
        lines,
        0,
        const Duration(seconds: 13, milliseconds: 800),
      );
      expect(snapEnd.lineProgress, equals(1.0));
      expect(snapEnd.spelledText, equals('Hallo Welt'));
      expect(snapEnd.remainingText, isEmpty);
      expect(snapEnd.chars.every((c) => c.isSung), isTrue);
    });

    test('Enhanced LRC word timestamps (<mm:ss.xx>) are parsed and interpolated letter by letter', () {
      const enhancedLrc = '''
[00:05.00] <00:05.00>Is <00:05.50>this <00:06.20>fantasy
''';
      final lines = lyricsService.parseLrc(enhancedLrc);
      expect(lines.length, equals(1));
      expect(lines.first.text, equals('Is this fantasy'));
      expect(lines.first.words.length, equals(3));
      expect(lines.first.words[2].text, equals('fantasy'));

      final snapDuringFantasy = lyricsService.getLineSnapshot(
        lines,
        0,
        const Duration(seconds: 6, milliseconds: 500),
      );
      expect(snapDuringFantasy.activeWord, equals('fantasy'));
      expect(snapDuringFantasy.activeWordSpelled.startsWith('f'), isTrue);
    });

    test('LyricsService syncOffsetMs adjusts effective playback position', () {
      lyricsService.resetSyncOffset();
      expect(lyricsService.syncOffsetMs, equals(0));
      lyricsService.adjustSyncOffset(200);
      expect(lyricsService.syncOffsetMs, equals(200));
      final adjusted = lyricsService.applySyncOffset(const Duration(seconds: 10));
      expect(adjusted, equals(const Duration(seconds: 10, milliseconds: 200)));
      lyricsService.resetSyncOffset();
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
