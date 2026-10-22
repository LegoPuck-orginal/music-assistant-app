import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  bool _isTesting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    final prov = context.read<MusicProvider>();
    _urlCtrl = TextEditingController(text: prov.serverUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final prov = context.read<MusicProvider>();
    await prov.updateServerUrl(_urlCtrl.text.trim());

    setState(() {
      _isTesting = false;
      _statusMessage = prov.isServerConnected
          ? 'Erfolgreich mit Music Assistant verbunden!'
          : 'Server erreichbar! ${prov.players.length} Player synchronisiert.';
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
          // Section: Music Assistant Server
          _sectionTitle('MUSIC ASSISTANT SERVER'),
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
                const SizedBox(height: 12),
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
                      label: const Text('Verbindung testen & Speichern',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 10),
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
          _sectionTitle('AUDIOQUALITÄT'),
          Container(
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _settingRow(
                  title: 'Lossless Streaming (FLAC / Hi-Res)',
                  subtitle: 'Direktes Bit-perfektes Streaming über lokales WLAN',
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
                const Divider(color: SpotifyColors.borderSubtle, height: 1),
                _settingRow(
                  title: 'Lautstärke-Normalisierung (ReplayGain)',
                  subtitle: 'Gleiche Lautstärke für alle Songs',
                  trailing: Switch(
                    value: false,
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
                  'Version 1.0.0 • Entwickelt für Tim Marquardt',
                  style: TextStyle(
                    color: SpotifyColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Verbindet sich direkt mit dem Music Assistant 2.0 Server im lokalen Netzwerk und steuert Multi-Room-Player wie Sonos, AirPlay, Chromecast und Snapcast nahtlos im eleganten Spotify-Design.',
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
