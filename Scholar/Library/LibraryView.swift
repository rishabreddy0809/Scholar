//
//  LibraryView.swift
//  Scholar
//

import SwiftUI

struct LibraryView: View {
    @Environment(Store.self) private var store
    @State private var filter: Filter = .all
    @State private var audio = AudioEngine.shared

    enum Filter: String, CaseIterable, Identifiable {
        case all, watch, listen
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .watch: return "Watch"
            case .listen: return "Listen"
            }
        }
    }

    private var items: [FeedItem] {
        switch filter {
        case .all:    return store.saved
        case .watch:  return store.saved.filter(\.isShort)
        case .listen: return store.saved.filter { !$0.isShort }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed rather than inside the scroll: the empty state has no
                // scroll view to sit in, and the title has to show in both.
                ScreenTitle(text: "Saved")
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)

                Group {
                    if store.saved.isEmpty {
                        FeedPlaceholder(
                            icon: "bookmark",
                            title: "Nothing saved yet",
                            message: "Tap the bookmark on any short or episode and it lands here."
                        )
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                picker
                                ForEach(items) { item in
                                    row(item)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 120)
                        }
                    }
                }
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var picker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(Filter.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 4)
    }

    private func row(_ item: FeedItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RemoteImage(url: item.artworkURL)
                    .frame(width: 78, height: 58)
                    .clipShape(.rect(cornerRadius: 10))
                Image(systemName: item.isShort ? "play.fill" : "waveform")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(item.sourceName)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            action(for: item)
        }
        .padding(10)
        .cardSurface(14)
        .contextMenu {
            Button("Remove", systemImage: "trash", role: .destructive) {
                store.toggleSave(item)
            }
        }
    }

    @ViewBuilder
    private func action(for item: FeedItem) -> some View {
        switch item {
        case .short(let video):
            if let url = video.watchURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.accentSoft)
                }
            }
        case .episode(let episode):
            Button {
                audio.isPinned = true
                audio.play(episode)
            } label: {
                Image(systemName: audio.current?.id == episode.id && audio.isPlaying
                      ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accentSoft)
            }
            .buttonStyle(.plain)
        }
    }
}
