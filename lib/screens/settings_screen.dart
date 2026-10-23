import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/apple_watch_remote_sheet.dart';
import '../widgets/dj_voice_settings_sheet.dart';
import '../widgets/downloads_sheet.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_edit_dialog.dart';
import '../widgets/update_dialog.dart';
import 'welcome_guide_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _tokenCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  bool _isTesting = false;
  bool _isDiscovering = false;
  bool _usePasswordAuth = false;
  bool _obscurePassword = true;
  String? _statusMessage;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    final prov = context.read<MusicProvider>();
    _urlCtrl = TextEditingController(text: prov.serverUrl);
    _tokenCtrl = TextEditingController(text: prov.authToken);
    _usernameCtrl =
        TextEditingController(text: prov.currentUser?.username ?? '');
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _discoverServers() async {
    setState(() {
      _isDiscovering = true;
      _statusMessage = 'Suche Music Assistant Server im lokalen WLAN...';
    });
    final prov = context.read<MusicProvider>();
    final found = await prov.discoverLocalServers();
    if (!mounted) return;
    setState(() {
      _isDiscovering = false;
      if (found.isNotEmpty) {
        _urlCtrl.text = found.first;
        _statusMessage = 'Server gefunden: ${found.first}';
      } else {
        _statusMessage =
            'Kein Server automatisch gefunden. Bitte URL manuell prüfen.';
      }
    });
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final prov = context.read<MusicProvider>();
    final cleanUrl = _urlCtrl.text.trim();

    if (_usePasswordAuth &&
        _usernameCtrl.text.trim().isNotEmpty &&
        _passwordCtrl.text.isNotEmpty) {
      final ok = await prov.login(
        serverUrl: cleanUrl,
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      if (ok) {
        _tokenCtrl.text = prov.authToken;
      }
      setState(() {
        _isTesting = false;
        _statusMessage = ok
            ? 'Erfolgreich angemeldet als ${prov.currentUser?.effectiveName ?? _usernameCtrl.text.trim()}!'
            : (prov.loginError ?? 'Anmeldung fehlgeschlagen.');
      });
      return;
    }

    await prov.updateServerSettings(
      cleanUrl,
      _tokenCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _statusMessage = prov.isServerConnected
          ? 'Erfolgreich mit Music Assistant verbunden! ${prov.players.length} Player & ${prov.queue.length} Songs aktiv.'
          : 'Server-Einstellungen gespeichert & Synchronisierung gestartet.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();

    return Scaffold(
      backgroundColor: SpotifyColors.pureBlack,
      appBar: AppBar(
        title: const Text('Einstellungen'),
        backgroundColor: SpotifyColors.pureBlack,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Section: Benutzerkonto & Anmeldung
          _sectionTitle('BENUTZERKONTO & SERVER'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: prov.isServerConnected
                    ? SpotifyColors.green.withValues(alpha: 0.3)
                    : SpotifyColors.surfaceHighlight,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ProfileAvatar(
                      user: prov.currentUser,
                      radius: 26,
                      showEditBadge: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ProfileEditDialog.show(context);
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                prov.currentUser?.effectiveName ??
                                    (prov.isAuthenticated
                                        ? 'Angemeldeter Benutzer'
                                        : 'Nicht angemeldet'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (prov.currentUser?.isAdmin == true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: SpotifyColors.surfaceHighlight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      color: SpotifyColors.green,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prov.serverUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: prov.isServerConnected
                            ? SpotifyColors.green
                            : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SpotifyColors.green,
                        side: const BorderSide(color: SpotifyColors.green, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Profil & Avatar'),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ProfileEditDialog.show(context);
                      },
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Abmelden'),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: SpotifyColors.surfaceElevated,
                            title: const Text('Abmelden?',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'Möchtest du dich wirklich von Music Assistant abmelden?',
                              style: TextStyle(color: SpotifyColors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Abbrechen',
                                    style: TextStyle(
                                        color: SpotifyColors.textSecondary)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  prov.logout();
                                },
                                child: const Text('Abmelden'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('Neu verbinden'),
                      style: TextButton.styleFrom(
                        foregroundColor: SpotifyColors.textSecondary,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        prov.refreshServerData();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Willkommens-Guide & Server-Assistent
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            tileColor: SpotifyColors.surfaceElevated,
            leading: const Icon(Icons.explore_rounded,
                color: SpotifyColors.orange, size: 28),
            title: const Text('Willkommens-Guide & Server-Setup',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'Schritt-für-Schritt Einrichtung, Server-Scan & Demo-Modus',
                style: TextStyle(
                    color: SpotifyColors.textSecondary, fontSize: 12)),
            trailing:
                const Icon(Icons.chevron_right, color: SpotifyColors.textMuted),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WelcomeGuideScreen(isStandalone: true),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Section: Music Assistant Server Details
          _sectionTitle('SERVER-VERBINDUNG & ANMELDUNG'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Server-Adresse (URL)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: SpotifyColors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _isDiscovering ? null : _discoverServers,
                      icon: _isDiscovering
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: SpotifyColors.green,
                              ),
                            )
                          : const Icon(Icons.radar, size: 15),
                      label: const Text(
                        'Im WLAN suchen',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: SpotifyColors.surfaceHighlight,
                    hintText: 'http://homeassistant.local:8095',
                    hintStyle: const TextStyle(color: SpotifyColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Auth Method Toggle (Password vs Token)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: SpotifyColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _usePasswordAuth = false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: !_usePasswordAuth
                                  ? SpotifyColors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                'API-Token (JWT)',
                                style: TextStyle(
                                  color: !_usePasswordAuth
                                      ? Colors.black
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _usePasswordAuth = true);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: _usePasswordAuth
                                  ? SpotifyColors.green
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                'Benutzer & Passwort',
                                style: TextStyle(
                                  color: _usePasswordAuth
                                      ? Colors.black
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_usePasswordAuth) ...[
                  TextField(
                    controller: _usernameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: SpotifyColors.surfaceHighlight,
                      hintText: 'Music Assistant Benutzername',
                      hintStyle:
                          const TextStyle(color: SpotifyColors.textMuted),
                      prefixIcon: const Icon(Icons.person_outline,
                          color: SpotifyColors.textSecondary, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: SpotifyColors.surfaceHighlight,
                      hintText: 'Passwort',
                      hintStyle:
                          const TextStyle(color: SpotifyColors.textMuted),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: SpotifyColors.textSecondary, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: SpotifyColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _tokenCtrl,
                    obscureText: _obscureToken,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: SpotifyColors.surfaceHighlight,
                      hintText: 'Music Assistant Access Token (JWT)',
                      hintStyle:
                          const TextStyle(color: SpotifyColors.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: SpotifyColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureToken = !_obscureToken;
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpotifyColors.green,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _isTesting ? null : _saveAndTest,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Icon(_usePasswordAuth ? Icons.login : Icons.sync,
                              size: 18),
                      label: Text(
                          _usePasswordAuth
                              ? 'Anmelden & Verbinden'
                              : 'Speichern & Synchronisieren',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage!,
                    style: const TextStyle(
                      color: SpotifyColors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Equalizer & DSP
          _sectionTitle('SOUND & EQUALIZER'),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            tileColor: SpotifyColors.surfaceElevated,
            leading: const Icon(Icons.tune, color: SpotifyColors.green),
            title: const Text('DSP & Adaptiver Equalizer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'Adaptiv: ${prov.adaptiveEqSettings.isEnabled ? "Aktiv (${prov.adaptiveEqSettings.mode.name})" : "Aus"} • Server-DSP: ${prov.dspConfig?.enabled == true ? "Aktiv" : "Aus"}',
              style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textMuted),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const EqualizerSheet(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Section: Web Dashboard
          _sectionTitle('WEB INTERFACE'),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            tileColor: SpotifyColors.surfaceElevated,
            leading: const Icon(Icons.web, color: SpotifyColors.green),
            title: const Text('Music Assistant Web-GUI öffnen',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: const Text('Volle Server-Konfiguration & Integrationen',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textMuted),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Music Assistant Web'),
                    ),
                    body: InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(prov.serverUrl),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Section: Streaming & Audio
          _sectionTitle('AUDIOQUALITÄT & LOKALE WIEDERGABE'),
          Container(
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _settingRow(
                  title: 'iPhone Lautsprecher & Kopfhörer',
                  subtitle: 'Direktes Audio-Streaming auf dem Smartphone erlauben',
                  trailing: Switch(
                    value: prov.allowLocalPlayback,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      prov.setAllowLocalPlayback(val);
                    },
                  ),
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                _settingRow(
                  title: 'Lossless Streaming (FLAC / Hi-Res)',
                  subtitle: 'Bit-perfektes Streaming über lokales WLAN',
                  trailing: Switch(
                    value: prov.losslessStreaming,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      prov.setLosslessStreaming(val);
                    },
                  ),
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                _settingRow(
                  title: 'Gapless & Crossfade',
                  subtitle: 'Nahtloser Übergang zwischen Musiktiteln auf dem Server',
                  trailing: Switch(
                    value: prov.crossfadeEnabled,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      prov.setCrossfadeEnabled(val);
                    },
                  ),
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                _settingRow(
                  title: 'Autoplay / Endlos-Mix',
                  subtitle:
                      'Spielt nach Warteschlangen-Ende automatisch ähnliche Titel weiter',
                  trailing: Switch(
                    value: prov.dontStopTheMusic,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      prov.setDontStopTheMusic(val);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Spotify KI-DJ & Sprachmodell
          _sectionTitle('SPOTIFY KI-DJ & SPRACHMODELL'),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            tileColor: SpotifyColors.surfaceElevated,
            leading: const Icon(Icons.record_voice_over_rounded, color: SpotifyColors.orange, size: 28),
            title: const Text('DJ Stimme & KI-Modell',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${prov.djVoiceSettings.voiceName} • ${prov.djVoiceSettings.enableOllamaLlm ? "Ollama (${prov.djVoiceSettings.ollamaModel})" : "Smart Radio"}',
                style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textMuted),
            onTap: () {
              HapticFeedback.lightImpact();
              DjVoiceSettingsSheet.show(context);
            },
          ),

          const SizedBox(height: 24),

          // Section: Apple Watch & Remote
          _sectionTitle('APPLE WATCH & REMOTE'),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            tileColor: SpotifyColors.surfaceElevated,
            leading: const Icon(Icons.watch, color: SpotifyColors.green, size: 28),
            title: const Text('Apple Watch Fernbedienung',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: const Text('watchOS Companion App, Multiroom & Spotify KI-DJ',
                style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textMuted),
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AppleWatchRemoteSheet(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Section: Downloads & Offline-Speicher
          _sectionTitle('DOWNLOADS & OFFLINE-SPEICHER'),
          Container(
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _settingRow(
                  title: 'Offline-Modus',
                  subtitle: 'Erzwingt Wiedergabe ausschließlich aus lokalen Downloads',
                  trailing: Switch(
                    value: prov.isOfflineMode,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      prov.setOfflineMode(val);
                    },
                  ),
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                ListTile(
                  leading: const Icon(Icons.download_done, color: SpotifyColors.green),
                  title: const Text('Offline-Downloads verwalten',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${prov.formattedDownloadedSize} belegt • ${prov.downloadedTracks.length} Titel auf dem Gerät',
                    style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: SpotifyColors.textMuted),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const DownloadsSheet(),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: App-Updates & Version
          _sectionTitle('APP-UPDATES & VERSION'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: prov.hasUpdate
                    ? SpotifyColors.green
                    : SpotifyColors.surfaceHighlight,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Installierte Version',
                          style: TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v${prov.updateInfo?.currentVersion ?? prov.appVersion} (Build 30)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    if (prov.hasUpdate)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SpotifyColors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Update: v${prov.updateInfo!.latestVersion}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: SpotifyColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Aktuell',
                          style: TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: prov.hasUpdate
                        ? SpotifyColors.green
                        : SpotifyColors.surfaceHighlight,
                    foregroundColor:
                        prov.hasUpdate ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: prov.isCheckingForUpdates
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          prov.hasUpdate
                              ? Icons.system_update_alt
                              : Icons.refresh,
                          size: 18,
                        ),
                  label: Text(
                    prov.hasUpdate
                        ? 'Update jetzt installieren'
                        : 'Nach Updates suchen',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final info = await prov.checkForUpdates();
                    if (context.mounted) {
                      UpdateDialog.show(context, info);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: About
          _sectionTitle('ÜBER DIE APP'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Music Assistant für iOS (Adobe OLED & Orange Edition)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${prov.appVersion} (Build 30) • Echte Server-API & Equalizer',
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Steuert echte Music Assistant Multi-Room-Player (Sonos, AirPlay, Chromecast, HomePod) und spielt Musik direkt lokal auf dem iPhone ab.',
                  style: TextStyle(
                    color: SpotifyColors.textMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: SpotifyColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _settingRow({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
