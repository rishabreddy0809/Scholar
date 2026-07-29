//
//  Models.swift
//  Scholar
//

import Foundation

// MARK: - Shorts

nonisolated struct ShortVideo: Identifiable, Hashable, Codable, Sendable {
    let id: String              // YouTube video ID
    let title: String
    let channelID: String
    let channelName: String
    let published: Date
    let thumbnailURL: URL?
    let summary: String
    let views: Int

    var watchURL: URL? { URL(string: "https://www.youtube.com/shorts/\(id)") }

    /// Descriptions are stuffed with sponsor blocks and link dumps. Keep only
    /// the leading prose, which is where the actual explanation lives.
    var cleanSummary: String {
        let stopMarkers = ["Sources", "SOURCES", "OUR CHANNELS", "Follow us", "▀▀▀",
                           "Subscribe", "SUBSCRIBE", "http", "#"]
        var text = summary
        for marker in stopMarkers {
            if let range = text.range(of: marker) { text = String(text[..<range.lowerBound]) }
        }
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
    }
}

// MARK: - Podcasts

nonisolated struct PodcastShow: Identifiable, Hashable, Codable, Sendable {
    let id: Int                 // iTunes collectionId
    let title: String
    let author: String
    let feedURL: URL
    let artworkURL: URL?
    let genres: [String]
}

nonisolated struct PodcastEpisode: Identifiable, Hashable, Codable, Sendable {
    let id: String              // guid, or audio URL as a fallback
    let title: String
    let showID: Int
    let showTitle: String
    /// Kept so any episode can open its show's full back catalogue.
    let showFeedURL: URL?
    let audioURL: URL
    let artworkURL: URL?
    let published: Date
    let duration: TimeInterval
    let summary: String

    var durationLabel: String {
        guard duration > 0 else { return "—" }
        let minutes = Int(duration) / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    var cleanSummary: String {
        summary
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Unified feed item

/// One card in an endless feed. Shorts and podcast episodes share a feed so a
/// single scroll can mix watching and listening.
nonisolated enum FeedItem: Identifiable, Hashable, Codable, Sendable {
    case short(ShortVideo)
    case episode(PodcastEpisode)

    var id: String {
        switch self {
        case .short(let v):   return "yt:\(v.id)"
        case .episode(let e): return "pod:\(e.id)"
        }
    }

    var title: String {
        switch self {
        case .short(let v):   return v.title
        case .episode(let e): return e.title
        }
    }

    var sourceName: String {
        switch self {
        case .short(let v):   return v.channelName
        case .episode(let e): return e.showTitle
        }
    }

    var artworkURL: URL? {
        switch self {
        case .short(let v):   return v.thumbnailURL
        case .episode(let e): return e.artworkURL
        }
    }

    var published: Date {
        switch self {
        case .short(let v):   return v.published
        case .episode(let e): return e.published
        }
    }

    var isShort: Bool { if case .short = self { return true }; return false }

    /// Show trailers and "welcome to the podcast" stings are usually under two
    /// minutes and teach nothing, so they never belong in a study feed.
    var isTrailer: Bool {
        guard case .episode(let episode) = self else { return false }
        if episode.duration > 0, episode.duration < 120 { return true }
        let title = episode.title.lowercased()
        return title.contains("(trailer)") || title.hasSuffix("trailer")
            || title.hasPrefix("welcome to")
    }
}

// MARK: - Persisted engagement

nonisolated enum Vote: Int, Codable, Sendable {
    case none = 0, up = 1, down = -1
}

/// A feed the user built themselves from a topic or a pasted link.
nonisolated struct GeneratedFeed: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var query: String
    var channelIDs: [String]
    var podcastIDs: [Int]
    var createdAt: Date
    var itemsSeen: Int
    /// Rough target for the progress bar, so a feed can read as "42% complete".
    var estimatedTotal: Int

    var progress: Double {
        guard estimatedTotal > 0 else { return 0 }
        return min(1, Double(itemsSeen) / Double(estimatedTotal))
    }

    init(id: UUID = UUID(), title: String, query: String, channelIDs: [String],
         podcastIDs: [Int], createdAt: Date = .now, itemsSeen: Int = 0,
         estimatedTotal: Int = 60) {
        self.id = id
        self.title = title
        self.query = query
        self.channelIDs = channelIDs
        self.podcastIDs = podcastIDs
        self.createdAt = createdAt
        self.itemsSeen = itemsSeen
        self.estimatedTotal = estimatedTotal
    }
}
