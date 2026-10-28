import Flutter
import UIKit
import AVFoundation
import MediaPlayer
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
    // Enable background audio session playback with Bluetooth, AirPlay, and speaker routing
    AudioSessionManager.shared.configureAudioSession()
    application.beginReceivingRemoteControlEvents()

    if let controller = window?.rootViewController as? FlutterViewController {
      AudioSessionManager.shared.setup(with: controller.binaryMessenger)
      WatchSessionManager.shared.setup(with: controller.binaryMessenger)
      NativeTtsManager.shared.setup(with: controller.binaryMessenger)
      AppleNowPlayingManager.shared.setup(with: controller.binaryMessenger)
      NativeUtilsManager.shared.setup(with: controller.binaryMessenger)
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioSessionManager") {
      AudioSessionManager.shared.setup(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WatchSessionManager") {
      WatchSessionManager.shared.setup(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeTtsManager") {
      NativeTtsManager.shared.setup(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppleNowPlayingManager") {
      AppleNowPlayingManager.shared.setup(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeUtilsManager") {
      NativeUtilsManager.shared.setup(with: registrar.messenger())
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

  private func scoreGermanVoice(_ v: AVSpeechSynthesisVoice) -> Int {
    var score = v.quality.rawValue * 100
    if v.language == "de-DE" {
      score += 40
    }
    let lowerId = v.identifier.lowercased()
    let lowerName = v.name.lowercased()
    if lowerId.contains("siri") || lowerName.contains("siri") {
      score += 50
    }
    if lowerId.contains("premium") || lowerId.contains("enhanced") {
      score += 30
    }
    if lowerName.contains("martin") || lowerName.contains("helena") || lowerName.contains("anna") || lowerName.contains("viktor") {
      score += 15
    }
    return score
  }

  private func resolveBestGermanVoice(preferredId: String?) -> AVSpeechSynthesisVoice? {
    if let id = preferredId, !id.isEmpty, id != "de-DE-Siri-1",
       let exact = AVSpeechSynthesisVoice(identifier: id) {
      return exact
    }
    let germanVoices = AVSpeechSynthesisVoice.speechVoices()
      .filter { $0.language.hasPrefix("de") }
      .sorted { scoreGermanVoice($0) > scoreGermanVoice($1) }
    if let best = germanVoices.first {
      return best
    }
    return AVSpeechSynthesisVoice(language: "de-DE")
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getVoices":
      let sortedVoices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("de") }
        .sorted { scoreGermanVoice($0) > scoreGermanVoice($1) }

      let voices = sortedVoices.map { v -> [String: Any] in
        var qualityStr = "default"
        let lowerId = v.identifier.lowercased()
        if v.quality.rawValue >= 3 || lowerId.contains("premium") {
          qualityStr = "premium"
        } else if v.quality.rawValue == 2 || lowerId.contains("enhanced") || lowerId.contains("siri") {
          qualityStr = "enhanced"
        }

        var genderStr = "unspecified"
        if v.gender.rawValue == 1 {
          genderStr = "male"
        } else if v.gender.rawValue == 2 {
          genderStr = "female"
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
      let rateMultiplier = (args["rate"] as? NSNumber)?.doubleValue ?? (args["rate"] as? Double) ?? 1.0
      let pitchMultiplier = (args["pitch"] as? NSNumber)?.doubleValue ?? (args["pitch"] as? Double) ?? 1.0
      let volume = (args["volume"] as? NSNumber)?.doubleValue ?? (args["volume"] as? Double) ?? 1.0

      if synthesizer.isSpeaking {
        _ = synthesizer.stopSpeaking(at: .immediate)
      }

      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = resolveBestGermanVoice(preferredId: voiceId)

      var speechRate = AVSpeechUtteranceDefaultSpeechRate * Float(rateMultiplier)
      if speechRate < AVSpeechUtteranceMinimumSpeechRate {
        speechRate = AVSpeechUtteranceMinimumSpeechRate
      } else if speechRate > AVSpeechUtteranceMaximumSpeechRate {
        speechRate = AVSpeechUtteranceMaximumSpeechRate
      }
      utterance.rate = speechRate

      var speechPitch = Float(pitchMultiplier)
      if abs(speechPitch - 1.0) <= 0.06 {
        speechPitch = 1.0
      }
      if speechPitch < 0.5 { speechPitch = 0.5 }
      if speechPitch > 2.0 { speechPitch = 2.0 }
      utterance.pitchMultiplier = speechPitch
      utterance.preUtteranceDelay = 0.04
      utterance.postUtteranceDelay = 0.08

      var speechVol = Float(volume)
      if speechVol < 0.0 { speechVol = 0.0 }
      if speechVol > 1.0 { speechVol = 1.0 }
      utterance.volume = speechVol

      do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        print("[NativeTtsManager] AudioSession error: \(error)")
      }

      synthesizer.speak(utterance)
      result(true)

    case "stop":
      if synthesizer.isSpeaking {
        _ = synthesizer.stopSpeaking(at: .immediate)
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
    restoreAudioSession()
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onSpeechFinished", arguments: nil)
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    restoreAudioSession()
    DispatchQueue.main.async { [weak self] in
      self?.channel?.invokeMethod("onSpeechCancelled", arguments: nil)
    }
  }

  private func restoreAudioSession() {
    AudioSessionManager.shared.configureAudioSession()
  }
}

// MARK: - Native iOS Audio Session Manager (Interruption, Route Changes, Bluetooth & AirPods)

class AudioSessionManager: NSObject {
  static let shared = AudioSessionManager()
  private var channel: FlutterMethodChannel?
  private var isConfigured = false

  private override init() {
    super.init()
  }

  func setup(with messenger: FlutterBinaryMessenger) {
    if isConfigured { return }
    isConfigured = true

    channel = FlutterMethodChannel(name: "de.timm.musicAssistantApp/audio_session", binaryMessenger: messenger)
    channel?.setMethodCallHandler { (call, result) in
      if call.method == "activateSession" {
        self.configureAudioSession()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    configureAudioSession()
    setupNotifications()
  }

  func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .default,
        options: []
      )
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      print("[AudioSessionManager] configureAudioSession error: \(error)")
    }
  }

  private func setupNotifications() {
    NotificationCenter.default.removeObserver(self)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption),
      name: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance()
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance()
    )
  }

  @objc private func handleInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    switch type {
    case .began:
      DispatchQueue.main.async { [weak self] in
        self?.channel?.invokeMethod("onInterruptionBegan", arguments: nil)
      }
    case .ended:
      var shouldResume = false
      if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        shouldResume = options.contains(.shouldResume)
      }
      DispatchQueue.main.async { [weak self] in
        self?.configureAudioSession()
        self?.channel?.invokeMethod("onInterruptionEnded", arguments: ["shouldResume": shouldResume])
      }
    @unknown default:
      break
    }
  }

  @objc private func handleRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }

    switch reason {
    case .oldDeviceUnavailable:
      DispatchQueue.main.async { [weak self] in
        self?.channel?.invokeMethod("onRouteChangePause", arguments: nil)
      }
    case .newDeviceAvailable:
      configureAudioSession()
    default:
      break
    }
  }
}

