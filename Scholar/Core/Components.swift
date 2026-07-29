//
//  Components.swift
//  Scholar
//

import SwiftUI

// MARK: - Images

/// Sizes to whatever space the parent offers rather than to the downloaded
/// image. Without the `Color.clear` base a `.fill` image reports its full
/// pixel size and blows out any enclosing stack.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        Color.clear
            .overlay {
                AsyncImage(url: url, transaction: .init(animation: .easeOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure:
                        Theme.surfaceHi.overlay(
                            Image(systemName: "photo").foregroundStyle(Theme.textFaint)
                        )
                    default:
                        Theme.surfaceHi.overlay(ProgressView().tint(Theme.textFaint))
                    }
                }
            }
            .clipped()
    }
}

// MARK: - Progress

struct ProgressBar: View {
    let value: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * geometry.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Tags

struct TagChip: View {
    let text: String
    var emoji: String? = nil
    var tint: Color = Theme.accent
    var isOn: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 5) {
                if let emoji { Text(emoji).font(.system(size: 12)) }
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isOn ? Color.black : Theme.text)
            .background(isOn ? tint : Theme.surfaceHi, in: .capsule)
            .overlay(
                Capsule().strokeBorder(isOn ? .clear : Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Action rail (vote / save / share)

struct ActionRail: View {
    let item: FeedItem
    @Environment(Store.self) private var store

    private var vote: Vote { store.vote(item) }

    var body: some View {
        VStack(spacing: 22) {
            Button {
                haptic()
                store.setVote(.up, for: item)
            } label: {
                railIcon(vote == .up ? "arrowshape.up.fill" : "arrowshape.up",
                         tint: vote == .up ? Theme.up : .white)
            }

            Button {
                haptic()
                store.setVote(.down, for: item)
            } label: {
                railIcon(vote == .down ? "arrowshape.down.fill" : "arrowshape.down",
                         tint: vote == .down ? Theme.down : .white)
            }

            Button {
                haptic()
                store.toggleSave(item)
            } label: {
                railIcon(store.isSaved(item) ? "bookmark.fill" : "bookmark",
                         tint: store.isSaved(item) ? Theme.accentSoft : .white)
            }

            if let url = shareURL {
                ShareLink(item: url) { railIcon("arrowshape.turn.up.right", tint: .white) }
            }
        }
        .buttonStyle(.plain)
    }

    private var shareURL: URL? {
        switch item {
        case .short(let video):   return video.watchURL
        case .episode(let episode): return episode.audioURL
        }
    }

    private func railIcon(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.28), in: .circle)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Empty & loading states

struct FeedPlaceholder: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.textFaint)
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: .capsule)
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Screen title

/// A large title drawn in the content instead of by the navigation bar.
///
/// A `.large` navigation title reserves an empty toolbar band above itself, so
/// the heading landed roughly 90pt down the screen with nothing in the gap.
/// These screens push nothing, so the bar was pure overhead.
struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Formatting

extension Int {
    /// 1_240_000 → "1.2M"
    var compactCount: String {
        switch self {
        case 1_000_000...:
            return String(format: "%.1fM", Double(self) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(self) / 1_000)
        default:
            return String(self)
        }
    }
}

extension Date {
    var relativeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}

// MARK: - Study focus

/// Marks content that matched the active study material's own vocabulary, as
/// opposed to content included merely because it shares the subject area.
struct OnTopicBadge: View {
    var isExact: Bool = true
    /// Subject name shown when the item is only adjacent, e.g. "History".
    var subject: String = ""

    var body: some View {
        Label(isExact ? "ON TOPIC" : "RELATED · \(subject.uppercased())",
              systemImage: isExact ? "target" : "circle.dashed")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(isExact ? .black : .white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isExact ? AnyShapeStyle(Theme.up)
                                : AnyShapeStyle(Color.white.opacity(0.22)), in: .capsule)
    }
}
