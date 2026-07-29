//
//  YouTubeRSS.swift
//  Scholar
//
//  Reads YouTube's public Atom feeds. No API key and no quota ceiling, which
//  is why the whole app can run on a fresh install with nothing configured.
//

import Foundation

// MARK: - Atom parsing

private nonisolated final class YouTubeAtomParser: NSObject, XMLParserDelegate {
    private var entries: [ShortVideo] = []
    private var path: [String] = []

    private var videoID = ""
    private var channelID = ""
    private var title = ""
    private var author = ""
    private var publishedText = ""
    private var thumbnail: URL?
    private var summary = ""
    private var views = 0
    private var buffer = ""

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parse(_ data: Data) -> [ShortVideo] {
        entries.removeAll()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.delegate = self
        parser.parse()
        return entries
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        path.append(elementName)
        buffer = ""

        switch elementName {
        case "entry":
            videoID = ""; channelID = ""; title = ""; author = ""
            publishedText = ""; thumbnail = nil; summary = ""; views = 0
        case "media:thumbnail":
            if let urlString = attributeDict["url"] { thumbnail = URL(string: urlString) }
        case "media:statistics":
            views = Int(attributeDict["views"] ?? "") ?? 0
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        buffer += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let insideEntry = path.contains("entry")

        switch elementName {
        case "yt:videoId" where insideEntry:
            videoID = text
        case "yt:channelId" where insideEntry:
            channelID = text
        case "title" where insideEntry && title.isEmpty:
            title = text
        case "name" where insideEntry && author.isEmpty:
            author = text
        case "published" where insideEntry:
            publishedText = text
        case "media:description":
            summary = text
        case "entry":
            if !videoID.isEmpty {
                entries.append(
                    ShortVideo(
                        id: videoID,
                        title: title,
                        channelID: channelID,
                        channelName: author,
                        published: Self.formatter.date(from: publishedText) ?? .distantPast,
                        thumbnailURL: thumbnail,
                        summary: summary,
                        views: views
                    )
                )
            }
        default:
            break
        }

        buffer = ""
        if let last = path.last, last == elementName { path.removeLast() }
    }
}

// MARK: - Service

actor YouTubeRSSService {
    static let shared = YouTubeRSSService()

    private var cache: [String: (fetched: Date, videos: [ShortVideo])] = [:]
    private let ttl: TimeInterval = 60 * 30
    private var inFlight: [String: Task<[ShortVideo], Never>] = [:]

    /// Shorts for one channel. Falls back to the uploads feed when a channel
    /// has no Shorts shelf, so channels added by link still produce something.
    /// Concurrent callers for the same channel share one request.
    func shorts(for channel: EduChannel) async -> [ShortVideo] {
        if let cached = cached(channel.id) { return cached }
        if let existing = inFlight[channel.id] { return await existing.value }

        let task = Task<[ShortVideo], Never> {
            var videos: [ShortVideo] = []
            if let url = channel.shortsFeedURL {
                videos = await Self.load(url)
            }
            if videos.isEmpty, let fallback = channel.uploadsFeedURL {
                videos = await Self.load(fallback)
            }
            return videos
        }
        inFlight[channel.id] = task

        let videos = await task.value
        inFlight[channel.id] = nil
        store(channel.id, videos)
        return videos
    }

    /// Fetches many channels concurrently and returns them grouped, so the
    /// caller can interleave rather than dumping one channel at a time.
    func shorts(for channels: [EduChannel]) async -> [[ShortVideo]] {
        await withTaskGroup(of: [ShortVideo].self) { group in
            for channel in channels {
                group.addTask { await self.shorts(for: channel) }
            }
            var results: [[ShortVideo]] = []
            for await batch in group where !batch.isEmpty { results.append(batch) }
            return results
        }
    }

    private func cached(_ key: String) -> [ShortVideo]? {
        guard let entry = cache[key], Date.now.timeIntervalSince(entry.fetched) < ttl else { return nil }
        return entry.videos
    }

    private func store(_ key: String, _ videos: [ShortVideo]) {
        guard !videos.isEmpty else { return }
        cache[key] = (.now, videos)
    }

    private static func load(_ url: URL) async -> [ShortVideo] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Scholar/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            return YouTubeAtomParser().parse(data)
        } catch {
            return []
        }
    }
}

// MARK: - Adding a channel by link

nonisolated enum ChannelResolver {
    /// Accepts a channel URL, a @handle URL, or a bare @handle and returns the
    /// underlying "UC..." channel, which is what the Atom feeds are keyed on.
    static func resolve(_ input: String) async -> EduChannel? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Already a channel ID or a /channel/UC... URL.
        if let match = trimmed.range(of: "UC[A-Za-z0-9_-]{22}", options: .regularExpression) {
            let id = String(trimmed[match])
            let name = await channelName(id: id) ?? "Channel"
            return EduChannel(id: id, name: name)
        }

        let handle: String
        if let range = trimmed.range(of: "@[A-Za-z0-9._-]+", options: .regularExpression) {
            handle = String(trimmed[range]).replacingOccurrences(of: "@", with: "")
        } else {
            handle = trimmed
        }

        guard let url = URL(string: "https://www.youtube.com/@\(handle)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8),
              let match = html.range(of: "UC[A-Za-z0-9_-]{22}", options: .regularExpression)
        else { return nil }

        let id = String(html[match])
        let name = await channelName(id: id) ?? handle
        return EduChannel(id: id, name: name)
    }

    private static func channelName(id: String) async -> String? {
        guard let url = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(id)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let xml = String(data: data, encoding: .utf8),
              let open = xml.range(of: "<name>"),
              let close = xml.range(of: "</name>", range: open.upperBound..<xml.endIndex)
        else { return nil }
        return String(xml[open.upperBound..<close.lowerBound])
    }
}
