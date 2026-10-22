import SwiftUI
import WatchKit

struct WatchSpeakersView: View {
    @ObservedObject var manager = WatchConnectivityManager.shared

    var body: some View {
        List {
            Section(header: Text("Räume & Lautsprecher").font(.system(size: 11, weight: .bold))) {
                if manager.speakers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(manager.activeSpeakerName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                        Text("Aktiv über iPhone verbunden")
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.6))
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(manager.speakers) { speaker in
                        let isSelected = (speaker.id == manager.activeSpeakerId) || (speaker.name == manager.activeSpeakerName)

                        Button(action: {
                            manager.selectSpeaker(id: speaker.id)
                        }) {
                            HStack {
                                Image(systemName: iconForSpeaker(speaker.name))
                                    .foregroundColor(isSelected ? Color(red: 0.11, green: 0.73, blue: 0.33) : .white)
                                    .font(.system(size: 14))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(speaker.name)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? Color(red: 0.11, green: 0.73, blue: 0.33) : .white)
                                        .lineLimit(1)

                                    Text("\(speaker.volume)% Lautstärke")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(white: 0.5))
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                                        .font(.system(size: 14))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(
                            isSelected ? Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.15) : Color.white.opacity(0.06)
                        )
                    }
                }
            }

            Section(header: Text("Schnell-Lautstärke").font(.system(size: 11, weight: .bold))) {
                HStack {
                    Button(action: {
                        manager.setVolume(manager.volume - 5)
                    }) {
                        Image(systemName: "speaker.minus.fill")
                    }

                    Spacer()

                    Text("\(Int(manager.volume))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))

                    Spacer()

                    Button(action: {
                        manager.setVolume(manager.volume + 5)
                    }) {
                        Image(systemName: "speaker.plus.fill")
                    }
                }
                .buttonStyle(BorderedButtonStyle())
            }
        }
        .listStyle(CarouselListStyle())
    }

    private func iconForSpeaker(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("sonos") { return "hifispeaker.fill" }
        if lower.contains("airplay") || lower.contains("apple") { return "airplayaudio" }
        if lower.contains("phone") || lower.contains("iphone") { return "iphone" }
        return "speaker.wave.2.fill"
    }
}
