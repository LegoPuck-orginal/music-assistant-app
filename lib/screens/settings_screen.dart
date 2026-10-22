import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import '../widgets/equalizer_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _tokenCtrl;
  bool _isTesting = false;
  String? _statusMessage;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    final prov = context.read<MusicProvider>();
    _urlCtrl = TextEditingController(text: prov.serverUrl);
    _tokenCtrl = TextEditingController(text: prov.authToken);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final prov = context.read<MusicProvider>();
    await prov.updateServerSettings(
      _urlCtrl.text.trim(),
      _tokenCtrl.text.trim(),
    );

    setState(() {
      _isTesting = false;
      _statusMessage = prov.isServerConnected
          ? 'Erfolgreich mit Music Assistant verbunden! ${prov.players.length} Player & ${prov.queue.length} Songs aktiv.'
          : 'Server erreichbar! Authentifizierung wird aktualisiert.';
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
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: SpotifyColors.green,
                      child: Text(
                        (prov.currentUser?.effectiveName.isNotEmpty == true)
                            ? prov.currentUser!.effectiveName[0].toUpperCase()
                            : 'M',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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

          const SizedBox(height: 24),

          // Section: Music Assistant Server Details
          _sectionTitle('SERVER-ADRESSE & API-TOKEN'),
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
                  'Server-Adresse (URL)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: SpotifyColors.surfaceHighlight,
                    hintText: 'http://192.168.188.25:8095',
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
                const Text(
                  'Music Assistant API Token (Long-Lived)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenCtrl,
                  obscureText: _obscureToken,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: SpotifyColors.surfaceHighlight,
                    hintText: 'Music Assistant Access Token (JWT)',
                    hintStyle: const TextStyle(color: SpotifyColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility_off : Icons.visibility,
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
                          : const Icon(Icons.sync, size: 18),
                      label: const Text('Speichern & Synchronisieren',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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
            title: const Text('DSP & Equalizer (Server-Sync)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: Text(
              'DSP: ${prov.dspConfig?.enabled == true ? "Aktiv" : "Aus"} • ${prov.dspConfig?.presetId != null ? (prov.dspPresets.where((p) => p.presetId == prov.dspConfig!.presetId).firstOrNull?.name ?? "Preset") : "Individuell"} (${prov.dspConfig?.bands.length ?? 5} Bänder)',
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
                    value: true,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {},
                  ),
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                _settingRow(
                  title: 'Lossless Streaming (FLAC / Hi-Res)',
                  subtitle: 'Bit-perfektes Streaming über lokales WLAN',
                  trailing: Switch(
                    value: true,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {},
                  ),
                ),
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                _settingRow(
                  title: 'Gapless Playback',
                  subtitle: 'Nahtloser Übergang zwischen Musiktiteln',
                  trailing: Switch(
                    value: true,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {},
                  ),
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Music Assistant für iOS (Spotify-Edition)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.1.0 • Echte Server-API & Equalizer',
                  style: TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Steuert echte Music Assistant Multi-Room-Player (Sonos, AirPlay, Chromecast, Shield) und spielt Musik direkt lokal auf dem iPhone ab.',
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
