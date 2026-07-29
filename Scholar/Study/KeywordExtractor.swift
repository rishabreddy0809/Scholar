//
//  KeywordExtractor.swift
//  Scholar
//
//  Turns raw document text into weighted search terms using Apple's
//  NaturalLanguage framework — lemmatisation, stop-word removal and named
//  entity detection. Runs on device, costs nothing, works offline.
//

import Foundation
import NaturalLanguage

nonisolated enum KeywordExtractor {

    /// Bumped whenever extraction changes in a way that would produce better
    /// keywords. Materials stamped with an older version are re-derived from
    /// their stored text rather than left with stale, weaker topics.
    static let version = 5

    /// Terms that carry no topical signal. Academic filler ("chapter",
    /// "figure", "lecture") is included because study material is full of it.
    private static let stopWords: Set<String> = [
        "the","a","an","and","or","but","if","then","than","that","this","these","those",
        "is","are","was","were","be","been","being","am","do","does","did","doing","have",
        "has","had","having","will","would","shall","should","can","could","may","might",
        "must","of","in","on","at","to","for","with","by","from","as","into","about",
        "over","under","between","through","during","before","after","above","below","up",
        "down","out","off","again","further","once","here","there","when","where","why",
        "how","all","any","both","each","few","more","most","other","some","such","no",
        "nor","not","only","own","same","so","too","very","just","also","its","it","he",
        "she","they","them","his","her","their","our","your","you","we","us","i","me","my",
        "who","whom","which","what","because","while","chapter","figure","table","page",
        "lecture","note","notes","example","exercise","problem","question","answer",
        "section","part","unit","week","introduction","summary","conclusion","overview",
        "one","two","three","four","five","first","second","third","next","last","new",
        "use","used","using","see","given","let","thus","hence","therefore","however",
        "based","following","above","shown","note","fig","eq","et","al","etc","ie","eg"
    ]

    /// Extracts weighted terms, strongest first.
    static func keywords(from text: String, limit: Int = 24) -> [Keyword] {
        let trimmed = String(text.prefix(60_000))    // plenty for a long PDF
        guard !trimmed.isEmpty else { return [] }

        var counts: [String: Double] = [:]

        // Single lemmatised words.
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = trimmed
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]

        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex,
                             unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            // Only nouns and adjectives carry topic meaning.
            guard let tag, tag == .noun || tag == .adjective || tag == .otherWord else { return true }

            let raw = String(trimmed[range]).lowercased()
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue.lowercased()
            let term = (lemma?.isEmpty == false ? lemma! : raw)

            guard isUsable(term) else { return true }
            counts[term, default: 0] += 1
            return true
        }

        // Named entities are strong topical anchors ("Napoleon", "Krebs").
        let entityTagger = NLTagger(tagSchemes: [.nameType])
        entityTagger.string = trimmed
        entityTagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex,
                                   unit: .word, scheme: .nameType, options: options) { tag, range in
            guard let tag,
                  tag == .personalName || tag == .placeName || tag == .organizationName
            else { return true }
            let term = String(trimmed[range]).lowercased()
            guard isUsable(term) else { return true }
            counts[term, default: 0] += 3
            return true
        }

        // Repeated two-word phrases beat single words for precision
        // ("cell membrane" is a better query than "cell").
        for (phrase, count) in bigrams(in: trimmed) where count >= 3 {
            counts[phrase, default: 0] += Double(count) * 1.6
        }

        // Capitalised multi-word phrases are the actual subjects of study
        // material — "American Revolution", "Boston Tea Party", "Declaration
        // of Independence". Weighted hard, because a bag of single words turns
        // a document about the American Revolution into a search for "army".
        for (phrase, count) in properPhrases(in: trimmed) {
            counts[phrase, default: 0] += Double(count) * 5 + 4
        }

        guard let maximum = counts.values.max(), maximum > 0 else { return [] }

        return counts
            .filter { $0.value >= 2 }             // drop one-off noise
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .prefix(limit)
            .map { Keyword(term: $0.key, weight: $0.value / maximum) }
    }

    private static func isUsable(_ term: String) -> Bool {
        guard term.count >= 4, term.count <= 32 else { return false }
        guard !stopWords.contains(term) else { return false }
        guard term.rangeOfCharacter(from: .letters) != nil else { return false }
        guard term.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
        return true
    }

    /// Words that may sit *inside* a proper phrase without breaking it, so
    /// "Declaration of Independence" survives as one topic.
    private static let phraseConnectors: Set<String> = ["of", "the", "and", "de", "for", "in"]

    /// Runs of capitalised words, keyed by their lowercased form.
    ///
    /// Capitalisation is the cheapest reliable signal for "this is a named
    /// topic" in study material, and it survives OCR far better than
    /// punctuation does.
    static func properPhrases(in text: String, limit: Int = 10) -> [String: Int] {
        var counts: [String: Int] = [:]

        for line in text.split(whereSeparator: \.isNewline) {
            let tokens = line.split { $0 == " " || $0 == "\t" }.map(String.init)
            var run: [String] = []
            var capitals = 0
            // A phrase can't be credited to the word that merely opens a
            // sentence, so the first token of each line is skipped as a seed.
            var index = 0

            func flush() {
                while let last = run.last, phraseConnectors.contains(last.lowercased()) {
                    run.removeLast()
                }
                if capitals >= 2, run.count >= 2 {
                    let phrase = run.joined(separator: " ").lowercased()
                    if phrase.count >= 8, phrase.count <= 40 { counts[phrase, default: 0] += 1 }
                }
                run.removeAll()
                capitals = 0
            }

            for token in tokens {
                defer { index += 1 }
                let bare = token.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                guard !bare.isEmpty else { flush(); continue }

                let isCapitalised = bare.first?.isUppercase == true
                    && bare.count >= 3
                    && !stopWords.contains(bare.lowercased())
                    && bare.rangeOfCharacter(from: .decimalDigits) == nil

                if isCapitalised {
                    run.append(bare)
                    capitals += 1
                } else if !run.isEmpty, phraseConnectors.contains(bare.lowercased()) {
                    run.append(bare)
                } else {
                    flush()
                }

                // A colon or full stop ends the topic. Without this, a heading
                // bleeds into the sentence after it and "Aftermath: the Treaty
                // of Paris" becomes one nonsense phrase.
                if token.last.map({ ":.,;!?".contains($0) }) == true { flush() }
            }
            flush()
        }

        return Dictionary(uniqueKeysWithValues:
            counts.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) })
    }

    private static func bigrams(in text: String) -> [String: Int] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            words.append(stopWords.contains(word) || word.count < 4 ? "" : word)
            return true
        }

        var result: [String: Int] = [:]
        for index in 0..<max(0, words.count - 1) {
            let left = words[index], right = words[index + 1]
            guard !left.isEmpty, !right.isEmpty else { continue }
            guard left.rangeOfCharacter(from: .decimalDigits) == nil,
                  right.rangeOfCharacter(from: .decimalDigits) == nil else { continue }
            result["\(left) \(right)", default: 0] += 1
        }
        return result
    }

    // MARK: - Mapping onto the catalogue

    /// Splits text into lowercased word tokens.
    ///
    /// Everything downstream matches on these rather than on raw substrings.
    /// Substring matching is what filed a document about training on-device
    /// models under Neuroscience: "neural" sits inside "neural network",
    /// "memory" inside "unified memory", and "ai" inside "training".
    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// One catalogue term, pre-split into the tokens it has to match.
    private struct CatalogTerm {
        let tokens: [String]
        let interestIndex: Int
        let isAnchor: Bool
    }

    /// A term token matches a document token exactly when it is short, and by
    /// prefix when it is long enough for the prefix to still be specific —
    /// so "behaviour" catches "behavioural" while "gene" never catches
    /// "general" and "ai" never catches "aircraft". The length ceiling stops
    /// a stem drifting into an unrelated longer word.
    private static func matches(term: String, token: String) -> Bool {
        guard term.count >= 6 else { return term == token }
        return token.count <= term.count + 4 && token.hasPrefix(term)
    }

    /// Whether a catalogue term is spoken by a tokenized piece of text, using
    /// the same word-boundary and stemming rules as subject matching.
    static func mentions(_ term: String, in tokens: [String]) -> Bool {
        let termTokens = tokenize(term)
        guard !termTokens.isEmpty, tokens.count >= termTokens.count else { return false }
        return (0...(tokens.count - termTokens.count)).contains { start in
            zip(termTokens, tokens[start...]).allSatisfy(matches(term:token:))
        }
    }

    /// Catalogue terms bucketed by the first four characters of their first
    /// token, so a document token only ever gets compared against the handful
    /// of terms that could plausibly start with it.
    private static let termBuckets: [String: [CatalogTerm]] = {
        var buckets: [String: [CatalogTerm]] = [:]
        for (index, interest) in Interest.all.enumerated() {
            for (terms, isAnchor) in [(interest.anchors, true), (interest.keywords, false)] {
                for term in terms {
                    let tokens = tokenize(term)
                    guard let first = tokens.first else { continue }
                    buckets[bucketKey(first), default: []]
                        .append(CatalogTerm(tokens: tokens, interestIndex: index, isAnchor: isAnchor))
                }
            }
        }
        return buckets
    }()

    private static let longestTerm: Int =
        termBuckets.values.flatMap { $0 }.map(\.tokens.count).max() ?? 1

    /// Prefix matching preserves the first six characters of a term, so four
    /// is a safe bucket width for both sides of the comparison.
    private static func bucketKey(_ token: String) -> String {
        token.count <= 4 ? token : String(token.prefix(4))
    }

    /// Picks the subject areas a document belongs to.
    ///
    /// Two rules do the real work. A subject has to be named by at least one
    /// of its *anchor* terms — the words that mean nothing else — before its
    /// shared vocabulary counts for anything; and when several terms cover the
    /// same span of text the longest one takes it outright, so "neural
    /// network" is credited to AI & Tech and Neuroscience never sees the word
    /// "neural" at all.
    ///
    /// Returns an empty list when nothing clears the bar. No tag is better
    /// than a wrong one: a wrong tag puts a whole subject's channels behind
    /// the study feed.
    static func matchingInterests(for keywords: [Keyword], in text: String,
                                  limit: Int = 2) -> [Interest] {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return [] }

        var anchorTerms: [Int: Set<String>] = [:]
        var anchorHits: [Int: Int] = [:]
        var supportTerms: [Int: Set<String>] = [:]

        var index = 0
        while index < tokens.count {
            let candidates = termBuckets[bucketKey(tokens[index])] ?? []
            var span = 1

            if !candidates.isEmpty {
                let reach = min(longestTerm, tokens.count - index)
                for length in stride(from: reach, through: 1, by: -1) {
                    let window = Array(tokens[index..<(index + length)])
                    let hits = candidates.filter { candidate in
                        candidate.tokens.count == length
                            && zip(candidate.tokens, window).allSatisfy(matches(term:token:))
                    }
                    guard !hits.isEmpty else { continue }

                    for hit in hits {
                        let term = hit.tokens.joined(separator: " ")
                        if hit.isAnchor {
                            anchorTerms[hit.interestIndex, default: []].insert(term)
                            anchorHits[hit.interestIndex, default: 0] += 1
                        } else {
                            supportTerms[hit.interestIndex, default: []].insert(term)
                        }
                    }
                    span = length
                    break
                }
            }
            index += span
        }

        let scored: [(Interest, Double)] = Interest.all.indices.compactMap { position in
            let distinct = anchorTerms[position]?.count ?? 0
            let occurrences = anchorHits[position] ?? 0
            guard distinct > 0 else { return nil }
            // One glancing mention of one anchor is a coincidence — a document
            // is allowed to say "brain" once without becoming neuroscience.
            guard distinct >= 2 || occurrences >= 3 else { return nil }

            // Breadth of distinct anchors dominates: three different anchors
            // is a far stronger signal than one anchor said thirty times.
            var score = Double(distinct * distinct) * 3
            score += min(Double(occurrences), 12)
            score += Double(min(supportTerms[position]?.count ?? 0, 6))
            return (Interest.all[position], score)
        }
        .sorted { $0.1 > $1.1 }

        guard let best = scored.first?.1 else { return [] }

        // Only subjects in the winner's league survive. A document is usually
        // about one thing, and every extra tag adds a channel's worth of
        // off-topic filler to the feed built from it.
        return Array(scored.filter { $0.1 >= best * 0.55 }.prefix(limit).map(\.0))
    }

    /// What actually gets sent to the podcast directory.
    ///
    /// The document's title and its named topics come first; a bare single
    /// word is only ever used paired with another, because searching for
    /// "army" returns military-career shows rather than the American
    /// Revolution.
    static func searchQueries(from keywords: [Keyword], title: String, limit: Int = 4) -> [String] {
        var queries: [String] = []

        // The title is usually the single best description of the material.
        let cleanedTitle = title.trimmingCharacters(in: .whitespaces)
        if cleanedTitle.split(separator: " ").count >= 2 { queries.append(cleanedTitle) }

        // Then the strongest named topics.
        queries += keywords.filter { $0.term.contains(" ") }.prefix(3).map(\.term)

        // Single words only ever go out paired, and only to top up.
        let singles = keywords.filter { !$0.term.contains(" ") }.map(\.term)
        if queries.count < 2, singles.count >= 2 {
            queries.append("\(singles[0]) \(singles[1])")
        }
        if queries.isEmpty { queries.append(cleanedTitle.isEmpty ? "study" : cleanedTitle) }

        var seen = Set<String>()
        return Array(queries.filter { seen.insert($0.lowercased()).inserted }.prefix(limit))
    }

    /// Display name for the document, taken from its first meaningful line
    /// with the "— revision notes" scaffolding stripped off.
    static func inferTitle(from text: String, fallback: String) -> String {
        let line = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count >= 4 && $0.count <= 90 }

        guard let line, line.rangeOfCharacter(from: .letters) != nil else { return fallback }

        // "The American Revolution — study notes" → "American Revolution"
        var cleaned = line
        for separator in ["—", "–", " - ", ":", "|"] {
            if let range = cleaned.range(of: separator) {
                let head = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if head.split(separator: " ").count >= 2 { cleaned = head }
            }
        }

        // "What Was the American Revolution?" → "American Revolution"
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "?!."))
        for opener in ["what was the ", "what is the ", "what were the ", "what are the ",
                       "who was the ", "who were the ", "why did the ", "why was the ",
                       "how did the ", "how does the ", "an introduction to ",
                       "introduction to ", "a guide to ", "guide to ", "all about "] {
            if cleaned.lowercased().hasPrefix(opener) {
                cleaned = String(cleaned.dropFirst(opener.count))
                break
            }
        }

        let noise: Set<String> = ["notes", "note", "revision", "study", "lecture", "summary",
                                  "overview", "handout", "worksheet", "chapter", "outline"]
        var words = cleaned.split(separator: " ").map(String.init)
        while let last = words.last, noise.contains(last.lowercased()) { words.removeLast() }
        while let first = words.first, first.lowercased() == "the" || noise.contains(first.lowercased()) {
            words.removeFirst()
        }

        let result = words.joined(separator: " ")
        return result.count >= 4 ? String(result.prefix(60)) : String(cleaned.prefix(60))
    }
}
