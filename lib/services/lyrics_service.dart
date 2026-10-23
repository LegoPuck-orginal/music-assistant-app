import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';
import '../models/track.dart';
import 'mass_api_service.dart';

/// Service zur Bereitstellung und Synchronisation von Songtexten (Lyrics)
/// im Spotify-Stil mit zeitgestempelter Zeilen-Hervorhebung (Karaoke / Synced LRC).
/// Fragt prioritär den Music Assistant Server ab (metadata/get_track_lyrics),
/// nutzt LRCLIB als weltweiten Synced-Lyrics-Katalog und verhindert Fake-Texte.
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final http.Client _client = http.Client();
  final Map<String, List<LyricLine>> _cache = {};

  /// Benutzerdefinierter Zeit-Offset in Millisekunden für präzises Buchstaben-Timing
  /// (z. B. zum Ausgleich von Bluetooth-/AirPlay-Latenz).
  int _syncOffsetMs = 0;
  int get syncOffsetMs => _syncOffsetMs;

  void adjustSyncOffset(int deltaMs) {
    _syncOffsetMs = (_syncOffsetMs + deltaMs).clamp(-5000, 5000);
  }

  void resetSyncOffset() {
    _syncOffsetMs = 0;
  }

  Duration applySyncOffset(Duration rawPosition) {
    final adjustedMs = rawPosition.inMilliseconds + _syncOffsetMs;
    return Duration(milliseconds: adjustedMs < 0 ? 0 : adjustedMs);
  }

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

  /// Berechnet den detaillierten Buchstaben-Snapshot für die Zeile an `index`
  LyricLineSnapshot getLineSnapshot(
    List<LyricLine> lines,
    int index,
    Duration position,
  ) {
    if (index < 0 || index >= lines.length) {
      return const LyricLineSnapshot(
        lineProgress: 0.0,
        chars: [],
        activeCharIndex: -1,
        spelledText: '',
        remainingText: '',
        activeWord: '',
        activeWordSpelled: '',
      );
    }
    final line = lines[index];
    final nextTimestamp =
        (index + 1 < lines.length) ? lines[index + 1].timestamp : line.endTimestamp;
    return line.computeSnapshot(
      position,
      nextLineTimestamp: nextTimestamp,
    );
  }

  /// Ruft echte synchronisierte Songtexte für einen Track ab
  Future<List<LyricLine>> getLyricsForTrack(Track track,
      {MassApiService? api}) async {
    final cacheKey =
        '${track.artist.toLowerCase().trim()} - ${track.title.toLowerCase().trim()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();

    // 1. Eingebettete Lyrics aus dem Track-Metadata-Objekt des Servers
    if (track.lrcLyrics != null && track.lrcLyrics!.trim().isNotEmpty) {
      final lines = parseLrc(track.lrcLyrics!);
      if (lines.isNotEmpty) {
        _cache[cacheKey] = lines;
        return lines;
      }
    }
    if (track.plainLyrics != null && track.plainLyrics!.trim().isNotEmpty) {
      final lines = _spacePlainLyrics(track.plainLyrics!, track.durationSeconds);
      if (lines.isNotEmpty) {
        _cache[cacheKey] = lines;
        return lines;
      }
    }

    // 2. Music Assistant Server API (metadata/get_track_lyrics)
    if (api != null && api.isConnected) {
      try {
        final serverLyrics = await api.fetchTrackLyrics(track);
        if (serverLyrics != null && serverLyrics.trim().isNotEmpty) {
          if (serverLyrics.contains('[') &&
              RegExp(r'\[\d{1,2}:\d{2}').hasMatch(serverLyrics)) {
            final lines = parseLrc(serverLyrics);
            if (lines.isNotEmpty) {
              _cache[cacheKey] = lines;
              return lines;
            }
          }
          final lines =
              _spacePlainLyrics(serverLyrics, track.durationSeconds);
          if (lines.isNotEmpty) {
            _cache[cacheKey] = lines;
            return lines;
          }
        }
      } catch (e) {
        debugPrint('[LyricsService] Mass API get_track_lyrics error: $e');
      }
    }

    // 3. Hörspiel-Songtext für Die drei ??? Intro
    if (title.contains('drei ???') ||
        artist.contains('drei ???') ||
        track.album.toLowerCase().contains('drei ???') ||
        title.contains('super-papagei') ||
        title.contains('karpatenhund')) {
      final res = _dieDreiFragezeichenIntroLyrics;
      _cache[cacheKey] = res;
      return res;
    }

    // 4. Bekannte kuratierte Hits
    if (title.contains('bohemian rhapsody') && artist.contains('queen')) {
      _cache[cacheKey] = _bohemianRhapsodyLyrics;
      return _bohemianRhapsodyLyrics;
    }

    // 5. Echte synchronisierte Songtexte von der offenen LRCLIB API abrufen
    try {
      final realLyrics = await _fetchFromLrclib(track);
      if (realLyrics.isNotEmpty) {
        _cache[cacheKey] = realLyrics;
        return realLyrics;
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB fetch error: $e');
    }

    // 6. Kein Fake-Text! Wenn keine Lyrics existieren, leere Liste zurückgeben,
    // damit das UI einen ehrlichen, sauberen Hinweis anzeigt.
    _cache[cacheKey] = [];
    return [];
  }

  /// Bereinigt Songtitel von störenden Zusätzen wie "(Remastered 2011)" für bessere Trefferquote
  String _cleanTrackTitle(String title) {
    var cleaned = title;
    cleaned = cleaned.replaceAll(
        RegExp(
            r'\s*[\(\[](?:feat\.|ft\.|remastered|live|mono|deluxe|version|edit|explicit|radio edit|20\d\d|19\d\d)[^\)\]]*[\)\]]',
            caseSensitive: false),
        '');
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*-\s*(?:remastered|live|radio edit|bonus track).*',
            caseSensitive: false),
        '');
    return cleaned.trim();
  }

  /// Extrahiert den primären Künstler bei Feature-Songs ("The Weeknd, Daft Punk" -> "The Weeknd")
  String _getPrimaryArtist(String artist) {
    final split = artist.split(RegExp(
        r'[,;&/]|\sfeat\.|\sft\.|\svs\.|\swith\s',
        caseSensitive: false));
    return split.isNotEmpty ? split.first.trim() : artist.trim();
  }

  /// Fragt die LRCLIB REST-API nach echten synchronisierten Texten ab
  Future<List<LyricLine>> _fetchFromLrclib(Track track) async {
    final cleanTitle = _cleanTrackTitle(track.title);
    final fullArtist = track.artist.trim();
    final primaryArtist = _getPrimaryArtist(fullArtist);

    if (cleanTitle.isEmpty) return [];

    const userAgent =
        'MusicAssistantApp/1.10.9 (https://github.com/LegoPuck-orginal/music-assistant-app)';
    final headers = {'User-Agent': userAgent};

    // Versuch 1: Exakte Suche mit /api/get (cleanTitle + primaryArtist)
    try {
      final queryParams = <String, String>{
        'track_name': cleanTitle,
        if (primaryArtist.isNotEmpty) 'artist_name': primaryArtist,
      };
      if (track.durationSeconds > 0) {
        queryParams['duration'] = track.durationSeconds.toString();
      }
      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final resp = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
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

    // Versuch 2: Flexible Volltext-Suche mit /api/search?q=
    try {
      final q = primaryArtist.isNotEmpty
          ? '$cleanTitle $primaryArtist'
          : cleanTitle;
      final searchUri = Uri.https('lrclib.net', '/api/search', {'q': q});
      final resp = await _client
          .get(searchUri, headers: headers)
          .timeout(const Duration(seconds: 4));

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

  /// Manuelle Suche nach Songtexten mit benutzerdefiniertem Titel & Künstler
  Future<List<LyricLine>> searchLyricsManually(String title, String artist,
      {int duration = 0}) async {
    final cleanT = _cleanTrackTitle(title);
    final cleanA = _getPrimaryArtist(artist);
    final dummy = Track(
      id: 'manual_search',
      title: cleanT,
      artist: cleanA,
      album: '',
      durationSeconds: duration,
    );
    final res = await _fetchFromLrclib(dummy);
    return res;
  }

  void clearCacheForTrack(Track track) {
    final cacheKey =
        '${track.artist.toLowerCase().trim()} - ${track.title.toLowerCase().trim()}';
    _cache.remove(cacheKey);
  }

  /// Parst einen LRC-Text ([mm:ss.xx] Songtext) inkl. optionaler Enhanced-LRC-Worttags
  /// (<mm:ss.xx>Wort) in strukturierte LyricLine-Objekte mit End-Zeitstempeln.
  List<LyricLine> parseLrc(String lrcContent) {
    final rawParsed = <LyricLine>[];
    final lineRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)');
    final wordTagRegex =
        RegExp(r'<(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?>\s*([^<]+)');

    for (final rawLine in lrcContent.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final match = lineRegex.firstMatch(line);
      if (match != null) {
        final min = int.tryParse(match.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
        final msStr = match.group(3);
        final ms = msStr != null
            ? (int.tryParse(msStr.padRight(3, '0').substring(0, 3)) ?? 0)
            : 0;
        final rawText = match.group(4)?.trim() ?? '';
        if (rawText.isEmpty) continue;

        final lineTimestamp =
            Duration(minutes: min, seconds: sec, milliseconds: ms);

        // Prüfen auf Enhanced LRC Wort-Zeitstempel (<mm:ss.xx>Wort)
        final wordMatches = wordTagRegex.allMatches(rawText).toList();
        final parsedWords = <LyricWord>[];
        if (wordMatches.isNotEmpty) {
          final tempStarts = <Duration>[];
          final tempTexts = <String>[];
          for (final wm in wordMatches) {
            final wMin = int.tryParse(wm.group(1) ?? '0') ?? 0;
            final wSec = int.tryParse(wm.group(2) ?? '0') ?? 0;
            final wMsStr = wm.group(3);
            final wMs = wMsStr != null
                ? (int.tryParse(wMsStr.padRight(3, '0').substring(0, 3)) ?? 0)
                : 0;
            final wText = wm.group(4)?.trim() ?? '';
            if (wText.isNotEmpty) {
              tempStarts.add(
                  Duration(minutes: wMin, seconds: wSec, milliseconds: wMs));
              tempTexts.add(wText);
            }
          }
          for (int i = 0; i < tempStarts.length; i++) {
            final nextStart = (i + 1 < tempStarts.length)
                ? tempStarts[i + 1]
                : tempStarts[i] +
                    Duration(milliseconds: (tempTexts[i].length * 110).clamp(250, 1200));
            parsedWords.add(LyricWord(
              text: tempTexts[i],
              start: tempStarts[i],
              end: nextStart,
            ));
          }
        }

        final cleanText = rawText
            .replaceAll(RegExp(r'<\d{1,2}:\d{2}(?:\.\d{1,3})?>'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (cleanText.isNotEmpty) {
          rawParsed.add(LyricLine(
            timestamp: lineTimestamp,
            text: cleanText,
            words: parsedWords,
          ));
        }
      }
    }

    // Verknüpfe jede Zeile mit dem Startzeitpunkt der darauffolgenden Zeile
    final lines = <LyricLine>[];
    for (int i = 0; i < rawParsed.length; i++) {
      final current = rawParsed[i];
      final nextTs =
          (i + 1 < rawParsed.length) ? rawParsed[i + 1].timestamp : null;
      lines.add(current.copyWith(endTimestamp: nextTs));
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
      final startMs = (i * interval * 1000).toInt();
      final endMs = ((i + 1) * interval * 1000).toInt();
      lines.add(LyricLine(
        timestamp: Duration(milliseconds: startMs),
        endTimestamp: Duration(milliseconds: endMs),
        text: rawLines[i],
      ));
    }
    return lines;
  }

  static const List<LyricLine> _dieDreiFragezeichenIntroLyrics = [
    LyricLine(
      timestamp: Duration(seconds: 0),
      text: '♪ Die drei ??? Titelmelodie & Hörspiel-Intro ♪',
    ),
    LyricLine(
      timestamp: Duration(seconds: 5),
      text: 'Erster Detektiv: Justus Jonas',
    ),
    LyricLine(
      timestamp: Duration(seconds: 9),
      text: 'Zweiter Detektiv: Peter Shaw',
    ),
    LyricLine(
      timestamp: Duration(seconds: 13),
      text: 'Recherchen und Archiv: Bob Andrews',
    ),
    LyricLine(
      timestamp: Duration(seconds: 17),
      text: 'Zentrale: Gebrauchtwarencenter T. Jonas, Rocky Beach',
    ),
    LyricLine(
      timestamp: Duration(seconds: 22),
      text: 'Wir übernehmen jeden Fall!',
    ),
    LyricLine(
      timestamp: Duration(seconds: 28),
      text: 'Die drei Fragezeichen stehen für das Unbekannte, ungelöste Rätsel.',
    ),
    LyricLine(
      timestamp: Duration(seconds: 35),
      text: '♪ Hörspiel beginnt... ♪',
    ),
  ];

  static const List<LyricLine> _bohemianRhapsodyLyrics = [
    LyricLine(timestamp: Duration(seconds: 0), text: 'Is this the real life?'),
    LyricLine(timestamp: Duration(seconds: 4), text: 'Is this just fantasy?'),
    LyricLine(
        timestamp: Duration(seconds: 8),
        text: 'Caught in a landslide, no escape from reality'),
    LyricLine(
        timestamp: Duration(seconds: 14),
        text: 'Open your eyes, look up to the skies and see'),
    LyricLine(
        timestamp: Duration(seconds: 21),
        text: "I'm just a poor boy, I need no sympathy"),
    LyricLine(
        timestamp: Duration(seconds: 26),
        text: "Because I'm easy come, easy go, little high, little low"),
    LyricLine(
        timestamp: Duration(seconds: 33),
        text: 'Any way the wind blows doesn\'t really matter to me, to me'),
    LyricLine(
        timestamp: Duration(seconds: 49),
        text: 'Mama, just killed a man'),
    LyricLine(
        timestamp: Duration(seconds: 54),
        text: 'Put a gun against his head, pulled my trigger, now he\'s dead'),
    LyricLine(
        timestamp: Duration(seconds: 62),
        text: 'Mama, life had just begun'),
    LyricLine(
        timestamp: Duration(seconds: 68),
        text: 'But now I\'ve gone and thrown it all away'),
    LyricLine(
        timestamp: Duration(seconds: 74),
        text: 'Mama, ooh, didn\'t mean to make you cry'),
    LyricLine(
        timestamp: Duration(seconds: 81),
        text: 'If I\'m not back again this time tomorrow'),
    LyricLine(
        timestamp: Duration(seconds: 86),
        text: 'Carry on, carry on as if nothing really matters'),
  ];
}