// MARK: - Native Apple MediaPlayer (Dynamic Island, Apple Watch, Lock Screen, Control Center)

class AppleNowPlayingManager: NSObject {
  static let shared = AppleNowPlayingManager()

  private var channel: FlutterMethodChannel?
  private var isConfigured = false
  private var currentArtworkUrl: String?
  private var cachedArtwork: MPMediaItemArtwork?
  private var artworkRequestToken: UInt64 = 0
  private let imageCache = NSCache<NSString, UIImage>()
  private var fallbackArtwork: MPMediaItemArtwork?
  private var silentPlayer: AVAudioPlayer?

  private override init() {
    super.init()
    imageCache.countLimit = 48
    fallbackArtwork = makeFallbackArtwork()
    setupSilentKeepAlivePlayer()
  }

  /// Erzeugt einen unhörbaren 1-Sekunden PCM-WAV-Loop im RAM, damit iOS die Now-Playing Dynamic Island
  /// (mit Album-Cover links und animierter Equalizer-Welle rechts) auch dann dauerhaft aktiv hält,
  /// wenn die Musik auf einem externen Music Assistant / Sonos Netzwerk-Lautsprecher läuft.
  private func setupSilentKeepAlivePlayer() {
    var wavBytes: [UInt8] = [
      0x52, 0x49, 0x46, 0x46,
      0x24, 0xAC, 0x00, 0x00,
      0x57, 0x41, 0x56, 0x45,
      0x66, 0x6D, 0x74, 0x20,
      0x10, 0x00, 0x00, 0x00,
      0x01, 0x00,
      0x01, 0x00,
      0x22, 0x56, 0x00, 0x00,
      0x44, 0xAC, 0x00, 0x00,
      0x02, 0x00,
      0x10, 0x00,
      0x64, 0x61, 0x74, 0x61,
      0x00, 0xAC, 0x00, 0x00
    ]
    wavBytes.append(contentsOf: [UInt8](repeating: 0, count: 44032))
    let wav = Data(wavBytes)

    do {
      let player = try AVAudioPlayer(data: wav)
      player.numberOfLoops = -1
      player.volume = 0.01
      player.prepareToPlay()
      silentPlayer = player
    } catch {
      print("[AppleNowPlayingManager] Failed to init silent keep-alive player: \(error)")
    }
  }

