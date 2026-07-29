//
//  Store.swift
//  Scholar
//
//  All engagement lives on device: votes, saves, per-topic progress and the
//  daily streak. Nothing is uploaded and there is no account.
//

import Foundation
import Observation

@Observable
final class Store {
    // MARK: Persisted state

    var selectedInterestIDs: Set<String> = Interest.starterIDs { didSet { persist(\.selectedInterestIDs, "interests") } }
    var votes: [String: Vote] = [:]                { didSet { persist(\.votes, "votes") } }
    var sourceVotes: [String: Int] = [:]           { didSet { persist(\.sourceVotes, "sourceVotes") } }
    var saved: [FeedItem] = []                     { didSet { persist(\.saved, "saved") } }
    var seenIDs: Set<String> = []                  { didSet { persistThrottled(\.seenIDs, "seen") } }
    var interestProgress: [String: Int] = [:]      { didSet { persist(\.interestProgress, "progress") } }
    var studySecondsByDay: [String: Int] = [:]     { didSet { persistThrottled(\.studySecondsByDay, "studySeconds") } }
    var generatedFeeds: [GeneratedFeed] = []       { didSet { persist(\.generatedFeeds, "generatedFeeds") } }
    var customChannels: [EduChannel] = []          { didSet { persist(\.customChannels, "customChannels") } }
    var materials: [StudyMaterial] = []            { didSet { persist(\.materials, "materials") } }
    /// When set, the Feed and Listen tabs serve this document instead of the
    /// user's general interests.
    var activeMaterialID: UUID? {
        didSet {
            if let id = activeMaterialID { defaults.set(id.uuidString, forKey: key("activeMaterial")) }
            else { defaults.removeObject(forKey: key("activeMaterial")) }
        }
    }
    var hasOnboarded = false                       { didSet { defaults.set(hasOnboarded, forKey: key("onboarded")) } }

    /// Minutes-per-day needed to keep the streak alive.
    var dailyGoalMinutes = 10 { didSet { defaults.set(dailyGoalMinutes, forKey: key("goal")) } }

    // MARK: Ephemeral

    /// Set while a short or episode is actually playing, so idle time doesn't count.
    @ObservationIgnored private var lastTick: Date?

    private let defaults: UserDefaults
    private let prefix = "scholar."
    @ObservationIgnored private var pendingSaves: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    private func key(_ name: String) -> String { prefix + name }

    // MARK: - Interests

    var selectedInterests: [Interest] {
        Interest.all.filter { selectedInterestIDs.contains($0.id) }
    }

    /// Never hand the feed an empty source list.
    var effectiveInterests: [Interest] {
        selectedInterests.isEmpty ? Interest.all.filter { Interest.starterIDs.contains($0.id) } : selectedInterests
    }

    func toggle(_ interest: Interest) {
        if selectedInterestIDs.contains(interest.id) {
            selectedInterestIDs.remove(interest.id)
        } else {
            selectedInterestIDs.insert(interest.id)
        }
    }

    func toggle(category: InterestCategory) {
        let ids = category.interests.map(\.id)
        if ids.allSatisfy(selectedInterestIDs.contains) {
            selectedInterestIDs.subtract(ids)
        } else {
            selectedInterestIDs.formUnion(ids)
        }
    }

    func isSelected(_ interest: Interest) -> Bool { selectedInterestIDs.contains(interest.id) }

    func isFullySelected(_ category: InterestCategory) -> Bool {
        let ids = category.interests.map(\.id)
        return !ids.isEmpty && ids.allSatisfy(selectedInterestIDs.contains)
    }

    // MARK: - Voting

    func vote(_ item: FeedItem) -> Vote { votes[item.id] ?? .none }

    func setVote(_ vote: Vote, for item: FeedItem) {
        let current = votes[item.id] ?? .none
        let resolved: Vote = (current == vote) ? .none : vote
        votes[item.id] = resolved

        // Track the tally per channel/show as well as per item, so the ranker
        // can promote sources the user likes rather than only the exact clips
        // they happened to vote on.
        sourceVotes[item.sourceName, default: 0] += resolved.rawValue - current.rawValue
    }

    /// Channels and shows with a net-positive vote tally; the ranker promotes
    /// anything from these.
    var boostedSources: Set<String> {
        Set(sourceVotes.filter { $0.value > 0 }.keys)
    }

    // MARK: - Saving

    func isSaved(_ item: FeedItem) -> Bool { saved.contains { $0.id == item.id } }

    func toggleSave(_ item: FeedItem) {
        if let index = saved.firstIndex(where: { $0.id == item.id }) {
            saved.remove(at: index)
        } else {
            saved.insert(item, at: 0)
        }
    }

    // MARK: - Progress & streak

