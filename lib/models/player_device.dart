class PlayerDevice {
  final String id;
  final String name;
  final String type; // Sonos, AirPlay, Chromecast, iPhone, etc.
  int volume; // 0 - 100
  bool isMuted;
  String state; // playing, paused, idle
  bool isSelected;

  PlayerDevice({
    required this.id,
    required this.name,
    required this.type,
    this.volume = 50,
    this.isMuted = false,
    this.state = 'idle',
    this.isSelected = false,
  });

  bool get isLocal => id == 'local_iphone';

  factory PlayerDevice.localIPhone({bool isSelected = false, int volume = 60}) {
    return PlayerDevice(
      id: 'local_iphone',
      name: 'Dieses iPhone (Lautsprecher / Kopfhörer)',
      type: 'iPhone',
      volume: volume,
      isSelected: isSelected,
    );
  }

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
