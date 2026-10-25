import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_service.dart';

enum FeedbackCategory {
  bug(
    title: 'Fehler / Bug',
    emoji: '🐛',
    githubLabel: 'bug',
    titlePrefix: '[Bug]',
  ),
  feature(
    title: 'Feature-Wunsch',
    emoji: '✨',
    githubLabel: 'enhancement',
    titlePrefix: '[Feature]',
  ),
  aiDj(
    title: 'KI-DJ & Stimme',
    emoji: '🎧',
    githubLabel: 'ai-dj',
    titlePrefix: '[KI-DJ]',
  ),
  lyrics(
    title: 'Lyrics & Sync',
    emoji: '🎤',
    githubLabel: 'lyrics',
    titlePrefix: '[Lyrics]',
  ),
  uiDesign(
    title: 'Design & Animation',
    emoji: '🎨',
    githubLabel: 'design',
    titlePrefix: '[UI/UX]',
  );

  final String title;
  final String emoji;
  final String githubLabel;
  final String titlePrefix;

  const FeedbackCategory({
    required this.title,
    required this.emoji,
    required this.githubLabel,
    required this.titlePrefix,
  });
}

class GitHubIssueResult {
  final bool success;
  final String? issueUrl;
  final int? issueNumber;
  final bool openedInBrowser;
  final String? errorMessage;

  const GitHubIssueResult({
    required this.success,
    this.issueUrl,
    this.issueNumber,
    this.openedInBrowser = false,
    this.errorMessage,
  });
}

/// Service zum direkten Erstellen von GitHub Issues aus der App heraus.
/// Achtet strikt auf Datenschutz: Es werden keinerlei persönliche Daten,
/// Server-IPs, Benutzernamen oder Tokens in den Issue-Text aufgenommen.
class GitHubFeedbackService {
  static const String repoOwner = UpdateService.repoOwner;
  static const String repoName = UpdateService.repoName;
  static const String _keyGithubToken = 'mass_github_feedback_token';

  final http.Client _client;

  GitHubFeedbackService({http.Client? client})
      : _client = client ?? http.Client();

