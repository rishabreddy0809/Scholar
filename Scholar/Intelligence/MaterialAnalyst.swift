//
//  MaterialAnalyst.swift
//  Scholar
//
//  Reads a study document with the on-device foundation model and improves what
//  the deterministic extractor already worked out: a better title, a real
//  summary, the right subjects, and — most usefully — the concepts the document
//  is *about* rather than only the words it happens to contain.
//
//  That last one is the point. Keyword matching can only recognise content that
//  echoes the document's own vocabulary, so notes on training models locally
//  never matched a clip called "Running Llama 3 on an M3 Max": the notes say
//  neither "Llama" nor "M3". The model supplies those adjacent names, they join
//  the keyword list, and the existing fast matcher does the rest. One model call
//  per document, at import — nothing runs while the user is scrolling.
//
//  Everything the model produces is validated against the catalogue before it is
//  used. It can suggest, never invent.
//

import Foundation
import FoundationModels

// MARK: - Generated shapes

@Generable
nonisolated struct DocumentAnalysis {
    @Guide(description: "The subject of the document in two to six words, phrased as a textbook chapter heading. Never include the words notes, revision, lecture, chapter or summary.")
    var title: String

    @Guide(description: "One plain sentence describing what a student would learn from this document.")
    var summary: String

    @Guide(description: "The single subject id this document belongs to, taken only from the supplied list. Add a second only if the document genuinely spans both, most important first. Return an empty list rather than guessing.", .maximumCount(2))
    var subjects: [String]

    @Guide(description: "Specific concepts, technologies, people and technical terms belonging to this topic. Include well-known names the document itself never mentions — the tools, models, hardware, systems or people any teacher of this material would bring up — because those are the words videos about it are titled with.", .count(6...14))
    var concepts: [String]

    @Guide(description: "Phrases to search a video and podcast library with to find teaching about this material. Each must be specific enough to make sense on its own, with no single bare words.", .count(3...5))
    var searchPhrases: [String]
}

@Generable
nonisolated struct TopicExpansion {
    @Guide(description: "Subject ids this topic belongs to, most important first, taken only from the supplied list. Return an empty list rather than guessing.", .maximumCount(3))
    var subjects: [String]

    @Guide(description: "Phrases to search a video and podcast library with for this topic.", .count(2...4))
    var searchPhrases: [String]
}

// MARK: - Analyst

