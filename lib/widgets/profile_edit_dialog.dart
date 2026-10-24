import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'profile_avatar.dart';

class ProfileEditDialog extends StatefulWidget {
  const ProfileEditDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ProfileEditDialog(),
    );
  }

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _urlCtrl;
  String? _selectedAvatar;

  @override
  void initState() {
    super.initState();
    final user = context.read<MusicProvider>().currentUser;
    _nameCtrl = TextEditingController(text: user?.displayName ?? user?.username ?? '');
    _urlCtrl = TextEditingController(
      text: (user?.avatarUrl != null && user!.avatarUrl!.startsWith('http'))
          ? user.avatarUrl
          : '',
    );
    _selectedAvatar = user?.avatarUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final user = prov.currentUser;
    final tempUser = (user ?? const UserProfile(userId: 'local', username: 'Musikfreund')).copyWith(
      displayName: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : null,
      avatarUrl: _selectedAvatar,
    );

    return Dialog(
      backgroundColor: SpotifyColors.surfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profil & Avatar bearbeiten',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: SpotifyColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Live Preview Avatar
              ProfileAvatar(
                user: tempUser,
                radius: 46,
              ),
              const SizedBox(height: 10),
              Text(
                tempUser.effectiveName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Benutzerkonto: @${user?.username ?? "user"} • ${user?.role ?? "Hörer"}',
                style: const TextStyle(
                  color: SpotifyColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),

              // Display Name Field
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Anzeigename',
                  labelStyle: const TextStyle(color: SpotifyColors.textSecondary),
                  prefixIcon: const Icon(Icons.person, color: SpotifyColors.green, size: 20),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Preset Avatars Selection
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WÄHLE EINEN AVATAR-STIL',
                  style: TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ProfileAvatar.presets.entries.map((entry) {
                  final preset = entry.value;
                  final isSelected = _selectedAvatar == preset.id;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedAvatar = preset.id;
                        _urlCtrl.clear();
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: preset.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: preset.gradient.first.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          preset.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Custom Image URL Field
              TextField(
                controller: _urlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) {
                  setState(() {
                    if (val.trim().isNotEmpty) {
                      _selectedAvatar = val.trim();
                    }
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Oder eigenes Bild (Bild-URL)',
                  hintText: 'https://beispiel.de/mein-foto.jpg',
                  hintStyle: const TextStyle(color: SpotifyColors.textMuted, fontSize: 12),
                  labelStyle: const TextStyle(color: SpotifyColors.textSecondary),
                  prefixIcon: const Icon(Icons.link, color: SpotifyColors.green, size: 20),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Abbrechen',
                        style: TextStyle(color: SpotifyColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpotifyColors.green,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final newName = _nameCtrl.text.trim();
                        final newAvatar = _selectedAvatar;
                        await prov.updateUserProfile(
                          displayName: newName.isNotEmpty ? newName : null,
                          avatarUrl: newAvatar,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profilbild & Daten erfolgreich aktualisiert!'),
                              backgroundColor: SpotifyColors.surfaceHighlight,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'Speichern',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
