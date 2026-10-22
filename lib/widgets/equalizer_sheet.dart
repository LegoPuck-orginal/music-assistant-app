import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/equalizer_settings.dart';
import '../providers/music_provider.dart';
import '../theme/spotify_colors.dart';

class EqualizerSheet extends StatelessWidget {
  const EqualizerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<MusicProvider>();
    final eq = prov.equalizerSettings;
    final active = prov.activePlayer;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
            const SizedBox(height: 16),

            // Header Title & On/Off Switch
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Equalizer & Sound',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Klangregelung für iPhone & Music Assistant',
                        style: TextStyle(
                          color: SpotifyColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Switch(
                    value: eq.isEnabled,
                    activeThumbColor: SpotifyColors.green,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      prov.setEqualizerEnabled(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Active Device Indicator
            if (active != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: SpotifyColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SpotifyColors.green.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active.isLocal ? Icons.smartphone : Icons.speaker,
                        color: SpotifyColors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aktiv auf: ${active.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        eq.currentPreset,
                        style: const TextStyle(
                          color: SpotifyColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Presets Horizontal Selector
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: EqualizerSettings.presets.keys.map((preset) {
                  final isSelected = eq.currentPreset == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(preset),
                      selected: isSelected,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      selectedColor: SpotifyColors.green,
                      backgroundColor: SpotifyColors.surfaceElevated,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onSelected: eq.isEnabled
                          ? (sel) {
                              if (sel) {
                                HapticFeedback.lightImpact();
                                prov.setEqualizerPreset(preset);
                              }
                            }
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 5-Band Equalizer Sliders
            Expanded(
              child: Opacity(
                opacity: eq.isEnabled ? 1.0 : 0.4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final gain = eq.bandGains[index];
                      final freq = EqualizerSettings.bandLabels[index];
                      final desc = EqualizerSettings.bandDescriptions[index];

                      return Column(
                        children: [
                          // dB Gain Label
                          Text(
                            gain > 0
                                ? '+${gain.toStringAsFixed(1)} dB'
                                : '${gain.toStringAsFixed(1)} dB',
                            style: TextStyle(
                              color: gain.abs() > 0.1
                                  ? SpotifyColors.green
                                  : SpotifyColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),

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
                                      enabledThumbRadius: 7),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 14),
                                  trackHeight: 3.5,
                                ),
                                child: Slider(
                                  value: gain,
                                  min: -12.0,
                                  max: 12.0,
                                  onChanged: eq.isEnabled
                                      ? (val) {
                                          prov.setEqualizerBandGain(index, val);
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Frequency Label (60 Hz, 1 kHz, etc.)
                          Text(
                            freq,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            desc,
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

            const SizedBox(height: 16),

            // Bottom Actions: Reset to Flat
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh,
                        size: 18, color: SpotifyColors.textSecondary),
                    label: const Text(
                      'Zurücksetzen (Flat)',
                      style: TextStyle(color: SpotifyColors.textSecondary),
                    ),
                    onPressed: eq.isEnabled
                        ? () {
                            HapticFeedback.lightImpact();
                            prov.setEqualizerPreset('Flat');
                          }
                        : null,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpotifyColors.green,
                      foregroundColor: Colors.black,
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
