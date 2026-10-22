import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final TextEditingController _serverController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _showAdvancedServer = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<MusicProvider>();
    _serverController = TextEditingController(
      text: prov.serverUrl.isNotEmpty
          ? prov.serverUrl
          : 'http://192.168.188.25:8095',
    );
    _usernameController = TextEditingController(
      text: prov.currentUser?.username.isNotEmpty == true
          ? prov.currentUser!.username
          : 'tim-m',
    );
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (server.isEmpty) {
      _showErrorSnackBar('Bitte gib eine Server-Adresse ein.');
      return;
    }
    if (username.isEmpty) {
      _showErrorSnackBar('Bitte gib deinen Benutzernamen ein.');
      return;
    }

    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    final prov = context.read<MusicProvider>();
    await prov.login(
      serverUrl: server,
      username: username,
      password: password,
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent.shade700,
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showTokenLoginDialog() {
    final tokenController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpotifyColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mit API-Token anmelden',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Falls du einen langlebigen Admin- oder API-Token besitzt, kannst du diesen hier direkt eingeben:',
              style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: tokenController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'JWT Access Token einfügen...',
                hintStyle: const TextStyle(color: SpotifyColors.textMuted),
                filled: true,
                fillColor: SpotifyColors.surfaceHighlight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen',
                style: TextStyle(color: SpotifyColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotifyColors.green,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final token = tokenController.text.trim();
              if (token.isNotEmpty) {
                Navigator.pop(ctx);
                final prov = context.read<MusicProvider>();
                prov.updateServerSettings(_serverController.text.trim(), token);
              }
            },
            child: const Text('Token speichern',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final isLoggingIn = prov.isLoggingIn;
    final loginError = prov.loginError;

    return Scaffold(
      backgroundColor: SpotifyColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glowing Music Icon
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          SpotifyColors.green.withValues(alpha: 0.35),
                          SpotifyColors.surfaceElevated,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SpotifyColors.green.withValues(alpha: 0.3),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: SpotifyColors.green,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.graphic_eq,
                      color: SpotifyColors.green,
                      size: 46,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Welcome Typography
                const Center(
                  child: Text(
                    'MUSIC ASSISTANT',
                    style: TextStyle(
                      color: SpotifyColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Musik ohne Grenzen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Melde dich mit deinem Benutzerkonto an, um Lautsprecher, Playlists und DSP zu steuern.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Error Banner
                if (loginError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loginError,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Username Input
                _buildInputLabel('BENUTZERNAME'),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameController,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: _inputDecoration(
                    hint: 'z. B. tim-m',
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 18),

                // Password Input
                _buildInputLabel('PASSWORT'),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: _inputDecoration(
                    hint: 'Dein Passwort',
                    icon: Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: SpotifyColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Server URL Toggle
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAdvancedServer = !_showAdvancedServer;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _showAdvancedServer
                            ? 'Server-Adresse verbergen'
                            : 'Server-Adresse anpassen (${_cleanServerDisplay(_serverController.text)})',
                        style: const TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _showAdvancedServer
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: SpotifyColors.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                ),

                if (_showAdvancedServer) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: _inputDecoration(
                      hint: 'http://192.168.188.25:8095',
                      icon: Icons.dns_outlined,
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Login Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpotifyColors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shadowColor: SpotifyColors.green.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: isLoggingIn ? null : _handleLogin,
                  child: isLoggingIn
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'Anmelden',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
                const SizedBox(height: 18),

                // Alternative Options
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        prov.continueAsGuest();
                      },
                      child: const Text(
                        'Als Gast / Offline ausprobieren',
                        style: TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Text('•',
                        style: TextStyle(color: SpotifyColors.textMuted)),
                    TextButton(
                      onPressed: _showTokenLoginDialog,
                      child: const Text(
                        'API-Token',
                        style: TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: SpotifyColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: SpotifyColors.textMuted, fontSize: 14),
      prefixIcon: Icon(icon, color: SpotifyColors.textSecondary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: SpotifyColors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SpotifyColors.surfaceHighlight,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: SpotifyColors.green,
          width: 1.5,
        ),
      ),
    );
  }

  String _cleanServerDisplay(String url) {
    return url.replaceFirst(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), '');
  }
}
