//
//  GenerateFeedView.swift
//  Scholar
//
//  "Generate knowledge from any source" — here that means real sources rather
//  than synthesised text. A topic is matched against the channel catalogue and
//  searched against the podcast directory; a pasted link is resolved directly.
//

import SwiftUI

struct GenerateFeedView: View {
    var onCreated: (GeneratedFeed) -> Void

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var isWorking = false
    @State private var status: String?
    @State private var failure: String?

    private let suggestions = ["Roman Empire", "Quantum Physics", "Sustainable Development",
                               "Neuroscience", "Machine Learning", "Ancient Egypt",
                               "Behavioural Economics", "Climate Science"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    prompt
                    input
                    if let failure { errorBanner(failure) }
                    quickPicks
                    explainer
                }
                .padding(20)
            }
            .background(Theme.bg)
            .navigationTitle("Generate feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What do you want to learn?")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Name a topic, or paste a YouTube channel or podcast RSS link.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)
        }
    }

    private var input: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textFaint)
                TextField("", text: $query, prompt: Text("Roman Empire, or a link…")
                    .foregroundStyle(Theme.textFaint))
                    .foregroundStyle(Theme.text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit { Task { await generate() } }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .cardSurface(14)

            Button {
                Task { await generate() }
            } label: {
                HStack(spacing: 8) {
                    if isWorking {
                        ProgressView().tint(.white).controlSize(.small)
                        Text(status ?? "Working…")
                    } else {
                        Image(systemName: "bolt.fill")
                        Text("Generate feed")
                    }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    query.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.surfaceHi : Theme.accent,
                    in: .rect(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
            .disabled(isWorking || query.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(Theme.down)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.down.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    private var quickPicks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK SEARCH")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textFaint)
                .tracking(0.8)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    TagChip(text: suggestion, tint: Theme.accent) {
                        query = suggestion
                        Task { await generate() }
                    }
                }
            }
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Everything is real content", systemImage: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.up)
            Text("Shorts come from educational YouTube channels via the official embedded player. Episodes come from the Apple Podcasts directory and each show's own feed. Nothing is generated or re-hosted.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textDim)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(14)
    }

    // MARK: - Generation

    private func generate() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isWorking else { return }

        isWorking = true
        failure = nil
        defer { isWorking = false }

        // A pasted link short-circuits the topic path.
        if trimmed.contains("youtube.com") || trimmed.contains("youtu.be") || trimmed.hasPrefix("@") {
            status = "Resolving channel…"
            if let channel = await ChannelResolver.resolve(trimmed) {
                if !store.customChannels.contains(where: { $0.id == channel.id }) {
                    store.customChannels.append(channel)
                }
                finish(GeneratedFeed(title: channel.name, query: channel.name,
                                     channelIDs: [channel.id], podcastIDs: [],
                                     estimatedTotal: 30))
                return
            }
            failure = "Couldn't find that channel. Check the link and try again."
            return
        }

        if trimmed.lowercased().hasPrefix("http") {
            status = "Reading podcast feed…"
            if let url = URL(string: trimmed), let show = await PodcastService.shared.show(fromFeedURL: url) {
                finish(GeneratedFeed(title: show.title, query: show.title,
                                     channelIDs: [], podcastIDs: [show.id],
                                     estimatedTotal: 40))
                return
            }
            failure = "That link didn't return a readable podcast feed."
            return
        }

        // Topic path: match the catalogue for video, search the directory for audio.
        status = "Matching channels…"
        // The on-device model knows that "transformers" typed by someone
        // learning about AI is not electrical engineering. It only ever adds
        // subjects; catalogue matching still runs and still decides on its own
        // when the model is unavailable.
        let expansion = await MaterialAnalyst.expand(topic: trimmed)
        let matched = matchChannels(for: trimmed, preferring: expansion?.subjects ?? [])

        status = "Searching podcasts…"
        var shows = await PodcastService.shared.searchShows(trimmed, limit: 10)
        // A typed topic is often too terse for the directory ("attention
        // heads"). The model's phrasing is the second attempt, never the first:
        // what the user actually typed deserves to win when it works.
        if shows.isEmpty, let phrase = expansion?.phrases.first {
            shows = await PodcastService.shared.searchShows(phrase, limit: 10)
        }

        guard !matched.isEmpty || !shows.isEmpty else {
            failure = "Nothing found for “\(trimmed)”. Try a broader topic."
            return
        }

        finish(GeneratedFeed(
            title: trimmed,
            query: trimmed,
            channelIDs: matched.map(\.id),
            podcastIDs: shows.map(\.id),
            estimatedTotal: max(40, matched.count * 15)
        ))
    }

    /// Scores every interest against the typed text and takes the channels
    /// behind the best matches.
    private func matchChannels(for text: String, preferring suggested: [Interest] = []) -> [EduChannel] {
        let needle = text.lowercased()
        let tokens = KeywordExtractor.tokenize(text)
        let words = Set(tokens.filter { $0.count > 2 })
        let suggestedIDs = Set(suggested.map(\.id))

        let scored = Interest.all.map { interest -> (Interest, Int) in
            var score = 0
            // Weighted to outrank a keyword coincidence but not a subject the
            // user named outright, so "physics" still means Physics.
            if suggestedIDs.contains(interest.id) { score += 16 }
            if interest.name.lowercased().contains(needle) { score += 12 }
            for word in words where interest.name.lowercased().contains(word) { score += 6 }

            // Anchors decide the subject; the shared vocabulary only breaks
            // ties. Typing "neural networks" has to land on AI & Tech, and it
            // used to land on Neuroscience because "neural" was scored flat.
            for anchor in interest.anchors where KeywordExtractor.mentions(anchor, in: tokens) {
                score += anchor.contains(" ") ? 14 : 8
            }
            for keyword in interest.keywords where words.contains(keyword) { score += 2 }
            return (interest, score)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }

        // Only subjects in the winner's league contribute channels, so a
        // stray shared word can't attach a second, unrelated subject.
        let best = scored.first?.1 ?? 0
        let top = scored.filter { $0.1 >= max(6, best / 2) }.prefix(3).flatMap(\.0.channels)
        var seen = Set<String>()
        let unique = top.filter { seen.insert($0.id).inserted }

        // Nothing matched: fall back to the generalist channels so the feed
        // still has something on-topic-adjacent to show.
        return unique.isEmpty ? (Interest.find("curiosities")?.channels ?? []) : unique
    }

    private func finish(_ feed: GeneratedFeed) {
        store.addGeneratedFeed(feed)
        onCreated(feed)
        dismiss()
    }
}
