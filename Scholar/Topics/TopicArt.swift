//
//  TopicArt.swift
//  Scholar
//
//  Hand-built artwork for every topic in the catalogue, drawn as vectors and
//  animated, so the picker shows a Physics *scene* rather than a shared glyph
//  in a different colour.
//
//  Why vectors rather than bundled illustrations: 27 topics of raster art is
//  megabytes of asset that has to be redrawn at every scale and can't move.
//  These are authored once in a 100×100 space, scale to any tile, and every
//  moving part is a repeating Core Animation — the render server drives it, so
//  a full grid of them costs no per-frame work on the CPU.
//
//  Adding a topic: give it a palette in `TopicPalette.for(_:)` and a scene in
//  `TopicScene`. Nothing else in the app needs to change.
//

import SwiftUI

// MARK: - Palette

/// Five colours per topic: the backdrop pair the scene sits in, and three for
/// the objects themselves. Deliberately bright and slightly desaturated — the
/// tiles sit on a near-black background and pure hues vibrate against it.
struct TopicPalette: Sendable {
    let sky: Color
    let ground: Color
    let primary: Color
    let secondary: Color
    let detail: Color

    var backdrop: LinearGradient {
        LinearGradient(colors: [sky, ground], startPoint: .top, endPoint: .bottom)
    }

