import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update_info.dart';

class UpdateService {
  static const String repoOwner = 'LegoPuck-orginal';
  static const String repoName = 'music-assistant-app';
  static const String defaultCurrentVersion = '1.2.0';

  final http.Client _client;

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// Ruft die aktuelle App-Version vom Gerät ab (oder Fallback)
  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        return info.version;
      }
    } catch (e) {
      debugPrint('[UpdateService] PackageInfo error: $e');
    }
    return defaultCurrentVersion;
  }

  /// Prüft GitHub Releases auf eine neuere Version
  Future<AppUpdateInfo> checkForUpdate({String? currentVersionOverride}) async {
    final currentVersion =
        currentVersionOverride ?? await getCurrentVersion();

    final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases');

    try {
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'MusicAssistant-iOS-Updater',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
            '[UpdateService] GitHub releases check failed with status ${response.statusCode}');
        return AppUpdateInfo.noUpdate(currentVersion: currentVersion);
      }

      final List<dynamic> releases = jsonDecode(response.body) as List<dynamic>;
      if (releases.isEmpty) {
        return AppUpdateInfo.noUpdate(currentVersion: currentVersion);
      }

      // Suche nach dem neuesten versionierten Release (z. B. v1.6.0)
      Map<String, dynamic>? latestRelease;
      for (final r in releases) {
        final map = r as Map<String, dynamic>;
        final tag = map['tag_name']?.toString() ?? '';
        if (tag.startsWith('v')) {
          latestRelease = map;
          break;
        }
      }

      // Fallback auf das erste Release, falls keine v-Tags vorhanden
      latestRelease ??= releases.first as Map<String, dynamic>;

      final rawTag = latestRelease['tag_name']?.toString() ?? 'latest';
      final cleanRemoteVersion = rawTag.replaceFirst(RegExp(r'^v'), '');
      final releaseName =
          latestRelease['name']?.toString() ?? 'Music Assistant iOS';
      final changelog = latestRelease['body']?.toString() ?? '';
      final htmlUrl = latestRelease['html_url']?.toString() ??
          'https://github.com/$repoOwner/$repoName/releases';
      final publishedStr = latestRelease['published_at']?.toString();
      final publishedAt =
          publishedStr != null ? DateTime.tryParse(publishedStr) : null;

      // Finde den optimalen .ipa Download-Link in den Assets
      // Priorität 1: Standalone 'music-assistant.ipa' (garantiert ohne Companion-ID-Konflikt)
      // Priorität 2: IPA ohne 'with-watch'
      // Priorität 3: Jede beliebige IPA
      String downloadUrl =
          'https://github.com/$repoOwner/$repoName/releases/latest/download/music-assistant.ipa';
      final assets = (latestRelease['assets'] as List<dynamic>?) ?? [];
      String? fallbackIpaUrl;

      for (final a in assets) {
        final assetMap = a as Map<String, dynamic>;
        final name = assetMap['name']?.toString() ?? '';
        final browserUrl = assetMap['browser_download_url']?.toString();
        if (browserUrl == null || browserUrl.isEmpty) continue;

        if (name == 'music-assistant.ipa') {
          downloadUrl = browserUrl;
          break;
        } else if (name.endsWith('.ipa') && !name.contains('with-watch')) {
          fallbackIpaUrl ??= browserUrl;
        } else if (name.endsWith('.ipa')) {
          fallbackIpaUrl ??= browserUrl;
        }
      }
      if (downloadUrl.contains('latest/download') && fallbackIpaUrl != null) {
        downloadUrl = fallbackIpaUrl;
      }

      final hasUpdate = isVersionNewer(currentVersion, cleanRemoteVersion);

      return AppUpdateInfo(
        currentVersion: currentVersion,
        latestVersion: cleanRemoteVersion,
        releaseName: releaseName,
        changelog: changelog,
        downloadUrl: downloadUrl,
        htmlUrl: htmlUrl,
        publishedAt: publishedAt,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      debugPrint('[UpdateService] Update check exception: $e');
      return AppUpdateInfo.noUpdate(currentVersion: currentVersion);
    }
  }

  /// Lädt die Update-IPA Datei direkt in der App herunter (mit Fortschritts-Callback)
  Future<File?> downloadUpdateIpa(
    String downloadUrl, {
    required Function(double progress, int receivedBytes, int totalBytes) onProgress,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final updatesDir = Directory('${docsDir.path}/updates');
      if (!updatesDir.existsSync()) {
        updatesDir.createSync(recursive: true);
      }
      final targetFile = File('${updatesDir.path}/music-assistant-latest.ipa');

      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.followRedirects = true;
      request.maxRedirects = 10;
      final response = await _client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final total = response.contentLength ?? (25 * 1024 * 1024);
        int received = 0;
        final sink = targetFile.openWrite();

        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          final progress = total > 0
              ? (received / total).clamp(0.02, 0.99)
              : 0.5;
          onProgress(progress, received, total);
        }

        await sink.flush();
        await sink.close();
        onProgress(1.0, received, total);
        return targetFile;
      } else {
        debugPrint(
            '[UpdateService] Download failed with status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[UpdateService] downloadUpdateIpa error: $e');
    }
    return null;
  }

  /// Teilt die heruntergeladene IPA Datei über das native iOS Share Sheet
  /// (erlaubt 'In Dateien sichern', AirDrop, Öffnen in Sideloadern)
  static Future<bool> shareFile(String path) async {
    const channel = MethodChannel('de.timm.musicAssistantApp/native_utils');
    try {
      final res = await channel.invokeMethod<bool>('shareFile', {'path': path});
      return res ?? false;
    } catch (e) {
      debugPrint('[UpdateService] shareFile error: $e');
      return false;
    }
  }

  /// Führt die direkte Apple iOS OTA-Installation aus (ohne externe App)
  static Future<bool> installDirectOta(String otaUrl) async {
    final uri = Uri.parse(otaUrl);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UpdateService] installDirectOta error: $e');
      return false;
    }
  }

  /// Vergleicht zwei semantische Versionsnummern (z.B. "1.2.0" und "1.2.1")
  static bool isVersionNewer(String current, String remote) {
    if (remote.toLowerCase() == 'latest') return false;

    try {
      final curClean = current.trim().replaceFirst(RegExp(r'^v'), '');
      final remClean = remote.trim().replaceFirst(RegExp(r'^v'), '');

      if (curClean == remClean) return false;

      final curParts = curClean.split(RegExp(r'[+\-]'));
      final remParts = remClean.split(RegExp(r'[+\-]'));

      final curNums = curParts[0]
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final remNums = remParts[0]
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      while (curNums.length < 3) {
        curNums.add(0);
      }
      while (remNums.length < 3) {
        remNums.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (remNums[i] > curNums[i]) return true;
        if (remNums[i] < curNums[i]) return false;
      }

      // Fallback auf Build-Nummer falls Hauptversionsnummer identisch
      if (curParts.length > 1 && remParts.length > 1) {
        final curBuild = int.tryParse(curParts[1]) ?? 0;
        final remBuild = int.tryParse(remParts[1]) ?? 0;
        return remBuild > curBuild;
      }
    } catch (_) {}
    return false;
  }
}