  /// Rendert ein hochwertiges Obsidian-Ember Studio-Vinyl-Cover als sofortiges Fallback-Asset,
  /// damit die iOS Dynamic Island niemals ohne Grafik-Asset erscheint.
  private func makeFallbackArtwork() -> MPMediaItemArtwork {
    let size = CGSize(width: 512, height: 512)
    let renderer = UIGraphicsImageRenderer(size: size)
    let rendered = renderer.image { _ in
      let rect = CGRect(origin: .zero, size: size)
      UIColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0).setFill()
      UIBezierPath(rect: rect).fill()

      let center = CGPoint(x: 256, y: 256)
      UIColor(red: 1.0, green: 0.36, blue: 0.0, alpha: 0.16).setFill()
      UIBezierPath(ovalIn: CGRect(x: 36, y: 36, width: 440, height: 440)).fill()

      UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1.0).setFill()
      UIBezierPath(ovalIn: CGRect(x: 60, y: 60, width: 392, height: 392)).fill()

      let radii: [CGFloat] = [180, 155, 130, 105]
      UIColor(white: 1.0, alpha: 0.09).setStroke()
      for r in radii {
        let ring = UIBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ring.lineWidth = 2.0
        ring.stroke()
      }

      let labelRect = CGRect(x: center.x - 64, y: center.y - 64, width: 128, height: 128)
      UIColor(red: 1.0, green: 0.36, blue: 0.0, alpha: 1.0).setFill()
      UIBezierPath(ovalIn: labelRect).fill()

