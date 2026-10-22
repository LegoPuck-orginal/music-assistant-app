import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update_info.dart';
import '../services/update_service.dart';
import '../theme/spotify_colors.dart';

class UpdateDialog extends StatefulWidget {
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

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _progressText = '';
  bool _isFinished = false;

  Future<void> _startDirectUpdate() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.05;
      _progressText = 'Update wird vorbereitet...';
    });

    final updater = UpdateService();
    try {
      // 1. Direktes OTA Protokoll versuchen
      final launched = await UpdateService.installDirectOta(widget.updateInfo.directOtaUrl);

      if (launched) {
        setState(() {
          _isDownloading = false;
          _isFinished = true;
          _progressText = 'iOS System-Installation gestartet!';
        });
        return;
      }

      // 2. Fallback: Datei direkt in der App herunterladen
      await updater.downloadUpdateIpa(
        widget.updateInfo.downloadUrl,
        onProgress: (prog, received, total) {
          if (mounted) {
            setState(() {
              _progress = prog;
              final recMB = (received / (1024 * 1024)).toStringAsFixed(1);
              final totMB = (total / (1024 * 1024)).toStringAsFixed(1);
              _progressText =
                  '${(prog * 100).toInt()}% • $recMB MB von $totMB MB geladen';
            });
          }
        },
      );

      // Nach Abschluss erneut OTA triggern
      await UpdateService.installDirectOta(widget.updateInfo.directOtaUrl);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isFinished = true;
          _progressText =
              'Download fertig! Bestätige das iOS-Installationsfenster.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progressText = 'Fehler beim Update: $e';
        });
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String urlStr) async {
    final uri = Uri.parse(urlStr);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final hasUpdate = info.hasUpdate;

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
                              ? 'Neues Update verfügbar'
                              : 'App ist auf dem neuesten Stand',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasUpdate
                              ? 'Direktes In-App-Update ohne weitere Apps'
                              : 'Du nutzt die aktuellste Version',
                          style: const TextStyle(
                            color: SpotifyColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Version Badges
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: SpotifyColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SpotifyColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'INSTALLIERT',
                          style: TextStyle(
                            color: SpotifyColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v${info.currentVersion}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward,
                        color: SpotifyColors.textSecondary, size: 18),
                    Column(
                      children: [
                        const Text(
                          'NEUESTE VERSION',
                          style: TextStyle(
                            color: SpotifyColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v${info.latestVersion}',
                          style: TextStyle(
                            color: hasUpdate
                                ? SpotifyColors.green
                                : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Progress Bar during download
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: SpotifyColors.surfaceHighlight,
                    valueColor:
                        const AlwaysStoppedAnimation(SpotifyColors.green),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _progressText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: SpotifyColors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_isFinished) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SpotifyColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SpotifyColors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: SpotifyColors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _progressText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Actions
              if (hasUpdate && !_isFinished) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpotifyColors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.download_for_offline, size: 20),
                  label: Text(
                    _isDownloading
                        ? 'Wird heruntergeladen...'
                        : 'Jetzt direkt in der App installieren',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: _isDownloading
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _startDirectUpdate();
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
                      _launchUrl(context, info.htmlUrl);
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
