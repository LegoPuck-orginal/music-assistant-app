import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// SendspinPlayerService verbindet das iPhone nativ über das Sendspin-Protokoll
/// mit dem Music Assistant Server.
/// Dadurch agiert das iPhone als vollwertiger Player (Sample-genau, Hi-Fi,
/// volle Songlänge ohne Spotify-30s-Vorschau-Beschränkung).
class SendspinPlayerService {
  static final SendspinPlayerService _instance =
      SendspinPlayerService._internal();
  factory SendspinPlayerService() => _instance;
  SendspinPlayerService._internal();

  HeadlessInAppWebView? _headlessWebView;
  InAppWebViewController? _webViewController;

  bool _isInitialized = false;
  bool _isReady = false;
  String? _clientId;
  String? serverPlayerId;
  String? _currentServerUrl;
  Map<String, dynamic>? _lastState;

  final StreamController<Map<String, dynamic>> _stateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onStateChanged => _stateController.stream;
  bool get isReady => _isReady;
  bool get isInitialized => _isInitialized;
  String? get clientId => _clientId;
  Map<String, dynamic>? get lastState => _lastState;

  /// Initialisiert den Headless Sendspin Player im Hintergrund
  Future<void> initialize({
    required String serverUrl,
    String clientName = 'Dieses iPhone',
  }) async {
    final cleanUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (_isInitialized && _currentServerUrl == cleanUrl && _isReady) {
      debugPrint('[Sendspin] Bereits verbunden mit $cleanUrl');
      return;
    }

    _currentServerUrl = cleanUrl;
    _isReady = false;

    // In Unit-Tests oder Web ohne native Headless WebView sofort bereit simulieren
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      _isInitialized = true;
      _isReady = true;
      _clientId = 'mock_sendspin_client_test';
      debugPrint('[Sendspin] Test-Umgebung: Sendspin Mock aktiv.');
      return;
    }

    try {
      await dispose();

      // Sendspin Bundle Script aus Assets laden
      String bundleJs = '';
      try {
        bundleJs = await rootBundle.loadString('assets/js/sendspin.bundle.js');
      } catch (e) {
        debugPrint('[Sendspin] Fehler beim Laden von assets/js/sendspin.bundle.js: $e');
      }

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sendspin Player Bridge</title>
</head>
<body style="background: transparent; margin: 0; padding: 0;">
  <audio id="dummy-media" preload="auto" playsinline loop></audio>
  <script>
$bundleJs
  </script>
  <script>
    let player = null;
    let registeredClientId = null;

    window.initSendspin = async function(baseUrl, clientName) {
      console.log("[Sendspin JS] Initialisiere mit baseUrl:", baseUrl, "clientName:", clientName);
      if (player) {
        try { player.disconnect("reconnect"); } catch (e) {}
        player = null;
      }

      try {
        const PlayerClass = (window.SendspinSDK && window.SendspinSDK.SendspinPlayer) || window.SendspinPlayer;
        if (!PlayerClass) {
          throw new Error("SendspinPlayer Klasse nicht gefunden");
        }

        player = new PlayerClass({
          baseUrl: baseUrl,
          clientName: clientName || "Dieses iPhone",
          productName: "Music Assistant iOS",
          correctionMode: "quality-local",
          requiredLeadTimeMs: 250,
          minBufferMs: 250,
          onStateChange: (state) => {
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('onSendspinState', JSON.stringify(state));
            }
          }
        });

        await player.unlock();
        await player.connect();

        registeredClientId = player.clientId;
        console.log("[Sendspin JS] Verbunden mit clientId:", registeredClientId);

        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('onSendspinReady', JSON.stringify({
            clientId: registeredClientId,
            clientName: clientName || "Dieses iPhone"
          }));
        }
        return { success: true, clientId: registeredClientId };
      } catch (err) {
        console.error("[Sendspin JS] Fehler bei init/connect:", err);
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('onSendspinError', err.toString());
        }
        return { success: false, error: err.toString() };
      }
    };

    window.sendspinUnlock = async function() {
      if (player) {
        try {
          await player.unlock();
          return true;
        } catch (e) {
          console.error("[Sendspin JS] unlock error:", e);
        }
      }
      return false;
    };

    window.sendspinCommand = function(cmd, args) {
      if (!player) return;
      try {
        if (cmd === 'volume') {
          const vol = (args && args.volume !== undefined) ? args.volume : 50;
          player.setVolume(vol);
        } else if (cmd === 'mute') {
          const muted = (args && args.muted !== undefined) ? args.muted : false;
          player.setMuted(muted);
        } else {
          player.sendCommand(cmd, args || {});
        }
      } catch (e) {
        console.error("[Sendspin JS] Command error:", cmd, e);
      }
    };

    window.sendspinDisconnect = function(reason) {
      if (player) {
        try {
          player.disconnect(reason || "user_request");
        } catch (e) {}
      }
    };
  </script>
