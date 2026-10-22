import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/dsp_models.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

class EqualizerSheet extends StatefulWidget {
  const EqualizerSheet({super.key});

  @override
  State<EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<EqualizerSheet> {
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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
            const SizedBox(height: 14),

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
                              child: const Text(
                                'SERVER DSP',
                                style: TextStyle(
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
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      prov.toggleDspEnabled(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Active Device & Preset Status Banner
            if (active != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        color:
                            isEnabled ? SpotifyColors.green : Colors.grey,
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

            const SizedBox(height: 12),

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
                        final isSelected =
                            dspConfig.presetId == preset.presetId;

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

            const SizedBox(height: 14),

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

            const SizedBox(height: 10),

            // Bottom Actions: Reset to Flat & Done
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
            const SizedBox(height: 6),
          ],
        ),
      ),
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
