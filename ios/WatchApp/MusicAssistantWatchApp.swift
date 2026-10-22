import SwiftUI

@main
struct MusicAssistantWatchApp: App {
    @StateObject private var manager = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(manager)
        }
    }
}
