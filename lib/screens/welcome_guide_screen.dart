import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../services/mass_api_service.dart';
import '../theme/spotify_colors.dart';

/// Interaktiver Willkommens-Guide & Schritt-für-Schritt Server-Assistent
/// Ermöglicht automatische Netzwerkerkennung, Verbindungstest, Login
/// und sofortigen 1-Klick-Start im Demo- & Offline-Modus.
class WelcomeGuideScreen extends StatefulWidget {
  final bool isStandalone;

  const WelcomeGuideScreen({super.key, this.isStandalone = false});

  @override
  State<WelcomeGuideScreen> createState() => _WelcomeGuideScreenState();
}

class _WelcomeGuideScreenState extends State<WelcomeGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Server Setup Fields
  late final TextEditingController _serverController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _tokenController;

  bool _obscurePassword = true;
  bool _useTokenAuth = false;
  bool _isTestingConnection = false;
  bool _isDiscovering = false;
  String? _connectionTestResult;
  bool? _connectionSuccess;
  List<String> _discoveredServers = [];

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
    _tokenController = TextEditingController(text: prov.authToken);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _testConnection() async {
    final url = _serverController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _connectionSuccess = false;
        _connectionTestResult = 'Bitte gib eine Server-Adresse ein.';
      });
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
      _connectionSuccess = null;
    });

    try {
      final res = await MassApiService.testConnection(url);
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        if (res['success'] == true) {
          _connectionSuccess = true;
          _connectionTestResult =
              '✓ Verbunden! Music Assistant Server ist erreichbar (v${res['serverVersion'] ?? '2.x'}).';
        } else {
          _connectionSuccess = false;
          _connectionTestResult =
              '✗ ${res['error'] ?? 'Server antwortet nicht unter $url'}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTestingConnection = false;
        _connectionSuccess = false;
        _connectionTestResult = 'Fehler beim Verbindungstest: $e';
      });
    }
  }

  Future<void> _startDiscovery() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDiscovering = true;
      _discoveredServers.clear();
      _connectionTestResult = null;
    });

    try {
      final found = await MassApiService.discoverLocalServers();
      if (!mounted) return;
      setState(() {
        _isDiscovering = false;
        _discoveredServers = found;
        if (found.isNotEmpty) {
          _serverController.text = found.first;
          _connectionSuccess = true;
          _connectionTestResult =
              '✓ Server gefunden: ${found.first}';
        } else {
          _connectionTestResult =
              'Keine Server automatisch gefunden. Bitte trage die IP oder Domain manuell ein.';
          _connectionSuccess = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDiscovering = false;
        _connectionTestResult = 'Suchfehler: $e';
      });
    }
  }

  Future<void> _handleConnect() async {
    final prov = context.read<MusicProvider>();
    final server = _serverController.text.trim();

    if (server.isEmpty) {
      _showToast('Bitte eine Server-Adresse angeben.');
      return;
    }

    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();

    if (_useTokenAuth) {
      final token = _tokenController.text.trim();
      if (token.isEmpty) {
        _showToast('Bitte ein API-Token eingeben.');
        return;
      }
      await prov.updateServerSettings(server, token);
      await prov.completeWelcomeGuide();
      if (widget.isStandalone && mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final user = _usernameController.text.trim();
    final pass = _passwordController.text;

    if (user.isEmpty) {
      _showToast('Bitte einen Benutzernamen eingeben.');
      return;
    }

    await prov.login(
      serverUrl: server,
      username: user,
      password: pass,
    );

    if (prov.isAuthenticated) {
      await prov.completeWelcomeGuide();
      if (widget.isStandalone && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      if (mounted && prov.loginError != null) {
        _showToast(prov.loginError!);
      }
    }
  }

  Future<void> _handleStartDemo() async {
    HapticFeedback.mediumImpact();
    final prov = context.read<MusicProvider>();
    await prov.continueAsGuest();
    await prov.completeWelcomeGuide();
    if (widget.isStandalone && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SpotifyColors.surfaceElevated,
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip / Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: _prevPage,
                    )
                  else
                    const SizedBox(width: 48),
                  // Progress Dots
                  Row(
                    children: List.generate(4, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? SpotifyColors.orange
                              : SpotifyColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  if (widget.isStandalone)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    TextButton(
                      onPressed: _handleStartDemo,
                      child: const Text(
                        'Demo',
                        style: TextStyle(
                          color: SpotifyColors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildSlide1Welcome(),
                  _buildSlide2HowItWorks(),
                  _buildSlide3AudiophileFeatures(),
                  _buildSlide4ConnectServer(),
                ],
              ),
            ),

            // Bottom Navigation Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentPage < 3)
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SpotifyColors.orange,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                          shadowColor:
                              SpotifyColors.orange.withValues(alpha: 0.35),
                        ),
                        onPressed: _nextPage,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Weiter',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SLIDE 1: WILLKOMMEN ---
  Widget _buildSlide1Welcome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // App Logo with glowing aura
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: SpotifyColors.orange.withValues(alpha: 0.38),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: SpotifyColors.surfaceElevated,
                  child: const Icon(
                    Icons.graphic_eq,
                    color: SpotifyColors.orange,
                    size: 56,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'MUSIC ASSISTANT',
            style: TextStyle(
              color: SpotifyColors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Deine Musik.\nOhne Grenzen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Das High-End Hi-Fi Streaming-System für dein Zuhause und unterwegs. Vereine alle Streaming-Dienste und Lautsprecher in einer nativen App.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),

          _buildFeatureBullet(
            icon: Icons.speaker_group_outlined,
            title: 'Echtes Multiroom-Streaming',
            desc: 'Sonos, AirPlay, Chromecast, HomePod & iPhone synchron steuern.',
          ),
          _buildFeatureBullet(
            icon: Icons.high_quality_outlined,
            title: 'Bit-perfektes Hi-Res & FLAC',
            desc: 'Verlustfreier Klang in Studio-Qualität bis zu 24-Bit / 192 kHz.',
          ),
          _buildFeatureBullet(
            icon: Icons.watch_outlined,
            title: 'Dynamic Island & Apple Watch',
            desc: 'Live-Wiedergabe auf Sperrbildschirm, Island und deiner Smartwatch.',
          ),
          _buildFeatureBullet(
            icon: Icons.cloud_off_outlined,
            title: '100% Unabhängig & Privat',
            desc: 'Kein Vendor-Lock-in. Deine Daten bleiben auf deinem Server.',
          ),
        ],
      ),
    );
  }

  // --- SLIDE 2: WIE FUNKTIONIERT ES ---
  Widget _buildSlide2HowItWorks() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SERVER-ARCHITEKTUR',
            style: TextStyle(
              color: SpotifyColors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Wie funktioniert Music Assistant?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Music Assistant ist ein mächtiger Open-Source Musik-Server. Diese iOS-App fungiert als hochmodernes Steuer- und Abspielgerät.',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          // Architectural Diagram Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: SpotifyColors.borderHighlight,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _buildArchStep(
                  step: '1',
                  icon: Icons.dns_rounded,
                  title: 'Dein Music Assistant Server',
                  desc:
                      'Installiert als Home Assistant Add-on, Docker Container oder auf einem Raspberry Pi.',
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 26),
                _buildArchStep(
                  step: '2',
                  icon: Icons.wifi_rounded,
                  title: 'Lokale & Mobile Verbindung',
                  desc:
                      'Zu Hause über dein WLAN (Standard-Port :8095) oder unterwegs sicher via VPN (WireGuard / Tailscale) und Reverse Proxy.',
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 26),
                _buildArchStep(
                  step: '3',
                  icon: Icons.library_music_rounded,
                  title: 'Alle Musikquellen vereint',
                  desc:
                      'Spotify, Apple Music, Tidal, Qobuz, Deezer, lokale Festplatten und Web Radio in einer zentralen Bibliothek.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpotifyColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SpotifyColors.orange.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: SpotifyColors.orange, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Noch keinen Server eingerichtet? Du kannst die App trotzdem im Demo- und Offline-Modus vollumfänglich ausprobieren.',
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 3: EXKLUSIVE FEATURES ---
  Widget _buildSlide3AudiophileFeatures() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'HIGHLIGHTS',
            style: TextStyle(
              color: SpotifyColors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Exklusive Audio-Features',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Maßgeschneidert für audiophile Musikliebhaber und Podcast-Fans.',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),

          _buildFeatureCard(
            icon: Icons.mic_external_on_rounded,
            title: 'Live Synchronisierte Lyrics (LRCLIB)',
            desc:
                'Echte Songtexte laufen automatisch und taktgenau im Karaoke-Stil mit.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: Icons.graphic_eq_rounded,
            title: 'Interaktiver Audio-Waveform Scrubber',
            desc:
                '48 dynamische Klangwellenbalken visualisieren den Songverlauf mit haptischem Feedback.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: Icons.auto_stories_rounded,
            title: 'Hörbücher & Die drei ???',
            desc:
                'Eigener Bereich für Rocky-Beach-Abenteuer mit Folgenliste, Sprechern und Kapiteln.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: Icons.equalizer_rounded,
            title: '10-Band EQ & Fletcher-Munson Loudness',
            desc:
                'Präzise Akustikanpassung mit dynamischer Bass-Korrektur bei geringer Lautstärke.',
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            icon: Icons.record_voice_over_rounded,
            title: 'KI-DJ mit Apple Siri & Ollama',
            desc:
                'Automatischer Radio-DJ moderiert deine Lieblingstracks und Stimmungen an.',
          ),
        ],
      ),
    );
  }

  // --- SLIDE 4: SERVER VERBINDEN & START ---
  Widget _buildSlide4ConnectServer() {
    final prov = context.watch<MusicProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'VERBINDUNG EINRICHTEN',
            style: TextStyle(
              color: SpotifyColors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Verbinde deinen Server',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wähle deinen Music Assistant Server oder starte sofort im Offline- & Demo-Modus.',
            style: TextStyle(
              color: SpotifyColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Auto-Discovery Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotifyColors.surfaceElevated,
              foregroundColor: SpotifyColors.orange,
              side: const BorderSide(color: SpotifyColors.orange, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isDiscovering ? null : _startDiscovery,
            icon: _isDiscovering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(SpotifyColors.orange),
                    ),
                  )
                : const Icon(Icons.radar_rounded, size: 20),
            label: Text(
              _isDiscovering
                  ? 'Suche Server im lokalen Netzwerk...'
                  : '🔍 Lokale Server automatisch suchen',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),

          // Discovered Servers Chips
          if (_discoveredServers.isNotEmpty) ...[
            const Text(
              'Gefundene Server:',
              style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _discoveredServers.map((url) {
                return ActionChip(
                  avatar: const Icon(Icons.check_circle,
                      color: SpotifyColors.orange, size: 16),
                  backgroundColor: SpotifyColors.surfaceHighlight,
                  label: Text(url,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _serverController.text = url;
                      _testConnection();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // Presets
          Row(
            children: [
              const Text('Schnell-Vorlagen: ',
                  style: TextStyle(color: SpotifyColors.textMuted, fontSize: 11)),
              _buildPresetChip('homeassistant.local:8095'),
              const SizedBox(width: 6),
              _buildPresetChip('mass.local:8095'),
            ],
          ),
          const SizedBox(height: 10),

          // Server URL Input & Test Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverController,
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
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isTestingConnection ? null : _testConnection,
                  child: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                SpotifyColors.orange),
                          ),
                        )
                      : const Text(
                          'Testen',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ],
          ),

          // Connection Test Feedback Banner
          if (_connectionTestResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _connectionSuccess == true
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _connectionSuccess == true
                      ? Colors.green.withValues(alpha: 0.4)
                      : Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _connectionSuccess == true
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: _connectionSuccess == true
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionTestResult!,
                      style: TextStyle(
                        color: _connectionSuccess == true
                            ? Colors.greenAccent
                            : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Toggle Username/Password vs Token Auth
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _useTokenAuth
                    ? 'Anmeldung mit API-Token'
                    : 'Anmeldung mit Benutzerdaten',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _useTokenAuth = !_useTokenAuth),
                child: Text(
                  _useTokenAuth ? 'Benutzername/Passwort' : 'API-Token nutzen',
                  style: const TextStyle(
                    color: SpotifyColors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          if (_useTokenAuth) ...[
            TextField(
              controller: _tokenController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: _inputDecoration(
                hint: 'Music Assistant Access Token (JWT)...',
                icon: Icons.key_outlined,
              ),
            ),
          ] else ...[
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hint: 'Benutzername (z. B. admin)',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleConnect(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(
                hint: 'Passwort',
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: SpotifyColors.textMuted,
                    size: 18,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Connect Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpotifyColors.orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
              elevation: 4,
              shadowColor: SpotifyColors.orange.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: prov.isLoggingIn ? null : _handleConnect,
            child: prov.isLoggingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text(
                    'Mit Server verbinden',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
          const SizedBox(height: 12),

          // Demo Mode Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: SpotifyColors.surfaceHighlight),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _handleStartDemo,
            icon: const Icon(Icons.play_circle_outline,
                color: SpotifyColors.orange, size: 20),
            label: const Text(
              'Im Demo- & Offline-Modus starten',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildFeatureBullet({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SpotifyColors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: SpotifyColors.orange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchStep({
    required String step,
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: SpotifyColors.orange.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, color: SpotifyColors.orange, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  color: SpotifyColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpotifyColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpotifyColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SpotifyColors.orange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: SpotifyColors.orange, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String host) {
    return ActionChip(
      backgroundColor: SpotifyColors.surfaceElevated,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      label: Text(host,
          style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 11)),
      onPressed: () {
        setState(() {
          _serverController.text = 'http://$host';
          _testConnection();
        });
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: SpotifyColors.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: SpotifyColors.textSecondary, size: 18),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: SpotifyColors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          color: SpotifyColors.orange,
          width: 1.5,
        ),
      ),
    );
  }
}
