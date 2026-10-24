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

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getVoices":
      let voices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("de") }
        .map { v -> [String: Any] in
          var qualityStr = "default"
          if v.quality.rawValue == 3 {
            qualityStr = "premium"
          } else if v.quality.rawValue == 2 {
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
      if let id = voiceId, !id.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: id) {
        utterance.voice = voice
      } else {
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
      }

      var speechRate = AVSpeechUtteranceDefaultSpeechRate * Float(rateMultiplier)
      if speechRate < AVSpeechUtteranceMinimumSpeechRate {
        speechRate = AVSpeechUtteranceMinimumSpeechRate
      } else if speechRate > AVSpeechUtteranceMaximumSpeechRate {
        speechRate = AVSpeechUtteranceMaximumSpeechRate
      }
      utterance.rate = speechRate

      var speechPitch = Float(pitchMultiplier)
      if speechPitch < 0.5 { speechPitch = 0.5 }
      if speechPitch > 2.0 { speechPitch = 2.0 }
      utterance.pitchMultiplier = speechPitch

      var speechVol = Float(volume)
      if speechVol < 0.0 { speechVol = 0.0 }
      if speechVol > 1.0 { speechVol = 1.0 }
      utterance.volume = speechVol

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
  private lazy var fallbackArtwork: MPMediaItemArtwork = makeFallbackArtwork()
  private var silentPlayer: AVAudioPlayer?

  private override init() {
    super.init()
    imageCache.countLimit = 48
    setupSilentKeepAlivePlayer()
  }

  /// Erzeugt einen unhörbaren 1-Sekunden PCM-WAV-Loop im RAM, damit iOS die Now-Playing Dynamic Island
  /// (mit Album-Cover links und animierter Equalizer-Welle rechts) auch dann dauerhaft aktiv hält,
  /// wenn die Musik auf einem externen Music Assistant / Sonos Netzwerk-Lautsprecher läuft.
  private func setupSilentKeepAlivePlayer() {
    let sampleRate: UInt32 = 22050
    let numSamples: UInt32 = sampleRate
    let dataSize: UInt32 = numSamples * 2
    let fileSize: UInt32 = 36 + dataSize

    var wav = Data()
    wav.append("RIFF".data(using: .ascii)!)
    var leFileSize = fileSize.littleEndian
    wav.append(Data(bytes: &leFileSize, count: 4))
    wav.append("WAVEfmt ".data(using: .ascii)!)
    var fmtChunkSize: UInt32 = 16.littleEndian
    wav.append(Data(bytes: &fmtChunkSize, count: 4))
    var audioFormat: UInt16 = 1.littleEndian
    wav.append(Data(bytes: &audioFormat, count: 2))
    var numChannels: UInt16 = 1.littleEndian
    wav.append(Data(bytes: &numChannels, count: 2))
    var leSampleRate = sampleRate.littleEndian
    wav.append(Data(bytes: &leSampleRate, count: 4))
    var byteRate: UInt32 = (sampleRate * 2).littleEndian
    wav.append(Data(bytes: &byteRate, count: 4))
    var blockAlign: UInt16 = 2.littleEndian
    wav.append(Data(bytes: &blockAlign, count: 2))
    var bitsPerSample: UInt16 = 16.littleEndian
    wav.append(Data(bytes: &bitsPerSample, count: 2))
    wav.append("data".data(using: .ascii)!)
    var leDataSize = dataSize.littleEndian
    wav.append(Data(bytes: &leDataSize, count: 4))
    wav.append(Data(count: Int(dataSize)))

    do {
      let player = try AVAudioPlayer(data: wav, fileTypeHint: AVFileType.wav.rawValue)
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
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = true
    format.scale = 1.0
    let rendered = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
      let cg = ctx.cgContext
      let rect = CGRect(origin: .zero, size: size)

      // Obsidian Hintergrund
      UIColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0).setFill()
      cg.fill(rect)

      // Subtiler Neon-Ember Radial-Glow
      let colorSpace = CGColorSpaceCreateDeviceRGB()
      let colors = [
        UIColor(red: 1.0, green: 0.36, blue: 0.0, alpha: 0.42).cgColor,
        UIColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0).cgColor
      ] as CFArray
      if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        cg.drawRadialGradient(
          gradient,
          startCenter: center,
          startRadius: 10,
          endCenter: center,
          endRadius: 240,
          options: .drawsAfterEndLocation
        )
      }

      // Vinyl-Scheibe & Rillen
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      for r in stride(from: CGFloat(210), through: CGFloat(85), by: -18) {
        let path = UIBezierPath(
          arcCenter: center,
          radius: r,
          startAngle: 0,
          endAngle: .pi * 2,
          clockwise: true
        )
        path.lineWidth = 2.0
        UIColor(white: 1.0, alpha: 0.08).setStroke()
        path.stroke()
      }

      // Neon-Ember Center-Label (#FF5C00)
      let labelRect = CGRect(x: center.x - 64, y: center.y - 64, width: 128, height: 128)
      UIColor(red: 1.0, green: 0.36, blue: 0.0, alpha: 1.0).setFill()
      UIBezierPath(ovalIn: labelRect).fill()

      // Equalizer-Balken im Zentrum
      let barWidths: CGFloat = 12
      let barHeights: [CGFloat] = [28, 52, 38, 46]
      let totalWidth: CGFloat = CGFloat(barHeights.count) * barWidths + CGFloat(barHeights.count - 1) * 8
      var x = center.x - totalWidth / 2
      UIColor.white.setFill()
      for h in barHeights {
        let barRect = CGRect(x: x, y: center.y - h / 2, width: barWidths, height: h)
        UIBezierPath(roundedRect: barRect, cornerRadius: 6).fill()
        x += barWidths + 8
      }
    }
    return makeMediaArtwork(from: rendered)
  }

  /// Normalisiert ein beliebiges UIImage in eine opake sRGB-Bitmap und erzeugt ein MPMediaItemArtwork,
  /// das jede von SpringBoard (Dynamic Island / Lock Screen / Apple Watch) angeforderte Zielgröße exakt bedient.
  private func normalizeImage(_ image: UIImage, targetSize: CGSize = CGSize(width: 512, height: 512)) -> UIImage {
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = true
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: targetSize, format: format).image { ctx in
      UIColor.black.setFill()
      ctx.fill(CGRect(origin: .zero, size: targetSize))
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  private func makeMediaArtwork(from rawImage: UIImage) -> MPMediaItemArtwork {
    let baseSize = CGSize(width: 512, height: 512)
    let normalized = normalizeImage(rawImage, targetSize: baseSize)
    return MPMediaItemArtwork(boundsSize: baseSize) { requestedSize in
      let w = max(24, min(1024, requestedSize.width.isFinite && requestedSize.width > 0 ? requestedSize.width : 512))
      let h = max(24, min(1024, requestedSize.height.isFinite && requestedSize.height > 0 ? requestedSize.height : 512))
      let outSize = CGSize(width: w, height: h)
      if abs(w - baseSize.width) < 1 && abs(h - baseSize.height) < 1 {
        return normalized
      }
      let fmt = UIGraphicsImageRendererFormat.default()
      fmt.opaque = true
      fmt.scale = 1.0
      return UIGraphicsImageRenderer(size: outSize, format: fmt).image { _ in
        normalized.draw(in: CGRect(origin: .zero, size: outSize))
      }
    }
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
    let rate: Double = isPlaying ? 1.0 : 0.0
    let artworkUrl = (info["artworkUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let artworkBytes = (info["artworkBytes"] as? FlutterStandardTypedData)?.data

    // Aktiviere AudioSession + unhörbaren Keep-Alive-Player während der Wiedergabe,
    // damit iOS die Now-Playing Dynamic Island (inkl. Album-Cover & animierter Welle) dauerhaft anzeigt.
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
    if #available(iOS 10.0, *) {
      nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    }

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
      if #available(iOS 13.0, *) {
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
      }
      return
    }

    // 2. Prüfen, ob das Cover bereits im NSCache liegt
    if let urlStr = artworkUrl, !urlStr.isEmpty, let cachedImg = imageCache.object(forKey: urlStr as NSString) {
      let art = makeMediaArtwork(from: cachedImg)
      cachedArtwork = art
      currentArtworkUrl = urlStr
      nowPlayingInfo[MPMediaItemPropertyArtwork] = art
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
      if #available(iOS 13.0, *) {
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
      }
      return
    }

    // 3. Niemals ohne Asset rendern: vorhandenes Cover oder unser Obsidian-Ember Studio-Cover sofort setzen!
    if let art = cachedArtwork, currentArtworkUrl == artworkUrl {
      nowPlayingInfo[MPMediaItemPropertyArtwork] = art
    } else {
      nowPlayingInfo[MPMediaItemPropertyArtwork] = cachedArtwork ?? fallbackArtwork
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    if #available(iOS 13.0, *) {
      MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }

    // 4. Falls eine neue Cover-URL vorliegt, asynchron nachladen und Dynamic Island aktualisieren
    guard let urlStr = artworkUrl, !urlStr.isEmpty else { return }
    let resolvedUrl = URL(string: urlStr) ?? urlStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap { URL(string: $0) }
    guard let url = resolvedUrl else { return }

    if urlStr != currentArtworkUrl || cachedArtwork == nil {
      artworkRequestToken &+= 1
      let token = artworkRequestToken
      var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8.0)
      request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

      URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
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
    if #available(iOS 13.0, *) {
      MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
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
    public var albumArtBase64: String?
    public var isPlaying: Bool
    public var speakerName: String
    public var djVibe: String
    public var isDjSpeaking: Bool
    public var djSpeechText: String?

    public init(
      trackTitle: String,
      artist: String,
      albumArtUrl: String,
      albumArtBase64: String? = nil,
      isPlaying: Bool,
      speakerName: String,
      djVibe: String,
      isDjSpeaking: Bool,
      djSpeechText: String?
    ) {
      self.trackTitle = trackTitle
      self.artist = artist
      self.albumArtUrl = albumArtUrl
      self.albumArtBase64 = albumArtBase64
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
  private var cachedThumbUrl: String = ""
  private var cachedThumbBase64: String?

  private override init() {
    super.init()
  }

  /// Prüft, ob tatsächlich ein WidgetExtension (.appex) im Bundle eingebettet ist.
  /// Ohne eingebettetes WidgetExtension darf Activity.request nicht aufgerufen werden,
  /// da iOS sonst eine leere Dynamic-Island-Kapsel ohne Assets anstelle der MPNowPlaying-Insel zeigt.
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

    // Beende eventuelle verwaiste Aktivitäten beim Start, damit die MPNowPlaying Dynamic Island frei ist
    if !hasEmbeddedWidgetExtension() {
      Task {
        for activity in Activity<MusicAssistantActivityAttributes>.activities {
          await activity.end(dismissalPolicy: .immediate)
        }
      }
    }

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
    // Wenn kein WidgetExtension (.appex) eingebettet ist, übernimmt AppleNowPlayingManager
    // (MPNowPlayingInfoCenter) die echte iOS Dynamic Island inklusive Album-Cover & Audio-Wellen!
    guard hasEmbeddedWidgetExtension(), ActivityAuthorizationInfo().areActivitiesEnabled else { return }

    let trackTitle = dict["trackTitle"] as? String ?? "Keine Wiedergabe"
    let artist = dict["artist"] as? String ?? "Music Assistant"
    let albumArtUrl = dict["albumArtUrl"] as? String ?? ""
    let isPlaying = dict["isPlaying"] as? Bool ?? false
    let speakerName = dict["speakerName"] as? String ?? "Sonos"
    let djVibe = dict["djVibe"] as? String ?? "Allzeit-Favoriten"
    let isDjSpeaking = dict["isDjSpeaking"] as? Bool ?? false
    let djSpeechText = dict["djSpeechText"] as? String

    let thumbBase64 = (albumArtUrl == cachedThumbUrl) ? cachedThumbBase64 : nil

    let contentState = MusicAssistantActivityAttributes.ContentState(
      trackTitle: trackTitle,
      artist: artist,
      albumArtUrl: albumArtUrl,
      albumArtBase64: thumbBase64,
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

    if !albumArtUrl.isEmpty, albumArtUrl != cachedThumbUrl, let url = URL(string: albumArtUrl) {
      cachedThumbUrl = albumArtUrl
      URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
        guard let self = self, let data = data, let img = UIImage(data: data) else { return }
        let thumbSize = CGSize(width: 56, height: 56)
        let renderer = UIGraphicsImageRenderer(size: thumbSize)
        let smallImg = renderer.image { _ in
          img.draw(in: CGRect(origin: .zero, size: thumbSize))
        }
        guard let jpeg = smallImg.jpegData(compressionQuality: 0.55) else { return }
        let b64 = jpeg.base64EncodedString()
        self.cachedThumbBase64 = b64
        let updatedState = MusicAssistantActivityAttributes.ContentState(
          trackTitle: trackTitle,
          artist: artist,
          albumArtUrl: albumArtUrl,
          albumArtBase64: b64,
          isPlaying: isPlaying,
          speakerName: speakerName,
          djVibe: djVibe,
          isDjSpeaking: isDjSpeaking,
          djSpeechText: djSpeechText
        )
        if let activity = self.currentActivity {
          Task {
            await activity.update(using: updatedState)
          }
        }
      }.resume()
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
