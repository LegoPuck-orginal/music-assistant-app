import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/adaptive_eq_settings.dart';
import '../models/dsp_models.dart';
import '../models/player_device.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';
import 'adaptive_eq_visualizer.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
  int _selectedTab = 0; // 0 = Adaptiver EQ, 1 = Manueller DSP
  final Map<int, double> _localBandGains = {};
  double? _localPreamp;
  int? _draggingBandIndex;
  bool _isDraggingPreamp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicProvider>().loadDspForPlayer();
    });
  }

  String _freqRole(double freq) {
    if (freq < 80) return 'Sub-Bass';
    if (freq < 250) return 'Bass';
    if (freq < 800) return 'Tiefmitten';
    if (freq < 2500) return 'Mitten';
    if (freq < 6000) return 'Präsenz';
    return 'Brillanz';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final active = prov.activePlayer;
    final dspConfig = prov.dspConfig ?? DspConfig.defaultFlat();
    final isEnabled = dspConfig.enabled;
    final bands = dspConfig.bands.isNotEmpty
        ? dspConfig.bands
        : DspConfig.defaultFlat().bands;
    final currentPreamp = _isDraggingPreamp
        ? (_localPreamp ?? dspConfig.preamp)
        : dspConfig.preamp;

    final adaptive = prov.adaptiveEqSettings;
    final adaptiveDeltas = prov.currentAdaptiveDeltas;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: SpotifyColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Title & Master Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'DSP & Equalizer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: const BoxDecoration(
                                color: SpotifyColors.surfaceHighlight,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(6)),
                              ),
                              child: Text(
                                _selectedTab == 0 ? 'ADAPTIV' : 'SERVER DSP',
                                style: const TextStyle(
                                  color: SpotifyColors.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active != null
                              ? 'Klangkurve für ${active.name}'
                              : 'Music Assistant DSP-Einstellungen',
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
                  Switch(
                    value: isEnabled,
                    activeTrackColor: SpotifyColors.green,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      prov.toggleDspEnabled(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Segmented Tab Switcher (Adaptiver EQ vs. Manueller DSP)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: SpotifyColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? SpotifyColors.green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 13,
                                  color: _selectedTab == 0
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ADAPTIVER EQ',
                                  style: TextStyle(
                                    color: _selectedTab == 0
                                        ? Colors.black
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? SpotifyColors.green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 13,
                                  color: _selectedTab == 1
                                      ? Colors.black
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'MANUELLER DSP',
                                  style: TextStyle(
                                    color: _selectedTab == 1
                                        ? Colors.black
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: _selectedTab == 0
                  ? _buildAdaptiveEqTab(prov, active, dspConfig, adaptive, adaptiveDeltas, bands)
                  : _buildManualDspTab(prov, active, dspConfig, isEnabled, bands, currentPreamp),
            ),

            // Bottom Actions: Done & Reset
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh,
                        size: 16, color: SpotifyColors.textSecondary),
                    label: const Text(
                      'Flat (0 dB)',
                      style: TextStyle(
                          color: SpotifyColors.textSecondary, fontSize: 13),
                    ),
                    onPressed: isEnabled
                        ? () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _localBandGains.clear();
                              _localPreamp = 0.0;
                            });
                            prov.resetDspToFlat();
                          }
                        : null,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpotifyColors.green,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fertig',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: ADAPTIVER EQUALIZER ---
  Widget _buildAdaptiveEqTab(
    MusicProvider prov,
    PlayerDevice? active,
    DspConfig dspConfig,
    AdaptiveEqSettings adaptive,
    List<double> adaptiveDeltas,
    List<DspBand> bands,
  ) {
    final baseGains = bands.map((b) => b.gain).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Real-Time Spline Visualizer
        AdaptiveEqVisualizer(
          baselineGains: baseGains,
          adaptiveDeltas: adaptiveDeltas,
          isAdaptiveEnabled: adaptive.isEnabled && dspConfig.enabled,
          mode: adaptive.mode,
          speakerName: active?.name ?? 'Lautsprecher',
        ),

        const SizedBox(height: 14),

        // Live Real-Time Band Delta Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (idx) {
              final labels = ['60Hz', '230Hz', '910Hz', '4kHz', '14kHz'];
              final delta = idx < adaptiveDeltas.length ? adaptiveDeltas[idx] : 0.0;
              final isPositive = delta > 0.1;
              final isNegative = delta < -0.1;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? SpotifyColors.green.withValues(alpha: 0.15)
                      : isNegative
                          ? const Color(0xFF00F2FE).withValues(alpha: 0.15)
                          : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPositive
                        ? SpotifyColors.green.withValues(alpha: 0.4)
                        : isNegative
                            ? const Color(0xFF00F2FE).withValues(alpha: 0.4)
                            : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      labels[idx],
                      style: const TextStyle(color: Colors.white60, fontSize: 9),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      delta > 0
                          ? '+${delta.toStringAsFixed(1)}'
                          : delta.toStringAsFixed(1),
                      style: TextStyle(
                        color: isPositive
                            ? SpotifyColors.green
                            : isNegative
                                ? const Color(0xFF00F2FE)
                                : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 16),

        // Adaptive Master Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adaptiver EQ aktiv',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Passt Frequenzen live an Lautstärke & Track an',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: adaptive.isEnabled,
                  activeTrackColor: SpotifyColors.green,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    prov.updateAdaptiveEqSettings(adaptive.copyWith(isEnabled: val));
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Mode Selection
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'ADAPTIONS-MODUS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildModeTile(
                mode: AdaptiveEqMode.auto,
                title: 'Voll-Adaptiv (Smart)',
                subtitle:
                    'Kombiniert dynamische Fletcher-Munson Loudness, Genre-Erkennung & Lautsprecher-Profil.',
                icon: Icons.auto_awesome,
                current: adaptive.mode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  prov.updateAdaptiveEqSettings(
                      adaptive.copyWith(mode: AdaptiveEqMode.auto));
                },
              ),
              const SizedBox(height: 8),
              _buildModeTile(
                mode: AdaptiveEqMode.dynamicLoudness,
                title: 'Fletcher-Munson Loudness',
                subtitle:
                    'Hebt Sub-Bass & Höhen bei leiser Lautstärke automatisch an (ISO 226).',
                icon: Icons.graphic_eq_rounded,
                current: adaptive.mode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  prov.updateAdaptiveEqSettings(
                      adaptive.copyWith(mode: AdaptiveEqMode.dynamicLoudness));
                },
              ),
              const SizedBox(height: 8),
              _buildModeTile(
                mode: AdaptiveEqMode.genreDynamic,
                title: 'Auto-Genre Profiling',
                subtitle:
                    'Erkennt Rock, EDM, Hip-Hop, Pop oder Akustik und optimiert die Klangdynamik.',
                icon: Icons.music_note_rounded,
                current: adaptive.mode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  prov.updateAdaptiveEqSettings(
                      adaptive.copyWith(mode: AdaptiveEqMode.genreDynamic));
                },
              ),
              const SizedBox(height: 8),
              _buildModeTile(
                mode: AdaptiveEqMode.nightComfort,
                title: 'Nacht-Modus (Bass-Schutz)',
                subtitle:
                    'Zähmt tiefe Bassvibrationen für Nachbarn, hält Gesang & Stimmen glasklar.',
                icon: Icons.bedtime_rounded,
                current: adaptive.mode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  prov.updateAdaptiveEqSettings(
                      adaptive.copyWith(mode: AdaptiveEqMode.nightComfort));
                },
              ),
              const SizedBox(height: 8),
              _buildModeTile(
                mode: AdaptiveEqMode.hearingProtection,
                title: 'Gehörschutz / Anti-Fatigue',
                subtitle:
                    'Glättet schrille Frequenzen bei hoher Lautstärke gegen Hörermüdung.',
                icon: Icons.hearing_rounded,
                current: adaptive.mode,
                onTap: () {
                  HapticFeedback.lightImpact();
                  prov.updateAdaptiveEqSettings(
                      adaptive.copyWith(mode: AdaptiveEqMode.hearingProtection));
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Intensity Slider & Feature Toggles
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Adaptions-Stärke',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text(
                      '${(adaptive.intensity * 100).toInt()} %',
                      style: const TextStyle(
                        color: SpotifyColors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: adaptive.intensity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  activeColor: SpotifyColors.green,
                  onChanged: (val) {
                    prov.updateAdaptiveEqSettings(
                        adaptive.copyWith(intensity: val));
                  },
                ),
                const Divider(color: Colors.white12, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lautsprecher-Profilierung (Sonos/iPhone)',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Switch.adaptive(
                      value: adaptive.enableDeviceAdaptation,
                      activeTrackColor: SpotifyColors.green,
                      onChanged: (val) {
                        prov.updateAdaptiveEqSettings(
                            adaptive.copyWith(enableDeviceAdaptation: val));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildModeTile({
    required AdaptiveEqMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required AdaptiveEqMode current,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? SpotifyColors.green.withValues(alpha: 0.12)
              : SpotifyColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? SpotifyColors.green : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? SpotifyColors.green
                    : Colors.white10,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.black : Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: SpotifyColors.green, size: 20),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: MANUELLER DSP EQUALIZER ---
  Widget _buildManualDspTab(
    MusicProvider prov,
    PlayerDevice? active,
    DspConfig dspConfig,
    bool isEnabled,
    List<DspBand> bands,
    double currentPreamp,
  ) {
    return Column(
      children: [
        // Speaker Badge
        if (active != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: SpotifyColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isEnabled
                      ? SpotifyColors.green.withValues(alpha: 0.3)
                      : SpotifyColors.surfaceHighlight,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    active.isLocal ? Icons.smartphone : Icons.speaker,
                    color: isEnabled ? SpotifyColors.green : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${active.name} (${active.type})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (prov.isLoadingDsp)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            SpotifyColors.green),
                      ),
                    )
                  else ...[
                    Text(
                      _getAppliedPresetName(prov, dspConfig),
                      style: TextStyle(
                        color: isEnabled
                            ? SpotifyColors.green
                            : SpotifyColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        prov.loadDspForPlayer();
                      },
                      child: const Icon(Icons.refresh,
                          color: SpotifyColors.textSecondary, size: 16),
                    ),
                  ],
                ],
              ),
            ),
          ),

        const SizedBox(height: 10),

        // Server DSP Presets Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'SERVER PRESETS (${prov.dspPresets.length})',
              style: const TextStyle(
                color: SpotifyColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        SizedBox(
          height: 36,
          child: prov.dspPresets.isEmpty
              ? (prov.isLoadingDsp
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              SpotifyColors.green),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Keine Presets auf dem Server gefunden',
                        style: TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: prov.dspPresets.length,
                  itemBuilder: (context, index) {
                    final preset = prov.dspPresets[index];
                    final isSelected = dspConfig.presetId == preset.presetId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        avatar: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.black)
                            : null,
                        label: Text(preset.name),
                        selected: isSelected,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        selectedColor: SpotifyColors.green,
                        backgroundColor: SpotifyColors.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: isEnabled
                            ? (selected) {
                                if (selected) {
                                  HapticFeedback.lightImpact();
                                  _localBandGains.clear();
                                  _localPreamp = null;
                                  prov.applyDspPreset(preset);
                                }
                              }
                            : null,
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 12),

        // Dynamic Equalizer Frequency Sliders
        Expanded(
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.35,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(bands.length, (index) {
                  final band = bands[index];
                  final gain = _draggingBandIndex == index
                      ? (_localBandGains[index] ?? band.gain)
                      : band.gain;

                  return Column(
                    children: [
                      // dB Gain Label
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gain.abs() > 0.1
                              ? SpotifyColors.green.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gain > 0
                              ? '+${gain.toStringAsFixed(1)} dB'
                              : '${gain.toStringAsFixed(1)} dB',
                          style: TextStyle(
                            color: gain.abs() > 0.1
                                ? SpotifyColors.green
                                : SpotifyColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Vertical Slider
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: SpotifyColors.green,
                              inactiveTrackColor:
                                  SpotifyColors.surfaceHighlight,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12),
                              trackHeight: 3.0,
                            ),
                            child: Slider(
                              value: gain.clamp(-12.0, 12.0),
                              min: -12.0,
                              max: 12.0,
                              onChanged: isEnabled
                                  ? (val) {
                                      setState(() {
                                        _draggingBandIndex = index;
                                        _localBandGains[index] = val;
                                      });
                                      prov.updateDspBandGain(index, val);
                                    }
                                  : null,
                              onChangeEnd: isEnabled
                                  ? (val) {
                                      setState(() {
                                        _draggingBandIndex = null;
                                        _localBandGains[index] = val;
                                      });
                                      HapticFeedback.lightImpact();
                                      prov.updateDspBandGain(index, val);
                                      prov.saveCurrentDspConfig();
                                    }
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Frequency Label
                      Text(
                        band.formattedFreq,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _freqRole(band.frequency),
                        style: const TextStyle(
                          color: SpotifyColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Preamp Level Slider
        Opacity(
          opacity: isEnabled ? 1.0 : 0.35,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: SpotifyColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune,
                    size: 16, color: SpotifyColors.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Preamp:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  currentPreamp > 0
                      ? '+${currentPreamp.toStringAsFixed(1)} dB'
                      : '${currentPreamp.toStringAsFixed(1)} dB',
                  style: TextStyle(
                    color: currentPreamp.abs() > 0.1
                        ? SpotifyColors.green
                        : SpotifyColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: SpotifyColors.green,
                      inactiveTrackColor: SpotifyColors.surfaceHighlight,
                      thumbColor: Colors.white,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      trackHeight: 2.5,
                    ),
                    child: Slider(
                      value: currentPreamp.clamp(-12.0, 6.0),
                      min: -12.0,
                      max: 6.0,
                      onChanged: isEnabled
                          ? (val) {
                              setState(() {
                                _isDraggingPreamp = true;
                                _localPreamp = val;
                              });
                              prov.updateDspPreamp(val);
                            }
                          : null,
                      onChangeEnd: isEnabled
                          ? (val) {
                              setState(() {
                                _isDraggingPreamp = false;
                                _localPreamp = val;
                              });
                              HapticFeedback.lightImpact();
                              prov.updateDspPreamp(val);
                              prov.saveCurrentDspConfig();
                            }
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getAppliedPresetName(MusicProvider prov, DspConfig config) {
    if (config.presetId != null) {
      for (final p in prov.dspPresets) {
        if (p.presetId == config.presetId) {
          return p.name;
        }
      }
      return 'Server Preset';
    }
    return 'Benutzerdefiniert';
  }
}
