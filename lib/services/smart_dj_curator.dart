import 'dart:math';
import '../models/track.dart';
import '../models/playlist.dart';
import '../models/virtual_dj_vibe.dart';

/// Geschmacksprofil des Nutzers, aggregiert aus Likes, Playlists und Hörverlauf.
class UserTasteProfile {
  final Set<String> likedTrackIds;
  final Map<String, int> artistAffinities;
  final Map<String, int> genreAffinities;
  final Set<String> recentlyHeardIds;
  final Set<String> recentlyHeardArtists;

  const UserTasteProfile({
    this.likedTrackIds = const {},
    this.artistAffinities = const {},
    this.genreAffinities = const {},
    this.recentlyHeardIds = const {},
    this.recentlyHeardArtists = const {},
  });

  factory UserTasteProfile.build({
    required List<Track> likedTracks,
    required List<Track> recentlyPlayed,
    required List<Playlist> playlists,
    required Set<String> sessionPlayedIds,
  }) {
    final Map<String, int> artistScores = {};
    final Map<String, int> genreScores = {};
    final Set<String> likedIds = {};

    // 1. Favoriten gewichten (stärkstes Signal)
    for (final t in likedTracks) {
      if (t.id.isNotEmpty) likedIds.add(t.id);
      final artist = t.artist.trim().toLowerCase();
      if (artist.isNotEmpty && artist != 'unbekannter künstler') {
        artistScores[artist] = (artistScores[artist] ?? 0) + 3;
      }
      _extractGenres(t).forEach((g) {
        genreScores[g] = (genreScores[g] ?? 0) + 3;
      });
    }

    // 2. Kürzlich gespielte Titel
    for (int i = 0; i < recentlyPlayed.length; i++) {
      final t = recentlyPlayed[i];
      final weight = max(1, 3 - (i ~/ 5));
      final artist = t.artist.trim().toLowerCase();
      if (artist.isNotEmpty && artist != 'unbekannter künstler') {
        artistScores[artist] = (artistScores[artist] ?? 0) + weight;
      }
      _extractGenres(t).forEach((g) {
        genreScores[g] = (genreScores[g] ?? 0) + weight;
      });
    }

    // 3. Eigene Playlists
    for (final pl in playlists) {
      for (final t in pl.tracks) {
        final artist = t.artist.trim().toLowerCase();
        if (artist.isNotEmpty && artist != 'unbekannter künstler') {
          artistScores[artist] = (artistScores[artist] ?? 0) + 1;
        }
      }
    }

    final recentIds = <String>{...sessionPlayedIds};
    final recentArtists = <String>{};
    for (final t in recentlyPlayed.take(15)) {
      if (t.id.isNotEmpty) recentIds.add(t.id);
      if (t.artist.isNotEmpty) recentArtists.add(t.artist.trim().toLowerCase());
    }

    return UserTasteProfile(
      likedTrackIds: likedIds,
      artistAffinities: artistScores,
      genreAffinities: genreScores,
      recentlyHeardIds: recentIds,
      recentlyHeardArtists: recentArtists,
    );
  }

  static List<String> _extractGenres(Track t) {
    final list = <String>[];
    final rawMeta = t.rawSource?['metadata'];
    if (rawMeta is Map && rawMeta['genres'] is List) {
      for (final g in rawMeta['genres'] as List) {
        final s = g?.toString().trim().toLowerCase();
        if (s != null && s.isNotEmpty) list.add(s);
      }
    }
    return list;
  }
}

/// Intelligente Musik-Kuratierung & Empfehlungs-Engine für den virtuellen DJ.
///
/// Löst alle Probleme früherer simpler Heuristiken:
/// - Strikte Musik-Hygiene (filtert Hörspiele, Audiobooks, Jingles und Radiostreams aus Musik-Mixes aus).
/// - Echtes genrespezifisches Multi-Faktor-Scoring pro Vibe (keine simplen "Dauer >= 175s"-Prüfungen mehr).
/// - Berücksichtigt Nutzer-Affinität, Likes, Playlists und Server-Empfehlungen.
/// - DJ-Fluss-Sequenzierung: Verhindert Künstler- und Album-Wiederholungen direkt hintereinander.
class SmartDjCurator {
  static const _audiobookKeywords = [
    'die drei ???',
    'drei fragezeichen',
    'tkkg',
    'fünf freunde',
    'bibi blocksberg',
    'benjamin blümchen',
    'john sinclair',
    'sherlock holmes',
    'hörspiel',
    'hörbuch',
    'audiobook',
    'folge ',
    'teil ',
    'kapitel ',
    'chapter ',
    'episodes ',
    'akt ',
  ];

