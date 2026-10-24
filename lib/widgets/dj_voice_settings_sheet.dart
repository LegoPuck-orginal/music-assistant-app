import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dj_voice_settings.dart';
import '../providers/music_provider.dart';
import '../services/native_tts_service.dart';
import '../services/ollama_service.dart';
import '../theme/spotify_colors.dart';

class DjVoiceSettingsSheet extends StatefulWidget {
  const DjVoiceSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DjVoiceSettingsSheet(),
    );
  }

  @override
  State<DjVoiceSettingsSheet> createState() => _DjVoiceSettingsSheetState();
}

class _DjVoiceSettingsSheetState extends State<DjVoiceSettingsSheet> {
  late DjVoiceEngine _engine;
  late String _voiceId;
  late String _voiceName;
  late double _speechRate;
  late double _pitch;
  late bool _enableDucking;
  late int _duckingPercent;
  late DjAudioOutput _audioOutput;
  late bool _enableOllama;
  late TextEditingController _ollamaHostCtrl;
  late String _ollamaModel;
  late TextEditingController _localTtsUrlCtrl;
  late TextEditingController _localTtsTokenCtrl;
  late TextEditingController _openAiEndpointCtrl;
  late String _openAiVoice;

  List<NativeVoiceInfo> _appleVoices = [];
  List<String> _ollamaModels = [];
  bool _isLoadingModels = false;
  bool _isTestingVoice = false;

  @override
  void initState() {
    super.initState();
    final prov = context.read<MusicProvider>();
    final s = prov.djVoiceSettings;

    _engine = s.engine;
    _voiceId = s.voiceId;
    _voiceName = s.voiceName;
    _speechRate = s.speechRate;
    _pitch = s.pitch;
    _enableDucking = s.enableDucking;
    _duckingPercent = s.duckingVolumePercent;
    _audioOutput = s.audioOutput;
    _enableOllama = s.enableOllamaLlm;
    _ollamaHostCtrl = TextEditingController(text: s.ollamaHost);
    _ollamaModel = s.ollamaModel;
    _localTtsUrlCtrl = TextEditingController(text: s.localTtsUrl);
    _localTtsTokenCtrl = TextEditingController(text: s.localTtsToken);
    _openAiEndpointCtrl = TextEditingController(text: s.openAiEndpoint);
    _openAiVoice = s.openAiVoice;

    _loadVoicesAndModels();
  }