    private var todayKey: String { Self.dayKey(.now) }

    static func dayKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    var studySecondsToday: Int { studySecondsByDay[todayKey] ?? 0 }
    var studyMinutesToday: Int { studySecondsToday / 60 }

    var dailyGoalProgress: Double {
        min(1, Double(studySecondsToday) / Double(max(1, dailyGoalMinutes * 60)))
    }

    func metGoal(on date: Date) -> Bool {
        (studySecondsByDay[Self.dayKey(date)] ?? 0) >= dailyGoalMinutes * 60
    }

    /// Consecutive days ending today (or yesterday, if today isn't done yet).
    var streak: Int {
        var count = 0
        var cursor = Date.now
        if !metGoal(on: cursor) {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        while metGoal(on: cursor) {
            count += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Monday-through-Sunday of the current week, for the dashboard strip.
    var currentWeek: [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    /// Call once per second while media is playing.
    func tickStudyTime() {
        let now = Date.now
        defer { lastTick = now }
        guard let last = lastTick else { return }
        let delta = Int(now.timeIntervalSince(last).rounded())
        guard delta > 0, delta < 5 else { return }   // ignore gaps from backgrounding
        studySecondsByDay[todayKey, default: 0] += delta
    }

    func pausePlaybackClock() { lastTick = nil }

    func markSeen(_ item: FeedItem, interests: [Interest]) {
        guard !seenIDs.contains(item.id) else { return }
        seenIDs.insert(item.id)
        for interest in interests {
            interestProgress[interest.id, default: 0] += 1
        }
    }

    func progress(for interest: Interest) -> Double {
        let target = 120.0
        return min(1, Double(interestProgress[interest.id] ?? 0) / target)
    }

    // MARK: - Study materials

    var activeMaterial: StudyMaterial? {
        guard let activeMaterialID else { return nil }
        return materials.first { $0.id == activeMaterialID }
    }

    func addMaterial(_ material: StudyMaterial) {
        materials.insert(material, at: 0)
    }

    func removeMaterial(_ material: StudyMaterial) {
        materials.removeAll { $0.id == material.id }
        if activeMaterialID == material.id { activeMaterialID = nil }
    }

    func recordMaterialProgress(_ id: UUID) {
        guard let index = materials.firstIndex(where: { $0.id == id }) else { return }
        materials[index].itemsStudied += 1
    }

    // MARK: - Generated feeds

    func addGeneratedFeed(_ feed: GeneratedFeed) {
        generatedFeeds.removeAll { $0.query.lowercased() == feed.query.lowercased() }
        generatedFeeds.insert(feed, at: 0)
    }

    func removeGeneratedFeed(_ feed: GeneratedFeed) {
        generatedFeeds.removeAll { $0.id == feed.id }
    }

    // MARK: - Persistence

    private func persist<T: Encodable>(_ keyPath: KeyPath<Store, T>, _ name: String) {
        guard let data = try? JSONEncoder().encode(self[keyPath: keyPath]) else { return }
        defaults.set(data, forKey: key(name))
    }

    /// High-churn collections are written at most once a second.
    private func persistThrottled<T: Encodable>(_ keyPath: KeyPath<Store, T>, _ name: String) {
        guard !pendingSaves.contains(name) else { return }
        pendingSaves.insert(name)
        let snapshot = self[keyPath: keyPath]
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self else { return }
            if let data = try? JSONEncoder().encode(snapshot) {
                self.defaults.set(data, forKey: self.key(name))
            }
            self.pendingSaves.remove(name)
        }
    }

    private func decode<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func load() {
        if let value = decode("interests", as: Set<String>.self) { selectedInterestIDs = value }
        if let value = decode("votes", as: [String: Vote].self) { votes = value }
        if let value = decode("sourceVotes", as: [String: Int].self) { sourceVotes = value }
        if let value = decode("saved", as: [FeedItem].self) { saved = value }
        if let value = decode("seen", as: Set<String>.self) { seenIDs = value }
        if let value = decode("progress", as: [String: Int].self) { interestProgress = value }
        if let value = decode("studySeconds", as: [String: Int].self) { studySecondsByDay = value }
        if let value = decode("generatedFeeds", as: [GeneratedFeed].self) { generatedFeeds = value }
        if let value = decode("customChannels", as: [EduChannel].self) { customChannels = value }
        if let value = decode("materials", as: [StudyMaterial].self) {
            materials = value.map(MaterialImporter.rederived)
        }
        if let raw = defaults.string(forKey: key("activeMaterial")) { activeMaterialID = UUID(uuidString: raw) }
        hasOnboarded = defaults.bool(forKey: key("onboarded"))
        let goal = defaults.integer(forKey: key("goal"))
        if goal > 0 { dailyGoalMinutes = goal }
    }
}
