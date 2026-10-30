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
  String _authToken = '';
  String _clientName = 'Dieses iPhone';
  Map<String, String> _identityStore = {};
  Future<void> Function(Map<String, String> items)? _onPersistIdentity;
  Timer? _reconnectTimer;
  bool _stopped = false;
  Map<String, dynamic>? _lastState;

  final StreamController<Map<String, dynamic>> _stateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _readyController =
      StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onStateChanged => _stateController.stream;
  Stream<String> get onReady => _readyController.stream;
  bool get isReady => _isReady;
  bool get isInitialized => _isInitialized;
  String? get clientId => _clientId;

  /// Name, unter dem sich dieses iPhone beim Server registriert. Er ist durch
  /// ein persistentes Zufalls-Suffix eindeutig und dient der Zuordnung zur
  /// vom Server vergebenen Player-ID (die NICHT der SDK-Client-ID entspricht).
  String get clientName => _clientName;
  Map<String, dynamic>? get lastState => _lastState;

  /// Initialisiert den Headless Sendspin Player im Hintergrund
  Future<void> initialize({
    required String serverUrl,
    String clientName = 'Dieses iPhone',
    String authToken = '',
    Map<String, String>? identityStore,
    Future<void> Function(Map<String, String> items)? onPersistIdentity,
  }) async {
    final cleanUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (_isInitialized && _currentServerUrl == cleanUrl && _isReady) {
      debugPrint('[Sendspin] Bereits verbunden mit $cleanUrl');
      return;
    }

    _currentServerUrl = cleanUrl;
    _clientName = clientName;
    _authToken = authToken.trim();
    _identityStore = Map<String, String>.from(identityStore ?? _identityStore);
    _onPersistIdentity = onPersistIdentity ?? _onPersistIdentity;
    _isReady = false;

    // In Unit-Tests oder Web ohne native Headless WebView sofort bereit simulieren
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      _isInitialized = true;
      _isReady = true;
      _clientId = 'mock_sendspin_client_test';
      serverPlayerId = _clientId;
      _readyController.add(_clientId!);
      debugPrint('[Sendspin] Test-Umgebung: Sendspin Mock aktiv.');
      return;
    }

    try {
      await dispose();
      _stopped = false;

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

    function notifyFlutter(handler, payload) {
      try {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler(handler, payload);
        }
      } catch (e) {}
    }

    // Persistenter Speicher fuer die SDK-Identitaet (wird von Flutter gesichert),
    // damit das iPhone nach jedem Start derselbe Player auf dem Server bleibt.
    function makeStorage(storeJson) {
      const store = {};
      try { Object.assign(store, JSON.parse(storeJson || '{}')); } catch (e) {}
      const has = function(k) { return Object.prototype.hasOwnProperty.call(store, k); };
      return {
        getItem: function(k) { return has(k) ? store[k] : null; },
        setItem: function(k, v) { store[k] = String(v); notifyFlutter('onSendspinStore', JSON.stringify(store)); },
        removeItem: function(k) { delete store[k]; notifyFlutter('onSendspinStore', JSON.stringify(store)); }
      };
    }

    // Music Assistant verlangt als ERSTE Nachricht auf /sendspin {"type":"auth","token":...}
    // und antwortet mit {"type":"auth_ok"}. Ohne diesen Schritt schliesst der Server
    // sofort mit Code 4001 und das iPhone erscheint nie als Player.
    function openAuthedSocket(baseUrl, token) {
      return new Promise(function(resolve, reject) {
        const u = new URL(baseUrl);
        const proto = u.protocol === 'https:' ? 'wss:' : 'ws:';
        let path = u.pathname;
        while (path.length > 0 && path.charAt(path.length - 1) === '/') { path = path.slice(0, -1); }
        const ws = new WebSocket(proto + '//' + u.host + path + '/sendspin');
        ws.binaryType = 'arraybuffer';
        const timer = setTimeout(function() {
          try { ws.close(); } catch (e) {}
          reject(new Error('Sendspin-Auth: Zeitueberschreitung'));
        }, 8000);
        ws.onopen = function() {
          if (token) {
            ws.send(JSON.stringify({ type: 'auth', token: token }));
          } else {
            clearTimeout(timer);
            ws.onclose = null; ws.onerror = null;
            resolve(ws);
          }
        };
        ws.onmessage = function(e) {
          if (typeof e.data !== 'string') return;
          try {
            const m = JSON.parse(e.data);
            if (m.type === 'auth_ok') {
              clearTimeout(timer);
              ws.onmessage = null; ws.onclose = null; ws.onerror = null;
              resolve(ws);
            }
          } catch (err) {}
        };
        ws.onerror = function() { clearTimeout(timer); reject(new Error('Sendspin-WebSocket-Fehler')); };
        ws.onclose = function(e) {
          clearTimeout(timer);
          reject(new Error('Sendspin-Verbindung geschlossen (' + e.code + ' ' + (e.reason || '') + ')'));
        };
      });
    }

    window.initSendspin = async function(baseUrl, clientName, token, storeJson) {
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

        const audioEl = document.getElementById('dummy-media');
        const ws = await openAuthedSocket(baseUrl, token);
        ws.addEventListener('close', function(e) {
          notifyFlutter('onSendspinClosed', JSON.stringify({ code: e.code, reason: e.reason || '' }));
        });

        player = new PlayerClass({
          baseUrl: baseUrl,
          webSocket: ws,
          storage: makeStorage(storeJson),
          clientName: clientName || "Dieses iPhone",
          productName: "Music Assistant iOS",
          correctionMode: "quality-local",
          audioElement: audioEl,
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
                  // Die vom Server vergebene Player-ID ist NICHT die SDK-Client-ID.
                  // Sie wird vom MusicProvider anhand des eindeutigen Namens ermittelt.
                  serverPlayerId = null;
                  if (_clientId != null) {
                    _readyController.add(_clientId!);
                  }
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
            handlerName: 'onSendspinStore',
            callback: (args) {
              try {
                if (args.isEmpty) return;
                final data = jsonDecode(args.first.toString());
                if (data is Map) {
                  _identityStore =
                      data.map((k, v) => MapEntry(k.toString(), v.toString()));
                  final persist = _onPersistIdentity;
                  if (persist != null) {
                    unawaited(persist(Map<String, String>.from(_identityStore)));
                  }
                }
              } catch (e) {
                debugPrint('[Sendspin] onSendspinStore parse error: $e');
              }
            },
          );

          controller.addJavaScriptHandler(
            handlerName: 'onSendspinClosed',
            callback: (args) {
              debugPrint('[Sendspin] Verbindung getrennt: ${args.join(', ')}');
              _isReady = false;
              serverPlayerId = null;
              _scheduleReconnect();
            },
          );

          controller.addJavaScriptHandler(
            handlerName: 'onSendspinError',
            callback: (args) {
              debugPrint('[Sendspin JS Error] ${args.join(', ')}');
              if (!_isReady) _scheduleReconnect();
            },
          );
        },
        onLoadStop: (controller, url) async {
          debugPrint('[Sendspin] WebView geladen. Starte Sendspin Verbindung...');
          await _startJsSession();
        },
      );

      await _headlessWebView!.run();
      _isInitialized = true;
      debugPrint('[Sendspin] HeadlessInAppWebView erfolgreich gestartet.');
    } catch (e) {
      debugPrint('[Sendspin] Fehler beim Starten des Sendspin Players: $e');
    }
  }

  /// Startet (oder wiederholt) die authentifizierte Sendspin-Sitzung im WebView
  Future<void> _startJsSession() async {
    final controller = _webViewController;
    final url = _currentServerUrl;
    if (controller == null || url == null || _stopped) return;
    await controller.evaluateJavascript(
      source: 'window.initSendspin(${jsonEncode(url)}, ${jsonEncode(_clientName)}, '
          '${jsonEncode(_authToken)}, ${jsonEncode(jsonEncode(_identityStore))});',
    );
  }

  void _scheduleReconnect() {
    if (_stopped) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_stopped || _isReady) return;
      debugPrint('[Sendspin] Verbinde erneut...');
      unawaited(_startJsSession());
    });
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
    _stopped = true;
    _reconnectTimer?.cancel();
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
