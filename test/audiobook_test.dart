import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/audiobook.dart';
import 'package:music_assistant_app/providers/music_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audiobook & Die drei ??? Tests', () {
    test('Audiobook sample collection contains Die drei ??? classics', () {
      final list = Audiobook.sampleAudiobooks;
      expect(list.isNotEmpty, isTrue);

      final superPapagei = list.firstWhere((a) => a.id == 'ddf_001');
      expect(superPapagei.series, 'Die drei ???');
      expect(superPapagei.title, 'und der Super-Papagei');
      expect(superPapagei.episodeNumber, 1);
      expect(superPapagei.formattedEpisode, 'Folge 1');
      expect(superPapagei.chapters.length, 6);
      expect(superPapagei.narrator, contains('Oliver Rohrbeck'));
    });

    test('Audiobook JSON serialization and roundtrip preserves all fields', () {
      final sample = Audiobook.sampleAudiobooks.first;
      final json = sample.toJson();
      final restored = Audiobook.fromJson(json);

      expect(restored.id, sample.id);
      expect(restored.title, sample.title);
      expect(restored.series, sample.series);
      expect(restored.episodeNumber, sample.episodeNumber);
      expect(restored.chapters.length, sample.chapters.length);
      expect(restored.chapters.first.title, sample.chapters.first.title);
    });

    test('MusicProvider playAudiobook enqueues all chapters and plays target', () async {
      final prov = MusicProvider();
      final sample = Audiobook.sampleAudiobooks.first;

      await prov.playAudiobook(sample, chapterIndex: 2);

      expect(prov.currentTrack, isNotNull);
      expect(prov.currentTrack!.id, sample.chapters[2].id);
      expect(prov.currentTrack!.title, sample.chapters[2].title);
      expect(prov.queue.length, sample.chapters.length);
      expect(prov.isPlaying, isTrue);
    });
  });
}
