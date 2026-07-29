//
//  EpisodeBrowser.swift
//  Scholar
//
//  Full episode list for whichever show is on screen. A dedicated topic
//  podcast often has hundreds of episodes, and that back catalogue is the
//  densest on-topic material the app can offer — far more than the handful
//  the feed itself surfaces.
//

import SwiftUI

struct EpisodeBrowser: View {
    let showTitle: String
    let showID: Int
    let feedURL: URL?
    let artworkURL: URL?
    /// When present, episodes matching the active study material are pinned
    /// to the top and badged.
    var material: StudyMaterial?

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var audio = AudioEngine.shared

    @State private var episodes: [PodcastEpisode] = []
    @State private var isLoading = true
    @State private var query = ""
    @State private var onTopicOnly = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(Theme.accentSoft)
                        Text("Loading episodes…")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textDim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if episodes.isEmpty {
                    FeedPlaceholder(
                        icon: "waveform.slash",
                        title: "No episodes found",
                        message: "This show's feed didn't return anything readable."
                    )
                } else {
                    list
                }
            }
            .background(Theme.bg)
            .navigationTitle(showTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accentSoft)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                header

                ForEach(filtered) { episode in
                    row(episode)
                }

                if filtered.isEmpty {
                    Text("Nothing matches that.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textDim)
                        .padding(.top, 30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .searchable(text: $query, prompt: "Search episodes")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RemoteImage(url: artworkURL)
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(episodes.count) episodes")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    if let material, matchCount > 0 {
                        Text("\(matchCount) match \(material.topTerms.prefix(2).joined(separator: ", "))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.up)
                    }
                }
                Spacer()
            }

            if material != nil, matchCount > 0 {
                Toggle(isOn: $onTopicOnly) {
                    Text("On-topic only")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
                .tint(Theme.accent)
            }
        }
        .padding(.vertical, 8)
    }

    private func row(_ episode: PodcastEpisode) -> some View {
        let isPlaying = audio.current?.id == episode.id && audio.isPlaying
        let onTopic = material?.matches(text: "\(episode.title) \(episode.cleanSummary)", source: showTitle) ?? false

        return Button {
            audio.isPinned = true
            if audio.current?.id == episode.id { audio.toggle() } else { audio.play(episode) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accentSoft)

                VStack(alignment: .leading, spacing: 4) {
                    if onTopic { OnTopicBadge() }

                    Text(episode.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Text(episode.durationLabel)
                        Text("·")
                        Text(episode.published.relativeLabel)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textDim)
                }

                Spacer(minLength: 4)

                Button {
                    store.toggleSave(.episode(episode))
                } label: {
                    Image(systemName: store.isSaved(.episode(episode)) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 15))
                        .foregroundStyle(store.isSaved(.episode(episode)) ? Theme.accentSoft : Theme.textFaint)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .cardSurface(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private var matchCount: Int {
        guard let material else { return 0 }
        return episodes.filter { material.matches(text: "\($0.title) \($0.cleanSummary)", source: showTitle) }.count
    }

    private var filtered: [PodcastEpisode] {
        var result = episodes

        if onTopicOnly, let material {
            result = result.filter { material.matches(text: "\($0.title) \($0.cleanSummary)", source: showTitle) }
        }
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            let needle = query.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(needle) || $0.cleanSummary.lowercased().contains(needle)
            }
        }
        // On-topic episodes float to the top of a long back catalogue.
        if let material, !onTopicOnly {
            result.sort { lhs, rhs in
                let l = material.matches(text: "\(lhs.title) \(lhs.cleanSummary)", source: showTitle)
                let r = material.matches(text: "\(rhs.title) \(rhs.cleanSummary)", source: showTitle)
                return l == r ? lhs.published > rhs.published : l
            }
        }
        return result
    }

    private func load() async {
        guard episodes.isEmpty, let feedURL else { isLoading = false; return }
        let show = PodcastShow(id: showID, title: showTitle, author: "",
                               feedURL: feedURL, artworkURL: artworkURL, genres: [])
        // Far deeper than the feed pulls, since this is the browse view.
        episodes = await PodcastService.shared.episodes(for: show, limit: 300)
        isLoading = false
    }
}
