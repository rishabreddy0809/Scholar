//
//  ShortCard.swift
//  Scholar
//

import SwiftUI

struct ShortCard: View {
    let video: ShortVideo
    /// Only the centred card plays; neighbours stay mounted but paused.
    let isCurrent: Bool
    /// Cards outside this window render a still and never build a web view.
    let isNearby: Bool
    let isMuted: Bool
    /// True when this clip matched the active study material's own vocabulary,
    /// rather than merely coming from the right subject area.
    var onTopic: Bool = false
    var isExactMatch: Bool = true
    var subject: String = ""
    let onPlaybackChange: (Bool) -> Void

    @Environment(Store.self) private var store
    @State private var isPaused = false
    @State private var showFullSummary = false
    @State private var showHeart = false
    /// Set to the player's error code once the embed gives up; the still takes
    /// over and the code picks the explanation.
    @State private var embedError: Int?

    private var item: FeedItem { .short(video) }

    var body: some View {
        ZStack {
            Color.black

            // Soft bed behind the letterboxed 9:16 player.
            RemoteImage(url: video.thumbnailURL)
                .blur(radius: 45)
                .opacity(0.5)
                .clipped()

            if isNearby && embedError == nil {
                YouTubePlayerView(
                    videoID: video.id,
                    isActive: isCurrent && !isPaused,
                    isMuted: isMuted,
                    onStateChange: { state in
                        onPlaybackChange(state == .playing)
                    },
                    onError: { code in
                        onPlaybackChange(false)
                        embedError = code
                    }
                )
                .allowsHitTesting(false)
            } else {
                RemoteImage(url: video.thumbnailURL, contentMode: .fit)
                if let embedError { embedFallback(code: embedError) }
            }

            scrim
            tapLayer
            overlay
            if showHeart { heartBurst }
        }
        .clipped()
        .onChange(of: isCurrent) { _, current in
            if !current {
                isPaused = false
                showFullSummary = false
                onPlaybackChange(false)
            }
        }
    }

    /// The player draws its own overlay — the Shorts label, the unmute
    /// affordance, the video title — along the top edge of the iframe. Pushing
    /// it out of sight would mean oversizing the iframe, which is what used to
    /// crop the picture; a scrim hides it for free instead, and doubles as
    /// contrast for the app's own header over a bright clip.
    private var scrim: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.25), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 165)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    /// Shown when the embed gives up — the still stays, with a route out to the
    /// YouTube app rather than a dead black card.
    private func embedFallback(code: Int) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "play.slash.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.75))
            Text("This one can't play here")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text(Self.reason(for: code))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            if let url = video.watchURL {
                Link(destination: url) {
                    Label("Watch on YouTube", systemImage: "arrow.up.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.white, in: .capsule)
                }
            }
        }
        .padding(24)
        .background(.black.opacity(0.55), in: .rect(cornerRadius: 20))
    }

    /// A wrong explanation sends you hunting through the catalogue for a
    /// channel that isn't at fault, so each code gets its own wording.
    private static func reason(for code: Int) -> String {
        let explanation: String
        switch code {
        case 100:            explanation = "This video isn't available any more."
        case 101, 150:       explanation = "The channel disabled off-site playback."
        case 2:              explanation = "YouTube rejected this video's ID."
        case 5:              explanation = "The player couldn't handle this one."
        case -3, -4, -8:     explanation = "Couldn't start the player. Check your connection."
        case -7:             explanation = "The player loaded but never started."
        default:             explanation = "The player didn't start."
        }
        #if DEBUG
        // Guessing at the cause cost a round of device testing.
        return "\(explanation)\n(player error \(code))"
        #else
        return explanation
        #endif
    }

    // MARK: - Gestures

    private var tapLayer: some View {
        Color.clear
            .contentShape(.rect)
            .onTapGesture(count: 2) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if store.vote(item) != .up { store.setVote(.up, for: item) }
                withAnimation(.spring(duration: 0.3)) { showHeart = true }
                Task {
                    try? await Task.sleep(for: .seconds(0.7))
                    withAnimation(.easeOut(duration: 0.3)) { showHeart = false }
                }
            }
            .onTapGesture {
                isPaused.toggle()
                onPlaybackChange(!isPaused)
            }
    }

    private var heartBurst: some View {
        Image(systemName: "arrowshape.up.fill")
            .font(.system(size: 88, weight: .bold))
            .foregroundStyle(Theme.up)
            .shadow(color: .black.opacity(0.4), radius: 12)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
            .allowsHitTesting(false)
    }

    // MARK: - Overlay

    private var overlay: some View {
        VStack(spacing: 0) {
            Spacer()

            // Runs to near-solid at the very bottom so the player's own title
            // caption, which sits on the last few points of the frame, is
            // covered rather than showing faintly through.
            LinearGradient(
                colors: [.clear, .black.opacity(0.55), .black.opacity(0.88), .black.opacity(0.97)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 330)
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 12) {
                    metadata
                    Spacer(minLength: 4)
                    ActionRail(item: item)
                }
                .padding(.horizontal, 16)
                // The floating tab bar sits ~90pt up from the bottom edge;
                // 96 left "Show more" all but touching it.
                .padding(.bottom, 118)
            }
        }
        .overlay(alignment: .center) {
            if isPaused {
                Image(systemName: "play.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 10)
                    .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(true)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            if onTopic { OnTopicBadge(isExact: isExactMatch, subject: subject) }

            HStack(spacing: 6) {
                Text(video.channelName)
                    .font(.system(size: 14, weight: .bold))
                if video.views > 0 {
                    Text("· \(video.views.compactCount) views")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .foregroundStyle(.white)

            Text(video.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(showFullSummary ? 6 : 2)
                .multilineTextAlignment(.leading)

            let summary = video.cleanSummary
            if !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(showFullSummary ? 12 : 2)
                    .multilineTextAlignment(.leading)

                Button(showFullSummary ? "Show less" : "Show more") {
                    withAnimation(.easeInOut(duration: 0.2)) { showFullSummary.toggle() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accentSoft)
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
    }
}
