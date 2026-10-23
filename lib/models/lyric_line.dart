import 'dart:math' as math;

/// Repräsentiert ein einzelnes zeitgestempeltes Wort innerhalb einer Songtext-Zeile
/// (z. B. aus Enhanced LRC `<mm:ss.xx>` oder prosodischer Wort-Segmentierung).
class LyricWord {
  final String text;
  final Duration start;
  final Duration end;

  const LyricWord({
    required this.text,
    required this.start,
    required this.end,
  });
}

/// Status eines einzelnen Buchstabens zu einem bestimmten Wiedergabe-Zeitpunkt
/// für die Buchstabe-für-Buchstabe (Letter-by-Letter) Karaoke-Animation.
class LyricCharState {
  final String char;
  final int index;

  /// Fortschritt dieses Buchstabens von 0.0 (noch nicht gesungen) bis 1.0 (vollständig gesungen).
  final double progress;

  /// Gibt an, ob dieser Buchstabe gerade in diesem Moment aktiv gesungen/buchstabiert wird.
  final bool isCurrentActiveLetter;

  const LyricCharState({
    required this.char,
    required this.index,
    required this.progress,
    this.isCurrentActiveLetter = false,
  });

  bool get isSung => progress >= 1.0;
  bool get isStarted => progress > 0.0;
}

/// Detaillierter Berechnungs-Snapshot einer Songtext-Zeile für einen exakten Zeitstempel.
class LyricLineSnapshot {
  /// Gesamtfortschritt der Zeile (0.0 bis 1.0)
  final double lineProgress;

  /// Buchstaben-Zustände für jeden einzelnen Charakter der Zeile
  final List<LyricCharState> chars;

  /// Index des aktuell gesungenen Buchstabens (-1 falls noch nicht gestartet)
  final int activeCharIndex;

  /// Der bis zur aktuellen Millisekunde bereits buchstabierte Teil-Text
  final String spelledText;

  /// Der noch kommende (noch nicht gesungene) Teil-Text
  final String remainingText;

  /// Das aktuell gesungene Wort (für das Live-Buchstabier-HUD)
  final String activeWord;

  /// Der bis jetzt buchstabierte Teil des aktuellen Wortes
  final String activeWordSpelled;

  const LyricLineSnapshot({
    required this.lineProgress,
    required this.chars,
    required this.activeCharIndex,
    required this.spelledText,
    required this.remainingText,
    required this.activeWord,
    required this.activeWordSpelled,
  });
}