nonisolated enum MaterialAnalyst {

    /// Bumped when the prompt or the shape above changes enough that stored
    /// materials are worth re-reading. Mirrors `KeywordExtractor.version`.
    static let version = 1

    /// The model gets a document's first few thousand characters. The context
    /// window is small, and the opening of a set of notes is overwhelmingly
    /// where the subject is stated; the extractor's own terms are passed
    /// alongside to stand in for the rest.
    private static let excerptBudget = 2_500

    // MARK: Documents

    /// Returns the material unchanged when the model is unavailable, refuses,
    /// or produces nothing usable. Never throws: enrichment is a bonus, and a
    /// failed one must not fail an import.
    static func enrich(_ material: StudyMaterial) async -> StudyMaterial {
        guard Intelligence.isReady else { return material }
        guard let analysis = await analyse(material) else { return material }
        return apply(analysis, to: material)
    }

    private static func analyse(_ material: StudyMaterial) async -> DocumentAnalysis? {
        let session = LanguageModelSession(instructions: documentInstructions)
        let prompt = """
        Analyse this study material.

        Working title: \(material.title)
        Terms found by the keyword extractor: \(material.keywords.prefix(10).map(\.term).joined(separator: ", "))

        Text:
        \(material.excerpt.prefix(excerptBudget))
        """

        do {
            // Low temperature: this is a classification, not a piece of writing,
            // and the same document should read the same way every time.
            let response = try await session.respond(
                to: prompt,
                generating: DocumentAnalysis.self,
                options: GenerationOptions(temperature: 0.2)
            )
            return response.content
        } catch {
            log(error, during: "document analysis")
            return nil
        }
    }

    private static func apply(_ analysis: DocumentAnalysis,
                              to material: StudyMaterial) -> StudyMaterial {
        var updated = material
        updated.analystVersion = version

        // A title only wins if it looks like a title. The extractor's version
        // came from the document's own first line, which is a decent floor.
        let title = analysis.title.trimmed
        if title.count >= 4, title.count <= 70, title.rangeOfCharacter(from: .letters) != nil {
            updated.title = title
        }

        if let summary = tidySummary(analysis.summary) { updated.summary = summary }

        // Subjects are resolved against the catalogue, so a hallucinated one
        // simply disappears. An empty result leaves the extractor's answer in
        // place rather than clearing the tags.
        let subjects = agreedSubjects(analysis.subjects, extractor: material.interestIDs)
        if !subjects.isEmpty { updated.interestIDs = subjects.map(\.id) }

        updated.keywords = mergedKeywords(analysis.concepts, into: material)

        let phrases = usablePhrases(analysis.searchPhrases)
        if !phrases.isEmpty {
            // The title still leads: it is the one description of the document
            // that came from the document itself.
            var queries = [updated.title.trimmed].filter { $0.split(separator: " ").count >= 2 }
            queries += phrases
            var seen = Set<String>()
            updated.searchQueries = Array(queries.filter { seen.insert($0.lowercased()).inserted }.prefix(5))
        }

        return updated
    }

    /// Model concepts join the keyword list, ranked just under the document's
    /// own title but above the extractor's single words — they are the terms
    /// most likely to appear in the title of something worth watching.
    private static func mergedKeywords(_ concepts: [String],
                                       into material: StudyMaterial) -> [Keyword] {
        let titleTerm = material.title.lowercased().trimmed
        let leading = material.keywords.filter { $0.term == titleTerm }
        let rest = material.keywords.filter { $0.term != titleTerm }

        var seen = Set(material.keywords.map(\.term))
        var added: [Keyword] = []
        for concept in concepts {
            let term = concept.trimmed.lowercased()
            guard term.count >= 4, term.count <= 48,
                  term.rangeOfCharacter(from: .letters) != nil,
                  seen.insert(term).inserted
            else { continue }
            added.append(Keyword(term: term, weight: 0.85))
        }

        return Array((leading + added + rest).prefix(40))
    }

    // MARK: Typed topics

    /// Used by the Generate flow, where the input is a few typed words rather
    /// than a document. `nil` means "fall back to catalogue matching".
    static func expand(topic: String) async -> (subjects: [Interest], phrases: [String])? {
        guard Intelligence.isReady else { return nil }
        let trimmed = topic.trimmed
        guard trimmed.count >= 2, trimmed.count <= 200 else { return nil }

        let session = LanguageModelSession(instructions: topicInstructions)
        do {
            let response = try await session.respond(
                to: "Topic: \(trimmed)",
                generating: TopicExpansion.self,
                options: GenerationOptions(temperature: 0.2)
            )
            let subjects = resolveSubjects(response.content.subjects)
            let phrases = usablePhrases(response.content.searchPhrases)
            guard !subjects.isEmpty || !phrases.isEmpty else { return nil }
            return (subjects, phrases)
        } catch {
            log(error, during: "topic expansion")
            return nil
        }
    }

    // MARK: Shared

    /// The subjects the model is allowed to choose from.
    ///
    /// Curiosities and Big Ideas are excluded for the same reason they carry no
    /// anchors in the catalogue: they are the generalist fallback, not a verdict
    /// about what a document is about.
    private static var classifiableSubjects: [Interest] {
        Interest.all.filter { !$0.anchors.isEmpty }
    }

    private static var subjectList: String {
        classifiableSubjects.map { "\($0.id) — \($0.name)" }.joined(separator: "\n")
    }

    private static let strictnessRule = """
        Judge a document by what it is teaching, not by which words it contains. \
        Notes on training machine learning models are about artificial intelligence, \
        not about the brain, however often they say "neural", "memory" or "learning". \
        Notes about the economy of an empire are history, not economics. When two \
        subjects both seem to fit, choose the one the document would be shelved under.

        Only name a subject the material is genuinely, substantially about. An empty \
        list is the correct answer for anything that is not study material, and a \
        wrong subject is much worse than none.
        """

    private static var documentInstructions: String {
        """
        You classify study material for a learning app that builds a video and \
        podcast feed around whatever a student has to revise.

        \(strictnessRule)

        Choose subjects only from this list, copying the id exactly as written:
        \(subjectList)
        """
    }

    private static var topicInstructions: String {
        """
        A student has typed a topic they want to learn about. Work out which \
        subjects it belongs to and how to search for teaching about it.

        \(strictnessRule)

        Choose subjects only from this list, copying the id exactly as written:
        \(subjectList)
        """
    }

    /// Combines the model's opinion with the extractor's. The model may narrow
    /// the answer or break a tie; it may never widen one.
    ///
    /// Both directions of this were observed on real notes. Left alone the
    /// model is generous — training models on a Mac came back as AI & Tech
    /// *and* Engineering, and that second tag puts an entire unrelated channel
    /// list behind a study feed. Trusting it outright is worse still: it
    /// re-filed a set of synaptic transmission notes from Neuroscience to
    /// Biology, which is defensible in a viva and useless in a feed.
    ///
    /// So the extractor's hard anchor evidence wins any outright disagreement,
    /// and the model's contribution is to pick from what the extractor already
    /// believes — or to answer at all when the extractor found nothing.
    private static func agreedSubjects(_ raw: [String], extractor: [String]) -> [Interest] {
        let resolved = resolveSubjects(raw)

        // Nothing recognised by the catalogue: this is the model's to call,
        // and one subject is as far as its unaided word goes.
        guard !extractor.isEmpty else {
            return Array(resolved.prefix(1))
        }

        // Where they agree, the model's ordering wins — it is better than the
        // extractor at knowing which of two real subjects leads.
        let agreed = resolved.filter { extractor.contains($0.id) }
        guard agreed.isEmpty else { return Array(agreed.prefix(2)) }

        // Flat disagreement. The extractor only ever speaks when it matched
        // anchor terms that mean one subject and nothing else, so it keeps it.
        return []
    }

    /// Summaries are shown on a card, so they must not stop mid-word.
    private static func tidySummary(_ raw: String) -> String? {
        let cleaned = raw.trimmed
        guard cleaned.count >= 12 else { return nil }
        guard cleaned.count > 240 else { return cleaned }

        let window = String(cleaned.prefix(240))
        if let stop = window.lastIndex(of: "."), window.distance(from: window.startIndex, to: stop) > 80 {
            return String(window[...stop])
        }
        if let space = window.lastIndex(of: " ") {
            return String(window[..<space]) + "…"
        }
        return window + "…"
    }

    /// Catalogue lookup, tolerant of the model answering with a display name
    /// ("AI & Tech") where an id was asked for ("ai-tech").
    private static func resolveSubjects(_ raw: [String]) -> [Interest] {
        var seen = Set<String>()
        return raw.compactMap { candidate -> Interest? in
            let cleaned = candidate.trimmed.lowercased()
            guard !cleaned.isEmpty else { return nil }
            let match = Interest.find(cleaned)
                ?? classifiableSubjects.first { $0.name.lowercased() == cleaned }
            guard let match, !match.anchors.isEmpty else { return nil }
            return seen.insert(match.id).inserted ? match : nil
        }
    }

    /// A single bare word is not a search phrase — "army" returns
    /// military-career shows when the material is about the American Revolution.
    private static func usablePhrases(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw.compactMap { phrase -> String? in
            let cleaned = phrase.trimmed
            guard cleaned.split(separator: " ").count >= 2, cleaned.count <= 70 else { return nil }
            return seen.insert(cleaned.lowercased()).inserted ? cleaned : nil
        }
    }

    private static func log(_ error: Error, during stage: String) {
        #if DEBUG
        if let generation = error as? LanguageModelSession.GenerationError {
            print("[Scholar.Intelligence] \(stage) failed: \(generation.localizedDescription)")
        } else {
            print("[Scholar.Intelligence] \(stage) failed: \(error)")
        }
        #endif
    }
}

private extension String {
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
