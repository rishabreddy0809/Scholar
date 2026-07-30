//
//  StudyMaterial.swift
//  Scholar
//
//  Something the user actually has to study — a lecture PDF, a photo of their
//  notes, a pasted syllabus. Everything derived from it is computed on device.
//

import Foundation

nonisolated struct Keyword: Codable, Hashable, Sendable {
    let term: String
    /// 0...1, relative to the strongest term in the same document.
    let weight: Double
}

nonisolated enum MaterialKind: String, Codable, Sendable {
    case pdf, image, text

    var symbol: String {
        switch self {
        case .pdf:   return "doc.text.fill"
        case .image: return "photo.fill"
        case .text:  return "text.alignleft"
        }
    }

    var label: String {
        switch self {
        case .pdf:   return "PDF"
        case .image: return "Scan"
        case .text:  return "Notes"
        }
    }
}

nonisolated struct StudyMaterial: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var kind: MaterialKind
    var createdAt: Date
    /// Trimmed extract, kept for the detail view and for re-deriving keywords.
    var excerpt: String
    var keywords: [Keyword]
    /// Interests whose vocabulary best matches this document.
    var interestIDs: [String]
    /// Phrases handed to the podcast directory as real search terms.
    var searchQueries: [String]
    var itemsStudied: Int
    var wordCount: Int
    /// Extractor build that produced the keywords above.
    ///
    /// Optional on purpose: Swift's synthesised decoder has no concept of a
    /// default for a missing key, so adding a non-optional field here would
    /// fail to decode every material saved before this build existed and
    /// silently wipe the user's library.
    var extractorVersion: Int?
    /// One sentence from the on-device model saying what this document teaches.
    /// Absent whenever Apple Intelligence wasn't available at import.
    var summary: String?
    /// Analyst build that last read this document, or `nil` if none has.
    /// Optional for the same decoding reason as `extractorVersion`.
    var analystVersion: Int?

    init(id: UUID = UUID(), title: String, kind: MaterialKind, createdAt: Date = .now,
         excerpt: String, keywords: [Keyword], interestIDs: [String],
         searchQueries: [String], itemsStudied: Int = 0, wordCount: Int,
         extractorVersion: Int? = KeywordExtractor.version,
         summary: String? = nil, analystVersion: Int? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.createdAt = createdAt
        self.excerpt = excerpt
        self.keywords = keywords
        self.interestIDs = interestIDs
        self.searchQueries = searchQueries
        self.itemsStudied = itemsStudied
        self.wordCount = wordCount
        self.extractorVersion = extractorVersion
        self.summary = summary
        self.analystVersion = analystVersion
    }

    var interests: [Interest] { interestIDs.compactMap(Interest.find) }

    var channels: [EduChannel] {
        var seen = Set<String>()
        return interests.flatMap(\.channels).filter { seen.insert($0.id).inserted }
    }

    /// Rough completion, so a material reads like a course with a progress bar.
    var progress: Double {
        min(1, Double(itemsStudied) / 40.0)
    }

    var topTerms: [String] { keywords.prefix(6).map(\.term) }

    /// True when the stored topics predate the current extractor.
    var needsRederive: Bool { (extractorVersion ?? 0) < KeywordExtractor.version }

    /// True when the on-device model has never read this document, or read it
    /// with an older prompt. Drives the catch-up pass on launch, so materials
    /// imported before Apple Intelligence was switched on still benefit.
    var needsAnalysis: Bool { (analystVersion ?? 0) < MaterialAnalyst.version }

    /// How well a piece of content matches this material, plus how many
    /// distinct concepts lined up.
    ///
    /// Matching is done on stems rather than whole words: the extractor emits
    /// lemmas ("mitochondrion", "respiration") while real titles use the
    /// inflected form ("mitochondria", "respiratory"), and an exact substring
    /// test misses every one of those.
    func score(of text: String) -> (total: Double, matches: Int, phrases: Int) {
        guard !keywords.isEmpty else { return (0, 0, 0) }
        let haystack = text.lowercased()

        var total = 0.0
        var matches = 0
        var phrases = 0
        for keyword in keywords where haystack.contains(Self.stem(keyword.term)) {
            // A named topic ("american revolution") is far stronger evidence
            // than a bare common word ("army"), which lands in long episode
            // descriptions by accident.
            let isPhrase = keyword.term.contains(" ")
            total += keyword.weight * (isPhrase ? 2.5 : 1)
            matches += 1
            if isPhrase { phrases += 1 }
        }
        return (total, matches, phrases)
    }

    func relevance(of text: String) -> Double { score(of: text).total }

    /// Whether a piece of content earns a place in this material's feed.
    ///
    /// The bar is deliberately high, and it is a bar on *evidence* rather than
    /// on the total alone: a single heavily-weighted common word could clear
    /// any threshold by itself, which is how a psychology short about memory
    /// got into a feed built from machine learning notes. Either the content
    /// names one of the document's actual topics, or it echoes at least two
    /// of its terms.
    func matches(_ text: String) -> Bool {
        let result = score(of: text)
        guard result.total >= 1.2 else { return false }
        return result.phrases >= 1 || result.matches >= 2
    }

    /// A weaker test used only to top up a feed that would otherwise be empty:
    /// some real overlap with the document, short of earning a place outright.
    func looselyMatches(_ text: String) -> Bool {
        let result = score(of: text)
        return result.total >= 0.5 && result.matches >= 1
    }

    /// Whether a whole channel or show is dedicated to this material's subject
    /// — "American Revolution Podcast" against American Revolution notes.
    ///
    /// This is the strongest signal available: when the source itself is on
    /// topic, its entire back catalogue is worth studying, and no per-episode
    /// keyword test comes close to being as reliable.
    func matchesSource(_ name: String) -> Bool {
        let haystack = name.lowercased()
        if haystack.contains(title.lowercased()), title.count >= 6 { return true }
        return keywords.contains { keyword in
            keyword.term.contains(" ") && haystack.contains(Self.stem(keyword.term))
        }
    }

    /// Full test for a feed item, preferring the source-level signal.
    func matches(text: String, source: String) -> Bool {
        matchesSource(source) || matches(text)
    }

    /// Long words are truncated to a stem; short ones must match in full so
    /// "atom" doesn't start matching "automatic".
    ///
    /// The stem keeps 70% of the word rather than a flat six characters,
    /// which was short enough to be actively wrong: "transformer" became
    /// "transf" and matched "transfer", "transfusion" and "transform".
    private static func stem(_ term: String) -> String {
        guard !term.contains(" ") else {
            return term.split(separator: " ").map { stem(String($0)) }.joined(separator: " ")
        }
        guard term.count >= 8 else { return term }
        return String(term.prefix(max(6, Int(Double(term.count) * 0.7))))
    }
}
