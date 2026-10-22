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
      NativeTtsManager.shared.setup(with: controller.binaryMessenger)
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeTtsManager") {
      NativeTtsManager.shared.setup(with: registrar.messenger())
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

// MARK: - Native iOS Neural TTS Manager (Siri / AVSpeechSynthesizer)

class NativeTtsManager: NSObject, AVSpeechSynthesizerDelegate {
  static let shared = NativeTtsManager()

  private var channel: FlutterMethodChannel?
  private let synthesizer = AVSpeechSynthesizer()
  private var isConfigured = false

  private override init() {
    super.init()
    synthesizer.delegate = self
  }

  func setup(with messenger: FlutterBinaryMessenger) {
    if isConfigured { return }
    isConfigured = true

    channel = FlutterMethodChannel(name: "de.timm.musicAssistantApp/native_tts", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getVoices":
      let voices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("de") }
        .map { v -> [String: Any] in
          var qualityStr = "default"
          if #available(iOS 16.0, *) {
            if v.quality == .premium { qualityStr = "premium" }
            else if v.quality == .enhanced { qualityStr = "enhanced" }
          }
          let genderStr: String
          switch v.gender {
          case .male: genderStr = "male"
          case .female: genderStr = "female"
          default: genderStr = "unspecified"
          }
          return [
            "identifier": v.identifier,
            "name": v.name,
            "language": v.language,
            "quality": qualityStr,
            "gender": genderStr
          ]
        }
      result(voices)

    case "speak":
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "text required", details: nil))
        return
      }

      let voiceId = args["voiceIdentifier"] as? String
      let rateMultiplier = (args["rate"] as? Double) ?? 1.0
      let pitchMultiplier = (args["pitch"] as? Double) ?? 1.0
      let volume = (args["volume"] as? Double) ?? 1.0

      if synthesizer.isSpeaking {
        synthesizer.stopSpeaking(at: .immediate)
      }

      let utterance = AVSpeechUtterance(string: text)
      if let id = voiceId, !id.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: id) {
        utterance.voice = voice
      } else {
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
      }

      utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(rateMultiplier)
      utterance.pitchMultiplier = Float(pitchMultiplier)
      utterance.volume = Float(volume)

      do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers, .mixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        print("[NativeTtsManager] AudioSession error: \(error)")
      }

      synthesizer.speak(utterance)
      result(true)

    case "stop":
      if synthesizer.isSpeaking {
        synthesizer.stopSpeaking(at: .immediate)
      }
      result(true)

    case "isSpeaking":
      result(synthesizer.isSpeaking)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - AVSpeechSynthesizerDelegate

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onSpeechFinished", nil)
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onSpeechCancelled", nil)
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
