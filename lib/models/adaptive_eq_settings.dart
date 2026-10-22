import 'dart:convert';
import 'player_device.dart';
import 'track.dart';

/// Modi für den adaptiven Equalizer
enum AdaptiveEqMode {
  /// Voll-Adaptiv: Kombiniert dynamische Loudness, Genre-Erkennung & Geräte-Profil
  auto,

  /// Fletcher-Munson Dynamic Loudness: Passt Sub-Bass und Höhen dynamisch an die Hörlautstärke an
  dynamicLoudness,

  /// Auto-Genre: Passt Frequenzen automatisch an die Art des aktuellen Songs an
  genreDynamic,

  /// Nacht-Modus: Zähmt tiefe Bassvibrationen, hebt Sprachverständlichkeit hervor
  nightComfort,

  /// Gehörschutz & Anti-Fatigue: Glättet schrille Resonanzen bei hoher Lautstärke
  hearingProtection,
}

/// Detaillierte Einstellungen für den Adaptiven Equalizer
class AdaptiveEqSettings {
  final bool isEnabled;
  final AdaptiveEqMode mode;
  final double intensity; // 0.0 bis 1.0 (wie stark eingegriffen wird, Standard 0.75)
  final bool enableBassProtection; // Verhindert Übersteuern bei hoher Lautstärke
  final bool enableDeviceAdaptation; // Passt Klang an (iPhone Speaker vs. Sonos vs. AirPods)

  const AdaptiveEqSettings({
    this.isEnabled = true,
    this.mode = AdaptiveEqMode.auto,
    this.intensity = 0.75,
    this.enableBassProtection = true,
    this.enableDeviceAdaptation = true,
  });

