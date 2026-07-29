//
//  PodcastAPI.swift
//  Scholar
//
//  Podcast discovery runs on the public iTunes Search directory (real
//  full-text search, no key) and episodes come from each show's own RSS feed.
//

import Foundation

// MARK: - Directory search

private nonisolated struct iTunesResponse: Decodable {
    let results: [Result]

    struct Result: Decodable {
        let collectionId: Int?
        let collectionName: String?
        let artistName: String?
        let feedUrl: String?
        let artworkUrl600: String?
        let artworkUrl100: String?
        let genres: [String]?
    }
}

// MARK: - Episode RSS parsing

private nonisolated final class PodcastRSSParser: NSObject, XMLParserDelegate {
    private var episodes: [PodcastEpisode] = []
    private var inItem = false
    private var buffer = ""

    private var title = ""
    private var guid = ""
    private var pubDate = ""
    private var summary = ""
    private var durationText = ""
    private var audioURL: URL?
    private var episodeArtwork: URL?
    private var showArtwork: URL?

    private let showID: Int
    private let showTitle: String
    private let showFeedURL: URL?
    private let fallbackArtwork: URL?

    init(showID: Int, showTitle: String, showFeedURL: URL?, fallbackArtwork: URL?) {
        self.showID = showID
        self.showTitle = showTitle
        self.showFeedURL = showFeedURL
        self.fallbackArtwork = fallbackArtwork
    }

    private static let dateFormatters: [DateFormatter] = {
        ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd MMM yyyy HH:mm Z"]
            .map { format in
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = format
                return f
            }
    }()

    func parse(_ data: Data, limit: Int) -> [PodcastEpisode] {
        episodes.removeAll()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.delegate = self
        parser.parse()
        return Array(episodes.prefix(limit))
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        buffer = ""
        switch elementName {
        case "item":
            inItem = true
            title = ""; guid = ""; pubDate = ""; summary = ""
            durationText = ""; audioURL = nil; episodeArtwork = nil
        case "enclosure":
            if let urlString = attributeDict["url"],
               (attributeDict["type"] ?? "audio").contains("audio") {
                audioURL = Self.secure(urlString)
            }
        case "itunes:image":
            if let href = attributeDict["href"], let url = Self.secure(href) {
                if inItem { episodeArtwork = url } else if showArtwork == nil { showArtwork = url }
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { buffer += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        buffer += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if inItem {
            switch elementName {
            case "title":            if title.isEmpty { title = text }
            case "guid":             guid = text
            case "pubDate":          pubDate = text
            case "itunes:duration":  durationText = text
            case "description":      if summary.isEmpty { summary = text }
            case "itunes:summary":   if summary.isEmpty { summary = text }
            case "item":
                inItem = false
                if let audioURL, !title.isEmpty {
                    episodes.append(
                        PodcastEpisode(
                            id: guid.isEmpty ? audioURL.absoluteString : guid,
                            title: text.isEmpty ? title : title,
                            showID: showID,
                            showTitle: showTitle,
                            showFeedURL: showFeedURL,
                            audioURL: audioURL,
                            artworkURL: episodeArtwork ?? showArtwork ?? fallbackArtwork,
                            published: Self.parseDate(pubDate),
                            duration: Self.parseDuration(durationText),
                            summary: summary
                        )
                    )
                }
            default: break
            }
        }
        buffer = ""
    }

    /// Plenty of feeds still advertise `http` enclosures, which App Transport
    /// Security blocks outright. Every major podcast host serves the same path
    /// over TLS, so upgrade rather than punching a hole in ATS.
    private static func secure(_ raw: String) -> URL? {
        guard var components = URLComponents(string: raw) else { return nil }
        if components.scheme?.lowercased() == "http" { components.scheme = "https" }
        return components.url
    }

    private static func parseDate(_ raw: String) -> Date {
        for formatter in dateFormatters {
            if let date = formatter.date(from: raw) { return date }
        }
        return .distantPast
    }

    /// iTunes durations arrive as raw seconds, "MM:SS", or "HH:MM:SS".
    private static func parseDuration(_ raw: String) -> TimeInterval {
        guard !raw.isEmpty else { return 0 }
        let parts = raw.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 1: return parts[0]
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return 0
        }
    }
}

// MARK: - Service

actor PodcastService {
    static let shared = PodcastService()

    private var showCache: [String: (fetched: Date, shows: [PodcastShow])] = [:]
    private var episodeCache: [Int: (fetched: Date, episodes: [PodcastEpisode])] = [:]
    private let ttl: TimeInterval = 60 * 60

    /// Real full-text search against the Apple podcast directory.
    func searchShows(_ term: String, limit: Int = 12) async -> [PodcastShow] {
        let key = "\(term.lowercased())|\(limit)"
        if let cached = showCache[key], Date.now.timeIntervalSince(cached.fetched) < ttl {
            return cached.shows
        }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            .init(name: "media", value: "podcast"),
            .init(name: "term", value: term),
            .init(name: "limit", value: String(limit))
        ]
        guard let url = components.url else { return [] }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(iTunesResponse.self, from: data)

            let shows: [PodcastShow] = decoded.results.compactMap { result in
                guard let id = result.collectionId,
                      let name = result.collectionName,
                      let feed = result.feedUrl.flatMap(URL.init(string:))
                else { return nil }
                return PodcastShow(
                    id: id,
                    title: name,
                    author: result.artistName ?? "",
                    feedURL: feed,
                    artworkURL: (result.artworkUrl600 ?? result.artworkUrl100).flatMap(URL.init(string:)),
                    genres: result.genres ?? []
                )
            }
            showCache[key] = (.now, shows)
            return shows
        } catch {
            return []
        }
    }

    func episodes(for show: PodcastShow, limit: Int = 20) async -> [PodcastEpisode] {
        if let cached = episodeCache[show.id], Date.now.timeIntervalSince(cached.fetched) < ttl {
            return Array(cached.episodes.prefix(limit))
        }
        var request = URLRequest(url: show.feedURL)
        request.timeoutInterval = 20
        request.setValue("Scholar/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return [] }
        let parser = PodcastRSSParser(showID: show.id, showTitle: show.title,
                                      showFeedURL: show.feedURL, fallbackArtwork: show.artworkURL)
        let parsed = parser.parse(data, limit: 500)
        if !parsed.isEmpty { episodeCache[show.id] = (.now, parsed) }
        return Array(parsed.prefix(limit))
    }

    /// Grouped by show so callers can interleave and avoid runs from one feed.
    func episodes(forShows shows: [PodcastShow], perShow: Int = 8) async -> [[PodcastEpisode]] {
        await withTaskGroup(of: [PodcastEpisode].self) { group in
            for show in shows {
                group.addTask { await self.episodes(for: show, limit: perShow) }
            }
            var results: [[PodcastEpisode]] = []
            for await batch in group where !batch.isEmpty { results.append(batch) }
            return results
        }
    }

    /// Resolve a pasted RSS URL into a show without going through the directory.
    func show(fromFeedURL url: URL) async -> PodcastShow? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let xml = String(data: data, encoding: .utf8) else { return nil }

        func tag(_ name: String) -> String? {
            guard let open = xml.range(of: "<\(name)>"),
                  let close = xml.range(of: "</\(name)>", range: open.upperBound..<xml.endIndex)
            else { return nil }
            return String(xml[open.upperBound..<close.lowerBound])
                .replacingOccurrences(of: "<![CDATA[", with: "")
                .replacingOccurrences(of: "]]>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let title = tag("title") else { return nil }
        var artwork: URL?
        if let range = xml.range(of: "<itunes:image href=\"[^\"]+\"", options: .regularExpression) {
            let fragment = String(xml[range])
            if let start = fragment.range(of: "\""),
               let end = fragment.range(of: "\"", range: start.upperBound..<fragment.endIndex) {
                artwork = URL(string: String(fragment[start.upperBound..<end.lowerBound]))
            }
        }
        return PodcastShow(id: abs(url.absoluteString.hashValue), title: title,
                           author: tag("itunes:author") ?? "", feedURL: url,
                           artworkURL: artwork, genres: [])
    }
}
