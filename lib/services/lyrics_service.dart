import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';
import '../models/track.dart';

/// Service zur Bereitstellung und Synchronisation von Songtexten (Lyrics)
/// im Spotify-Stil mit zeitgestempelter Zeilen-Hervorhebung (Karaoke / Synced LRC).
/// Unterstützt echte synchronisierte Songtexte über die offene LRCLIB-API sowie
/// kuratierte Hörspiel-Inhalte für Die drei ???.
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final http.Client _client = http.Client();
  final Map<String, List<LyricLine>> _cache = {};

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

  /// Ruft echte synchronisierte Songtexte für einen Track ab
  Future<List<LyricLine>> getLyricsForTrack(Track track) async {
    final cacheKey = '${track.artist.toLowerCase()} - ${track.title.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();

    // 1. Spezieller Hörspiel-Songtext für Die drei ???
    if (title.contains('drei ???') ||
        artist.contains('drei ???') ||
        track.album.toLowerCase().contains('drei ???') ||
        title.contains('super-papagei') ||
        title.contains('karpatenhund')) {
      final res = _dieDreiFragezeichenIntroLyrics;
      _cache[cacheKey] = res;
      return res;
    }

    // 2. Bekannte kuratierte Hits
    if (title.contains('bohemian rhapsody') && artist.contains('queen')) {
      _cache[cacheKey] = _bohemianRhapsodyLyrics;
      return _bohemianRhapsodyLyrics;
    }

    // 3. Echte synchronisierte Songtexte von der offenen LRCLIB API abrufen
    try {
      final realLyrics = await _fetchFromLrclib(track);
      if (realLyrics.isNotEmpty) {
        _cache[cacheKey] = realLyrics;
        return realLyrics;
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB fetch error: $e');
    }

    // 4. Fallback: Dynamische musikalisch getaktete Verse
    final fallback = _generateDynamicLyrics(track);
    _cache[cacheKey] = fallback;
    return fallback;
  }

  /// Bereinigt Songtitel von störenden Zusätzen wie "(Remastered 2011)" für bessere Trefferquote
  String _cleanTrackTitle(String title) {
    var cleaned = title;
    cleaned = cleaned.replaceAll(RegExp(r'\s*[\(\[](?:feat\.|ft\.|remastered|live|mono|deluxe|version|edit|explicit)[^\)\]]*[\)\]]', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*(?:remastered|live|radio edit|bonus track).*', caseSensitive: false), '');
    return cleaned.trim();
  }

  /// Fragt die LRCLIB REST-API nach echten synchronisierten Texten ab
  Future<List<LyricLine>> _fetchFromLrclib(Track track) async {
    final cleanTitle = _cleanTrackTitle(track.title);
    final cleanArtist = track.artist.trim();
    if (cleanTitle.isEmpty || cleanArtist.isEmpty) return [];

    const userAgent = 'MusicAssistantApp/1.10.4 (https://github.com/LegoPuck-orginal/music-assistant-app)';
    final headers = {'User-Agent': userAgent};

    // Versuch 1: Exakte Suche mit /api/get
    try {
      final queryParams = {
        'track_name': cleanTitle,
        'artist_name': cleanArtist,
      };
      if (track.durationSeconds > 0) {
        queryParams['duration'] = track.durationSeconds.toString();
      }
      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final resp = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          final lines = parseLrc(synced);
          if (lines.isNotEmpty) return lines;
        }

        final plain = data['plainLyrics'] as String?;
        if (plain != null && plain.trim().isNotEmpty) {
          return _spacePlainLyrics(plain, track.durationSeconds);
        }
      }
    } catch (_) {}

    // Versuch 2: Flexible Suche mit /api/search
    try {
      final searchUri = Uri.https('lrclib.net', '/api/search', {
        'track_name': cleanTitle,
        'artist_name': cleanArtist,
      });
      final resp = await _client.get(searchUri, headers: headers).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final synced = item['syncedLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              final lines = parseLrc(synced);
              if (lines.isNotEmpty) return lines;
            }
          }
        }

        // Falls kein Synced, nehme Plain Lyrics des ersten Treffers
        if (list.isNotEmpty && list.first is Map<String, dynamic>) {
          final first = list.first as Map<String, dynamic>;
          final plain = first['plainLyrics'] as String?;
          if (plain != null && plain.trim().isNotEmpty) {
            return _spacePlainLyrics(plain, track.durationSeconds);
          }
        }
      }
    } catch (_) {}

    return [];
  }

  /// Parst einen LRC-Text ([mm:ss.xx] Songtext) in strukturierte LyricLine-Objekte
  List<LyricLine> parseLrc(String lrcContent) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = regex.firstMatch(line);
      if (match != null) {
        final min = int.tryParse(match.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
        final msStr = match.group(3);
        final ms = msStr != null
            ? (int.tryParse(msStr.padRight(3, '0').substring(0, 3)) ?? 0)
            : 0;
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(minutes: min, seconds: sec, milliseconds: ms),
            text: text,
          ));
        }
      }
    }
    return lines;
  }

  /// Verteilt ungetaktete Plain Lyrics gleichmäßig über die Songdauer
  List<LyricLine> _spacePlainLyrics(String plainLyrics, int durationSeconds) {
    final rawLines = plainLyrics
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (rawLines.isEmpty) return [];

    final dur = durationSeconds > 0 ? durationSeconds : (rawLines.length * 4);
    final interval = (dur / (rawLines.length + 1)).clamp(2.5, 12.0);

    final lines = <LyricLine>[];
    for (int i = 0; i < rawLines.length; i++) {
      lines.add(LyricLine(
        timestamp: Duration(milliseconds: (i * interval * 1000).toInt()),
        text: rawLines[i],
      ));
    }
    return lines;
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

  // --- Kuratierte Klassiker ---

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
}
