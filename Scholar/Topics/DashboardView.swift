//
//  DashboardView.swift
//  Scholar
//

import SwiftUI

struct DashboardView: View {
    @Environment(Store.self) private var store
    @Binding var route: AppRoute

    @State private var showInterests = false
    @State private var showGenerate = false
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    // Inside the scroll, so it slides away as you read rather
                    // than holding a permanent band at the top.
                    ScreenTitle(text: "Your Topics")
                    welcomeCard
                    todayCard
                    studyMaterials
                    yourTopics
                    generatedFeeds
                    discoverMore
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showInterests) { InterestGridView().environment(store) }
        .sheet(isPresented: $showImport) {
            StudyMaterialImportView { material in
                route = .material(material)
            }
            .environment(store)
        }
        .sheet(isPresented: $showGenerate) {
            GenerateFeedView { feed in
                route = .generated(feed)
            }
            .environment(store)
        }
    }

    // MARK: - Welcome + streak

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(streakMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.82))
            }

            HStack(spacing: 0) {
                ForEach(Array(store.currentWeek.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 7) {
                        Text(Self.weekdayLetter(day))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        dayMarker(day)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.welcomeGradient, in: .rect(cornerRadius: 22))
    }

    private var streakMessage: String {
        let streak = store.streak
        switch streak {
        case 0:  return "Study for \(store.dailyGoalMinutes) minutes to start a streak."
        case 1:  return "You have a 1 day streak going."
        default: return "You have a \(streak) day streak going."
        }
    }

    private func dayMarker(_ day: Date) -> some View {
        let isFuture = day > .now
        let done = store.metGoal(on: day)
        let isToday = Calendar.current.isDateInToday(day)

        return ZStack {
            Circle()
                .fill(done ? Color.white : Color.white.opacity(0.16))
                .frame(width: 26, height: 26)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(isToday ? 0.9 : 0), lineWidth: 2)
                .frame(width: 32, height: 32)
        )
        .opacity(isFuture ? 0.45 : 1)
    }

    private static func weekdayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }

    // MARK: - Today

    private var todayCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: store.dailyGoalProgress)
                    .stroke(Theme.flame, style: .init(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(store.studyMinutesToday)")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text("Today")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("\(store.studyMinutesToday) of \(store.dailyGoalMinutes) min · \(store.seenIDs.count) items studied")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
            }

            Spacer()

            Button {
                route = .feed
            } label: {
                Text("Study")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Theme.accent, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .cardSurface()
    }

    // MARK: - Study materials

    private var studyMaterials: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Study Material",
                          action: store.materials.isEmpty ? nil : ("Add", { showImport = true }))

            if store.materials.isEmpty {
                Button { showImport = true } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(Theme.accentSoft)
                            .frame(width: 46, height: 46)
                            .background(Theme.accent.opacity(0.16), in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Upload what you're studying")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text("A PDF, a photo of your notes, or pasted text — the feed retunes to it")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textDim)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(13)
                    .cardSurface(16)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.materials) { material in
                        materialRow(material)
                    }
                }
            }
        }
    }

    private func materialRow(_ material: StudyMaterial) -> some View {
        let isActive = store.activeMaterialID == material.id

        return Button {
            store.activeMaterialID = material.id
            route = .material(material)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 13) {
                    Image(systemName: material.kind.symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(isActive ? Theme.accentSoft : Theme.textDim)
                        .frame(width: 44, height: 44)
                        .background((isActive ? Theme.accent : Color.white).opacity(isActive ? 0.18 : 0.06),
                                    in: .rect(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(material.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(material.topTerms.prefix(4).joined(separator: " · "))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textDim)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if isActive {
                        Text("STUDYING")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Theme.accentSoft, in: .capsule)
                    }
                }

                ProgressBar(value: material.progress, tint: Theme.accentSoft)
            }
            .padding(12)
            .cardSurface(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isActive ? Theme.accent.opacity(0.7) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isActive {
                Button("Stop studying this", systemImage: "xmark.circle") {
                    store.activeMaterialID = nil
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                store.removeMaterial(material)
            }
        }
    }

    // MARK: - Topics

    private var yourTopics: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your Topics", action: ("Edit", { showInterests = true }))

            if store.selectedInterests.isEmpty {
                Text("No topics yet — tap Edit to choose what you want to learn.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textDim)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
            } else {
                VStack(spacing: 10) {
                    ForEach(store.selectedInterests) { interest in
                        topicRow(interest)
                    }
                }
            }
        }
    }

    private func topicRow(_ interest: Interest) -> some View {
        Button {
            route = .topic(interest.id)
        } label: {
            HStack(spacing: 13) {
                Text(interest.emoji)
                    .font(.system(size: 22))
                    .frame(width: 48, height: 48)
                    .background(interest.tint.opacity(0.18), in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 7) {
                    Text(interest.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    ProgressBar(value: store.progress(for: interest), tint: interest.tint)
                }

                Text("\(Int(store.progress(for: interest) * 100))%")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(12)
            .cardSurface(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generated feeds

    @ViewBuilder
    private var generatedFeeds: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Generated Feeds", action: ("New", { showGenerate = true }))

            if store.generatedFeeds.isEmpty {
                Button { showGenerate = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.accentSoft)
                            .frame(width: 44, height: 44)
                            .background(Theme.accent.opacity(0.16), in: .rect(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Build a feed from anything")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.text)
                            Text("A topic, a YouTube channel, or a podcast link")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.textFaint)
                    }
                    .padding(12)
                    .cardSurface(16)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    ForEach(store.generatedFeeds) { feed in
                        Button { route = .generated(feed) } label: {
                            HStack(spacing: 13) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.accentSoft)
                                    .frame(width: 48, height: 48)
                                    .background(Theme.accent.opacity(0.16), in: .rect(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(feed.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                    ProgressBar(value: feed.progress, tint: Theme.accentSoft)
                                }
                                Text("\(Int(feed.progress * 100))%")
                                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Theme.textDim)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .padding(12)
                            .cardSurface(16)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                store.removeGeneratedFeed(feed)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Discover

    private var discoverMore: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Discover", action: nil)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(unselectedSuggestions) { interest in
                    TagChip(text: interest.name, emoji: interest.emoji, tint: interest.tint) {
                        withAnimation(.snappy(duration: 0.2)) { store.toggle(interest) }
                    }
                }
            }
        }
    }

    private var unselectedSuggestions: [Interest] {
        Interest.all.filter { !store.selectedInterestIDs.contains($0.id) }.prefix(10).map { $0 }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String,
                               action: (String, () -> Void)?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.text)
            Spacer()
            if let action {
                Button(action.0, action: action.1)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentSoft)
                    .buttonStyle(.plain)
            }
        }
    }
}