  static const _jingleKeywords = [
    'intro',
    'outro',
    'skit',
    'interlude',
    'jingle',
    'station id',
    'moderation',
  ];

  /// Prüft, ob ein Track ein echter Musiktitel ist und für DJ-Sets infrage kommt.
  static bool isEligibleMusicTrack(Track track, {bool allowAudiobooks = false}) {
    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();
    final album = track.album.toLowerCase();
    final combined = '$title $artist $album';

    // 1. Hörspiel / Hörbuch Filter
    if (!allowAudiobooks) {
      for (final kw in _audiobookKeywords) {
        if (combined.contains(kw)) return false;
      }
      // Folgennummern-Muster wie "216 - " oder "Kapitel 12"
      if (RegExp(r'^\d{2,4}\s*[-–.]').hasMatch(track.title) &&
          (combined.contains('teil') || combined.contains('folge') || combined.contains('kapitel'))) {
        return false;
      }
    }

    // 2. Radio Live Streams aussortieren
    final uri = (track.uri ?? '').toLowerCase();
    if (uri.contains('stream.') ||
        uri.contains('.m3u8') ||
        combined.contains('rock antenne') ||
        combined.contains('live stream') ||
        title == 'live stream') {
      return false;
    }

    // 3. Dauer-Prüfung: Unter 60s (Jingles/Skits) oder über 12 Minuten (Podcasts/Hörbücher)
    if (track.durationSeconds < 60 || track.durationSeconds > 750) {
      return false;
    }

    // 4. Skits / Interludes filtern
    if (track.durationSeconds < 90) {
      for (final kw in _jingleKeywords) {
        if (title.contains(kw)) return false;
      }
    }

    return true;
  }

