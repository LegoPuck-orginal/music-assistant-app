class EqualizerSettings {
  bool isEnabled;
  String currentPreset;
  List<double> bandGains; // 5 bands in dB: [-12.0 ... +12.0]

  // Frequencies for the 5 bands
  static const List<String> bandLabels = [
    '60 Hz',
    '230 Hz',
    '910 Hz',
    '3.6 kHz',
    '14 kHz',
  ];

  static const List<String> bandDescriptions = [
    'Sub-Bass',
    'Bass',
    'Mitten',
    'Präsenz',
    'Höhen',
  ];

  static const Map<String, List<double>> presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Booster': [6.0, 4.5, 1.0, 0.0, -1.0],
    'Treble Booster': [-1.0, 0.0, 1.5, 4.5, 6.0],
    'Electronic': [5.0, 3.5, 0.0, 2.5, 4.5],
    'Rock': [4.5, 2.5, -1.0, 2.0, 4.0],
    'Pop': [-1.0, 1.5, 3.5, 2.0, -1.0],
    'Vocal Booster': [-2.0, 0.0, 4.5, 3.0, 1.0],
    'Acoustic': [3.5, 2.0, 1.0, 2.5, 3.0],
    'Hip-Hop': [6.5, 4.0, 0.0, 1.5, 3.5],
    'Custom': [0.0, 0.0, 0.0, 0.0, 0.0],
  };

  EqualizerSettings({
    this.isEnabled = true,
    this.currentPreset = 'Flat',
    List<double>? bandGains,
  }) : bandGains = bandGains ?? [0.0, 0.0, 0.0, 0.0, 0.0];

  void applyPreset(String presetName) {
    if (presets.containsKey(presetName)) {
      currentPreset = presetName;
      bandGains = List<double>.from(presets[presetName]!);
    }
  }

  void setBandGain(int index, double gain) {
    if (index >= 0 && index < bandGains.length) {
      bandGains[index] = gain.clamp(-12.0, 12.0);
      currentPreset = 'Custom';
    }
  }

  EqualizerSettings copyWith({
    bool? isEnabled,
    String? currentPreset,
    List<double>? bandGains,
  }) {
    return EqualizerSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      currentPreset: currentPreset ?? this.currentPreset,
      bandGains: bandGains != null ? List<double>.from(bandGains) : List<double>.from(this.bandGains),
    );
  }
}
