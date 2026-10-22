import WidgetKit
import SwiftUI
import ActivityKit

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
struct MusicAssistantDynamicIslandWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicAssistantActivityAttributes.self) { context in
            // Lock Screen Live Activity Banner
            LockScreenLiveActivityView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                            .frame(width: 6, height: 6)
                        Text(context.state.speakerName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 3) {
                        ForEach(0..<4) { idx in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                                .frame(width: 3, height: CGFloat(context.state.isPlaying ? (6 + (idx * 3)) : 4))
                        }
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.trackTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(context.state.artist)
                            .font(.system(size: 12))
                            .foregroundColor(Color.gray)
                            .lineLimit(1)

                        if context.state.isDjSpeaking, let speech = context.state.djSpeechText {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                                    .font(.system(size: 11))
                                Text(speech)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                                    .lineLimit(1)
                            }
                            .padding(.top, 2)
                        } else {
                            HStack(spacing: 4) {
                                Text("Vibe:")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.gray)
                                Text(context.state.djVibe)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                // Compact Leading (Pill Left)
                Image(systemName: "music.note")
                    .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .font(.system(size: 12, weight: .bold))
            } compactTrailing: {
                // Compact Trailing (Pill Right)
                HStack(spacing: 2) {
                    ForEach(0..<3) { idx in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                            .frame(width: 2.5, height: CGFloat(context.state.isPlaying ? (5 + (idx * 3)) : 3))
                    }
                }
            } minimal: {
                // Minimal (Shared Pill)
                Image(systemName: "music.note")
                    .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .font(.system(size: 11))
            }
        }
    }
}

// Lock Screen Live Activity Widget View
@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let state: MusicAssistantActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            // Album Art / Disc
            ZStack {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "music.note")
                    .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                        .frame(width: 6, height: 6)
                    Text(state.speakerName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.11, green: 0.73, blue: 0.33))
                }

                Text(state.trackTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(state.artist)
                    .font(.system(size: 12))
                    .foregroundColor(Color.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Playback Equalizer Waves
            HStack(spacing: 3) {
                ForEach(0..<4) { idx in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                        .frame(width: 3.5, height: CGFloat(state.isPlaying ? (10 + (idx * 4)) : 4))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }
}
#endif