    nonisolated static func `for`(_ id: String) -> TopicPalette {
        switch id {
        case "physics":       return .init(sky: Color(hex: 0x8B6BFF), ground: Color(hex: 0xE86BB0), primary: Color(hex: 0xFFF0FB), secondary: Color(hex: 0x5EE7FF), detail: Color(hex: 0xFFD166))
        case "mathematics":   return .init(sky: Color(hex: 0x2B4E9B), ground: Color(hex: 0x63A7FF), primary: Color(hex: 0xFFFFFF), secondary: Color(hex: 0xFFD166), detail: Color(hex: 0x9BE8FF))
        case "chemistry":     return .init(sky: Color(hex: 0x1F8A70), ground: Color(hex: 0x8FE38C), primary: Color(hex: 0xEAFFF6), secondary: Color(hex: 0x5EE7FF), detail: Color(hex: 0xFF8FA3))
        case "space":         return .init(sky: Color(hex: 0x2A1B5E), ground: Color(hex: 0x7A4BC4), primary: Color(hex: 0xFFC978), secondary: Color(hex: 0xFFF3D6), detail: Color(hex: 0x9BE8FF))
        case "ai-tech":       return .init(sky: Color(hex: 0x1B4B8F), ground: Color(hex: 0x28D9C5), primary: Color(hex: 0xEFFFFD), secondary: Color(hex: 0x7C5CFF), detail: Color(hex: 0xFFD166))
        case "engineering":   return .init(sky: Color(hex: 0x8A5A22), ground: Color(hex: 0xFFB86B), primary: Color(hex: 0xFFF1DC), secondary: Color(hex: 0x6E7B8C), detail: Color(hex: 0xFF8A3D))
        case "biology":       return .init(sky: Color(hex: 0x1E6F5C), ground: Color(hex: 0x6FD98F), primary: Color(hex: 0xFFF6E8), secondary: Color(hex: 0xFF8FA3), detail: Color(hex: 0x5EE7FF))
        case "medicine":      return .init(sky: Color(hex: 0x1D6FB8), ground: Color(hex: 0x8FD6FF), primary: Color(hex: 0xFFFFFF), secondary: Color(hex: 0xFF6B7F), detail: Color(hex: 0xFFD166))
        case "genetics":      return .init(sky: Color(hex: 0x4B2A7A), ground: Color(hex: 0xB98BFF), primary: Color(hex: 0xF6EEFF), secondary: Color(hex: 0x5EE7FF), detail: Color(hex: 0xFFD166))
        case "zoology":       return .init(sky: Color(hex: 0x7A5A1E), ground: Color(hex: 0xE0C56B), primary: Color(hex: 0xFFF6E0), secondary: Color(hex: 0x6FA86B), detail: Color(hex: 0xFF8A3D))
        case "ecology":       return .init(sky: Color(hex: 0x2E7A2E), ground: Color(hex: 0xBEE86B), primary: Color(hex: 0xF4FFE0), secondary: Color(hex: 0x4ADE80), detail: Color(hex: 0xFFD166))
        case "neuroscience":  return .init(sky: Color(hex: 0x6B2A5E), ground: Color(hex: 0xFF8FC4), primary: Color(hex: 0xFFF0F8), secondary: Color(hex: 0x9BE8FF), detail: Color(hex: 0xFFD166))
        case "history":       return .init(sky: Color(hex: 0xA85A1E), ground: Color(hex: 0xFFC978), primary: Color(hex: 0xFFF3DC), secondary: Color(hex: 0xC24B3A), detail: Color(hex: 0xFFE9A8))
        case "philosophy":    return .init(sky: Color(hex: 0x3E3A6E), ground: Color(hex: 0x9B96D6), primary: Color(hex: 0xFFFFFF), secondary: Color(hex: 0xFFD166), detail: Color(hex: 0xC9C4FF))
        case "language":      return .init(sky: Color(hex: 0x1E5F8A), ground: Color(hex: 0x6BD6E8), primary: Color(hex: 0xFFFFFF), secondary: Color(hex: 0xFFD166), detail: Color(hex: 0xFF8FA3))
        case "anthropology":  return .init(sky: Color(hex: 0x6E4A2A), ground: Color(hex: 0xD6A86B), primary: Color(hex: 0xF2E4CE), secondary: Color(hex: 0x8A9B6B), detail: Color(hex: 0xFFD166))
        case "geography":     return .init(sky: Color(hex: 0x1B6E8A), ground: Color(hex: 0x6BD6C4), primary: Color(hex: 0xEAFFFB), secondary: Color(hex: 0x8FE38C), detail: Color(hex: 0xFF8A3D))
        case "psychology":    return .init(sky: Color(hex: 0x7A2A5E), ground: Color(hex: 0xE86BA8), primary: Color(hex: 0xFFF0F8), secondary: Color(hex: 0xFFD166), detail: Color(hex: 0x9BE8FF))
        case "politics":      return .init(sky: Color(hex: 0x8A2A3A), ground: Color(hex: 0xE86B7A), primary: Color(hex: 0xFFF0F0), secondary: Color(hex: 0x5EA8FF), detail: Color(hex: 0xFFD166))
        case "social-issues": return .init(sky: Color(hex: 0x5A3A8A), ground: Color(hex: 0xA88FE8), primary: Color(hex: 0xFFFFFF), secondary: Color(hex: 0xFFD166), detail: Color(hex: 0x8FE38C))
        case "education":     return .init(sky: Color(hex: 0x2A4B8A), ground: Color(hex: 0x8FB8FF), primary: Color(hex: 0xFFFFFF), secondary: Color(hex: 0xFFD166), detail: Color(hex: 0xFF8FA3))
        case "economics":     return .init(sky: Color(hex: 0x1E6E4A), ground: Color(hex: 0x6BE8A8), primary: Color(hex: 0xEAFFF2), secondary: Color(hex: 0xFFD166), detail: Color(hex: 0x5EA8FF))
        case "finance":       return .init(sky: Color(hex: 0x8A6E1E), ground: Color(hex: 0xFFE06B), primary: Color(hex: 0xFFFBE8), secondary: Color(hex: 0x4ADE80), detail: Color(hex: 0xFF8A3D))
        case "health":        return .init(sky: Color(hex: 0xB8452A), ground: Color(hex: 0xFF9B7A), primary: Color(hex: 0xFFF0E8), secondary: Color(hex: 0x5EE7FF), detail: Color(hex: 0xFFD166))
        case "productivity":  return .init(sky: Color(hex: 0x8A6E00), ground: Color(hex: 0xFFD84D), primary: Color(hex: 0xFFFDF0), secondary: Color(hex: 0x7C5CFF), detail: Color(hex: 0x4ADE80))
        case "curiosities":   return .init(sky: Color(hex: 0x3A2A7A), ground: Color(hex: 0x8F6BE8), primary: Color(hex: 0xD6C9FF), secondary: Color(hex: 0x5EE7FF), detail: Color(hex: 0xFFD166))
        default:              return .init(sky: Color(hex: 0x8A6E1E), ground: Color(hex: 0xFFD84D), primary: Color(hex: 0xFFFBE8), secondary: Color(hex: 0x7C5CFF), detail: Color(hex: 0xFFF3C4))
        }
    }
}

// MARK: - Canvas

