import SwiftUI

struct WatchContentView: View {
    @ObservedObject var manager = WatchConnectivityManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WatchNowPlayingView()
                .tag(0)

            WatchSpeakersView()
                .tag(1)

            WatchDjView()
                .tag(2)
        }
        .tabViewStyle(PageTabViewStyle())
    }
}
