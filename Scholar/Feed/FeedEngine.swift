//
//  FeedEngine.swift
//  Scholar
//
//  Turns a set of interests into a feed that never hits a bottom. Sources are
//  consumed in waves and round-robin interleaved so you never get five clips
//  from the same channel in a row; when every source is spent the corpus is
//  reshuffled, unseen items first.
//

import Foundation
import Observation

enum FeedKind: String, Sendable {
    case shorts, podcasts, mixed
}

enum FeedSource: Equatable {
    case interests([String])        // interest IDs
    case generated(GeneratedFeed)
    /// Everything the user is shown is scored against this document.
    case material(StudyMaterial)

    static func == (lhs: FeedSource, rhs: FeedSource) -> Bool {
        switch (lhs, rhs) {
        case (.interests(let a), .interests(let b)): return Set(a) == Set(b)
        case (.generated(let a), .generated(let b)): return a.id == b.id
        case (.material(let a), .material(let b)):   return a.id == b.id
        default: return false
        }
    }

    var material: StudyMaterial? {
        if case .material(let m) = self { return m }
        return nil
    }
}

@MainActor
@Observable
final class FeedEngine {
    private(set) var items: [FeedItem] = []
    private(set) var isLoading = false
    private(set) var isExtending = false
    /// Set only when the sources themselves came back with nothing — never
    /// because the relevance filter rejected what they returned. Those are
    /// different failures and they need different words in front of the user.
    private(set) var loadFailed = false
    private(set) var recycled = false

    /// Whether a wave actually went out to the network this fill, and whether
    /// anything at all came back before filtering. Together they separate "the
    /// feeds are unreachable" from "the feeds are fine and nothing matched".
    private var attemptedFetch = false
    private var fetchedAnything = false

    let kind: FeedKind
    private var source: FeedSource
    private weak var store: Store?

    /// Sources not yet pulled in this pass.
    private var channelQueue: [EduChannel] = []
    private var podcastQueryQueue: [String] = []
    private var knownShows: [PodcastShow] = []
    private var showQueue: [PodcastShow] = []

    /// Channels belonging to the document's subject area. Used as the
    /// second tier when nothing matches the document's exact vocabulary.
    private var preferredChannelIDs: Set<String> = []

    /// Everything fetched so far this session, kept for the recycle pass.
    private var corpus: [FeedItem] = []
    private var presentIDs: Set<String> = []

    private let waveChannelCount = 5
    private let waveQueryCount = 2
    private let waveShowCount = 4
    private let extendThreshold = 8
    private let minItemsPerFill = 6
    private let maxWavesPerFill = 5

    init(kind: FeedKind, source: FeedSource, store: Store?) {
        self.kind = kind
        self.source = source
        self.store = store
    }

    // MARK: - Lifecycle

    func updateSource(_ newSource: FeedSource) async {
        guard newSource != source else { return }
        source = newSource
        await reload()
    }

    func reload() async {
        items.removeAll()
        corpus.removeAll()
        presentIDs.removeAll()
        knownShows.removeAll()
        recycled = false
        loadFailed = false
        resetQueues()
        await load()
    }

    func load() async {
        guard !isLoading, items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        if !hasSources { resetQueues() }
        _ = await fill()
        // An empty feed is only a *load* failure when the fetches came back
        // empty-handed. A study feed that pulled 25 channels and found nothing
        // on topic has loaded perfectly well; telling that user to check their
        // connection sends them to fix a network that was never broken.
        loadFailed = attemptedFetch && !fetchedAnything
    }

    /// Called as the user scrolls; keeps a runway of items ahead of them.
    func extendIfNeeded(currentIndex: Int) async {
        guard !isExtending, !isLoading else { return }
        guard items.count - currentIndex <= extendThreshold else { return }

        isExtending = true
        defer { isExtending = false }

        var added = await fill()
        if added == 0 {
            // Every source is spent — reshuffle what we have, unseen first.
            added = recycle()
        }
    }

    /// Only counts queues this feed will actually draw from — a shorts feed
    /// with a full podcast queue and no channels left is spent, and should
    /// recycle rather than burn waves fetching audio it will never show.
    private var hasSources: Bool {
        let video = kind != .podcasts && !channelQueue.isEmpty
        let audio = kind != .shorts && (!podcastQueryQueue.isEmpty || !showQueue.isEmpty)
        return video || audio
    }