/// Every scene is authored against a fixed 100×100 grid and scaled to whatever
/// it is asked to occupy, so one drawing serves a 44pt row thumbnail and a
/// full-width tile without a second set of numbers.
///
/// Scaling is driven by the *shorter* edge with a deliberate overscan, which is
/// the only sizing that survives both shapes of container. Scaling on the long
/// edge fills a wide tile but slices the top and bottom off the composition —
/// the plates, bases and horizons all live down at y≈80 and vanished. Scaling
/// on the short edge alone leaves the art marooned in the middle of a wide
/// card. The overscan splits the difference: it bleeds off the sides, where
/// scenes are empty anyway, and keeps the vertical band 12…88 visible, which is
/// where every scene is authored to sit.
struct ArtCanvas<Content: View>: View {
    /// 1.0 fits the scene exactly inside the short edge; 1.3 lets it bleed.
    var overscan: CGFloat = 1.3
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            ZStack { content }
                .frame(width: 100, height: 100)
                .scaleEffect(min(geo.size.width, geo.size.height) / 100 * overscan)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Motion

/// The five kinds of movement the scenes are built from. All of them are
/// implicit repeating animations kicked off by a one-shot `onAppear` flag,
/// which is what keeps them off the CPU once running.
///
/// `delay` exists so sibling shapes drift out of phase. Identical timing on
/// six orbs reads as a single sliding sheet rather than as floating.
private struct ArtFloat: ViewModifier {
    let distance: CGFloat
    let duration: Double
    let delay: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .offset(y: on ? -distance : distance)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay), value: on)
            .onAppear { on = true }
    }
}

private struct ArtDrift: ViewModifier {
    let x: CGFloat
    let y: CGFloat
    let duration: Double
    let delay: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .offset(x: on ? x : -x, y: on ? y : -y)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay), value: on)
            .onAppear { on = true }
    }
}

private struct ArtSpin: ViewModifier {
    let duration: Double
    let clockwise: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(on ? (clockwise ? 360 : -360) : 0))
            .animation(.linear(duration: duration).repeatForever(autoreverses: false), value: on)
            .onAppear { on = true }
    }
}

private struct ArtSway: ViewModifier {
    let degrees: Double
    let duration: Double
    let anchor: UnitPoint
    let delay: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(on ? degrees : -degrees), anchor: anchor)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay), value: on)
            .onAppear { on = true }
    }
}

private struct ArtPulse: ViewModifier {
    let scale: CGFloat
    let duration: Double
    let delay: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? scale : 1)
            .animation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay), value: on)
            .onAppear { on = true }
    }
}

/// Fades and grows outward once per cycle without reversing — the shape a
/// travelling signal or an expanding ring needs, where snapping back to the
/// start is invisible because it happens at zero opacity.
private struct ArtEmit: ViewModifier {
    let from: CGSize
    let to: CGSize
    let scale: CGFloat
    let duration: Double
    let delay: Double
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? scale : 1)
            .offset(on ? to : from)
            .opacity(on ? 0 : 1)
            .animation(.easeOut(duration: duration).repeatForever(autoreverses: false).delay(delay), value: on)
            .onAppear { on = true }
    }
}

extension View {
    func artFloat(_ distance: CGFloat, _ duration: Double, delay: Double = 0) -> some View {
        modifier(ArtFloat(distance: distance, duration: duration, delay: delay))
    }

    func artDrift(x: CGFloat = 0, y: CGFloat = 0, _ duration: Double, delay: Double = 0) -> some View {
        modifier(ArtDrift(x: x, y: y, duration: duration, delay: delay))
    }

    func artSpin(_ duration: Double, clockwise: Bool = true) -> some View {
        modifier(ArtSpin(duration: duration, clockwise: clockwise))
    }

    func artSway(_ degrees: Double, _ duration: Double,
                 anchor: UnitPoint = .center, delay: Double = 0) -> some View {
        modifier(ArtSway(degrees: degrees, duration: duration, anchor: anchor, delay: delay))
    }

    func artPulse(_ scale: CGFloat, _ duration: Double, delay: Double = 0) -> some View {
        modifier(ArtPulse(scale: scale, duration: duration, delay: delay))
    }

    func artEmit(from: CGSize = .zero, to: CGSize = .zero, scale: CGFloat = 1,
                 _ duration: Double, delay: Double = 0) -> some View {
        modifier(ArtEmit(from: from, to: to, scale: scale, duration: duration, delay: delay))
    }

    /// Places a shape in the 100×100 authoring grid.
    func at(_ x: CGFloat, _ y: CGFloat) -> some View {
        position(x: x, y: y)
    }
}

// MARK: - Primitives