class LyricLine {
  final Duration timestamp;
  final Duration? endTimestamp;
  final String text;
  final List<LyricWord> words;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.endTimestamp,
    this.words = const [],
  });

  LyricLine copyWith({
    Duration? timestamp,
    Duration? endTimestamp,
    String? text,
    List<LyricWord>? words,
  }) {
    return LyricLine(
      timestamp: timestamp ?? this.timestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      text: text ?? this.text,
      words: words ?? this.words,
    );
  }

  /// Berechnet die natürliche Gesangsdauer dieser Zeile basierend auf dem Abstand
  /// zur nächsten Zeile (`nextLineTimestamp`) und der Textlänge, damit Buchstaben
  /// im echten Sing-Tempo buchstabiert werden (und nicht über lange Instrumental-Pausen gestreckt werden).
  Duration computeVocalEndTimestamp({Duration? nextLineTimestamp}) {
    if (words.isNotEmpty) {
      return words.last.end;
    }
    final rawNext = nextLineTimestamp ?? endTimestamp;
    final cleanLen = text.trim().length;
    // Natürliches maximales Singtempo: ~110ms pro Buchstabe (mind. 1.6s, max. 6.8s)
    final maxNaturalMs = (cleanLen * 110).clamp(1600, 6800);

    if (rawNext != null && rawNext > timestamp) {
      final gapMs = (rawNext - timestamp).inMilliseconds;
      // 90% des Abstands zur nächsten Zeile (10% kurze Atempause), aber begrenzt auf natürliche Gesangsdauer
      final vocalMs = math.min((gapMs * 0.90).round(), maxNaturalMs);
      final clampedMs = math.max(math.min(gapMs, 450), vocalMs);
      return timestamp + Duration(milliseconds: clampedMs);
    }

    return timestamp + Duration(milliseconds: maxNaturalMs);
  }

  /// Berechnet das prosodische Gewicht eines einzelnen Zeichens beim Singen:
  /// Vokale werden länger gehalten, Konsonanten kürzer, Satzzeichen erzeugen kurze Atempausen.
  static double _charSingingWeight(String ch) {
    if (ch.isEmpty) return 1.0;
    final lower = ch.toLowerCase();
    if ('aeiouäöüy'.contains(lower)) {
      return 1.38; // Vokale tragen die Melodie
    }
    if (ch == ' ') {
      return 0.48; // Wortübergang
    }
    if (',;-–—'.contains(ch)) {
      return 1.85; // Kurze Phrasierungs-Pause
    }
    if ('.!?…:'.contains(ch)) {
      return 2.25; // Deutliche Zäsur
    }
    if ('♪♫•'.contains(ch)) {
      return 0.6;
    }
    return 0.95; // Konsonant
  }

  /// Berechnet den exakten Buchstabe-für-Buchstabe-Fortschritt für die gegebene `position`.
  LyricLineSnapshot computeSnapshot(
    Duration position, {
    Duration? nextLineTimestamp,
  }) {
    if (text.isEmpty) {
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

    final vocalEnd = computeVocalEndTimestamp(
      nextLineTimestamp: nextLineTimestamp,
    );
    final startMs = timestamp.inMilliseconds;
    final endMs = math.max(startMs + 200, vocalEnd.inMilliseconds);
    final posMs = position.inMilliseconds;

    final rawLineProgress = ((posMs - startMs) / (endMs - startMs)).clamp(0.0, 1.0);

    final codeUnitsLen = text.length;
    final weights = List<double>.filled(codeUnitsLen, 1.0);

    // Falls Enhanced-LRC-Wortzeitstempel vorhanden sind, nutze deren Zeitfenster
    if (words.isNotEmpty) {
      final charStates = <LyricCharState>[];
      int globalIdx = 0;
      int activeIdx = -1;

      for (int wIdx = 0; wIdx < words.length; wIdx++) {
        final w = words[wIdx];
        final wStart = w.start.inMilliseconds;
        final wEnd = math.max(wStart + 80, w.end.inMilliseconds);
        final wProgress = ((posMs - wStart) / (wEnd - wStart)).clamp(0.0, 1.0);

        final wText = wIdx < words.length - 1 ? '${w.text} ' : w.text;
        double wTotalWeight = 0.0;
        final wWeights = <double>[];
        for (int i = 0; i < wText.length; i++) {
          final cw = _charSingingWeight(wText[i]);
          wWeights.add(cw);
          wTotalWeight += cw;
        }
        if (wTotalWeight <= 0) wTotalWeight = 1.0;

        double cum = 0.0;
        for (int i = 0; i < wText.length; i++) {
          final cStart = cum / wTotalWeight;
          cum += wWeights[i];
          final cEnd = cum / wTotalWeight;
          final span = math.max(0.0001, cEnd - cStart);
          final cp = ((wProgress - cStart) / span).clamp(0.0, 1.0);
          if (cp > 0.0) {
            activeIdx = globalIdx;
          }
          charStates.add(LyricCharState(
            char: wText[i],
            index: globalIdx,
            progress: cp,
          ));
          globalIdx++;
        }
      }

      return _finalizeSnapshot(
        rawLineProgress: rawLineProgress,
        rawStates: charStates,
        activeIdx: activeIdx,
      );
    }

    // Prosodische Gewichtung über alle Buchstaben der Zeile
    double totalWeight = 0.0;
    for (int i = 0; i < codeUnitsLen; i++) {
      final w = _charSingingWeight(text[i]);
      weights[i] = w;
      totalWeight += w;
    }
    if (totalWeight <= 0) totalWeight = 1.0;

    final rawStates = <LyricCharState>[];
    double cumulative = 0.0;
    int activeIdx = -1;

    for (int i = 0; i < codeUnitsLen; i++) {
      final charStart = cumulative / totalWeight;
      cumulative += weights[i];
      final charEnd = cumulative / totalWeight;
      final span = math.max(0.0001, charEnd - charStart);
      final charProgress = ((rawLineProgress - charStart) / span).clamp(0.0, 1.0);

      if (charProgress > 0.0) {
        activeIdx = i;
      }

      rawStates.add(LyricCharState(
        char: text[i],
        index: i,
        progress: charProgress,
      ));
    }

    return _finalizeSnapshot(
      rawLineProgress: rawLineProgress,
      rawStates: rawStates,
      activeIdx: activeIdx,
    );
  }

  LyricLineSnapshot _finalizeSnapshot({
    required double rawLineProgress,
    required List<LyricCharState> rawStates,
    required int activeIdx,
  }) {
    final fullStr = rawStates.map((e) => e.char).join();
    final updatedStates = <LyricCharState>[];
    for (int i = 0; i < rawStates.length; i++) {
      final s = rawStates[i];
      // Der aktuell buchstabierte Buchstabe (und sein unmittelbarer Nachbar für weichen Übergang)
      final isCurrent = (i == activeIdx && rawLineProgress > 0.0 && rawLineProgress < 1.0);
      updatedStates.add(LyricCharState(
        char: s.char,
        index: s.index,
        progress: s.progress,
        isCurrentActiveLetter: isCurrent,
      ));
    }

    final splitPos = activeIdx < 0 ? 0 : math.min(fullStr.length, activeIdx + 1);
    final spelled = fullStr.substring(0, splitPos);
    final remaining = fullStr.substring(splitPos);

    // Ermittle das aktuell gesungene Wort für das Buchstabier-HUD
    String activeWord = '';
    String activeWordSpelled = '';
    if (fullStr.isNotEmpty) {
      final cursor = activeIdx.clamp(0, fullStr.length - 1);
      int wordStart = cursor;
      while (wordStart > 0 && fullStr[wordStart - 1] != ' ') {
        wordStart--;
      }
      int wordEnd = cursor;
      while (wordEnd < fullStr.length && fullStr[wordEnd] != ' ') {
        wordEnd++;
      }
      activeWord = fullStr.substring(wordStart, wordEnd).trim();
      final spelledEnd = splitPos.clamp(wordStart, wordEnd);
      activeWordSpelled = fullStr.substring(wordStart, spelledEnd).trim();
    }

    return LyricLineSnapshot(
      lineProgress: rawLineProgress,
      chars: updatedStates,
      activeCharIndex: activeIdx,
      spelledText: spelled,
      remainingText: remaining,
      activeWord: activeWord,
      activeWordSpelled: activeWordSpelled,
    );
  }

  @override
  String toString() => '[${timestamp.inSeconds}s] $text';
}
