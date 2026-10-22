import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant_app/models/dsp_models.dart';
import 'package:music_assistant_app/providers/music_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DSP & Equalizer Unit Tests', () {
    test('DspBand formats frequencies correctly', () {
      const bandLow = DspBand(frequency: 42.0, gain: 2.0);
      expect(bandLow.formattedFreq, '42 Hz');

      const bandMid = DspBand(frequency: 220.0, gain: -2.5);
      expect(bandMid.formattedFreq, '220 Hz');

      const bandHigh = DspBand(frequency: 2600.0, gain: 1.5);
      expect(bandHigh.formattedFreq, '2.6 kHz');

      const bandTreble = DspBand(frequency: 14000.0, gain: 0.0);
      expect(bandTreble.formattedFreq, '14 kHz');
    });

    test('DspConfig.fromJson parses server JSON correctly', () {
      final json = {
        'enabled': true,
        'input_gain': 0.0,
        'output_gain': 0.0,
        'preset_id': 'djwkbum5',
        'filters': [
          {
            'enabled': true,
            'type': 'parametric_eq',
            'preamp': -4.5,
            'per_channel_preamp': {},
            'bands': [
              {
                'frequency': 42.0,
                'q': 1.2,
                'gain': 2.0,
                'type': 'peak',
                'enabled': true,
                'channel': 'ALL',
              },
              {
                'frequency': 85.0,
                'q': 1.5,
                'gain': 4.5,
                'type': 'peak',
                'enabled': true,
                'channel': 'ALL',
              },
            ],
          },
          {
            'enabled': true,
            'type': 'stereo_width',
            'width': 1.35,
          }
        ],
      };

      final config = DspConfig.fromJson(json);
      expect(config.enabled, isTrue);
      expect(config.presetId, 'djwkbum5');
      expect(config.filters.length, 2);

      final peq = config.parametricEqFilter;
      expect(peq, isNotNull);
      expect(peq!.preamp, -4.5);
      expect(peq.bands.length, 2);
      expect(peq.bands[0].frequency, 42.0);
      expect(peq.bands[0].gain, 2.0);
      expect(peq.bands[1].frequency, 85.0);
      expect(peq.bands[1].gain, 4.5);
    });

    test('DspPreset.fromJson parses preset name and config', () {
      final presetJson = {
        'name': 'ARC Daily Punch',
        'preset_id': 'djwkbum5',
        'config': {
          'enabled': true,
          'filters': [
            {
              'type': 'parametric_eq',
              'enabled': true,
              'preamp': -4.5,
              'bands': [
                {'frequency': 42.0, 'gain': 2.0},
              ],
            }
          ],
        },
      };

      final preset = DspPreset.fromJson(presetJson);
      expect(preset.name, 'ARC Daily Punch');
      expect(preset.presetId, 'djwkbum5');
      expect(preset.config.enabled, isTrue);
      expect(preset.config.bands.length, 1);
    });

    test('MusicProvider updates DSP band gains and preamp in memory', () {
      final prov = MusicProvider();

      // Test gain update
      prov.updateDspBandGain(0, 3.5);
      expect(prov.dspConfig?.bands[0].gain, 3.5);
      expect(prov.dspConfig?.presetId, isNull); // Custom modification clears preset

      // Test preamp update
      prov.updateDspPreamp(-2.0);
      expect(prov.dspConfig?.preamp, -2.0);

      // Test reset to flat
      prov.resetDspToFlat();
      for (final band in prov.dspConfig!.bands) {
        expect(band.gain, 0.0);
      }
      expect(prov.dspConfig!.preamp, 0.0);
    });
  });
}
