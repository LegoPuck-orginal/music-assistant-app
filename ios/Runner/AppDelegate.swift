import Flutter
import UIKit
import AVFoundation
import WatchConnectivity
#if canImport(ActivityKit)
import ActivityKit
#endif

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
      #if canImport(ActivityKit)
      if #available(iOS 16.1, *) {
        LiveActivityManager.shared.setup(with: controller.binaryMessenger)
      }
      #endif
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WatchSessionManager") {
      WatchSessionManager.shared.setup(with: registrar.messenger())
    }
    #if canImport(ActivityKit)
    if #available(iOS 16.1, *) {
      if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityManager") {
        LiveActivityManager.shared.setup(with: registrar.messenger())
      }
    }
    #endif
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

// MARK: - Apple Dynamic Island & Live Activity (ActivityKit)
#if canImport(ActivityKit)
@available(iOS 16.1, *)
public struct MusicAssistantActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    public var trackTitle: String
    public var artist: String
    public var albumArtUrl: String
    public var isPlaying: Bool
    public var speakerName: String
    public var djVibe: String
    public var isDjSpeaking: Bool
    public var djSpeechText: String?

    public init(
      trackTitle: String,
      artist: String,
      albumArtUrl: String,
      isPlaying: Bool,
      speakerName: String,
      djVibe: String,
      isDjSpeaking: Bool,
      djSpeechText: String?
    ) {
      self.trackTitle = trackTitle
      self.artist = artist
      self.albumArtUrl = albumArtUrl
      self.isPlaying = isPlaying
      self.speakerName = speakerName
      self.djVibe = djVibe
      self.isDjSpeaking = isDjSpeaking
      self.djSpeechText = djSpeechText
    }
  }

  public var appName: String = "Music Assistant"

  public init() {}
}

@available(iOS 16.1, *)
class LiveActivityManager: NSObject {
  static let shared = LiveActivityManager()
  private var currentActivity: Activity<MusicAssistantActivityAttributes>?
  private var channel: FlutterMethodChannel?
  private var isConfigured = false

  private override init() {
    super.init()
  }

  func setup(with messenger: FlutterBinaryMessenger) {
    if isConfigured { return }
    isConfigured = true

    channel = FlutterMethodChannel(name: "de.timm.musicAssistantApp/live_activity", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startOrUpdate":
      if let args = call.arguments as? [String: Any] {
        startOrUpdateActivity(from: args)
        result(true)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a dictionary", details: nil))
      }
    case "endActivity":
      endActivity()
      result(true)
    case "isSupported":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func startOrUpdateActivity(from dict: [String: Any]) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let trackTitle = dict["trackTitle"] as? String ?? "Keine Wiedergabe"
    let artist = dict["artist"] as? String ?? "Music Assistant"
    let albumArtUrl = dict["albumArtUrl"] as? String ?? ""
    let isPlaying = dict["isPlaying"] as? Bool ?? false
    let speakerName = dict["speakerName"] as? String ?? "Sonos"
    let djVibe = dict["djVibe"] as? String ?? "Allzeit-Favoriten"
    let isDjSpeaking = dict["isDjSpeaking"] as? Bool ?? false
    let djSpeechText = dict["djSpeechText"] as? String

    let contentState = MusicAssistantActivityAttributes.ContentState(
      trackTitle: trackTitle,
      artist: artist,
      albumArtUrl: albumArtUrl,
      isPlaying: isPlaying,
      speakerName: speakerName,
      djVibe: djVibe,
      isDjSpeaking: isDjSpeaking,
      djSpeechText: djSpeechText
    )

    if let activity = currentActivity {
      Task {
        await activity.update(using: contentState)
      }
    } else {
      let attributes = MusicAssistantActivityAttributes()
      do {
        currentActivity = try Activity.request(
          attributes: attributes,
          contentState: contentState,
          pushType: nil
        )
      } catch {
        print("[LiveActivityManager] Activity.request error: \(error)")
      }
    }
  }

  func endActivity() {
    guard let activity = currentActivity else { return }
    Task {
      await activity.end(dismissalPolicy: .immediate)
      self.currentActivity = nil
    }
  }
}
#endif
