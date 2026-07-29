//
//  PagingFeedView.swift
//  Scholar
//
//  One endless vertical pager drives every feed in the app — the shorts tab,
//  the listen tab, and any focused topic or generated feed. Only the centred
//  card and its immediate neighbours are live, so a feed of hundreds of items
//  still holds at most three web views.
//

import Combine
import SwiftUI

struct PagingFeedView: View {
    let kind: FeedKind
    let source: FeedSource
    let title: String
    /// Present when the feed is pushed rather than a root tab.
    var onClose: (() -> Void)? = nil
    /// Interest-backed feeds rebuild themselves when the selection changes.
    var followsInterests = false
    /// Set when this feed is scoped to an uploaded document.
    var focusedMaterial: StudyMaterial? = nil

    @Environment(Store.self) private var store
    @State private var engine: FeedEngine?
    @State private var currentID: String?
    @State private var isMuted = false
    @State private var isVideoPlaying = false
    @State private var showInterests = false
    @State private var audio = AudioEngine.shared
    @State private var dwellTask: Task<Void, Never>?

    /// Ticks only while media is actually playing, so a paused card parked on
    /// screen never inflates the daily streak.
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isPlaying: Bool { isVideoPlaying || audio.isPlaying }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if let engine {
                if engine.items.isEmpty {
                    placeholder(engine)
                } else {
                    // The cards run edge to edge, under the Dynamic Island and
                    // the home indicator both — a letterboxed strip above the
                    // video reads as a rendering glitch. The header is a
                    // sibling rather than an overlay so it keeps the safe area
                    // this deliberately gives up.
                    // The outer reader still has the safe area, so it can
                    // measure the inset the inner one is about to give up.
                    // Cards that top-align their content need it back as
                    // padding, or they run under the Dynamic Island.
                    GeometryReader { outer in
                        let topInset = outer.safeAreaInsets.top
                        GeometryReader { inner in
                            scroll(engine, size: inner.size, topInset: topInset)
                        }
                        .ignoresSafeArea()
                    }
                }
            } else {
                ProgressView().tint(Theme.textDim)
            }

