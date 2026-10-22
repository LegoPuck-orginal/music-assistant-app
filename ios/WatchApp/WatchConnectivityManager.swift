import Foundation
import WatchConnectivity
import WatchKit

struct WatchSpeaker: Identifiable, Hashable {
    let id: String
    let name: String
    let volume: Int
    let isAvailable: Bool
}

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var trackTitle: String = "Keine Wiedergabe"
    @Published var artist: String = "Music Assistant"
    @Published var album: String = ""
    @Published var imageUrl: String = ""
    @Published var isPlaying: Bool = false
    @Published var volume: Double = 35.0
    @Published var activeSpeakerName: String = "Sonos"
    @Published var activeSpeakerId: String = ""
    @Published var speakers: [WatchSpeaker] = []
    @Published var currentDjVibe: String = "Allzeit-Favoriten"
    @Published var isDjActive: Bool = false
    @Published var isConnectedToPhone: Bool = false

    private var session: WCSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Actions to iPhone

    func togglePlayPause() {
        WKInterfaceDevice.current().play(.click)
        isPlaying.toggle()
        sendAction(["action": "togglePlayPause"])
    }

    func nextTrack() {
        WKInterfaceDevice.current().play(.directionUp)
        sendAction(["action": "next"])
    }

    func previousTrack() {
        WKInterfaceDevice.current().play(.directionDown)
        sendAction(["action": "previous"])
    }

    func setVolume(_ newVolume: Double) {
        volume = max(0, min(100, newVolume))
        sendAction(["action": "setVolume", "volume": volume])
    }

    func selectSpeaker(id: String) {
        WKInterfaceDevice.current().play(.success)
        activeSpeakerId = id
        if let s = speakers.first(where: { $0.id == id }) {
            activeSpeakerName = s.name
            volume = Double(s.volume)
        }
        sendAction(["action": "selectSpeaker", "speakerId": id])
    }

    func switchDjVibe() {
        WKInterfaceDevice.current().play(.click)
        sendAction(["action": "switchDjVibe"])
    }

    func triggerDjSpeech() {
        WKInterfaceDevice.current().play(.notification)
        sendAction(["action": "triggerDjSpeech"])
    }

    private func sendAction(_ dict: [String: Any]) {
        guard let session = session, session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { error in
                print("[WatchApp] Failed to send action: \(error)")
            }
        } else {
            do {
                try session.updateApplicationContext(dict)
            } catch {
                print("[WatchApp] Failed to update context: \(error)")
            }
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnectedToPhone = (activationState == .activated)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnectedToPhone = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.updateState(from: applicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.updateState(from: message)
        }
    }

    private func updateState(from dict: [String: Any]) {
        if let title = dict["trackTitle"] as? String { self.trackTitle = title }
        if let art = dict["artist"] as? String { self.artist = art }
        if let alb = dict["album"] as? String { self.album = alb }
        if let img = dict["imageUrl"] as? String { self.imageUrl = img }
        if let playing = dict["isPlaying"] as? Bool { self.isPlaying = playing }
        if let vol = dict["volume"] as? Double { self.volume = vol }
        if let volInt = dict["volume"] as? Int { self.volume = Double(volInt) }
        if let spkName = dict["activeSpeakerName"] as? String { self.activeSpeakerName = spkName }
        if let spkId = dict["activeSpeakerId"] as? String { self.activeSpeakerId = spkId }
        if let vibe = dict["currentDjVibe"] as? String { self.currentDjVibe = vibe }
        if let djActive = dict["isDjActive"] as? Bool { self.isDjActive = djActive }

        if let spkList = dict["speakers"] as? [[String: Any]] {
            self.speakers = spkList.compactMap { item in
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String else { return nil }
                let vol = item["volume"] as? Int ?? 30
                let avail = item["isAvailable"] as? Bool ?? true
                return WatchSpeaker(id: id, name: name, volume: vol, isAvailable: avail)
            }
        }
    }
}
