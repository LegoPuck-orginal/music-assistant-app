import 'track.dart';

/// Modell für Hörbücher und Hörspiele (z. B. Die drei ???, TKKG, Sherlock Holmes)
class Audiobook {
  final String id;
  final String title;
  final String series;
  final int episodeNumber;
  final String narrator;
  final String author;
  final String description;
  final String imageUrl;
  final int totalDurationSeconds;
  final List<Track> chapters;
  final int currentChapterIndex;
  final int progressSeconds;
  final bool isListened;

  const Audiobook({
    required this.id,
    required this.title,
    required this.series,
    required this.episodeNumber,
    required this.narrator,
    required this.author,
    required this.description,
    required this.imageUrl,
    required this.totalDurationSeconds,
    required this.chapters,
    this.currentChapterIndex = 0,
    this.progressSeconds = 0,
    this.isListened = false,
  });

  String get formattedDuration {
    final m = totalDurationSeconds ~/ 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final remM = m % 60;
      return '$h Std. $remM Min.';
    }
    return '$m Min.';
  }

  String get formattedEpisode => 'Folge $episodeNumber';

  Audiobook copyWith({
    String? id,
    String? title,
    String? series,
    int? episodeNumber,
    String? narrator,
    String? author,
    String? description,
    String? imageUrl,
    int? totalDurationSeconds,
    List<Track>? chapters,
    int? currentChapterIndex,
    int? progressSeconds,
    bool? isListened,
  }) {
    return Audiobook(
      id: id ?? this.id,
      title: title ?? this.title,
      series: series ?? this.series,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      narrator: narrator ?? this.narrator,
      author: author ?? this.author,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      chapters: chapters ?? this.chapters,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      isListened: isListened ?? this.isListened,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'series': series,
      'episodeNumber': episodeNumber,
      'narrator': narrator,
      'author': author,
      'description': description,
      'imageUrl': imageUrl,
      'totalDurationSeconds': totalDurationSeconds,
      'chapters': chapters.map((c) => c.toJson()).toList(),
      'currentChapterIndex': currentChapterIndex,
      'progressSeconds': progressSeconds,
      'isListened': isListened,
    };
  }

  factory Audiobook.fromJson(Map<String, dynamic> json) {
    return Audiobook(
      id: json['id'] as String,
      title: json['title'] as String,
      series: json['series'] as String? ?? 'Die drei ???',
      episodeNumber: json['episodeNumber'] as int? ?? 1,
      narrator: json['narrator'] as String? ?? 'Oliver Rohrbeck',
      author: json['author'] as String? ?? 'Alfred Hitchcock',
      description: json['description'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      totalDurationSeconds: json['totalDurationSeconds'] as int? ?? 2700,
      chapters: (json['chapters'] as List<dynamic>?)
              ?.map((c) => Track.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      currentChapterIndex: json['currentChapterIndex'] as int? ?? 0,
      progressSeconds: json['progressSeconds'] as int? ?? 0,
      isListened: json['isListened'] as bool? ?? false,
    );
  }

  static const String defaultSampleStream =
      'https://stream.rockantenne.hamburg/rockantenne-hamburg/stream/mp3';

  /// Beliebte Hörspiele & Klassiker von "Die drei ???"
  static List<Audiobook> get sampleAudiobooks => [
        Audiobook(
          id: 'ddf_001',
          title: 'und der Super-Papagei',
          series: 'Die drei ???',
          episodeNumber: 1,
          narrator: 'Oliver Rohrbeck, Jens Wawrczeck, Andreas Fröhlich, Peter Pasetti',
          author: 'Robert Arthur / Alfred Hitchcock',
          description:
              'Ein sprechender Papagei, der lateinische Verse krächzt, führt Justus, Peter und Bob auf die Spur eines verschollenen Gemäldes und in ein spannendes Abenteuer.',
          imageUrl:
              'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?w=600&auto=format&fit=crop&q=80',
          totalDurationSeconds: 2740,
          chapters: [
            Track(
              id: 'ddf_1_1',
              title: 'Teil 1: Der seltsame Vogel Blacky',
              artist: 'Die drei ???',
              album: 'Folge 1: Der Super-Papagei',
              durationSeconds: 310,
              imageUrl:
                  'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_1_2',
              title: 'Teil 2: Ein Anruf von Mr. Frobisher',
              artist: 'Die drei ???',
              album: 'Folge 1: Der Super-Papagei',
              durationSeconds: 420,
              imageUrl:
                  'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_1_3',
              title: 'Teil 3: Die sieben Vögel',
              artist: 'Die drei ???',
              album: 'Folge 1: Der Super-Papagei',
              durationSeconds: 490,
              imageUrl:
                  'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_1_4',
              title: 'Teil 4: Auf der Spur von Hugenay',
              artist: 'Die drei ???',
              album: 'Folge 1: Der Super-Papagei',
              durationSeconds: 520,
              imageUrl:
                  'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_1_5',
              title: 'Teil 5: Das Rätsel des Friedhofs',
              artist: 'Die drei ???',
              album: 'Folge 1: Der Super-Papagei',
              durationSeconds: 480,
              imageUrl:
                  'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_1_6',
              title: 'Teil 6: Justus lüftet das Geheimnis',
              artist: 'Die drei ???',
              album: 'Folge 1: Der Super-Papagei',
              durationSeconds: 520,
              imageUrl:
                  'https://images.unsplash.com/photo-1546527868-ccb7ee7dfa6a?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
          ],
        ),
        Audiobook(
          id: 'ddf_011',
          title: 'und das Gespensterschloss',
          series: 'Die drei ???',
          episodeNumber: 11,
          narrator: 'Oliver Rohrbeck, Jens Wawrczeck, Andreas Fröhlich',
          author: 'Robert Arthur',
          description:
              'Ein verlassenes Schloss in Hollywood, seltsame Heulgeräusche und ein geheimnisvoller Spiegel: Justus, Peter und Bob erforschen das Schloss des Stummfilmstars Terrill.',
          imageUrl:
              'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
          totalDurationSeconds: 2890,
          chapters: [
            Track(
              id: 'ddf_11_1',
              title: 'Teil 1: Das Schloss in den Hügeln',
              artist: 'Die drei ???',
              album: 'Folge 11: Das Gespensterschloss',
              durationSeconds: 410,
              imageUrl:
                  'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_11_2',
              title: 'Teil 2: Die unheimliche Orgel',
              artist: 'Die drei ???',
              album: 'Folge 11: Das Gespensterschloss',
              durationSeconds: 530,
              imageUrl:
                  'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_11_3',
              title: 'Teil 3: Das Phantom von Stephen Terrill',
              artist: 'Die drei ???',
              album: 'Folge 11: Das Gespensterschloss',
              durationSeconds: 610,
              imageUrl:
                  'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_11_4',
              title: 'Teil 4: Die blaue Flamme',
              artist: 'Die drei ???',
              album: 'Folge 11: Das Gespensterschloss',
              durationSeconds: 640,
              imageUrl:
                  'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_11_5',
              title: 'Teil 5: Die Abrechnung in der Zentrale',
              artist: 'Die drei ???',
              album: 'Folge 11: Das Gespensterschloss',
              durationSeconds: 700,
              imageUrl:
                  'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
          ],
        ),
        Audiobook(
          id: 'ddf_003',
          title: 'und der Karpatenhund',
          series: 'Die drei ???',
          episodeNumber: 3,
          narrator: 'Oliver Rohrbeck, Jens Wawrczeck, Andreas Fröhlich',
          author: 'M. V. Carey',
          description:
              'In einer Wohnanlage in Los Angeles wird die Kristallskulptur eines Hundes gestohlen. Zudem geschehen unerklärliche Dinge: Ein Priester wird bedroht und Säure zerstört Gemälde.',
          imageUrl:
              'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=600&auto=format&fit=crop&q=80',
          totalDurationSeconds: 2980,
          chapters: [
            Track(
              id: 'ddf_3_1',
              title: 'Teil 1: Die geheimnisvolle Skulptur',
              artist: 'Die drei ???',
              album: 'Folge 3: Der Karpatenhund',
              durationSeconds: 460,
              imageUrl:
                  'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_3_2',
              title: 'Teil 2: Ein Fall für Mr. Prentice',
              artist: 'Die drei ???',
              album: 'Folge 3: Der Karpatenhund',
              durationSeconds: 580,
              imageUrl:
                  'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_3_3',
              title: 'Teil 3: Säure im Treppenhaus',
              artist: 'Die drei ???',
              album: 'Folge 3: Der Karpatenhund',
              durationSeconds: 610,
              imageUrl:
                  'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_3_4',
              title: 'Teil 4: Die Geisterbeschwörung',
              artist: 'Die drei ???',
              album: 'Folge 3: Der Karpatenhund',
              durationSeconds: 680,
              imageUrl:
                  'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_3_5',
              title: 'Teil 5: Des Rätsels verblüffende Lösung',
              artist: 'Die drei ???',
              album: 'Folge 3: Der Karpatenhund',
              durationSeconds: 650,
              imageUrl:
                  'https://images.unsplash.com/photo-1583337130417-3346a1be7dee?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
          ],
        ),
        Audiobook(
          id: 'ddf_125',
          title: 'Feuermond',
          series: 'Die drei ???',
          episodeNumber: 125,
          narrator: 'Oliver Rohrbeck, Jens Wawrczeck, Andreas Fröhlich, Thomas Fritsch',
          author: 'André Marx',
          description:
              'Jubiläums-Meisterwerk: Der berüchtigte Kunstdieb Victor Hugenay kehrt zurück und fordert die drei Detektive zu einem perfiden Duell um das Vermächtnis eines Malers heraus.',
          imageUrl:
              'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
          totalDurationSeconds: 7200,
          chapters: [
            Track(
              id: 'ddf_125_1',
              title: 'Teil 1: Das Erbe des Malers',
              artist: 'Die drei ???',
              album: 'Folge 125: Feuermond',
              durationSeconds: 980,
              imageUrl:
                  'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_125_2',
              title: 'Teil 2: Hugenays Botschaft',
              artist: 'Die drei ???',
              album: 'Folge 125: Feuermond',
              durationSeconds: 1120,
              imageUrl:
                  'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_125_3',
              title: 'Teil 3: Das Rätsel der Gedichte',
              artist: 'Die drei ???',
              album: 'Folge 125: Feuermond',
              durationSeconds: 1240,
              imageUrl:
                  'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_125_4',
              title: 'Teil 4: Die Nacht im Museum',
              artist: 'Die drei ???',
              album: 'Folge 125: Feuermond',
              durationSeconds: 1380,
              imageUrl:
                  'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
            Track(
              id: 'ddf_125_5',
              title: 'Teil 5: Der Feuermond erstrahlt',
              artist: 'Die drei ???',
              album: 'Folge 125: Feuermond',
              durationSeconds: 1480,
              imageUrl:
                  'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
              uri: defaultSampleStream,
            ),
          ],
        ),
      ];
}
