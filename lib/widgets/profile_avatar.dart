import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/spotify_colors.dart';

class ProfileAvatar extends StatelessWidget {
  final UserProfile? user;
  final double radius;
  final VoidCallback? onTap;
  final bool showEditBadge;

  const ProfileAvatar({
    super.key,
    required this.user,
    this.radius = 20,
    this.onTap,
    this.showEditBadge = false,
  });

  static const Map<String, AvatarPreset> presets = {
    'preset:dj_neon': AvatarPreset(
      id: 'preset:dj_neon',
      name: 'DJ Pulse',
      icon: Icons.graphic_eq,
      gradient: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
    ),
    'preset:vinyl': AvatarPreset(
      id: 'preset:vinyl',
      name: 'Vinyl Master',
      icon: Icons.album,
      gradient: [Color(0xFFFFB75E), Color(0xFFED8F03)],
    ),
    'preset:cassette': AvatarPreset(
      id: 'preset:cassette',
      name: 'Retro Tape',
      icon: Icons.radio,
      gradient: [Color(0xFFF857A6), Color(0xFFFF5858)],
    ),
    'preset:headphones': AvatarPreset(
      id: 'preset:headphones',
      name: 'Audiophil',
      icon: Icons.headphones,
      gradient: [SpotifyColors.orange, Color(0xFF191414)],
    ),
    'preset:rocker': AvatarPreset(
      id: 'preset:rocker',
      name: 'Rock Star',
      icon: Icons.electric_bolt,
      gradient: [Color(0xFF7F00FF), Color(0xFFE100FF)],
    ),
    'preset:astronaut': AvatarPreset(
      id: 'preset:astronaut',
      name: 'Space Walker',
      icon: Icons.rocket_launch,
      gradient: [Color(0xFF1CB5E0), Color(0xFF000046)],
    ),
    'preset:cyberpunk': AvatarPreset(
      id: 'preset:cyberpunk',
      name: 'Cyberpunk',
      icon: Icons.auto_awesome,
      gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    'preset:flame': AvatarPreset(
      id: 'preset:flame',
      name: 'Hot Tracks',
      icon: Icons.local_fire_department,
      gradient: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final avatar = user?.avatarUrl;
    Widget avatarContent;

    if (avatar != null && avatar.startsWith('preset:') && presets.containsKey(avatar)) {
      final preset = presets[avatar]!;
      avatarContent = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: preset.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            preset.icon,
            color: Colors.white,
            size: radius * 1.1,
          ),
        ),
      );
    } else if (avatar != null && avatar.startsWith('http')) {
      avatarContent = ClipOval(
        child: Image.network(
          avatar,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackInitial(),
        ),
      );
    } else {
      avatarContent = _buildFallbackInitial();
    }

    Widget child = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: SpotifyColors.surfaceHighlight,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: avatarContent,
    );

    if (showEditBadge) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: SpotifyColors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                size: 11,
                color: Colors.black,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: child,
      );
    }

    return child;
  }

  Widget _buildFallbackInitial() {
    final initial = (user?.effectiveName.isNotEmpty == true)
        ? user!.effectiveName[0].toUpperCase()
        : 'M';
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [SpotifyColors.orange, SpotifyColors.orangeLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: radius * 0.9,
          ),
        ),
      ),
    );
  }
}

class AvatarPreset {
  final String id;
  final String name;
  final IconData icon;
  final List<Color> gradient;

  const AvatarPreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradient,
  });
}