    /// Pulls waves until there's a worthwhile batch. An interest feed is
    /// satisfied by a single wave; a focused study feed usually isn't, because
    /// the relevance filter discards most of what comes back.
    private func fill() async -> Int {
        attemptedFetch = false
        fetchedAnything = false

        var added = 0
        var waves = 0
        while added < minItemsPerFill, waves < maxWavesPerFill, hasSources {
            added += await pullWave()
            waves += 1
        }
        return added
    }

    // MARK: - Source queues

    private func resetQueues() {
        let interests = resolvedInterests()

        var channels: [EduChannel] = []
        var queries: [String] = []

        switch source {
        case .interests:
            channels = interests.flatMap(\.channels)
            queries = interests.flatMap(\.podcastQueries)
        case .generated(let feed):
            channels = feed.channelIDs.compactMap(ChannelCatalog.channel(id:))
            queries = [feed.query]
            if channels.isEmpty { channels = interests.flatMap(\.channels) }
        case .material(let material):
            // Subject-matched channels first, then everything else. Each
            // channel's Shorts feed only exposes its ~15 most recent clips, so
            // a narrow pool leaves the relevance filter with nothing to find.
            let preferred = material.channels
            preferredChannelIDs = Set(preferred.map(\.id))
            channels = preferred
                + ChannelCatalog.all.filter { !preferredChannelIDs.contains($0.id) }.shuffled()
            queries = material.searchQueries
        }

        channels.append(contentsOf: store?.customChannels ?? [])

        // A focused feed has already ordered its channels by subject fit, so
        // only the open-ended feeds get shuffled.
        let ordered = source.material == nil ? channels.shuffled() : channels
        var seenChannels: Set<String> = []
        channelQueue = ordered.filter { seenChannels.insert($0.id).inserted }

        var seenQueries: Set<String> = []
        podcastQueryQueue = queries.shuffled().filter { seenQueries.insert($0.lowercased()).inserted }
        showQueue = []
    }

    private func resolvedInterests() -> [Interest] {
        switch source {
        case .interests(let ids):
            let resolved = ids.compactMap(Interest.find)
            return resolved.isEmpty ? (store?.effectiveInterests ?? []) : resolved
        case .generated:
            return store?.effectiveInterests ?? []
        case .material(let material):
            // No fallback here on purpose. A document whose subject wasn't
            // recognised must not inherit the user's general interests —
            // that turns a focused study feed back into the everyday one.
            return material.interests
        }
    }

    // MARK: - Fetching

    /// Pulls one wave from whichever source types this feed uses.
    /// Returns how many new items landed in the feed.
    private func pullWave() async -> Int {
        var batches: [[FeedItem]] = []

        attemptedFetch = true
        if kind != .podcasts {
            batches += await pullShortsWave()
        }
        if kind != .shorts {
            batches += await pullPodcastWave()
        }
        // Recorded before ranking, because this is the question "did the
        // network answer?" and the filter has not had its say yet.
        if !batches.isEmpty { fetchedAnything = true }
        guard !batches.isEmpty else { return 0 }

        var ordered = interleave(batches)

        // Source-diversity interleaving is right for an open feed, but in a
        // focused one it can hand the top slot to same-subject filler while
        // genuinely on-topic items wait below. Partition so matches lead.
        if let material = source.material {
            let onTopic = ordered.filter {
                material.matches(text: Self.searchText($0), source: $0.sourceName)
            }
            let rest = ordered.filter {
                !material.matches(text: Self.searchText($0), source: $0.sourceName)
            }
            ordered = onTopic + rest
        }
        return append(ordered)
    }

    private func pullShortsWave() async -> [[FeedItem]] {
        guard !channelQueue.isEmpty else { return [] }
        let wave = Array(channelQueue.prefix(waveChannelCount))
        channelQueue.removeFirst(wave.count)

        let grouped = await YouTubeRSSService.shared.shorts(for: wave)
        return grouped.map { batch in batch.map(FeedItem.short) }
    }

    private func pullPodcastWave() async -> [[FeedItem]] {
        if showQueue.isEmpty, !podcastQueryQueue.isEmpty {
            let queries = Array(podcastQueryQueue.prefix(waveQueryCount))
            podcastQueryQueue.removeFirst(queries.count)

            var discovered: [PodcastShow] = []
            for query in queries {
                discovered += await PodcastService.shared.searchShows(query, limit: 10)
            }
            var seen = Set(knownShows.map(\.id))
            let fresh = discovered.filter { seen.insert($0.id).inserted }
            knownShows += fresh
            showQueue += fresh.shuffled()
        }

        guard !showQueue.isEmpty else { return [] }
        let wave = Array(showQueue.prefix(waveShowCount))
        showQueue.removeFirst(wave.count)

        let grouped = await PodcastService.shared.episodes(forShows: wave, perShow: 6)
        return grouped.map { batch in batch.map(FeedItem.episode) }
    }

