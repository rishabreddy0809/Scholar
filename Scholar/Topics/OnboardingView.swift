//
//  OnboardingView.swift
//  Scholar
//

import SwiftUI

struct OnboardingView: View {
    @Environment(Store.self) private var store
    @State private var page = 0

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                if page == 0 { intro } else { picker }
                footer
            }
        }
    }

    // MARK: - Pages

    private var intro: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.accentSoft)

            Text("Study by scrolling")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)

            Text("The same endless feed you already scroll — filled with short explainers and podcasts from people who actually teach.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)

            VStack(alignment: .leading, spacing: 14) {
                bullet("play.rectangle.fill", "Real shorts",
                       "Pulled live from \(ChannelCatalog.all.count) educational channels.")
                bullet("waveform", "Real podcasts",
                       "Searched across the Apple Podcasts directory.")
                bullet("flame.fill", "Keep a streak",
                       "Hit your daily minutes and the week fills in.")
            }
            .padding(.top, 12)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pick your interests")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("Choose at least three. You can change these any time.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textDim)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            ScrollView {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Interest.all) { interest in
                        TagChip(
                            text: interest.name,
                            emoji: interest.emoji,
                            tint: interest.tint,
                            isOn: store.isSelected(interest)
                        ) {
                            withAnimation(.snappy(duration: 0.2)) { store.toggle(interest) }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.accentSoft)
                .frame(width: 26, height: 26)
                .background(Theme.accent.opacity(0.16), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                if page == 0 {
                    withAnimation(.easeInOut(duration: 0.25)) { page = 1 }
                } else {
                    store.hasOnboarded = true
                }
            } label: {
                Text(page == 0 ? "Get started" : startTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(canContinue ? Theme.accent : Theme.surfaceHi, in: .rect(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)

            if page == 1 {
                Text("\(store.selectedInterestIDs.count) selected")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }

    private var canContinue: Bool {
        page == 0 || store.selectedInterestIDs.count >= 3
    }

    private var startTitle: String {
        store.selectedInterestIDs.count >= 3 ? "Start scrolling" : "Pick at least 3"
    }
}
