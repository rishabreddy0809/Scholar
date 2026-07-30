//
//  InterestGridView.swift
//  Scholar
//
//  The "Discover new interests" grid: broad categories on top, specific tags
//  beneath. Tapping a category toggles everything inside it.
//

import SwiftUI

struct InterestGridView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    intro

                    section("Categories") {
                        flow {
                            ForEach(InterestCategory.allCases) { category in
                                TagChip(
                                    text: category.title,
                                    tint: category.tint,
                                    isOn: store.isFullySelected(category)
                                ) {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        store.toggle(category: category)
                                    }
                                }
                            }
                        }
                    }

                    ForEach(InterestCategory.allCases) { category in
                        if !category.interests.isEmpty {
                            section(category.title) {
                                TopicTileGrid(interests: category.interests)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accentSoft)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What should your feed teach you?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("\(store.selectedInterestIDs.count) selected · pulls from \(sourceCount) channels")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)
        }
    }

    private var sourceCount: Int {
        Set(store.effectiveInterests.flatMap(\.channelIDs)).count
    }

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textFaint)
                .tracking(0.8)
            content()
        }
    }

    private func flow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        FlowLayout(spacing: 8, lineSpacing: 8) { content() }
    }
}

// MARK: - Flow layout

/// Wraps chips onto as many lines as they need — the grid in the reference is
/// ragged, not a fixed column count.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