      let barHeights: [CGFloat] = [28, 52, 38, 46]
      var x: CGFloat = center.x - 36
      UIColor.white.setFill()
      for h in barHeights {
        let barRect = CGRect(x: x, y: center.y - (h / 2.0), width: 12, height: h)
        UIBezierPath(roundedRect: barRect, cornerRadius: 6).fill()
        x += 20
      }
    }
    return makeMediaArtwork(from: rendered)
  }

  private func makeMediaArtwork(from rawImage: UIImage) -> MPMediaItemArtwork {
    let baseSize = CGSize(width: 512, height: 512)
    let renderer = UIGraphicsImageRenderer(size: baseSize)
    let normalized = renderer.image { _ in
      UIColor.black.setFill()
      UIBezierPath(rect: CGRect(origin: .zero, size: baseSize)).fill()
      rawImage.draw(in: CGRect(origin: .zero, size: baseSize))
    }
    return MPMediaItemArtwork(boundsSize: baseSize) { _ in normalized }
  }

  func setup(with messenger: FlutterBinaryMessenger) {
    if isConfigured { return }
    isConfigured = true

    channel = FlutterMethodChannel(name: "de.timm.musicAssistantApp/apple_now_playing", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }

    setupRemoteCommandCenter()
  }

  private func setupRemoteCommandCenter() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.removeTarget(nil)
    commandCenter.playCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("onRemoteCommand", arguments: ["action": "play"])
      }
      return .success
    }

    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.removeTarget(nil)
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("onRemoteCommand", arguments: ["action": "pause"])
      }
      return .success
    }

    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.removeTarget(nil)
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("onRemoteCommand", arguments: ["action": "togglePlayPause"])
      }
      return .success
    }

    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.removeTarget(nil)
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("onRemoteCommand", arguments: ["action": "next"])
      }
      return .success
    }

    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.removeTarget(nil)
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("onRemoteCommand", arguments: ["action": "previous"])
      }
      return .success
    }

    commandCenter.changePlaybackPositionCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
        return .commandFailed
      }
      let targetSeconds = posEvent.positionTime
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("onRemoteCommand", arguments: [
          "action": "seek",
          "positionSeconds": targetSeconds
        ])
      }
      return .success
    }

    commandCenter.skipForwardCommand.preferredIntervals = [15]
    commandCenter.skipForwardCommand.isEnabled = true
    commandCenter.skipForwardCommand.removeTarget(nil)
    commandCenter.skipForwardCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("onRemoteCommand", arguments: ["action": "skipForward", "interval": 15])
      }
      return .success
    }

    commandCenter.skipBackwardCommand.preferredIntervals = [15]
    commandCenter.skipBackwardCommand.isEnabled = true
    commandCenter.skipBackwardCommand.removeTarget(nil)
    commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
      DispatchQueue.main.async {
        self?.channel?.invokeMethod("onRemoteCommand", arguments: ["action": "skipBackward", "interval": 15])
      }
      return .success
    }
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateNowPlaying":
      if let args = call.arguments as? [String: Any] {
        updateNowPlayingInfo(args)
        result(true)
      } else {
        result(FlutterError(code: "INVALID_ARGS", message: "Arguments must be a dictionary", details: nil))
      }
    case "clearNowPlaying":
      clearNowPlayingInfo()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func updateNowPlayingInfo(_ info: [String: Any]) {
    var nowPlayingInfo = [String: Any]()

    let title = info["title"] as? String ?? ""
    let artist = info["artist"] as? String ?? ""
    let album = info["album"] as? String ?? ""
    let duration = (info["durationSeconds"] as? NSNumber)?.doubleValue ?? 0.0
    let position = (info["positionSeconds"] as? NSNumber)?.doubleValue ?? 0.0
    let isPlaying = info["isPlaying"] as? Bool ?? false
    let isLocal = info["isLocal"] as? Bool ?? false
    let rate: Double = isPlaying ? 1.0 : 0.0
    let artworkUrl = (info["artworkUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let artworkBytes = (info["artworkBytes"] as? FlutterStandardTypedData)?.data

    // Aktiviere AudioSession + unhörbaren Keep-Alive-Player während der Wiedergabe,
    // damit iOS die App im Hintergrund niemals pausiert und die Dynamic Island aktiv hält.
    if isPlaying {
      AudioSessionManager.shared.configureAudioSession()
      if silentPlayer?.isPlaying != true {
        silentPlayer?.play()
      }
    } else {
      silentPlayer?.pause()
    }

    nowPlayingInfo[MPMediaItemPropertyTitle] = title
    nowPlayingInfo[MPMediaItemPropertyArtist] = artist
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
    nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

    // 1. Falls Dart bereits die Bild-Bytes mitgeliefert hat, sofort dekodieren & cachen
    if let bytes = artworkBytes, !bytes.isEmpty, let decoded = UIImage(data: bytes) {
      let art = makeMediaArtwork(from: decoded)
      cachedArtwork = art
      if let urlStr = artworkUrl, !urlStr.isEmpty {
        currentArtworkUrl = urlStr
        imageCache.setObject(decoded, forKey: urlStr as NSString)
      }
      nowPlayingInfo[MPMediaItemPropertyArtwork] = art
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
      return
    }

    // 2. Prüfen, ob das Cover bereits im NSCache liegt
    if let urlStr = artworkUrl, !urlStr.isEmpty, let cachedImg = imageCache.object(forKey: urlStr as NSString) {
      let art = makeMediaArtwork(from: cachedImg)
      cachedArtwork = art
      currentArtworkUrl = urlStr
      nowPlayingInfo[MPMediaItemPropertyArtwork] = art
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
      return
    }

    // 3. Niemals ohne Asset rendern: vorhandenes Cover oder unser Obsidian-Ember Studio-Cover sofort setzen!
    if let art = cachedArtwork, currentArtworkUrl == artworkUrl {
      nowPlayingInfo[MPMediaItemPropertyArtwork] = art
    } else if let art = cachedArtwork ?? fallbackArtwork {
      nowPlayingInfo[MPMediaItemPropertyArtwork] = art
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

    // 4. Falls eine neue Cover-URL vorliegt, asynchron nachladen und Dynamic Island aktualisieren
    guard let urlStr = artworkUrl, !urlStr.isEmpty else { return }
    var targetUrl = URL(string: urlStr)
    if targetUrl == nil, let encoded = urlStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      targetUrl = URL(string: encoded)
    }
    guard let url = targetUrl else { return }

    if urlStr != currentArtworkUrl || cachedArtwork == nil {
      artworkRequestToken &+= 1
      let token = artworkRequestToken

      URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
        guard let self = self,
              let data = data,
              !data.isEmpty,
              let image = UIImage(data: data) else { return }
        let artwork = self.makeMediaArtwork(from: image)
        self.imageCache.setObject(image, forKey: urlStr as NSString)
        DispatchQueue.main.async {
          guard self.artworkRequestToken == token else { return }
          self.currentArtworkUrl = urlStr
          self.cachedArtwork = artwork
          var current = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? nowPlayingInfo
          current[MPMediaItemPropertyArtwork] = artwork
          MPNowPlayingInfoCenter.default().nowPlayingInfo = current
        }
      }.resume()
    }
  }

  func clearNowPlayingInfo() {
    silentPlayer?.pause()
    currentArtworkUrl = nil
    cachedArtwork = nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }
}

