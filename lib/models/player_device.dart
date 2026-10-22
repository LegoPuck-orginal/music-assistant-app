class PlayerDevice {
  final String id;
  final String name;
  final String type; // Sonos, AirPlay, Chromecast, Snapcast, Local, etc.
  int volume; // 0 - 100
  bool isMuted;
  String state; // playing, paused, idle
  bool isSelected;

  PlayerDevice({
    required this.id,
    required this.name,
    required this.type,
    this.volume = 40,
    this.isMuted = false,
    this.state = 'idle',
    this.isSelected = false,
  });

  PlayerDevice copyWith({
    String? id,
    String? name,
    String? type,
    int? volume,
    bool? isMuted,
    String? state,
    bool? isSelected,
  }) {
    return PlayerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      state: state ?? this.state,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