  AdaptiveEqSettings copyWith({
    bool? isEnabled,
    AdaptiveEqMode? mode,
    double? intensity,
    bool? enableBassProtection,
    bool? enableDeviceAdaptation,
  }) {
    return AdaptiveEqSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      mode: mode ?? this.mode,
      intensity: intensity ?? this.intensity,
      enableBassProtection: enableBassProtection ?? this.enableBassProtection,
      enableDeviceAdaptation:
          enableDeviceAdaptation ?? this.enableDeviceAdaptation,
    );
  }

  /// Berechnet dynamische dB-Korrekturen für die 5 Frequenzbänder:
  /// [0: 60Hz (Sub-Bass), 1: 230Hz (Bass), 2: 910Hz (Mitten), 3: 4kHz (Präsenz), 4: 14kHz (Höhen)]
  List<double> calculateCorrections({
    required int volume, // 0 bis 100
    Track? currentTrack,
    PlayerDevice? activePlayer,
  }) {
    if (!isEnabled) {
      return [0.0, 0.0, 0.0, 0.0, 0.0];
    }

    double dSubBass = 0.0;
    double dBass = 0.0;
    double dMids = 0.0;
    double dPresence = 0.0;
    double dTreble = 0.0;

    final normVol = (volume / 100.0).clamp(0.0, 1.0);

    // 1. Fletcher-Munson Dynamic Loudness (ISO 226 Equal-Loudness Contour)
    // Bei niedriger Lautstärke hört das menschliche Gehör Bässe und Höhen viel schwächer.
    if (mode == AdaptiveEqMode.auto || mode == AdaptiveEqMode.dynamicLoudness) {
      if (normVol < 0.65) {
        final loudnessFactor = (0.65 - normVol) / 0.65; // 0.0 bis 1.0
        dSubBass += loudnessFactor * 6.5; // Bis zu +6.5 dB Subbass bei Flüsterlautstärke
        dBass += loudnessFactor * 4.0;
        dTreble += loudnessFactor * 3.5; // Höhen-Frische
        dPresence += loudnessFactor * 1.0;
      } else if (normVol > 0.85) {
        // Bei sehr hoher Lautstärke Bässe leicht zurücknehmen, um Gehör & Boxen zu schützen
        final highVolFactor = (normVol - 0.85) / 0.15;
        dSubBass -= highVolFactor * 2.0;
        dPresence -= highVolFactor * 1.5;
      }
    }

    // 2. Genre & Content Dynamics Adaptation
    if (mode == AdaptiveEqMode.auto || mode == AdaptiveEqMode.genreDynamic) {
      final title = currentTrack?.title.toLowerCase() ?? '';
      final artist = currentTrack?.artist.toLowerCase() ?? '';
      final album = currentTrack?.album.toLowerCase() ?? '';
      final text = '$title $artist $album';

      if (text.contains('rock') ||
          text.contains('metal') ||
          text.contains('queen') ||
          text.contains('guitar') ||
          text.contains('riff')) {
        // Rock Profil: Dynamischer Kickbass, warme Tiefmitten, präsente Lead-Gitarren
        dSubBass += 1.5;
        dBass += 3.0;
        dMids -= 1.0;
        dPresence += 2.5;
        dTreble += 2.0;
      } else if (text.contains('techno') ||
          text.contains('edm') ||
          text.contains('dance') ||
          text.contains('electronic') ||
          text.contains('remix') ||
          text.contains('club')) {
        // EDM Profil: Mächtiger Subbass, Punch, klare kristalline Höhen
        dSubBass += 4.5;
        dBass += 2.5;
        dMids -= 1.5;
        dPresence += 1.0;
        dTreble += 4.0;
      } else if (text.contains('hip hop') ||
          text.contains('rap') ||
          text.contains('beat') ||
          text.contains('trap') ||
          text.contains('bass')) {
        // Hip-Hop Profil: Tiefe 808-Bässe, klare Vocals
        dSubBass += 5.0;
        dBass += 2.5;
        dMids += 1.0;
        dPresence += 2.0;
        dTreble += 1.5;
      } else if (text.contains('acoustic') ||
          text.contains('unplugged') ||
          text.contains('piano') ||
          text.contains('folk') ||
          text.contains('jazz')) {
        // Akustik Profil: Natürliche Mitten, samtige Höhen, dezenter Subbass
        dSubBass -= 1.0;
        dBass += 1.0;
        dMids += 2.5;
        dPresence += 2.0;
        dTreble += 2.5;
      } else if (text.contains('podcast') ||
          text.contains('talk') ||
          text.contains('audiobook') ||
          text.contains('folge') ||
          text.contains('interview')) {
        // Sprach / Podcast Profil: Stimmen-Verständlichkeit maximieren, Rumpeln filtern
        dSubBass -= 4.0;
        dBass -= 2.0;
        dMids += 4.0;
        dPresence += 3.5;
        dTreble -= 1.0;
      }
    }

    // 3. Nacht-Modus (Night Comfort)
    if (mode == AdaptiveEqMode.nightComfort) {
      dSubBass -= 5.0; // Bässe die durch Wände dringen stark absenken
      dBass -= 2.5;
      dMids += 2.5; // Dialoge und Gesang verständlich halten
      dPresence += 1.5;
      dTreble -= 2.0; // Sanfte, nicht ermüdende Höhen
    }

    // 4. Gehörschutz & Anti-Fatigue
    if (mode == AdaptiveEqMode.hearingProtection) {
      dPresence -= 3.0; // Schrille Frequenzen dämpfen
      dTreble -= 2.5;
      dMids += 1.0;
    }

    // 5. Speaker / Device Acoustic Profiling
    if (enableDeviceAdaptation && activePlayer != null) {
      if (activePlayer.isLocal) {
        // iPhone Lautsprecher: Kann physikalisch keinen echten Subbass (<80Hz) wiedergeben
        // Verhindert Scheppern und maximiert Lautstärke & Klarheit
        dSubBass -= 3.5;
        dBass += 1.5;
        dMids += 2.5;
        dPresence += 2.0;
      } else if (activePlayer.type.toLowerCase().contains('sonos') ||
          activePlayer.name.toLowerCase().contains('sonos') ||
          activePlayer.type.toLowerCase().contains('airplay')) {
        // Hochwertige Hi-Fi Lautsprecher: Ausnutzen der vollen Dynamik
        dSubBass += 1.5;
        dBass += 1.0;
        dTreble += 1.5;
      }
    }

    // 6. Intensitäts-Gewichtung & Sicherheitsgrenzen
    final scale = intensity.clamp(0.0, 1.0);
    return [
      (dSubBass * scale).clamp(-8.0, 8.0),
      (dBass * scale).clamp(-6.0, 6.0),
      (dMids * scale).clamp(-5.0, 5.0),
      (dPresence * scale).clamp(-5.0, 5.0),
      (dTreble * scale).clamp(-6.0, 6.0),
    ];
  }

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'mode': mode.name,
        'intensity': intensity,
        'enableBassProtection': enableBassProtection,
        'enableDeviceAdaptation': enableDeviceAdaptation,
      };

  factory AdaptiveEqSettings.fromJson(Map<String, dynamic> json) {
    AdaptiveEqMode parseMode(String? val) {
      return AdaptiveEqMode.values.firstWhere(
        (m) => m.name == val,
        orElse: () => AdaptiveEqMode.auto,
      );
    }

    return AdaptiveEqSettings(
      isEnabled: json['isEnabled'] as bool? ?? true,
      mode: parseMode(json['mode']),
      intensity: (json['intensity'] as num?)?.toDouble() ?? 0.75,
      enableBassProtection: json['enableBassProtection'] as bool? ?? true,
      enableDeviceAdaptation: json['enableDeviceAdaptation'] as bool? ?? true,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AdaptiveEqSettings.fromJsonString(String str) {
    try {
      return AdaptiveEqSettings.fromJson(
          jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return const AdaptiveEqSettings();
    }
  }
}
