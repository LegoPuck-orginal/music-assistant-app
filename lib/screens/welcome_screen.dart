import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'welcome_guide_screen.dart';

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
  bool _isTesting = false;
  String? _testMessage;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final prov = context.read<MusicProvider>();
    _serverController = TextEditingController(
      text: prov.serverUrl.isNotEmpty
          ? prov.serverUrl
          : 'http://homeassistant.local:8095',
    );
    _usernameController = TextEditingController(
      text: prov.currentUser?.username.isNotEmpty == true
          ? prov.currentUser!.username
          : '',
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

  Future<void> _handleTestConnection() async {
    final server = _serverController.text.trim();
    if (server.isEmpty) {
      _showErrorSnackBar('Bitte gib eine Server-Adresse ein.');
      return;
    }
    setState(() {
      _isTesting = true;
      _testMessage = null;
      _testSuccess = null;
    });

    final prov = context.read<MusicProvider>();
    final res = await prov.testServerConnection(server);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      if (res['success'] == true) {
        _testSuccess = true;
        _testMessage =
            '✓ Verbunden! Music Assistant v${res['serverVersion'] ?? '2.x'} ist erreichbar.';
      } else {
        _testSuccess = false;
        _testMessage = '✗ ${res['error'] ?? 'Server antwortet nicht.'}';
      }
    });
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
              backgroundColor: SpotifyColors.orange,
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
                // App Icon with subtle glow
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: SpotifyColors.green.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: SpotifyColors.surfaceElevated,
                          child: const Icon(
                            Icons.graphic_eq,
                            color: SpotifyColors.green,
                            size: 46,
                          ),
                        ),
                      ),
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
                    hint: 'z. B. admin oder dein Name',
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _serverController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration(
                            hint: 'http://homeassistant.local:8095',
                            icon: Icons.dns_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SpotifyColors.surfaceHighlight,
                            foregroundColor: SpotifyColors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isTesting ? null : _handleTestConnection,
                          child: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        SpotifyColors.orange),
                                  ),
                                )
                              : const Text('Testen',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  if (_testMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _testSuccess == true
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _testMessage!,
                        style: TextStyle(
                          color: _testSuccess == true
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // Login Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpotifyColors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shadowColor: SpotifyColors.orange.withValues(alpha: 0.4),
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
                const SizedBox(height: 14),

                // Button: Willkommens-Guide öffnen
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SpotifyColors.orange,
                    side: const BorderSide(color: SpotifyColors.surfaceHighlight),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const WelcomeGuideScreen(isStandalone: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.explore_rounded, size: 18),
                  label: const Text(
                    'Willkommens-Guide & Server-Assistent',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