</body>
</html>
''';

      _headlessWebView = HeadlessInAppWebView(
        initialData: InAppWebViewInitialData(
          data: htmlContent,
          baseUrl: WebUri(cleanUrl),
        ),
        initialSettings: InAppWebViewSettings(
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
          javaScriptEnabled: true,
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;

          // JavaScript-to-Flutter Handlers
          controller.addJavaScriptHandler(
            handlerName: 'onSendspinReady',
            callback: (args) {
              try {
                if (args.isNotEmpty) {
                  final data = jsonDecode(args.first.toString());
                  _clientId = data['clientId']?.toString();
                  _isReady = true;
                  debugPrint('[Sendspin] Bereit! ClientId: $_clientId');
                }
              } catch (e) {
                debugPrint('[Sendspin] onSendspinReady parse error: $e');
              }
            },
          );

          controller.addJavaScriptHandler(
            handlerName: 'onSendspinState',
            callback: (args) {
              try {
                if (args.isNotEmpty) {
                  final data = jsonDecode(args.first.toString());
                  if (data is Map<String, dynamic>) {
                    _lastState = data;
                    _stateController.add(data);
                  }
                }
              } catch (e) {
                debugPrint('[Sendspin] onSendspinState parse error: $e');
              }
            },
          );

          controller.addJavaScriptHandler(
            handlerName: 'onSendspinError',
            callback: (args) {
              debugPrint('[Sendspin JS Error] ${args.join(', ')}');
            },
          );
        },
        onLoadStop: (controller, url) async {
          debugPrint('[Sendspin] WebView geladen. Starte Sendspin Verbindung...');
          await controller.evaluateJavascript(
            source: "window.initSendspin('$cleanUrl', '$clientName');",
          );
        },
      );

      await _headlessWebView!.run();
      _isInitialized = true;
      debugPrint('[Sendspin] HeadlessInAppWebView erfolgreich gestartet.');
    } catch (e) {
      debugPrint('[Sendspin] Fehler beim Starten des Sendspin Players: $e');
    }
  }

  /// Entsperrt den Web Audio Context für sofortige verzögerungsfreie Wiedergabe
  Future<void> unlock() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await _webViewController?.evaluateJavascript(
        source: 'window.sendspinUnlock();',
      );
    } catch (e) {
      debugPrint('[Sendspin] unlock error: $e');
    }
  }

  /// Sendet Steuerbefehle an den Sendspin Player
  Future<void> sendCommand(String cmd, [Map<String, dynamic>? args]) async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final argsJson = jsonEncode(args ?? {});
      await _webViewController?.evaluateJavascript(
        source: "window.sendspinCommand('$cmd', $argsJson);",
      );
    } catch (e) {
      debugPrint('[Sendspin] sendCommand ($cmd) error: $e');
    }
  }

  /// Lokale Lautstärkeregelung des Sendspin Players (0 - 100)
  Future<void> setVolume(int volume) async {
    await sendCommand('volume', {'volume': volume.clamp(0, 100)});
  }

  /// Stummschaltung
  Future<void> setMuted(bool muted) async {
    await sendCommand('mute', {'muted': muted});
  }

  /// Trennt die Sendspin Verbindung sauber
  Future<void> disconnect([String reason = 'user_request']) async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await _webViewController?.evaluateJavascript(
        source: "window.sendspinDisconnect('$reason');",
      );
    } catch (_) {}
  }

  /// Gibt alle Ressourcen frei
  Future<void> dispose() async {
    try {
      await disconnect('dispose');
      await _headlessWebView?.dispose();
    } catch (_) {}
    _headlessWebView = null;
    _webViewController = null;
    _isInitialized = false;
    _isReady = false;
  }
}