// MARK: - Native iOS Utilities (Share Sheet, File Handling)

class NativeUtilsManager: NSObject {
  static let shared = NativeUtilsManager()
  private var channel: FlutterMethodChannel?
  private var isConfigured = false

  private override init() {
    super.init()
  }

  func setup(with messenger: FlutterBinaryMessenger) {
    if isConfigured { return }
    isConfigured = true

    channel = FlutterMethodChannel(name: "de.timm.musicAssistantApp/native_utils", binaryMessenger: messenger)
    channel?.setMethodCallHandler { (call, result) in
      if call.method == "shareFile" {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "path required", details: nil))
          return
        }
        let url = URL(fileURLWithPath: filePath)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        let rootVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
          ?? UIApplication.shared.keyWindow?.rootViewController

        if let controller = rootVC {
          if let popover = activityVC.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
          }
          controller.present(activityVC, animated: true) {
            result(true)
          }
        } else {
          result(false)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
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

  /// Prüft, ob tatsächlich ein WidgetExtension (.appex) im Bundle eingebettet ist.
  /// Ohne eingebettetes WidgetExtension übernimmt AppleNowPlayingManager (MPNowPlayingInfoCenter)
  /// die iOS Dynamic Island inklusive Album-Cover & animierter Equalizer-Welle.
  private func hasEmbeddedWidgetExtension() -> Bool {
    guard let pluginsUrl = Bundle.main.builtInPlugInsURL,
          let contents = try? FileManager.default.contentsOfDirectory(at: pluginsUrl, includingPropertiesForKeys: nil) else {
      return false
    }
    return contents.contains { $0.pathExtension == "appex" }
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
      result(hasEmbeddedWidgetExtension() && ActivityAuthorizationInfo().areActivitiesEnabled)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func startOrUpdateActivity(from dict: [String: Any]) {
    guard hasEmbeddedWidgetExtension(), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

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
