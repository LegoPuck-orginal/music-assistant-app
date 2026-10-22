class UserProfile {
  final String userId;
  final String username;
  final String? displayName;
  final String role;
  final String? avatarUrl;

  const UserProfile({
    required this.userId,
    required this.username,
    this.displayName,
    this.role = 'user',
    this.avatarUrl,
  });

  String get effectiveName =>
      (displayName != null && displayName!.isNotEmpty) ? displayName! : username;

  bool get isAdmin => role.toLowerCase() == 'admin';

  UserProfile copyWith({
    String? userId,
    String? username,
    String? displayName,
    String? role,
    String? avatarUrl,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      displayName: json['display_name']?.toString(),
      role: json['role']?.toString() ?? 'user',
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'display_name': displayName,
        'role': role,
        'avatar_url': avatarUrl,
      };
}