  Future<String> loadSavedGitHubToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGithubToken) ?? '';
  }

  Future<void> saveGitHubToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_keyGithubToken);
    } else {
      await prefs.setString(_keyGithubToken, trimmed);
    }
  }

  /// Baut den strukturierten, komplett anonymisierten Markdown-Text für das GitHub Issue
  static String formatIssueBody({
    required FeedbackCategory category,
    required String description,
    String? stepsToReproduce,
    bool includeAppVersion = true,
    String? appVersion,
  }) {
    final buf = StringBuffer();
    buf.writeln('### ${category.emoji} Kategorie');
    buf.writeln('**${category.title}** (`${category.githubLabel}`)');
    buf.writeln();
    buf.writeln('### 📝 Beschreibung');
    buf.writeln(description.trim());

    if (stepsToReproduce != null && stepsToReproduce.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln('### 🔄 Schritte zum Reproduzieren');
      buf.writeln(stepsToReproduce.trim());
    }

    if (includeAppVersion) {
      buf.writeln();
      buf.writeln('---');
      buf.writeln('### 📱 Technische Umgebung (Anonymisiert)');
      buf.writeln('- **App-Version:** `${appVersion ?? UpdateService.defaultCurrentVersion}`');
      buf.writeln('- **Plattform:** `iOS / Flutter`');
      buf.writeln('- **Quelle:** `In-App Feedback Assistent`');
    }

    return buf.toString();
  }

  /// Baut die vorausgefüllte GitHub Issue Web-URL (funktioniert ohne API-Token)
  static Uri buildGitHubWebIssueUri({
    required FeedbackCategory category,
    required String title,
    required String body,
  }) {
    final cleanTitle = title.trim();
    final fullTitle = cleanTitle.startsWith('[')
        ? cleanTitle
        : '${category.titlePrefix} $cleanTitle';

    // Begrenzung auf 3500 Zeichen, damit Mobile Safari/Chrome die Web-URL nicht verwerfen
    final safeBody = body.length > 3500
        ? '${body.substring(0, 3450)}\n\n[...Bericht für Web-URL gekürzt]'
        : body;

    return Uri.https(
      'github.com',
      '/$repoOwner/$repoName/issues/new',
      {
        'title': fullTitle,
        'body': safeBody,
        'labels': category.githubLabel,
      },
    );
  }

  /// Erstellt ein GitHub Issue entweder direkt per GitHub REST API (falls Token vorhanden)
  /// oder öffnet das fertig ausgefüllte GitHub-Issue-Formular im Browser.
  Future<GitHubIssueResult> createIssue({
    required FeedbackCategory category,
    required String title,
    required String description,
    String? stepsToReproduce,
    bool includeAppVersion = true,
    String? appVersion,
    String? githubToken,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || description.trim().isEmpty) {
      return const GitHubIssueResult(
        success: false,
        errorMessage: 'Bitte gib einen Titel und eine Beschreibung ein.',
      );
    }

    final fullTitle = cleanTitle.startsWith('[')
        ? cleanTitle
        : '${category.titlePrefix} $cleanTitle';

    final body = formatIssueBody(
      category: category,
      description: description,
      stepsToReproduce: stepsToReproduce,
      includeAppVersion: includeAppVersion,
      appVersion: appVersion,
    );

    final token = (githubToken ?? await loadSavedGitHubToken()).trim();

    // 1. Direkter GitHub REST API Upload, falls ein Personal Access Token hinterlegt wurde
    if (token.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://api.github.com/repos/$repoOwner/$repoName/issues',
        );
        final response = await _client
            .post(
              uri,
              headers: {
                'Accept': 'application/vnd.github+json',
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'User-Agent': 'MusicAssistant-iOS-Feedback',
              },
              body: jsonEncode({
                'title': fullTitle,
                'body': body,
                'labels': [category.githubLabel],
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return GitHubIssueResult(
            success: true,
            issueUrl: data['html_url'] as String?,
            issueNumber: (data['number'] as num?)?.toInt(),
            openedInBrowser: false,
          );
        } else {
          debugPrint(
            '[GitHubFeedbackService] API status ${response.statusCode}: ${response.body}',
          );
          return GitHubIssueResult(
            success: false,
            errorMessage:
                'GitHub API Fehler (${response.statusCode}). Prüfe deinen Token oder nutze „Im Browser öffnen“.',
          );
        }
      } catch (e) {
        debugPrint('[GitHubFeedbackService] API error: $e');
        return const GitHubIssueResult(
          success: false,
          errorMessage: 'Netzwerkfehler beim direkten Senden an die GitHub API.',
        );
      }
    }

    // 2. Zero-Config Direkt-Erstellung über GitHub Web Issue URL
    return openPreFilledIssueInBrowser(
      category: category,
      title: cleanTitle,
      description: description,
      stepsToReproduce: stepsToReproduce,
      includeAppVersion: includeAppVersion,
      appVersion: appVersion,
    );
  }

  Future<GitHubIssueResult> openPreFilledIssueInBrowser({
    required FeedbackCategory category,
    required String title,
    required String description,
    String? stepsToReproduce,
    bool includeAppVersion = true,
    String? appVersion,
  }) async {
    final body = formatIssueBody(
      category: category,
      description: description,
      stepsToReproduce: stepsToReproduce,
      includeAppVersion: includeAppVersion,
      appVersion: appVersion,
    );
    final webUri = buildGitHubWebIssueUri(
      category: category,
      title: title,
      body: body,
    );

    try {
      final launched = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      return GitHubIssueResult(
        success: launched,
        issueUrl: webUri.toString(),
        openedInBrowser: true,
        errorMessage:
            launched ? null : 'GitHub konnte nicht im Browser geöffnet werden.',
      );
    } catch (e) {
      return GitHubIssueResult(
        success: false,
        issueUrl: webUri.toString(),
        errorMessage: 'Fehler beim Öffnen von GitHub: $e',
      );
    }
  }
}
