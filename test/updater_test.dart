import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:music_assistant_app/models/app_update_info.dart';
import 'package:music_assistant_app/services/update_service.dart';

void main() {
  group('UpdateService & Semantic Versioning Tests', () {
    test('isVersionNewer compares version numbers correctly', () {
      expect(UpdateService.isVersionNewer('1.2.0', '1.2.1'), isTrue);
      expect(UpdateService.isVersionNewer('1.2.0', '1.3.0'), isTrue);
      expect(UpdateService.isVersionNewer('1.2.0', '2.0.0'), isTrue);
      expect(UpdateService.isVersionNewer('1.2.0', '1.2.0'), isFalse);
      expect(UpdateService.isVersionNewer('1.2.0', '1.1.9'), isFalse);
      expect(UpdateService.isVersionNewer('v1.2.0', 'v1.2.1'), isTrue);
      expect(UpdateService.isVersionNewer('1.2.0', 'latest'), isFalse);
    });

    test('isVersionNewer compares build numbers when main version matches', () {
      expect(UpdateService.isVersionNewer('1.2.0+5', '1.2.0+6'), isTrue);
      expect(UpdateService.isVersionNewer('1.2.0+6', '1.2.0+5'), isFalse);
    });

    test('AppUpdateInfo generates valid AltStore and SideStore URLs', () {
      const info = AppUpdateInfo(
        currentVersion: '1.2.0',
        latestVersion: '1.2.1',
        releaseName: 'v1.2.1',
        changelog: 'Fixes',
        downloadUrl:
            'https://github.com/LegoPuck-orginal/music-assistant-app/releases/download/v1.2.1/music-assistant.ipa',
        htmlUrl: 'https://github.com/LegoPuck-orginal/music-assistant-app',
        hasUpdate: true,
      );

      expect(info.altStoreUrl, startsWith('altstore://install?url='));
      expect(info.sideStoreUrl, startsWith('sidestore://install?url='));
      expect(info.altStoreUrl, contains('music-assistant.ipa'));
      expect(info.directOtaUrl, startsWith('itms-services://?action=download-manifest'));
      expect(info.directOtaUrl, contains('ota_manifest.plist'));
    });

    test('UpdateService parses GitHub releases API accurately', () async {
      final mockReleases = [
        {
          'tag_name': 'v1.3.0',
          'name': 'Music Assistant iOS v1.3.0',
          'body': 'Great new features',
          'html_url':
              'https://github.com/LegoPuck-orginal/music-assistant-app/releases/tag/v1.3.0',
          'published_at': '2026-10-22T21:00:00Z',
          'assets': [
            {
              'name': 'music-assistant.ipa',
              'browser_download_url':
                  'https://github.com/LegoPuck-orginal/music-assistant-app/releases/download/v1.3.0/music-assistant.ipa',
            }
          ]
        }
      ];

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockReleases), 200);
      });

      final service = UpdateService(client: mockClient);
      final update =
          await service.checkForUpdate(currentVersionOverride: '1.2.0');

      expect(update.hasUpdate, isTrue);
      expect(update.latestVersion, '1.3.0');
      expect(update.releaseName, 'Music Assistant iOS v1.3.0');
      expect(update.changelog, 'Great new features');
      expect(update.downloadUrl,
          'https://github.com/LegoPuck-orginal/music-assistant-app/releases/download/v1.3.0/music-assistant.ipa');
    });
  });
}
