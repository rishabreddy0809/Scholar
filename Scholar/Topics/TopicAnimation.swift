//
//  TopicAnimation.swift
//  Scholar
//
//  Bridges the bundled Lottie files to the topic artwork. Every animation in
//  `Scholar/lottie` is named after the interest id it belongs to, so a topic
//  gets its animation purely by matching filenames — nothing here has to be
//  edited to add one. Drop `history.json` in the folder and History picks it
//  up; topics with no file keep the hand-drawn `TopicScene`.
//
//  The one thing a new file *does* want is a line in `paleBacked`, because a
//  Lottie has no opinion about what it sits on: roughly half of these are drawn
//  in dark ink for a white page and the rest are white shapes meant for a dark
//  one, and putting either on the wrong ground erases the artwork.
//

import Lottie
import SwiftUI

// MARK: - Catalogue

@MainActor
enum TopicAnimation {
    /// The ground an animation needs under it to stay legible.
    enum Backdrop {
        /// The topic's saturated gradient, as the hand-drawn scenes use. For
        /// animations built from white and bright shapes.
        case tinted
        /// The same hue washed most of the way to white. For animations drawn
        /// in dark ink, which disappear entirely on the tinted ground.
        case pale
    }

    /// Topics whose animation is dark-on-transparent. Everything absent from
    /// this set gets the tinted ground, which is also the right default for a
    /// topic falling back to its `TopicScene`.
    private static let paleBacked: Set<String> = [
        "ai-tech", "anthropology", "curiosities", "ecology", "economics",
        "engineering", "finance", "genetics", "health", "language", "medicine",
        "neuroscience", "psychology", "zoology"
    ]

    static func backdrop(for id: String) -> Backdrop {
        paleBacked.contains(id) ? .pale : .tinted
    }

    // MARK: Framing

    /// How much of the tile the composition is blown up to cover.
    ///
    /// These are stock animations, and almost all of them are authored with a
    /// wide empty margin — several are a small subject centred in a 1920×1080
    /// frame. Fitted honestly inside a 128pt tile that leaves a stamp floating
    /// in the middle of a lot of nothing. Scaling past 1 pushes the margin off
    /// the tile, where the corner radius clips it, and brings the subject up to
    /// the size the hand-drawn scenes sit at.
    ///
    /// The number is per-topic because the margin is: `space` is composed edge
    /// to edge and must not be touched, `finance` is a sixth of its frame.
    private static let fills: [String: CGFloat] = [
        "space": 1.00, "language": 1.15, "engineering": 1.20, "ecology": 1.25,
        "chemistry": 1.30, "genetics": 1.30, "neuroscience": 1.30, "big-ideas": 1.30,
        "medicine": 1.70, "health": 1.70, "anthropology": 2.00, "economics": 2.00,
        "mathematics": 2.20, "zoology": 2.20, "ai-tech": 2.60, "finance": 2.80
    ]

    /// Anything not called out sits at a middling blow-up, which is the right
    /// answer for the majority that are composed with a modest margin.
    static func fill(for id: String) -> CGFloat { fills[id] ?? 1.45 }

    // MARK: Loading

    /// Parsed animations, keyed by interest id. The value is itself optional so
    /// a topic with no file is only looked up on disk once — this is called
    /// from `body`, and a miss is as worth caching as a hit.
    private static var cache: [String: LottieAnimation?] = [:]

    static func animation(for id: String) -> LottieAnimation? {
        if let cached = cache[id] { return cached }

        // Xcode's synchronized folders flatten resources into the bundle root,
        // but a folder reference keeps `lottie/` — try both rather than depend
        // on how the file happens to be added to the target.
        let loaded = LottieAnimation.named(id, bundle: .main, subdirectory: "lottie")
            ?? LottieAnimation.named(id, bundle: .main)
        cache[id] = loaded
        return loaded
    }
}

// MARK: - View

/// One Lottie, looping, sized to exactly the space SwiftUI offers it.
///
/// `sizeThatFits` is the important part: a `LottieAnimationView` reports the
/// composition's authored size as its intrinsic size, and several of these are
/// 1920×1080, which a plain representable would try to lay out at full width.
struct TopicAnimationView: UIViewRepresentable {
    let animation: LottieAnimation

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(animation: animation)
        view.contentMode = .scaleAspectFit
        view.loopMode = .loop
        // The tiles are decorative: a paused-and-restored animation coming back
        // from the background is cheaper than one that keeps a timer alive.
        view.backgroundBehavior = .pauseAndRestore
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.play()
        return view
    }

    func updateUIView(_ view: LottieAnimationView, context: Context) {
        // Cells are recycled as the grid scrolls; a view that comes back has
        // stopped and needs kicking, but one that never left must not restart
        // from frame zero.
        if !view.isAnimationPlaying { view.play() }
    }

    func sizeThatFits(_ proposal: ProposedViewSize,
                      uiView: LottieAnimationView,
                      context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 100, height: proposal.height ?? 100)
    }
}
