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
