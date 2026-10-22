/// Repräsentiert Versions- und Download-Informationen für In-App-Updates
class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseName;
  final String changelog;
  final String downloadUrl;
  final String htmlUrl;
  final DateTime? publishedAt;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.changelog,
    required this.downloadUrl,
    required this.htmlUrl,
    this.publishedAt,
    required this.hasUpdate,
  });

  /// Direktes Apple iOS Over-The-Air Installationsprotokoll (funktioniert ohne Drittanbieter-App)
  String get directOtaUrl =>
      'itms-services://?action=download-manifest&url=https://raw.githubusercontent.com/LegoPuck-orginal/music-assistant-app/main/ios/ota_manifest.plist';

  // Optionale Drittanbieter-Links für Tests
  String get sideStoreUrl =>
      'sidestore://install?url=${Uri.encodeComponent(downloadUrl)}';

  String get altStoreUrl =>
      'altstore://install?url=${Uri.encodeComponent(downloadUrl)}';

  factory AppUpdateInfo.noUpdate({required String currentVersion}) {
    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      releaseName: 'Aktuelle Version',
      changelog: '',
      downloadUrl:
          'https://github.com/LegoPuck-orginal/music-assistant-app/releases/download/latest/music-assistant.ipa',
      htmlUrl:
          'https://github.com/LegoPuck-orginal/music-assistant-app/releases',
      hasUpdate: false,
    );
  }
}
