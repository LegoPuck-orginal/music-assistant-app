import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../services/github_feedback_service.dart';
import '../theme/spotify_colors.dart';

class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FeedbackSheet(),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final GitHubFeedbackService _service = GitHubFeedbackService();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _stepsCtrl = TextEditingController();
  final TextEditingController _tokenCtrl = TextEditingController();

  FeedbackCategory _category = FeedbackCategory.bug;
  bool _includeAppVersion = true;
  bool _showTokenSection = false;
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final saved = await _service.loadSavedGitHubToken();
    if (mounted && saved.isNotEmpty) {
      setState(() {
        _tokenCtrl.text = saved;
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _stepsCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit({bool forceBrowser = false}) async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      setState(() {
        _isError = true;
        _statusMessage = 'Bitte gib einen kurzen Titel und eine Beschreibung ein.';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
      _isError = false;
    });

    final prov = context.read<MusicProvider>();
    final token = _tokenCtrl.text.trim();
    await _service.saveGitHubToken(token);

    final GitHubIssueResult result;
    if (forceBrowser || token.isEmpty) {
      result = await _service.openPreFilledIssueInBrowser(
        category: _category,
        title: title,
        description: desc,
        stepsToReproduce: _stepsCtrl.text.trim(),
        includeAppVersion: _includeAppVersion,
        appVersion: prov.appVersion,
      );
    } else {
      result = await _service.createIssue(
        category: _category,
        title: title,
        description: desc,
        stepsToReproduce: _stepsCtrl.text.trim(),
        includeAppVersion: _includeAppVersion,
        appVersion: prov.appVersion,
        githubToken: token,
      );
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (result.success) {
        _isError = false;
        _statusMessage = result.openedInBrowser
            ? '✓ GitHub Issue wurde vorausgefüllt geöffnet!'
            : '✓ GitHub Issue #${result.issueNumber ?? ""} wurde direkt erstellt!';
        _titleCtrl.clear();
        _descCtrl.clear();
        _stepsCtrl.clear();
      } else {
        _isError = true;
        _statusMessage = result.errorMessage ?? 'Fehler beim Erstellen des Issues.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.86,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: SpotifyColors.orange.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.bug_report_rounded,
                      color: SpotifyColors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GITHUB ISSUE ERSTELLEN',
                          style: TextStyle(
                            color: SpotifyColors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          'Feedback & Fehler melden',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: SpotifyColors.borderSubtle, height: 20),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                children: [
                  const Text(
                    'KATEGORIE WÄHLEN',
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FeedbackCategory.values.map((cat) {
                      final selected = _category == cat;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _category = cat);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? SpotifyColors.orange.withValues(alpha: 0.2)
                                : SpotifyColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? SpotifyColors.orange
                                  : SpotifyColors.borderSubtle,
                              width: selected ? 1.3 : 0.9,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 6),
                              Text(
                                cat.title,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : SpotifyColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Titel
                  const Text(
                    'TITEL / KURZBESCHREIBUNG',
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'z. B. Lyrics-Animation oder neuer Wunsch...',
                      hintStyle: const TextStyle(color: SpotifyColors.textMuted),
                      filled: true,
                      fillColor: SpotifyColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpotifyColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpotifyColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpotifyColors.orange),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Beschreibung
                  const Text(
                    'DETAILS',
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText:
                          'Was ist passiert oder was soll verbessert werden?',
                      hintStyle: const TextStyle(color: SpotifyColors.textMuted),
                      filled: true,
                      fillColor: SpotifyColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpotifyColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpotifyColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpotifyColors.orange),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Schritte zum Reproduzieren (optional)
                  TextField(
                    controller: _stepsCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Schritte zum Reproduzieren (optional)',
                      labelStyle: const TextStyle(
                        color: SpotifyColors.textSecondary,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: SpotifyColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpotifyColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: SpotifyColors.borderSubtle),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Datenschutz-Garantie & Versions-Schalter
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SpotifyColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SpotifyColors.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              color: SpotifyColors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '100 % Datenschutz: Es werden niemals Server-IPs, Tokens oder persönliche Daten mitgesendet.',
                                style: TextStyle(
                                  color: SpotifyColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: SpotifyColors.borderSubtle, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'App-Versionsnummer anhängen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch.adaptive(
                              value: _includeAppVersion,
                              activeTrackColor: SpotifyColors.orange,
                              onChanged: (v) =>
                                  setState(() => _includeAppVersion = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Optionaler GitHub API Token für Direkt-Upload ohne Browser
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showTokenSection = !_showTokenSection),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _showTokenSection
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: SpotifyColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Optional: GitHub Token für direkten 1-Klick API-Upload',
                            style: TextStyle(
                              color: SpotifyColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showTokenSection) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tokenCtrl,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'ghp_... oder github_pat_... (nur lokal gespeichert)',
                        hintStyle: const TextStyle(
                          color: SpotifyColors.textMuted,
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: SpotifyColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isError
                            ? Colors.redAccent.withValues(alpha: 0.15)
                            : SpotifyColors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isError
                              ? Colors.redAccent
                              : SpotifyColors.orange,
                        ),
                      ),
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isError ? Colors.redAccent : Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: SpotifyColors.primaryGradient,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        onPressed: _isSubmitting ? null : () => _submit(),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.black),
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.black),
                        label: Text(
                          _isSubmitting
                              ? 'Wird erstellt...'
                              : 'GITHUB ISSUE ERSTELLEN',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