    // MARK: - Ordering

    /// Round-robin across sources so consecutive cards come from different
    /// channels or shows.
    private func interleave(_ batches: [[FeedItem]]) -> [FeedItem] {
        let ranked = batches.map { rank($0) }
        var result: [FeedItem] = []
        var cursor = 0
        var exhausted = false

        while !exhausted {
            exhausted = true
            for batch in ranked where cursor < batch.count {
                result.append(batch[cursor])
                exhausted = false
            }
            cursor += 1
        }
        return result
    }

    private func rank(_ batch: [FeedItem]) -> [FeedItem] {
        guard let store else { return batch }
        let boosted = store.boostedSources

        var candidates = batch.filter { store.votes[$0.id] != .down && !$0.isTrailer }

        // A focused study feed only shows content that demonstrably matches
        // the document. Everything else is dropped rather than demoted.
        if let material = source.material {
            // Two tiers. Anything matching the document's own vocabulary is an
            // exact hit. Beyond that only same-subject channels survive —
            // YouTube's Shorts feed exposes just the ~15 most recent clips per
            // channel, so a specific topic often has no exact match anywhere in
            // the catalogue and a pure exact-match filter can leave the feed
            // empty.
            func isOnTopic(_ item: FeedItem) -> Bool {
                material.matches(text: Self.searchText(item), source: item.sourceName)
            }
            let onTopic = candidates.filter(isOnTopic)
            // Filler still has to be about the document. Belonging to the
            // right subject area is not on its own a reason to show a clip:
            // being tagged Neuroscience is what put pop-psychology shorts in
            // front of someone studying on-device model training. A filler
            // item must come from a subject channel *and* echo something the
            // document actually says.
            let filler = candidates.filter { item in
                guard !isOnTopic(item), case .short(let video) = item else { return false }
                return preferredChannelIDs.contains(video.channelID)
                    && material.looselyMatches(Self.searchText(item))
            }
            // Filler is capped per wave so the feed can't turn into a generic
            // subject feed the moment exact matches run out.
            candidates = onTopic + filler.shuffled().prefix(max(0, 3 - onTopic.count))
        }

        return candidates.sorted { lhs, rhs in
            score(lhs, store: store, boosted: boosted) > score(rhs, store: store, boosted: boosted)
        }
    }

    /// Everything about an item a keyword could reasonably match against.
    private static func searchText(_ item: FeedItem) -> String {
        switch item {
        case .short(let video):
            return "\(video.title) \(video.channelName) \(video.cleanSummary)"
        case .episode(let episode):
            return "\(episode.title) \(episode.showTitle) \(episode.cleanSummary)"
        }
    }

    private func score(_ item: FeedItem, store: Store, boosted: Set<String>) -> Double {
        var value = 0.0

        // In a focused feed, topical fit dominates everything else.
        if let material = source.material {
            value += material.relevance(of: Self.searchText(item)) * 6
            if material.matchesSource(item.sourceName) { value += 8 }
        }

        // Recency, decaying over roughly a year.
        let ageDays = max(0, Date.now.timeIntervalSince(item.published) / 86_400)
        value += max(0, 1 - ageDays / 365) * 2

        // Popularity, compressed so a viral clip can't dominate.
        if case .short(let video) = item, video.views > 0 {
            value += min(2, log10(Double(video.views)) / 3)
        }

        if boosted.contains(item.sourceName) { value += 1.5 }
        if store.seenIDs.contains(item.id) { value -= 4 }

        // Small jitter so repeat sessions don't replay an identical order.
        value += Double.random(in: 0...0.5)
        return value
    }

    @discardableResult
    private func append(_ candidates: [FeedItem]) -> Int {
        let fresh = candidates.filter { presentIDs.insert($0.id).inserted }
        guard !fresh.isEmpty else { return 0 }
        items += fresh
        corpus += fresh
        return fresh.count
    }

    /// Once every source is spent, keep the scroll alive by replaying the
    /// corpus in a new order with unseen items promoted.
    private func recycle() -> Int {
        guard !corpus.isEmpty, let store else { return 0 }
        recycled = true

        let unseen = corpus.filter { !store.seenIDs.contains($0.id) }.shuffled()
        let rest = corpus.filter { store.seenIDs.contains($0.id) }.shuffled()
        let next = Array((unseen + rest).prefix(40))

        guard !next.isEmpty else { return 0 }
        items += next
        return next.count
    }
}
