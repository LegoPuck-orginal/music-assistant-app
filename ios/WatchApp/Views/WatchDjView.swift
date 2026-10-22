import SwiftUI
import WatchKit

struct WatchDjView: View {
    @ObservedObject var manager = WatchConnectivityManager.shared
    @State private var isPulsing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Mini DJ Orb
                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.11, green: 0.73, blue: 0.33),
                                    Color(red: 0.12, green: 0.53, blue: 0.90),
                                    Color(red: 0.73, green: 0.11, blue: 0.65),
                                    Color(red: 0.11, green: 0.73, blue: 0.33)
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: 48, height: 48)
                        .scaleEffect(isPulsing ? 1.12 : 0.95)
                        .blur(radius: isPulsing ? 2 : 0)
                        .animation(
                            Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isPulsing
                        )

                    Circle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 38, height: 38)

                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                }
                .padding(.top, 4)
                .onAppear {
                    isPulsing = true
                }

                Text("SPOTIFY KI-DJ")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .tracking(1.2)

                // Current Vibe Badge
                VStack(spacing: 2) {
                    Text("Aktuelle Stimmung")
                        .font(.system(size: 9))
                        .foregroundColor(Color(white: 0.6))
                    Text(manager.currentDjVibe)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)

                // Vibe Switch Button
                Button(action: {
                    manager.switchDjVibe()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 11, weight: .bold))
                        Text("Vibe wechseln")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .tint(Color(red: 0.11, green: 0.73, blue: 0.33))
                .foregroundColor(.black)
                .padding(.horizontal, 4)

                // Trigger DJ Speech Button
                Button(action: {
                    manager.triggerDjSpeech()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.badge.mic")
                            .font(.system(size: 10))
                        Text("DJ Ansage auslösen")
                            .font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 4)
            }
            .padding(.bottom, 6)
        }
    }
}
