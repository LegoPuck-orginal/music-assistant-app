import WidgetKit
import SwiftUI
import UIKit
import ActivityKit

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
private struct DynamicIslandArtworkThumb: View {
    let base64: String?
    let size: CGFloat
    let cornerRadius: CGFloat

    private static let neonEmber = Color(red: 1.0, green: 0.36, blue: 0.0)

    var body: some View {
        if let b64 = base64,
           let data = Data(base64Encoded: b64),
           let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Self.neonEmber,
                                Color(red: 0.65, green: 0.14, blue: 0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                Image(systemName: "waveform")
                    .foregroundColor(.white)
                    .font(.system(size: size * 0.48, weight: .bold))
            }
        }
    }
}

@available(iOS 16.1, *)
struct MusicAssistantDynamicIslandWidget: Widget {
    private static let neonEmber = Color(red: 1.0, green: 0.36, blue: 0.0)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicAssistantActivityAttributes.self) { context in
            LockScreenLiveActivityView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        DynamicIslandArtworkThumb(
                            base64: context.state.albumArtBase64,
                            size: 44,
                            cornerRadius: 10
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Self.neonEmber)
                                    .frame(width: 6, height: 6)
                                Text(context.state.speakerName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Self.neonEmber)
                                    .lineLimit(1)
                            }
                            Text(context.state.djVibe)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 3) {
                        ForEach(0..<4) { idx in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Self.neonEmber)
                                .frame(
                                    width: 3.5,
                                    height: CGFloat(context.state.isPlaying ? (8 + (idx * 4)) : 4)
                                )
                        }
                    }
                    .padding(.trailing, 6)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 3) {
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
                                    .foregroundColor(Self.neonEmber)
                                    .font(.system(size: 11))
                                Text(speech)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Self.neonEmber)
                                    .lineLimit(1)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                DynamicIslandArtworkThumb(
                    base64: context.state.albumArtBase64,
                    size: 22,
                    cornerRadius: 6
                )
            } compactTrailing: {
                HStack(spacing: 2) {
                    ForEach(0..<4) { idx in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Self.neonEmber)
                            .frame(
                                width: 2.5,
                                height: CGFloat(context.state.isPlaying ? (5 + ((idx % 3) * 4)) : 3)
                            )
                    }
                }
            } minimal: {
                DynamicIslandArtworkThumb(
                    base64: context.state.albumArtBase64,
                    size: 20,
                    cornerRadius: 5
                )
            }
        }
    }
}

@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let state: MusicAssistantActivityAttributes.ContentState
    private static let neonEmber = Color(red: 1.0, green: 0.36, blue: 0.0)

    var body: some View {
        HStack(spacing: 12) {
            DynamicIslandArtworkThumb(
                base64: state.albumArtBase64,
                size: 48,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Self.neonEmber)
                        .frame(width: 6, height: 6)
                    Text(state.speakerName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Self.neonEmber)
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

            HStack(spacing: 3) {
                ForEach(0..<4) { idx in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Self.neonEmber)
                        .frame(width: 3, height: CGFloat(state.isPlaying ? (8 + (idx * 4)) : 4))
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.03, green: 0.03, blue: 0.05))
    }
}
#endif
