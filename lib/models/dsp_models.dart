class DspBand {
  final double frequency;
  final double gain;
  final double q;
  final String type;
  final bool enabled;
  final String channel;

  const DspBand({
    required this.frequency,
    required this.gain,
    this.q = 1.4,
    this.type = 'peak',
    this.enabled = true,
    this.channel = 'ALL',
  });

  DspBand copyWith({
    double? frequency,
    double? gain,
    double? q,
    String? type,
    bool? enabled,
    String? channel,
  }) {
    return DspBand(
      frequency: frequency ?? this.frequency,
      gain: gain ?? this.gain,
      q: q ?? this.q,
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      channel: channel ?? this.channel,
    );
  }

  factory DspBand.fromJson(Map<String, dynamic> json) {
    return DspBand(
      frequency: (json['frequency'] as num?)?.toDouble() ?? 1000.0,
      gain: (json['gain'] as num?)?.toDouble() ?? 0.0,
      q: (json['q'] as num?)?.toDouble() ?? 1.4,
      type: json['type'] as String? ?? 'peak',
      enabled: json['enabled'] as bool? ?? true,
      channel: json['channel'] as String? ?? 'ALL',
    );
  }

  Map<String, dynamic> toJson() => {
    'frequency': frequency,
    'gain': gain,
    'q': q,
    'type': type,
    'enabled': enabled,
    'channel': channel,
  };

  String get formattedFreq {
    if (frequency >= 1000) {
      final khz = frequency / 1000;
      return '${khz.toStringAsFixed(khz.truncateToDouble() == khz ? 0 : 1)} kHz';
    }
    return '${frequency.round()} Hz';
  }
}

class DspFilter {
  final String type;
  final bool enabled;
  final double preamp;
  final Map<String, dynamic> perChannelPreamp;
  final List<DspBand> bands;
  final Map<String, dynamic> raw;

  const DspFilter({
    required this.type,
    this.enabled = true,
    this.preamp = 0.0,
    this.perChannelPreamp = const {},
    this.bands = const [],
    this.raw = const {},
  });

  DspFilter copyWith({
    String? type,
    bool? enabled,
    double? preamp,
    Map<String, dynamic>? perChannelPreamp,
    List<DspBand>? bands,
    Map<String, dynamic>? raw,
  }) {
    return DspFilter(
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      preamp: preamp ?? this.preamp,
      perChannelPreamp: perChannelPreamp ?? this.perChannelPreamp,
      bands: bands ?? this.bands,
      raw: raw ?? this.raw,
    );
  }

  factory DspFilter.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    final bandsList = (json['bands'] as List<dynamic>?)
            ?.map((b) => DspBand.fromJson(Map<String, dynamic>.from(b as Map)))
            .toList() ??
        [];
    final perChannel = json['per_channel_preamp'] is Map
        ? Map<String, dynamic>.from(json['per_channel_preamp'] as Map)
        : const <String, dynamic>{};
    return DspFilter(
      type: type,
      enabled: json['enabled'] as bool? ?? true,
      preamp: (json['preamp'] as num?)?.toDouble() ?? 0.0,
      perChannelPreamp: perChannel,
      bands: bandsList,
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    final map = Map<String, dynamic>.from(raw);
    map['type'] = type;
    map['enabled'] = enabled;
    if (type == 'parametric_eq') {
      map['preamp'] = preamp;
      map['per_channel_preamp'] = perChannelPreamp;
      map['bands'] = bands.map((b) => b.toJson()).toList();
    }
    return map;
  }
}

class DspConfig {
  final bool enabled;
  final double inputGain;
  final double outputGain;
  final String? presetId;
  final List<DspFilter> filters;

  const DspConfig({
    this.enabled = false,
    this.inputGain = 0.0,
    this.outputGain = 0.0,
    this.presetId,
    this.filters = const [],
  });

  DspFilter? get parametricEqFilter {
    try {
      return filters.firstWhere((f) => f.type == 'parametric_eq');
    } catch (_) {
      return null;
    }
  }

  List<DspBand> get bands => parametricEqFilter?.bands ?? const [];
  double get preamp => parametricEqFilter?.preamp ?? 0.0;

  DspConfig copyWith({
    bool? enabled,
    double? inputGain,
    double? outputGain,
    String? presetId,
    List<DspFilter>? filters,
  }) {
    return DspConfig(
      enabled: enabled ?? this.enabled,
      inputGain: inputGain ?? this.inputGain,
      outputGain: outputGain ?? this.outputGain,
      presetId: presetId ?? this.presetId,
      filters: filters ?? this.filters,
    );
  }

  factory DspConfig.fromJson(Map<String, dynamic> json) {
    final filtersList = (json['filters'] as List<dynamic>?)
            ?.map((f) => DspFilter.fromJson(Map<String, dynamic>.from(f as Map)))
            .toList() ??
        [];
    return DspConfig(
      enabled: json['enabled'] as bool? ?? false,
      inputGain: (json['input_gain'] as num?)?.toDouble() ?? 0.0,
      outputGain: (json['output_gain'] as num?)?.toDouble() ?? 0.0,
      presetId: json['preset_id'] as String?,
      filters: filtersList,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'input_gain': inputGain,
        'output_gain': outputGain,
        'preset_id': presetId,
        'filters': filters.map((f) => f.toJson()).toList(),
      };

  static DspConfig defaultFlat() {
    return const DspConfig(
      enabled: true,
      inputGain: 0.0,
      outputGain: 0.0,
      filters: [
        DspFilter(
          type: 'parametric_eq',
          enabled: true,
          preamp: 0.0,
          bands: [
            DspBand(frequency: 60.0, gain: 0.0, q: 1.4),
            DspBand(frequency: 230.0, gain: 0.0, q: 1.4),
            DspBand(frequency: 910.0, gain: 0.0, q: 1.4),
            DspBand(frequency: 4000.0, gain: 0.0, q: 1.4),
            DspBand(frequency: 14000.0, gain: 0.0, q: 1.4),
          ],
        ),
      ],
    );
  }
}

class DspPreset {
  final String presetId;
  final String name;
  final DspConfig config;

  const DspPreset({
    required this.presetId,
    required this.name,
    required this.config,
  });

  factory DspPreset.fromJson(Map<String, dynamic> json) {
    final cfgMap = json['config'] is Map
        ? Map<String, dynamic>.from(json['config'] as Map)
        : <String, dynamic>{};
    return DspPreset(
      presetId: json['preset_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unbenanntes Preset',
      config: DspConfig.fromJson(cfgMap),
    );
  }
}