/// The shared vocabulary the scenes are assembled from. Everything takes its
/// size in authoring units so a scene reads as a list of placements.
enum Art {
    /// Soft light source. A radial gradient rather than a blurred circle:
    /// visually the same at this size and vastly cheaper, which matters when
    /// 27 of these are on screen together.
    static func glow(_ color: Color, _ size: CGFloat, opacity: Double = 0.5) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(opacity), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }

    /// Top-lit gradient built from a single colour, so a silhouette reads as a
    /// solid object rather than a paper cut-out. One fill, no extra layers.
    ///
    /// `mix` nudges alpha toward opaque, so this is only safe on colours that
    /// are already near-opaque — every scene keeps its fills at 0.9 or above
    /// for exactly this reason. Translucent washes should use a plain colour.
    static func shade(_ color: Color, lift: Double = 0.24, drop: Double = 0.20) -> LinearGradient {
        LinearGradient(
            colors: [color.mix(with: .white, by: lift), color, color.mix(with: .black, by: drop)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Spherical shading: highlight up and to the left, terminator bottom-right.
    /// The light direction is the same in every scene, which is most of what
    /// makes 27 separately-drawn tiles look like one set.
    static func sphere(_ color: Color, _ size: CGFloat, opacity: Double) -> RadialGradient {
        RadialGradient(
            colors: [color.mix(with: .white, by: 0.46).opacity(opacity),
                     color.opacity(opacity),
                     color.mix(with: .black, by: 0.30).opacity(opacity)],
            center: .init(x: 0.32, y: 0.26),
            startRadius: 0,
            endRadius: size * 0.92
        )
    }

    static func orb(_ color: Color, _ size: CGFloat, opacity: Double = 1) -> some View {
        Circle()
            .fill(sphere(color, size, opacity: opacity))
            .frame(width: size, height: size)
    }

    static func ring(_ color: Color, _ size: CGFloat, width: CGFloat = 2, opacity: Double = 1) -> some View {
        Circle().strokeBorder(color.opacity(opacity), lineWidth: width).frame(width: size, height: size)
    }

    static func box(_ color: Color, _ w: CGFloat, _ h: CGFloat,
                    radius: CGFloat = 2, opacity: Double = 1) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(shade(color, lift: 0.20, drop: 0.16).opacity(opacity))
            .frame(width: w, height: h)
    }

    /// The diorama floor the object scenes stand on — a squashed ellipse that
    /// reads as a platform seen from slightly above.
    static func plate(_ color: Color, w: CGFloat = 76, h: CGFloat = 22) -> some View {
        Ellipse()
            .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.55)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: w, height: h)
    }

    /// The soft dark patch directly under an object. Cheap, and the single
    /// biggest difference between a shape sitting on the ground and one
    /// hovering an inch above it.
    static func contact(_ w: CGFloat, opacity: Double = 0.3) -> some View {
        Ellipse()
            .fill(RadialGradient(colors: [.black.opacity(opacity), .black.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: w / 2))
            .frame(width: w, height: w * 0.26)
    }

    /// A stroked path in full-canvas coordinates — the path is drawn straight
    /// into the 100×100 grid, so `.at()` must *not* be applied to it.
    static func stroke(_ color: Color, width: CGFloat = 2,
                       cap: CGLineCap = .round,
                       _ build: @escaping (inout Path) -> Void) -> some View {
        Path { path in build(&path) }
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: .round))
            .frame(width: 100, height: 100)
    }

    /// A filled path in full-canvas coordinates. Same rule: no `.at()`.
    static func fill(_ color: Color, _ build: @escaping (inout Path) -> Void) -> some View {
        Path { path in build(&path) }
            .fill(shade(color))
            .frame(width: 100, height: 100)
    }

    /// A filled path in its *own* `w`×`h` box, which `.at()` then places by its
    /// centre. This is the one to use for a leaf, a pin, a flag — any small
    /// shape drawn from its own origin rather than positioned on the canvas.
    ///
    /// Keep it distinct from `fill`: re-framing a canvas-space path to a small
    /// box does not move the drawing into that box, it just crops the frame
    /// around a shape still sitting at its canvas coordinates. That silently
    /// flung every small shape a long way off its mark.
    static func shape(_ color: Color, _ w: CGFloat, _ h: CGFloat,
                      _ build: @escaping (inout Path) -> Void) -> some View {
        Path { path in build(&path) }
            .fill(shade(color))
            .frame(width: w, height: h)
    }

    /// Stroked counterpart to `shape`.
    static func outline(_ color: Color, width: CGFloat = 2,
                        _ w: CGFloat, _ h: CGFloat,
                        _ build: @escaping (inout Path) -> Void) -> some View {
        Path { path in build(&path) }
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            .frame(width: w, height: h)
    }

    /// A sine wave sampled across `from...to`, used for helices, ECG traces
    /// and wave functions.
    static func wave(from: CGFloat, to: CGFloat, mid: CGFloat,
                     amplitude: CGFloat, cycles: Double, phase: Double,
                     into path: inout Path) {
        let steps = 28
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let x = from + (to - from) * t
            let angle = Double(t) * cycles * 2 * .pi + phase
            let y = mid + amplitude * CGFloat(sin(angle))
            if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
    }

    /// Evenly spaced twinkling specks. Positions are fixed rather than random
    /// so a tile looks identical every time it scrolls back into view.
    static func sparkles(_ color: Color, _ points: [(CGFloat, CGFloat, CGFloat)]) -> some View {
        ForEach(Array(points.enumerated()), id: \.offset) { index, point in
            Art.orb(color, point.2)
                .at(point.0, point.1)
                .artPulse(1.6, 1.4 + Double(index % 3) * 0.4, delay: Double(index) * 0.25)
        }
    }
}

