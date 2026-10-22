import SwiftUI
import WatchKit

struct WatchNowPlayingView: View {
    @ObservedObject var manager = WatchConnectivityManager.shared
    @State private var crownVolume: Double = 35.0

    var body: some View {
        VStack(spacing: 6) {
            // Active Speaker Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .frame(width: 6, height: 6)
                Text(manager.activeSpeakerName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)

            // Album Artwork & Track Info
            HStack(spacing: 10) {
                if !manager.imageUrl.isEmpty, let url = URL(string: manager.imageUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "music.note")
                                        .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                                )
                        }
                    }
                    .frame(width: 44, height: 44)
                    .cornerRadius(8)
                    .shadow(color: manager.isPlaying ? Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.3) : Color.clear, radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.trackTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(manager.artist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 2)

            // Playback Controls
            HStack(spacing: 16) {
                Button(action: {
                    manager.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())

                // Play / Pause (Spotify Green)
                Button(action: {
                    manager.togglePlayPause()
                }) {
                    Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 46, height: 46)
                .background(Color(red: 0.11, green: 0.73, blue: 0.33))
                .clipShape(Circle())
                .shadow(color: Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.5), radius: 6)

                Button(action: {
                    manager.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
            }

            Spacer(minLength: 2)

            // Volume Indicator & Digital Crown Support
            HStack(spacing: 6) {
                Image(systemName: manager.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.6))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                            .frame(width: geo.size.width * CGFloat(manager.volume / 100.0), height: 4)
                    }
                }
                .frame(height: 4)

                Text("\(Int(manager.volume))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(white: 0.6))
                    .frame(width: 28, alignment: .trailing)
            }
            .padding(.horizontal, 6)
        }
        .padding(.vertical, 4)
        .focusable()
        .digitalCrownRotation(
            $crownVolume,
            from: 0.0,
            through: 100.0,
            by: 2.0,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownVolume) { newVol in
            manager.setVolume(newVol)
        }
        .onAppear {
            crownVolume = manager.volume
        }
    }
}