            header
        }
        .task { await bootstrap() }
        .onChange(of: store.selectedInterestIDs) { _, ids in
            guard followsInterests else { return }
            Task { await engine?.updateSource(.interests(Array(ids))) }
        }
        .onReceive(clock) { _ in
            guard isPlaying else { return }
            store.tickStudyTime()
        }
        .onChange(of: isPlaying) { _, playing in
            if !playing { store.pausePlaybackClock() }
        }
        .onDisappear {
            isVideoPlaying = false
            store.pausePlaybackClock()
        }
        .sheet(isPresented: $showInterests) { InterestGridView().environment(store) }
    }

    // MARK: - Scroll

    private func scroll(_ engine: FeedEngine, size: CGSize, topInset: CGFloat) -> some View {
        // Resolved once per pass. Doing it inside `card` made every visible
        // cell scan the whole feed, so scrolling got measurably heavier the
        // longer the session ran.
        let currentIndex = engine.items.firstIndex { $0.id == currentID } ?? 0

        return ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(engine.items.enumerated()), id: \.element.id) { index, item in
                    card(item, index: index, currentIndex: currentIndex, topInset: topInset)
                        .frame(width: size.width, height: size.height)
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $currentID)
        .onChange(of: currentID) { _, id in advance(to: id, engine: engine) }
    }

    @ViewBuilder
    private func card(_ item: FeedItem, index: Int, currentIndex: Int, topInset: CGFloat) -> some View {
        let isCurrent = item.id == currentID || (currentID == nil && index == 0)

        switch item {
        case .short(let video):
            ShortCard(
                video: video,
                isCurrent: isCurrent,
                isNearby: abs(index - currentIndex) <= 1,
                isMuted: isMuted,
                onTopic: focusedMaterial != nil,
                isExactMatch: isOnTopic(item),
                subject: focusedMaterial?.interests.first?.name ?? "",
                onPlaybackChange: { playing in
                    if isCurrent { isVideoPlaying = playing }
                }
            )
        case .episode(let episode):
            PodcastCard(episode: episode, isCurrent: isCurrent,
                        onTopic: focusedMaterial != nil,
                        isExactMatch: isOnTopic(item),
                        subject: focusedMaterial?.interests.first?.name ?? "",
                        topClearance: topInset + headerHeight,
                        material: focusedMaterial)
        }
    }

    /// How far the floating header reaches below the safe area: the title row,
    /// plus the study banner when a document is in focus.
    private var headerHeight: CGFloat {
        focusedMaterial == nil ? 52 : 92
    }

    private func isOnTopic(_ item: FeedItem) -> Bool {
        guard let material = focusedMaterial else { return false }
        let blob: String
        switch item {
        case .short(let v):   blob = "\(v.title) \(v.channelName) \(v.cleanSummary)"
        case .episode(let e): blob = "\(e.title) \(e.showTitle) \(e.cleanSummary)"
        }
        return material.matches(text: blob, source: item.sourceName)
    }

    private func advance(to id: String?, engine: FeedEngine) {
        guard let id, let index = engine.items.firstIndex(where: { $0.id == id }) else { return }

        let item = engine.items[index]

        // A short scrolling into view supersedes an unpinned episode.
        if item.isShort, !audio.isPinned, audio.isPlaying { audio.pause() }
        if item.isShort { isVideoPlaying = false }

        // Only count an item once it has actually held the screen. Flicking
        // past — or the lazy stack settling on load — shouldn't move progress.
        dwellTask?.cancel()
        dwellTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, currentID == id else { return }
            store.markSeen(item, interests: matchingInterests(for: item))
                if case .generated(let feed) = source { bumpProgress(feed) }
            if let material = focusedMaterial { store.recordMaterialProgress(material.id) }
        }

        Task { await engine.extendIfNeeded(currentIndex: index) }
    }

    private func bumpProgress(_ feed: GeneratedFeed) {
        guard let index = store.generatedFeeds.firstIndex(where: { $0.id == feed.id }) else { return }
        store.generatedFeeds[index].itemsSeen += 1
    }

    /// Attributes a viewed card back to the interests that supplied it, so the
    /// dashboard progress bars actually move.
    private func matchingInterests(for item: FeedItem) -> [Interest] {
        guard case .short(let video) = item else {
            let name = item.sourceName.lowercased()
            let tokens = KeywordExtractor.tokenize(name)
            let matched = store.effectiveInterests.filter { interest in
                interest.anchors.contains { KeywordExtractor.mentions($0, in: tokens) } ||
                interest.podcastQueries.contains { name.contains($0.lowercased()) }
            }
            return matched.isEmpty ? store.effectiveInterests : matched
        }
        return store.effectiveInterests.filter { $0.channelIDs.contains(video.channelID) }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack {
            HStack(spacing: 10) {
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.3), in: .circle)
                    }
                    .buttonStyle(.plain)
                }

                Text(title)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if store.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                        Text("\(store.streak)")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.flame)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.3), in: .capsule)
                }

                if kind != .podcasts {
                    iconButton(isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                        isMuted.toggle()
                    }
                }
                if focusedMaterial != nil {
                    iconButton("xmark") { store.activeMaterialID = nil }
                } else if onClose == nil {
                    iconButton("slider.horizontal.3") { showInterests = true }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            if let material = focusedMaterial { focusBanner(material) }

            Spacer()
        }
        .shadow(color: .black.opacity(0.45), radius: 6)
    }

    /// Makes it unmistakable that the feed is scoped, and shows what to.
    private func focusBanner(_ material: StudyMaterial) -> some View {
        HStack(spacing: 7) {
            Image(systemName: material.kind.symbol)
                .font(.system(size: 10, weight: .bold))
            Text("Studying · \(material.topTerms.prefix(3).joined(separator: ", "))")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Theme.accent.opacity(0.85), in: .capsule)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.3), in: .circle)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func placeholder(_ engine: FeedEngine) -> some View {
        if engine.isLoading {
            VStack(spacing: 14) {
                ProgressView().tint(.white)
                Text(kind == .podcasts ? "Finding episodes…" : "Building your feed…")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textDim)
            }
        } else if engine.loadFailed {
            FeedPlaceholder(
                icon: "wifi.exclamationmark",
                title: "Couldn't load the feed",
                message: "Scholar pulls live content from YouTube and the podcast directory. Check your connection and try again.",
                actionTitle: "Retry",
                action: { Task { await engine.reload() } }
            )
        } else if let material = focusedMaterial {
            let terms = material.topTerms.prefix(3).joined(separator: ", ")
            // Each tab only searches its own medium now, so an empty shorts
            // feed doesn't mean the document has nothing waiting in Listen.
            let hint = kind == .podcasts
                ? "Couldn't find episodes matching “\(terms)”. Try the Feed tab for shorts, or material with more specific terms."
                : "Couldn't find shorts matching “\(terms)”. Try the Listen tab for episodes, or material with more specific terms."
            FeedPlaceholder(
                icon: "doc.text.magnifyingglass",
                title: "Nothing on-topic yet",
                message: hint,
                actionTitle: "Leave study mode",
                action: { store.activeMaterialID = nil }
            )
        } else {
            FeedPlaceholder(
                icon: "square.stack.3d.up.slash",
                title: "Nothing here yet",
                message: "Pick a few interests and the feed fills itself.",
                actionTitle: "Choose topics",
                action: { showInterests = true }
            )
        }
    }

    // MARK: - Setup

    private func bootstrap() async {
        guard engine == nil else { return }
        let newEngine = FeedEngine(kind: kind, source: source, store: store)
        engine = newEngine
        await newEngine.load()
        currentID = newEngine.items.first?.id
    }
}