// MARK: - Entry point

/// The artwork for one topic: its backdrop, its scene, and a top-down light
/// wash that ties all 27 together as one set.
///
/// The scene is a bundled Lottie wherever one exists — see `TopicAnimation` —
/// and the hand-drawn `TopicScene` otherwise. Both sit inside the same
/// backdrop, light and vignette, which is what keeps a grid mixing the two from
/// reading as two different sets of artwork.
struct TopicArt: View {
    let interest: Interest

    private var palette: TopicPalette { TopicPalette.for(interest.id) }

    var body: some View {
        // Radii are derived from the tile rather than fixed, so the key light
        // and vignette read the same on a 48pt badge as on a full-width tile.
        GeometryReader { geo in
            let reach = max(geo.size.width, geo.size.height)
            let animation = TopicAnimation.animation(for: interest.id)
            let backdrop: TopicAnimation.Backdrop = animation == nil
                ? .tinted
                : TopicAnimation.backdrop(for: interest.id)

            ZStack {
                ground(backdrop, reach: reach)

                if let animation {
                    // Laid out as an overlay on nothing, so blowing the
                    // composition up past the tile (see `TopicAnimation.fill`)
                    // overflows into the clip rather than stretching the ZStack
                    // and dragging the backdrop gradient out with it.
                    Color.clear.overlay {
                        let fill = TopicAnimation.fill(for: interest.id)
                        TopicAnimationView(animation: animation)
                            .frame(width: geo.size.width * fill,
                                   height: geo.size.height * fill)
                    }
                    .id(interest.id)
                } else {
                    ArtCanvas { TopicScene(id: interest.id, palette: palette) }
                }

                // Vignette over the scene, which pushes the corners back and
                // stops the artwork fighting the name in the bottom corner.
                vignette(backdrop, reach: reach)
            }
        }
        // No `drawingGroup()` here on purpose: it would rasterise the scene
        // into an offscreen buffer every frame, turning free render-server
        // animation into per-frame GPU work across the whole grid.
    }

    @ViewBuilder
    private func ground(_ backdrop: TopicAnimation.Backdrop, reach: CGFloat) -> some View {
        switch backdrop {
        case .tinted:
            palette.backdrop
            // Key light, upper left — the same direction `Art.sphere` lights
            // every object from.
            RadialGradient(colors: [.white.opacity(0.22), .clear],
                           center: .init(x: 0.26, y: 0.1),
                           startRadius: 0, endRadius: reach * 0.85)
        case .pale:
            // Still unmistakably the topic's hue, just carried at paper
            // lightness so dark-inked artwork has something to sit on. Washing
            // it further than this is what turns a dozen tiles into the same
            // sheet of grey — the hue has to survive, it is the only thing
            // telling Zoology from Medicine at a glance.
            LinearGradient(colors: [palette.sky.mix(with: .white, by: 0.70),
                                    palette.ground.mix(with: .white, by: 0.46)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [.white.opacity(0.34), .clear],
                           center: .init(x: 0.26, y: 0.1),
                           startRadius: 0, endRadius: reach * 0.85)
        }
    }

    @ViewBuilder
    private func vignette(_ backdrop: TopicAnimation.Backdrop, reach: CGFloat) -> some View {
        // Black at a pale tile's corners reads as dirt; the topic's own colour
        // does the same job of pushing the edges back without greying it.
        let edge: Color = switch backdrop {
        case .tinted: .black.opacity(0.3)
        case .pale:   palette.ground.mix(with: .black, by: 0.25).opacity(0.22)
        }

        RadialGradient(colors: [.clear, edge],
                       center: .center,
                       startRadius: reach * 0.28, endRadius: reach * 0.78)
    }
}
