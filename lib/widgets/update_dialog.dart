import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update_info.dart';
import '../theme/spotify_colors.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdateDialog(updateInfo: info),
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlStr) async {
    final uri = Uri.parse(urlStr);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        // Fallback: in browser
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Konnte Link nicht öffnen: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUpdate = updateInfo.hasUpdate;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: SpotifyColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 20),

              // Status Icon & Title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasUpdate
                          ? SpotifyColors.green.withValues(alpha: 0.15)
                          : SpotifyColors.surfaceHighlight,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasUpdate
                            ? SpotifyColors.green
                            : SpotifyColors.textMuted,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      hasUpdate ? Icons.system_update_alt : Icons.check_circle,
                      color: hasUpdate
                          ? SpotifyColors.green
                          : SpotifyColors.textSecondary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasUpdate
                              ? 'Neues Update verfügbar!'
                              : 'App ist auf dem neuesten Stand',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasUpdate
                              ? 'v${updateInfo.currentVersion} ➔ v${updateInfo.latestVersion}'
                              : 'Installiert: v${updateInfo.currentVersion}',
                          style: TextStyle(
                            color: hasUpdate
                                ? SpotifyColors.green
                                : SpotifyColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Release Notes / Changelog
              if (hasUpdate && updateInfo.changelog.isNotEmpty) ...[
                const Text(
                  'WAS IST NEU?',
                  style: TextStyle(
                    color: SpotifyColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: SpotifyColors.surfaceHighlight,
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        updateInfo.changelog.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else if (!hasUpdate) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SpotifyColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Du verwendest bereits die aktuellste Version von Music Assistant iOS. Sobald ein neues Release auf GitHub erscheint, wirst du hier direkt benachrichtigt.',
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Actions
              if (hasUpdate) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpotifyColors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.install_mobile, size: 20),
                  label: const Text(
                    'Mit SideStore / AltStore installieren',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _launchUrl(context, updateInfo.altStoreUrl);
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: SpotifyColors.surfaceHighlight),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text(
                    'IPA herunterladen (Safari)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _launchUrl(context, updateInfo.downloadUrl);
                  },
                ),
                const SizedBox(height: 10),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new,
                        size: 14, color: SpotifyColors.textSecondary),
                    label: const Text(
                      'Releases auf GitHub',
                      style: TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () {
                      _launchUrl(context, updateInfo.htmlUrl);
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Schließen',
                      style: TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