  /// Berechnet den Vibe-Relevanzwert eines Tracks (0 bis 100+ Punkte).
  static double scoreTrackForVibe({
    required Track track,
    required DjVibeCategory vibe,
    required UserTasteProfile profile,
    String? currentTrackId,
    String? currentArtist,
  }) {
    if (!isEligibleMusicTrack(track)) return -100.0;
    if (track.id == currentTrackId) return -100.0;

    double score = 20.0; // Basiswert
    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();
    final album = track.album.toLowerCase();
    final combined = '$title $artist $album';
    final genres = _extractAllGenres(track);

    final isLiked = track.isLiked || profile.likedTrackIds.contains(track.id);
    final artistAffinity = profile.artistAffinities[artist] ?? 0;
    final isRecentlyHeard = profile.recentlyHeardIds.contains(track.id);
    final isRecentArtist = profile.recentlyHeardArtists.contains(artist);

    // Bei kürzlich gespieltem Titel starken Abzug geben, um Wiederholungen zu stoppen
    if (isRecentlyHeard) score -= 65.0;
    if (currentArtist != null && artist.isNotEmpty && artist == currentArtist.toLowerCase()) {
      score -= 35.0;
    } else if (isRecentArtist) {
      score -= 15.0;
    }

    switch (vibe) {
      case DjVibeCategory.allTimeFavorites:
        if (isLiked) score += 55.0;
        score += min(artistAffinity * 6.0, 30.0);
        if (track.rawSource?['play_count'] != null) {
          final pc = (track.rawSource!['play_count'] as num).toInt();
          score += min(pc * 2.0, 30.0);
        }
        if (isRecentlyHeard) score += 10.0; // Bei Favoriten weniger schlimm
        break;

      case DjVibeCategory.rockClassics:
        final rockMatch = _matchesRockGenreOrKeywords(genres, combined);
        if (rockMatch) {
          score += 65.0;
        } else {
          // Hartes Penalisieren von unpassenden Genres (Schlager, Rap, Chill Piano)
          if (_matchesIncompatibleRockGenres(genres, combined)) {
            score -= 75.0;
          } else {
            score -= 30.0;
          }
        }
        if (isLiked && rockMatch) score += 20.0;
        score += min(artistAffinity * 3.0, 15.0);
        break;

      case DjVibeCategory.partyVibes:
        final partyMatch = _matchesPartyGenreOrKeywords(genres, combined);
        if (partyMatch) {
          score += 65.0;
        } else if (_matchesIncompatiblePartyGenres(genres, combined)) {
          score -= 75.0;
        } else {
          score -= 25.0;
        }
        // Party-Tracks haben typischerweise 130s bis 260s Laufzeit
        if (track.durationSeconds >= 130 && track.durationSeconds <= 260) {
          score += 15.0;
        }
        if (isLiked && partyMatch) score += 20.0;
        break;

      case DjVibeCategory.lateNightChill:
        final chillMatch = _matchesChillGenreOrKeywords(genres, combined);
        if (chillMatch) {
          score += 70.0;
        } else if (_matchesIncompatibleChillGenres(genres, combined)) {
          score -= 85.0;
        } else {
          score -= 30.0;
        }
        if (isLiked && chillMatch) score += 15.0;
        break;

      case DjVibeCategory.forgottenGems:
        // Songs, die der Nutzer mag oder im Profil hat, aber lange NICHT gehört wurden
        if (isLiked) score += 50.0;
        if (artistAffinity > 0) score += 25.0;
        if (!isRecentlyHeard && !isRecentArtist) {
          score += 40.0;
        } else {
          score -= 60.0;
        }
        break;

      case DjVibeCategory.artistDiscoveries:
        // Bevorzuge Künstler, die zu den Lieblingsgenres passen, aber noch wenig gehört wurden
        final matchesFavoriteGenre = genres.any((g) => (profile.genreAffinities[g] ?? 0) > 0);
        if (matchesFavoriteGenre) score += 35.0;
        if (artistAffinity == 0) {
          score += 35.0; // Noch nie/selten gehörter Künstler
        } else if (artistAffinity <= 2) {
          score += 15.0;
        } else {
          score -= 25.0; // Schon sehr oft gehört
        }
        if (!isRecentlyHeard) score += 20.0;
        break;
    }

    return score;
  }

  /// Berechnet Relevanz für freie Nutzerwünsche (z. B. "80er Rock", "was Ruhiges", "Kavinsky").
  static double scoreTrackForCustomWish({
    required Track track,
    required String prompt,
    required UserTasteProfile profile,
    String? currentTrackId,
  }) {
    if (!isEligibleMusicTrack(track)) return -100.0;
    if (track.id == currentTrackId) return -100.0;

    final query = prompt.trim().toLowerCase();
    final title = track.title.toLowerCase();
    final artist = track.artist.toLowerCase();
    final album = track.album.toLowerCase();
    final combined = '$title $artist $album';
    final genres = _extractAllGenres(track);

    double score = 10.0;

    // 1. Exakter Künstler-Treffer (höchste Priorität)
    if (artist == query || artist.contains(query)) {
      score += 100.0;
    }

    // 2. Exakter Titel-Treffer
    if (title == query || title.contains(query)) {
      score += 90.0;
    }

    // 3. Wort-Treffer
    final words = query.split(RegExp(r'\s+')).where((w) => w.length > 2);
    for (final w in words) {
      if (combined.contains(w)) {
        score += 35.0;
      }
      if (genres.any((g) => g.contains(w))) {
        score += 30.0;
      }
    }

    // 4. Stimmungs-Schlüsselwörter
    if (query.contains('rock') || query.contains('gitarre') || query.contains('metal')) {
      score += _matchesRockGenreOrKeywords(genres, combined) ? 50.0 : -40.0;
    }
    if (query.contains('chill') || query.contains('ruhig') || query.contains('entspann') || query.contains('leise')) {
      score += _matchesChillGenreOrKeywords(genres, combined) ? 50.0 : -40.0;
    }
    if (query.contains('party') || query.contains('tanz') || query.contains('feier') || query.contains('beat')) {
      score += _matchesPartyGenreOrKeywords(genres, combined) ? 50.0 : -40.0;
    }

    if (track.isLiked || profile.likedTrackIds.contains(track.id)) {
      score += 15.0;
    }

    if (profile.recentlyHeardIds.contains(track.id)) {
      score -= 40.0;
    }

    return score;
  }

