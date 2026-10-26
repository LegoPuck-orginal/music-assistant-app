class PlayerDevice {
  final String id;
  final String name;
  final String type; // Sonos, AirPlay, Chromecast, iPhone, etc.
  int volume; // 0 - 100
  bool isMuted;
  String state; // playing, paused, idle
  bool isSelected;
  bool isAvailable;
  final String? syncedTo;
  final List<String> groupChilds;
  final List<String> canSyncWith;

  // Live Wiedergabedaten für Multiroom-Überwachung & Steuerung
  final String? currentTitle;
  final String? currentArtist;
  final String? currentAlbum;
  final String? currentImageUrl;
  final int? currentDurationSeconds;
  final int? elapsedTimeSeconds;
  final String? currentUri;

  PlayerDevice({
    required this.id,
    required this.name,
    required this.type,
    this.volume = 50,
    this.isMuted = false,
    this.state = 'idle',
    this.isSelected = false,
    this.isAvailable = true,
    this.syncedTo,
    this.groupChilds = const [],
    this.canSyncWith = const [],
    this.currentTitle,
    this.currentArtist,
    this.currentAlbum,
    this.currentImageUrl,
    this.currentDurationSeconds,
    this.elapsedTimeSeconds,
    this.currentUri,
  });

  bool get isLocal => id == 'local_iphone';
  bool get isSynced => syncedTo != null && syncedTo!.isNotEmpty;
  bool get isGroupLeader => groupChilds.isNotEmpty;
  bool get isPlaying => state == 'playing';
  bool get hasActiveTrack => currentTitle != null && currentTitle!.isNotEmpty;

  factory PlayerDevice.localIPhone({bool isSelected = false, int volume = 60}) {
    return PlayerDevice(
      id: 'local_iphone',
      name: 'Dieses iPhone (Sendspin Hi-Fi Player)',
      type: 'iPhone',
      volume: volume,
      isSelected: isSelected,
      isAvailable: true,
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
    bool? isAvailable,
    String? syncedTo,
    List<String>? groupChilds,
    List<String>? canSyncWith,
    String? currentTitle,
    String? currentArtist,
    String? currentAlbum,
    String? currentImageUrl,
    int? currentDurationSeconds,
    int? elapsedTimeSeconds,
    String? currentUri,
  }) {
    return PlayerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      state: state ?? this.state,
      isSelected: isSelected ?? this.isSelected,
      isAvailable: isAvailable ?? this.isAvailable,
      syncedTo: syncedTo ?? this.syncedTo,
      groupChilds: groupChilds ?? this.groupChilds,
      canSyncWith: canSyncWith ?? this.canSyncWith,
      currentTitle: currentTitle ?? this.currentTitle,
      currentArtist: currentArtist ?? this.currentArtist,
      currentAlbum: currentAlbum ?? this.currentAlbum,
      currentImageUrl: currentImageUrl ?? this.currentImageUrl,
      currentDurationSeconds: currentDurationSeconds ?? this.currentDurationSeconds,
      elapsedTimeSeconds: elapsedTimeSeconds ?? this.elapsedTimeSeconds,
      currentUri: currentUri ?? this.currentUri,
    );
  }
}