  @override
  void dispose() {
    _ollamaHostCtrl.dispose();
    _localTtsUrlCtrl.dispose();
    _localTtsTokenCtrl.dispose();
    _openAiEndpointCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVoicesAndModels() async {
    // Apple Stimmen laden
    final voices = await NativeTtsService().getGermanVoices();
    if (mounted) {
      setState(() {
        _appleVoices = voices;
      });
    }

    // Ollama Modelle prüfen
    await _detectOllamaModels();
  }

  Future<void> _detectOllamaModels() async {
    final serverUrl = context.read<MusicProvider>().serverUrl;
    setState(() => _isLoadingModels = true);
    final models = await OllamaService().fetchInstalledModels(
      _ollamaHostCtrl.text.trim(),
      fallbackServerUrl: serverUrl,
    );
    if (mounted) {
      setState(() {
        _isLoadingModels = false;
        _ollamaModels = models;
        if (models.isNotEmpty && !models.contains(_ollamaModel)) {
          _ollamaModel = models.first;
        }
      });
    }
  }

  void _saveSettings() {
    final prov = context.read<MusicProvider>();
    final updated = DjVoiceSettings(
      engine: _engine,
      voiceId: _voiceId,
      voiceName: _voiceName,
      speechRate: _speechRate,
      pitch: _pitch,
      enableDucking: _enableDucking,
      duckingVolumePercent: _duckingPercent,
      audioOutput: _audioOutput,
      enableOllamaLlm: _enableOllama,
      ollamaHost: _ollamaHostCtrl.text.trim(),
      ollamaModel: _ollamaModel,
      localTtsUrl: _localTtsUrlCtrl.text.trim(),
      localTtsToken: _localTtsTokenCtrl.text.trim(),
      openAiEndpoint: _openAiEndpointCtrl.text.trim(),
      openAiVoice: _openAiVoice,
    );
    prov.updateDjVoiceSettings(updated);
  }

  Future<void> _testVoice() async {
    _saveSettings();
    setState(() => _isTestingVoice = true);
    final prov = context.read<MusicProvider>();
    await prov.previewDjVoice();
    if (mounted) {
      setState(() => _isTestingVoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SpotifyColors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    color: SpotifyColors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DJ STIMME & SPRACHMODELL',
                        style: TextStyle(
                          color: SpotifyColors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Virtueller Spotify DJ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _saveSettings();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Fertig',
                    style: TextStyle(
                      color: SpotifyColors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 20),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // 1. STIMMEN-ENGINE AUSWAHL
                _buildSectionTitle('SPRACH- & STIMMEN-ENGINE'),
                const SizedBox(height: 8),
                _buildEngineCard(
                  engine: DjVoiceEngine.appleSiri,
                  title: 'Apple Neural Siri (Lokal auf iPhone)',
                  subtitle:
                      'Studio-Qualität direkt vom Apple Neural Prozessor. Absolut null Latenz, keine Roboterstimme.',
                  icon: Icons.apple,
                  badge: 'EMPFOHLEN',
                ),
                const SizedBox(height: 8),
                _buildEngineCard(
                  engine: DjVoiceEngine.localServer,
                  title: 'Home Assistant / Lokaler Piper Server',
                  subtitle:
                      'Nutzt deine selbstgehostete Piper Neural Engine oder Home Assistant TTS.',
                  icon: Icons.home_rounded,
                ),
                const SizedBox(height: 8),
                _buildEngineCard(
                  engine: DjVoiceEngine.openAiCompatible,
                  title: 'Lokaler OpenAI-kompatibler Server (Kokoro)',
                  subtitle:
                      'Für Kokoro TTS, LocalAI oder Speaches mit lebensechten Radio-Stimmen.',
                  icon: Icons.hub_rounded,
                ),
                const SizedBox(height: 8),
                _buildEngineCard(
                  engine: DjVoiceEngine.musicAssistant,
                  title: 'Music Assistant Raumlautsprecher',
                  subtitle:
                      'Sendet die Ansage direkt an den Server zur Wiedergabe auf deinen Boxen.',
                  icon: Icons.speaker_group_rounded,
                ),

                const SizedBox(height: 24),

                // 2. STIMMEN-DETAILS (JE NACH ENGINE)
                if (_engine == DjVoiceEngine.appleSiri) ...[
                  _buildSectionTitle('APPLE STIMME WÄHLEN'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _appleVoices.any((v) => v.identifier == _voiceId)
                            ? _voiceId
                            : (_appleVoices.isNotEmpty ? _appleVoices.first.identifier : null),
                        isExpanded: true,
                        dropdownColor: const Color(0xFF242424),
                        icon: const Icon(Icons.arrow_drop_down, color: SpotifyColors.orange),
                        items: _appleVoices.map((v) {
                          return DropdownMenuItem<String>(
                            value: v.identifier,
                            child: Row(
                              children: [
                                Icon(
                                  v.gender == 'male' ? Icons.male : Icons.female,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    v.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (v.isNeuralOrPremium)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: SpotifyColors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'NEURAL',
                                      style: TextStyle(
                                        color: SpotifyColors.orange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            final match = _appleVoices.firstWhere((v) => v.identifier == newId);
                            setState(() {
                              _voiceId = newId;
                              _voiceName = match.name;
                            });
                            _saveSettings();
                          }
                        },
                      ),
                    ),
                  ),
                ] else if (_engine == DjVoiceEngine.openAiCompatible) ...[
                  _buildSectionTitle('SERVER ENDPOINT & STIMME'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _openAiEndpointCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'OpenAI-kompatible TTS URL',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'http://127.0.0.1:8000/v1/audio/speech',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => _saveSettings(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _openAiVoice,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF242424),
                        items: const [
                          DropdownMenuItem(value: 'onyx', child: Text('Onyx (Tiefe, sonore DJ-Stimme)', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'alloy', child: Text('Alloy (Klar & Modern)', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'echo', child: Text('Echo (Warm & Ruhig)', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'nova', child: Text('Nova (Dynamisch)', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _openAiVoice = val);
                            _saveSettings();
                          }
                        },
                      ),
                    ),
                  ),
                ] else if (_engine == DjVoiceEngine.localServer) ...[
                  _buildSectionTitle('HOME ASSISTANT / PIPER VERBINDUNG'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _localTtsUrlCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Server URL (HA oder Piper HTTP)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'http://homeassistant.local:8123',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => _saveSettings(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _localTtsTokenCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Home Assistant Access Token (Optional)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (_) => _saveSettings(),
                  ),
                ],

                const SizedBox(height: 24),

                // 3. LOKALE KI-MODERATION (OLLAMA LLM)
                _buildSectionTitle('LOKALE KI-MODERATION (OLLAMA LLM)'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _enableOllama
                          ? SpotifyColors.orange.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Echte KI-DJ-Moderationen',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Generiert dynamische Sprüche über Song & Künstler',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _enableOllama,
                            activeTrackColor: SpotifyColors.orange,
                            onChanged: (val) {
                              setState(() => _enableOllama = val);
                              _saveSettings();
                            },
                          ),
                        ],
                      ),
                      if (_enableOllama) ...[
                        const Divider(color: Colors.white12, height: 20),
                        TextField(
                          controller: _ollamaHostCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Ollama Host URL',
                            labelStyle: const TextStyle(color: Colors.white60),
                            hintText: 'http://127.0.0.1:11434',
                            suffixIcon: IconButton(
                              icon: _isLoadingModels
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, color: SpotifyColors.orange),
                              onPressed: _detectOllamaModels,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF181818),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onSubmitted: (_) => _detectOllamaModels(),
                        ),
                        const SizedBox(height: 10),
                        if (_ollamaModels.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181818),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _ollamaModels.contains(_ollamaModel)
                                    ? _ollamaModel
                                    : _ollamaModels.first,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF242424),
                                items: _ollamaModels.map((m) {
                                  return DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      'Modell: $m',
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _ollamaModel = val);
                                    _saveSettings();
                                  }
                                },
                              ),
                            ),
                          )
                        else
                          Text(
                            _isLoadingModels
                                ? 'Suche nach Ollama Modellen...'
                                : 'Kein Ollama gefunden. Nutzt offline smarte Radio-Vorlagen.',
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. KLANG-FEINEINSTELLUNG & DUCKING
                _buildSectionTitle('STIMMEN-TUNING & RADIO-FLOW'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      // Rate Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sprechtempo', style: TextStyle(color: Colors.white)),
                          Text(
                            '${_speechRate.toStringAsFixed(2)}x ${_speechRate == 1.05 ? "(Radio DJ)" : ""}',
                            style: const TextStyle(
                              color: SpotifyColors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _speechRate,
                        min: 0.8,
                        max: 1.4,
                        divisions: 12,
                        activeColor: SpotifyColors.orange,
                        onChanged: (val) {
                          setState(() => _speechRate = val);
                          _saveSettings();
                        },
                      ),
                      const SizedBox(height: 8),

                      // Pitch Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tonhöhe / Bass', style: TextStyle(color: Colors.white)),
                          Text(
                            '${_pitch.toStringAsFixed(2)}x ${_pitch == 0.95 ? "(Sonorer Bass)" : ""}',
                            style: const TextStyle(
                              color: SpotifyColors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _pitch,
                        min: 0.8,
                        max: 1.2,
                        divisions: 8,
                        activeColor: SpotifyColors.orange,
                        onChanged: (val) {
                          setState(() => _pitch = val);
                          _saveSettings();
                        },
                      ),
                      const Divider(color: Colors.white12, height: 24),

                      // Ducking
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Musik-Ducking',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Musik während Moderation sanft absenken',
                                style: TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          Switch.adaptive(
                            value: _enableDucking,
                            activeTrackColor: SpotifyColors.orange,
                            onChanged: (val) {
                              setState(() => _enableDucking = val);
                              _saveSettings();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 5. TEST-BUTTON
                ElevatedButton.icon(
                  onPressed: _isTestingVoice ? null : _testVoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpotifyColors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  icon: _isTestingVoice
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.black),
                          ),
                        )
                      : const Icon(Icons.volume_up_rounded, color: Colors.black),
                  label: Text(
                    _isTestingVoice ? 'DJ spricht...' : 'DJ-STIMME TESTEN',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildEngineCard({
    required DjVoiceEngine engine,
    required String title,
    required String subtitle,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _engine == engine;
    return GestureDetector(
      onTap: () {
        setState(() => _engine = engine);
        _saveSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? SpotifyColors.orange.withValues(alpha: 0.12)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? SpotifyColors.orange : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? SpotifyColors.orange : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.black : Colors.white70,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SpotifyColors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? SpotifyColors.orange : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: SpotifyColors.orange,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