  /// Kuratiert ein 20-Track DJ-Set mit Abwechslung, Fluss und Artist-Spacing.
  static List<Track> curateSet({
    required List<Track> pool,
    required DjVibeCategory vibe,
    required UserTasteProfile profile,
    String? currentTrackId,
    String? currentArtist,
    int targetCount = 20,
  }) {
    if (pool.isEmpty) return [];

    // 1. Hygiene & Bewertung
    final scored = <_ScoredTrack>[];
    final random = Random();

    for (final track in pool) {
      final baseScore = scoreTrackForVibe(
        track: track,
        vibe: vibe,
        profile: profile,
        currentTrackId: currentTrackId,
        currentArtist: currentArtist,
      );

      if (baseScore <= 0.0) continue;

      // Kleiner kontrollierter Jitter (0-8 Pkt) für frische Varianz innerhalb desselben Relevanzbands
      final jitter = random.nextDouble() * 8.0;
      scored.add(_ScoredTrack(track, baseScore + jitter));
    }

    // Nach Score absteigend sortieren
    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) {
      // Notfall-Fallback auf bereinigte Pool-Tracks
      return pool.where((t) => isEligibleMusicTrack(t) && t.id != currentTrackId).take(targetCount).toList();
    }

    // 2. Fluss-Sequenzierung: Verhindert doppelte Künstler und Alben direkt hintereinander
    return _sequenceWithFlow(
      candidates: scored.map((s) => s.track).toList(),
      currentArtist: currentArtist,
      targetCount: targetCount,
    );
  }

  /// Kuratiert ein Set basierend auf einem Freitext-Wunsch.
  static List<Track> curateCustomWishSet({
    required List<Track> pool,
    required String prompt,
    required UserTasteProfile profile,
    String? currentTrackId,
    String? currentArtist,
    int targetCount = 20,
  }) {
    if (pool.isEmpty) return [];

    final scored = <_ScoredTrack>[];
    final random = Random();

    for (final track in pool) {
      final baseScore = scoreTrackForCustomWish(
        track: track,
        prompt: prompt,
        profile: profile,
        currentTrackId: currentTrackId,
      );

      if (baseScore <= 5.0) continue;
      final jitter = random.nextDouble() * 6.0;
      scored.add(_ScoredTrack(track, baseScore + jitter));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    if (scored.isEmpty) {
      return pool.where((t) => isEligibleMusicTrack(t) && t.id != currentTrackId).take(targetCount).toList();
    }

    return _sequenceWithFlow(
      candidates: scored.map((s) => s.track).toList(),
      currentArtist: currentArtist,
      targetCount: targetCount,
    );
  }

  /// Ordnet Tracks so an, dass:
  /// - Track #1 der stärkste Opener ist.
  /// - Derselbe Künstler mindestens 3 Songs Abstand hat.
  /// - Dasselbe Album niemals hintereinander läuft.
  static List<Track> _sequenceWithFlow({
    required List<Track> candidates,
    String? currentArtist,
    int targetCount = 20,
  }) {
    final result = <Track>[];
    final remaining = List<Track>.from(candidates);
    final recentArtists = <String>[];
    if (currentArtist != null && currentArtist.isNotEmpty) {
      recentArtists.add(currentArtist.toLowerCase().trim());
    }
    String? lastAlbum;

    while (result.length < targetCount && remaining.isNotEmpty) {
      int bestIdx = -1;

      for (int i = 0; i < remaining.length; i++) {
        final t = remaining[i];
        final artist = t.artist.toLowerCase().trim();
        final album = t.album.toLowerCase().trim();

        // Künstlersperre: Hat der Künstler in den letzten 2 Songs schon gespielt?
        final artistRecentlyUsed = recentArtists.isNotEmpty &&
            recentArtists.sublist(max(0, recentArtists.length - 2)).contains(artist);

        final sameAlbumConsecutive = (lastAlbum != null && lastAlbum.isNotEmpty && album.isNotEmpty && album == lastAlbum);

        if (!artistRecentlyUsed && !sameAlbumConsecutive) {
          bestIdx = i;
          break;
        }
      }

      // Falls keine perfekte Distanz mehr möglich ist, den nächstbesten nehmen
      if (bestIdx == -1) bestIdx = 0;

      final chosen = remaining.removeAt(bestIdx);
      result.add(chosen);

      final chosenArtist = chosen.artist.toLowerCase().trim();
      if (chosenArtist.isNotEmpty) {
        recentArtists.add(chosenArtist);
      }
      lastAlbum = chosen.album.toLowerCase().trim();
    }

    return result;
  }

  static List<String> _extractAllGenres(Track track) {
    final list = <String>[];
    final meta = track.rawSource?['metadata'];
    if (meta is Map) {
      if (meta['genres'] is List) {
        for (final g in meta['genres'] as List) {
          if (g != null) list.add(g.toString().toLowerCase().trim());
        }
      }
      if (meta['style'] != null) {
        list.add(meta['style'].toString().toLowerCase().trim());
      }
      if (meta['mood'] != null) {
        list.add(meta['mood'].toString().toLowerCase().trim());
      }
    }
    return list;
  }

  static bool _matchesRockGenreOrKeywords(List<String> genres, String text) {
    const rockKeys = [
      'rock', 'alternative', 'indie', 'metal', 'punk', 'grunge', 'guitar',
      'classic rock', 'hard rock', 'pop rock', 'blues rock', 'stoner',
    ];
    for (final k in rockKeys) {
      if (genres.any((g) => g.contains(k))) return true;
      if (text.contains(k)) return true;
    }
    return false;
  }

  static bool _matchesIncompatibleRockGenres(List<String> genres, String text) {
    const badKeys = [
      'schlager', 'volksmusik', 'ballermann', 'rap', 'hip hop', 'trap',
      'techno', 'ambient', 'lullaby', 'kinderlieder',
    ];
    for (final k in badKeys) {
      if (genres.any((g) => g.contains(k))) return true;
      if (text.contains(k)) return true;
    }
    return false;
  }

  static bool _matchesPartyGenreOrKeywords(List<String> genres, String text) {
    const partyKeys = [
      'dance', 'pop', 'electro', 'house', 'club', 'disco', 'funk',
      'party', 'edm', 'chart', 'remix', 'summer', 'banger', 'groove',
    ];
    for (final k in partyKeys) {
      if (genres.any((g) => g.contains(k))) return true;
      if (text.contains(k)) return true;
    }
    return false;
  }

  static bool _matchesIncompatiblePartyGenres(List<String> genres, String text) {
    const badKeys = [
      'ambient', 'sleep', 'lullaby', 'acoustic solo', 'sad', 'mournful',
      'classical slow', 'ballad', 'funeral',
    ];
    for (final k in badKeys) {
      if (genres.any((g) => g.contains(k))) return true;
      if (text.contains(k)) return true;
    }
    return false;
  }

  static bool _matchesChillGenreOrKeywords(List<String> genres, String text) {
    const chillKeys = [
      'chill', 'ambient', 'lofi', 'lo-fi', 'acoustic', 'downtempo', 'soul',
      'r&b', 'piano', 'jazz', 'night', 'relax', 'sleep', 'calm', 'soft',
      'synthwave', 'ballad', 'dream',
    ];
    for (final k in chillKeys) {
      if (genres.any((g) => g.contains(k))) return true;
      if (text.contains(k)) return true;
    }
    return false;
  }

  static bool _matchesIncompatibleChillGenres(List<String> genres, String text) {
    const badKeys = [
      'metal', 'hardcore', 'punk', 'hardstyle', 'schlager', 'heavy metal',
      'screamo', 'gabber', 'drill',
    ];
    for (final k in badKeys) {
      if (genres.any((g) => g.contains(k))) return true;
      if (text.contains(k)) return true;
    }
    return false;
  }
}

class _ScoredTrack {
  final Track track;
  final double score;
  _ScoredTrack(this.track, this.score);
}
