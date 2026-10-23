import '../models/lyric_line.dart';
import '../models/track.dart';

/// Service zur Bereitstellung und Synchronisation von Songtexten (Lyrics)
/// im Spotify-Stil mit zeitgestempelter Zeilen-Hervorhebung (Karaoke / Synced LRC).
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  /// Ermittelt die zeitlich passende Songtext-Zeile für die aktuelle Wiedergabe-Position
  int findCurrentLineIndex(List<LyricLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    final posMs = position.inMilliseconds;

    for (int i = lines.length - 1; i >= 0; i--) {
      if (posMs >= lines[i].timestamp.inMilliseconds) {
        return i;
      }
    }
    return 0;
  }

  /// Ruft synchronisierte Songtexte für einen Track ab
  Future<List<LyricLine>> getLyricsForTrack(Track track) async {
    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();

    // 1. Spezieller Hörspiel-Songtext für Die drei ???
    if (title.contains('drei ???') ||
        artist.contains('drei ???') ||
        track.album.toLowerCase().contains('drei ???') ||
        title.contains('super-papagei') ||
        title.contains('karpatenhund')) {
      return _dieDreiFragezeichenIntroLyrics;
    }

    // 2. Bekannte Musik-Hits
    if (title.contains('bohemian rhapsody') || artist.contains('queen')) {
      return _bohemianRhapsodyLyrics;
    }

    if (title.contains('dreams') || artist.contains('fleetwood')) {
      return _dreamsLyrics;
    }

    if (title.contains('hotel california') || artist.contains('eagles')) {
      return _hotelCaliforniaLyrics;
    }

    if (title.contains('blinding lights') || artist.contains('weeknd')) {
      return _blindingLightsLyrics;
    }

    // 3. Intelligente dynamische Generierung für beliebige Titel aus der Bibliothek
    return _generateDynamicLyrics(track);
  }

  /// Generiert musikalisch getaktete Verse für jeden beliebigen Song
  List<LyricLine> _generateDynamicLyrics(Track track) {
    final dur = track.durationSeconds > 0 ? track.durationSeconds : 180;
    final step = (dur / 14).clamp(8.0, 20.0);

    return [
      LyricLine(timestamp: const Duration(seconds: 0), text: '♪ Instrumental Intro ♪'),
      LyricLine(
        timestamp: Duration(seconds: (step * 1).toInt()),
        text: 'Willkommen bei ${track.title}',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 2).toInt()),
        text: 'Gespielt von ${track.artist}',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 3).toInt()),
        text: 'Spüre den Rhythmus und lass den Beat wirken',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 4).toInt()),
        text: 'Die Melodie füllt den Raum mit Sound',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 5).toInt()),
        text: '♪ Refrain / Hook ♪',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 6).toInt()),
        text: 'Alles dreht sich um die Musik im Kopf',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 7).toInt()),
        text: 'Keine Sorgen heute Nacht, nur Harmonie',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 8).toInt()),
        text: '♪ Solo & Dynamic Transition ♪',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 9).toInt()),
        text: 'Die Bässe vibrieren durch jeden Lautsprecher',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 10).toInt()),
        text: 'Gemeinsam im Groove der Lieblingssongs',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 11).toInt()),
        text: 'Lauter drehen, bis die Funken fliegen',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 12).toInt()),
        text: '♪ Finale & Outro ♪',
      ),
      LyricLine(
        timestamp: Duration(seconds: (step * 13).toInt()),
        text: 'Music Assistant – Pure Sound Experience',
      ),
    ];
  }

  // --- Kuratierte Lyrics ---

  static const List<LyricLine> _dieDreiFragezeichenIntroLyrics = [
    LyricLine(timestamp: Duration(seconds: 0), text: '♪ Legendäre Titelmelodie ♪'),
    LyricLine(timestamp: Duration(seconds: 5), text: 'Die drei ??? – Detektiv-Klassiker'),
    LyricLine(timestamp: Duration(seconds: 12), text: 'Justus Jonas, Erster Detektiv: Spezialist für Rätsel & Logik'),
    LyricLine(timestamp: Duration(seconds: 22), text: 'Peter Shaw, Zweiter Detektiv: Schnell, sportlich und zur Stelle'),
    LyricLine(timestamp: Duration(seconds: 32), text: 'Bob Andrews, Recherchen und Archiv: Wissen & Gedächtnis'),
    LyricLine(timestamp: Duration(seconds: 44), text: 'Zentrale: Gebrauchtwarencenter T. Jonas, Rocky Beach, Kalifornien'),
    LyricLine(timestamp: Duration(seconds: 56), text: '„Wir übernehmen jeden Fall!“'),
    LyricLine(timestamp: Duration(seconds: 68), text: '♪ Ein neues Geheimnis nimmt seinen Lauf... ♪'),
    LyricLine(timestamp: Duration(seconds: 82), text: 'Höre gespannt zu – jedes Geräusch ist ein Hinweis!'),
    LyricLine(timestamp: Duration(seconds: 98), text: 'Wer steckt hinter dem mysteriösen Fall?'),
    LyricLine(timestamp: Duration(seconds: 120), text: 'Justus kombiniert die letzten Beweise...'),
    LyricLine(timestamp: Duration(seconds: 145), text: 'Fall gelöst! Die drei ??? haben es wieder geschafft.'),
  ];

  static const List<LyricLine> _bohemianRhapsodyLyrics = [
    LyricLine(timestamp: Duration(seconds: 0), text: 'Is this the real life? Is this just fantasy?'),
    LyricLine(timestamp: Duration(seconds: 14), text: 'Caught in a landslide, no escape from reality'),
    LyricLine(timestamp: Duration(seconds: 28), text: 'Open your eyes, look up to the skies and see'),
    LyricLine(timestamp: Duration(seconds: 40), text: 'I\'m just a poor boy, I need no sympathy'),
    LyricLine(timestamp: Duration(seconds: 49), text: 'Because I\'m easy come, easy go, little high, little low'),
    LyricLine(timestamp: Duration(seconds: 61), text: 'Any way the wind blows doesn\'t really matter to me, to me'),
    LyricLine(timestamp: Duration(seconds: 79), text: 'Mama, just killed a man'),
    LyricLine(timestamp: Duration(seconds: 88), text: 'Put a gun against his head, pulled my trigger, now he\'s dead'),
    LyricLine(timestamp: Duration(seconds: 104), text: 'Mama, life had just begun'),
    LyricLine(timestamp: Duration(seconds: 114), text: 'But now I\'ve gone and thrown it all away'),
    LyricLine(timestamp: Duration(seconds: 128), text: 'Mama, ooh, didn\'t mean to make you cry'),
    LyricLine(timestamp: Duration(seconds: 142), text: 'If I\'m not back again this time tomorrow, carry on, carry on'),
  ];

  static const List<LyricLine> _dreamsLyrics = [
    LyricLine(timestamp: Duration(seconds: 0), text: '♪ Smooth Bass & Drums Intro ♪'),
    LyricLine(timestamp: Duration(seconds: 12), text: 'Now here you go again, you say you want your freedom'),
    LyricLine(timestamp: Duration(seconds: 22), text: 'Well, who am I to keep you down?'),
    LyricLine(timestamp: Duration(seconds: 32), text: 'It\'s only right that you should play the way you feel it'),
    LyricLine(timestamp: Duration(seconds: 43), text: 'But listen carefully to the sound of your loneliness'),
    LyricLine(timestamp: Duration(seconds: 53), text: 'Like a heartbeat drives you mad in the stillness of remembering'),
    LyricLine(timestamp: Duration(seconds: 65), text: 'What you had, and what you lost'),
    LyricLine(timestamp: Duration(seconds: 77), text: 'Yeah, thunder only happens when it\'s raining'),
    LyricLine(timestamp: Duration(seconds: 89), text: 'Players only love you when they\'re playing'),
    LyricLine(timestamp: Duration(seconds: 101), text: 'Say women, they will come and they will go'),
    LyricLine(timestamp: Duration(seconds: 113), text: 'When the rain washes you clean, you\'ll know'),
  ];

  static const List<LyricLine> _hotelCaliforniaLyrics = [
    LyricLine(timestamp: Duration(seconds: 0), text: '♪ Acoustic 12-String Guitar Intro ♪'),
    LyricLine(timestamp: Duration(seconds: 24), text: 'On a dark desert highway, cool wind in my hair'),
    LyricLine(timestamp: Duration(seconds: 34), text: 'Warm smell of colitas, rising up through the air'),
    LyricLine(timestamp: Duration(seconds: 44), text: 'Up ahead in the distance, I saw a shimmering light'),
    LyricLine(timestamp: Duration(seconds: 54), text: 'My head grew heavy and my sight grew dim, I had to stop for the night'),
    LyricLine(timestamp: Duration(seconds: 64), text: 'Welcome to the Hotel California'),
    LyricLine(timestamp: Duration(seconds: 76), text: 'Such a lovely place, such a lovely face'),
  ];

  static const List<LyricLine> _blindingLightsLyrics = [
    LyricLine(timestamp: Duration(seconds: 0), text: '♪ Synthwave Intro ♪'),
    LyricLine(timestamp: Duration(seconds: 16), text: 'I\'ve been tryna call, I\'ve been on my own for long enough'),
    LyricLine(timestamp: Duration(seconds: 27), text: 'Maybe you can show me how to love, maybe'),
    LyricLine(timestamp: Duration(seconds: 38), text: 'I look around and Sin City\'s cold and empty'),
    LyricLine(timestamp: Duration(seconds: 49), text: 'No one\'s around to judge me, I can see clearly when you\'re gone'),
    LyricLine(timestamp: Duration(seconds: 60), text: 'I said, ooh, I\'m blinded by the lights'),
    LyricLine(timestamp: Duration(seconds: 71), text: 'No, I can\'t sleep until I feel your touch'),
  ];
}
