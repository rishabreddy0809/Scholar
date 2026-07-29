//
//  PodcastCard.swift
//  Scholar
//

import SwiftUI

struct PodcastCard: View {
    let episode: PodcastEpisode
    let isCurrent: Bool
    var onTopic: Bool = false
    var isExactMatch: Bool = true
    var subject: String = ""
    /// The card runs edge to edge, so the space the safe area and the floating
    /// header would have taken has to come back as padding — otherwise the
    /// artwork slides under the Dynamic Island and the study banner.
    var topClearance: CGFloat = 0

    @Environment(Store.self) private var store
    @State private var audio = AudioEngine.shared
    @State private var showFullSummary = false
    @State private var showEpisodeBrowser = false
    /// Set when this card is inside a focused study feed, so the browser can
    /// pin matching episodes.
    var material: StudyMaterial? = nil

    private var item: FeedItem { .episode(episode) }
    private var isLoaded: Bool { audio.current?.id == episode.id }

    var body: some View {
        ZStack {
            background
            content
        }
        .clipped()
        .onChange(of: isCurrent) { _, current in
            // Scrolling away stops playback unless the user pinned the episode
            // to keep listening while they browse.
            if current {
                audio.play(episode)
            } else if isLoaded && !audio.isPinned {
                audio.pause()
            }
        }
        .onAppear { if isCurrent { audio.play(episode) } }
        .sheet(isPresented: $showEpisodeBrowser) {
            EpisodeBrowser(showTitle: episode.showTitle,
                           showID: episode.showID,
                           feedURL: episode.showFeedURL,
                           artworkURL: episode.artworkURL,
                           material: material)
                .environment(store)
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color.black
            RemoteImage(url: episode.artworkURL)
                .blur(radius: 60)
                .opacity(0.55)
                .clipped()
            LinearGradient(
                colors: [.black.opacity(0.25), .black.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: topClearance)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    artwork
                    details
                }
                ActionRail(item: item)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)

            Spacer(minLength: 0)
            transport
                .padding(.horizontal, 20)
                .padding(.bottom, 124)
        }
    }

    private var artwork: some View {
        RemoteImage(url: episode.artworkURL)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(.rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
            .overlay(alignment: .topLeading) {
                Label("PODCAST", systemImage: "waveform")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.55), in: .capsule)
                    .padding(10)
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showEpisodeBrowser = true } label: {
                    Label("All episodes", systemImage: "list.bullet")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.6), in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            if onTopic { OnTopicBadge(isExact: isExactMatch, subject: subject) }

            // The show name doubles as the way into its full catalogue.
            Button {
                showEpisodeBrowser = true
            } label: {
                HStack(spacing: 5) {
                    Text(episode.showTitle.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Theme.accentSoft)
            }
            .buttonStyle(.plain)

            Text(episode.title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(3)

            HStack(spacing: 6) {
                Text(episode.durationLabel)
                Text("·")
                Text(episode.published.relativeLabel)
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.65))

            let summary = episode.cleanSummary
            if !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(showFullSummary ? 10 : 3)

                Button(showFullSummary ? "Show less" : "Show more") {
                    withAnimation(.easeInOut(duration: 0.2)) { showFullSummary.toggle() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accentSoft)
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
    }

    // MARK: - Transport

    private var transport: some View {
        VStack(spacing: 14) {
            scrubber

            HStack(spacing: 34) {
                transportButton("gobackward.15", size: 24) { audio.skip(by: -15) }

                Button {
                    audio.toggle()
                } label: {
                    ZStack {
                        Circle().fill(.white).frame(width: 62, height: 62)
                        if audio.isBuffering && isLoaded {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: (isLoaded && audio.isPlaying) ? "pause.fill" : "play.fill")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(.black)
                                .offset(x: (isLoaded && audio.isPlaying) ? 0 : 2)
                        }
                    }
                }
                .buttonStyle(.plain)

                transportButton("goforward.30", size: 24) { audio.skip(by: 30) }
            }

            Button {
                audio.isPinned.toggle()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label(audio.isPinned ? "Keeping this playing" : "Keep playing while I browse",
                      systemImage: audio.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(audio.isPinned ? Theme.accentSoft : .white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    private var scrubber: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { isLoaded ? audio.currentTime : 0 },
                    set: { audio.seek(to: $0) }
                ),
                in: 0...max(1, isLoaded ? audio.duration : episode.duration)
            )
            .tint(.white)
            .disabled(!isLoaded)

            HStack {
                Text(timeLabel(isLoaded ? audio.currentTime : 0))
                Spacer()
                Text("-" + timeLabel(max(0, (isLoaded ? audio.duration : episode.duration) - (isLoaded ? audio.currentTime : 0))))
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func transportButton(_ name: String, size: CGFloat,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func timeLabel(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
