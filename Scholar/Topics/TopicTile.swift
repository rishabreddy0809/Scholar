//
//  TopicTile.swift
//  Scholar
//
//  The selectable card the interest pickers are built from: the topic's artwork
//  full-bleed, its name over a scrim at the bottom, and a check when it's on.
//

import SwiftUI

struct TopicTile: View {
    let interest: Interest
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                TopicArt(interest: interest)

                // Confined to the bottom third: enough to carry the name, but
                // it no longer washes out the scene the way a from-centre
                // scrim did.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.52),
                        .init(color: .black.opacity(0.28), location: 0.76),
                        .init(color: .black.opacity(0.72), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Text(interest.name)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 9)

                check
            }
            .frame(height: 128)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isOn ? interest.tint : Theme.stroke, lineWidth: isOn ? 2.5 : 1)
            )
            // Unselected tiles recede only slightly. The earlier values crushed
            // them to grey mud, which defeats the point of drawing 27 scenes —
            // selection is carried by the border and the check, not by hiding
            // the artwork.
            .saturation(isOn ? 1 : 0.9)
            .opacity(isOn ? 1 : 0.9)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(interest.name)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var check: some View {
        if isOn {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 21, height: 21)
                .background(interest.tint, in: .circle)
                .overlay(Circle().strokeBorder(.black.opacity(0.22), lineWidth: 1))
                .padding(7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

/// The two-column grid both pickers use, so onboarding and the customize sheet
/// can never drift apart.
struct TopicTileGrid: View {
    let interests: [Interest]
    @Environment(Store.self) private var store

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(interests) { interest in
                TopicTile(interest: interest, isOn: store.isSelected(interest)) {
                    withAnimation(.snappy(duration: 0.22)) { store.toggle(interest) }
                }
            }
        }
    }
}

/// The small square used where there's only room for a thumbnail — the topic
/// rows on the dashboard, and anywhere a chip needs to carry its artwork.
struct TopicBadge: View {
    let interest: Interest
    var size: CGFloat = 44
    var radius: CGFloat = 12

    var body: some View {
        TopicArt(interest: interest)
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}
