import Flutter
import UIKit
import AVFoundation
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Enable background audio session playback
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("[AppDelegate] Failed to set AVAudioSession category: \(error)")
    }
    application.beginReceivingRemoteControlEvents()

    if let controller = window?.rootViewController as? FlutterViewController {
      WatchSessionManager.shared.setup(with: controller.binaryMessenger)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WatchSessionManager") {
      WatchSessionManager.shared.setup(with: registrar.messenger())
    }
  }
}

class WatchSessionManager: NSObject, WCSessionDelegate {
  static let shared = WatchSessionManager()

  private var channel: FlutterMethodChannel?
  private var session: WCSession?
  private var isConfigured = false

  private override init() {
    super.init()
  }

  func setup(with messenger: FlutterBinaryMessenger) {
    if isConfigured { return }
    isConfigured = true

    channel = FlutterMethodChannel(name: "de.timm.musicAssistantApp/watch", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }

    if WCSession.isSupported() {
      session = WCSession.default
      session?.delegate = self
      session?.activate()
    }
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "syncState":
      if let data = call.arguments as? [String: Any] {
        sendStateToWatch(data)
        result(true)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a dictionary", details: nil))
      }
    case "isSupported":
      result(WCSession.isSupported())
    case "isPaired":
      result(session?.isPaired ?? false)
    case "isWatchAppInstalled":
      result(session?.isWatchAppInstalled ?? false)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func sendStateToWatch(_ state: [String: Any]) {
    guard let session = session, session.activationState == .activated else { return }

    do {
      try session.updateApplicationContext(state)
    } catch {
      print("[WatchSessionManager] Error updating application context: \(error)")
    }

    if session.isReachable {
      session.sendMessage(state, replyHandler: nil) { error in
        print("[WatchSessionManager] Error sending message to watch: \(error)")
      }
    }
  }

  // MARK: - WCSessionDelegate

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    print("[WatchSessionManager] WCSession activated: \(activationState.rawValue)")
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
  }

  func sessionDidDeactivate(_ session: WCSession) {
    WCSession.default.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onWatchAction", arguments: message)
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onWatchAction", arguments: message)
      replyHandler(["status": "ok"])
    }
  }
}
