//
//  TopicScenes.swift
//  Scholar
//
//  One scene per topic, authored in the 100×100 space `ArtCanvas` provides.
//  Each is a small diorama of the subject with something in it actually moving:
//  electrons orbit, gears mesh, the ECG trace beats, the scales tip.
//
//  Rules that keep the set coherent:
//   - Objects sit low, roughly on the 58–78 band, so the tiles share a horizon.
//   - Two to four moving parts. More reads as noise at tile size.
//   - Motion is slow (1.5–9s) and out of phase between siblings.
//   - Colours come only from the topic's palette, never hard-coded.
//

import SwiftUI

struct TopicScene: View {
    let id: String
    let palette: TopicPalette

    var body: some View {
        switch id {
        case "physics":       PhysicsScene(p: palette)
        case "mathematics":   MathematicsScene(p: palette)
        case "chemistry":     ChemistryScene(p: palette)
        case "space":         SpaceScene(p: palette)
        case "ai-tech":       AITechScene(p: palette)
        case "engineering":   EngineeringScene(p: palette)
        case "biology":       BiologyScene(p: palette)
        case "medicine":      MedicineScene(p: palette)
        case "genetics":      GeneticsScene(p: palette)
        case "zoology":       ZoologyScene(p: palette)
        case "ecology":       EcologyScene(p: palette)
        case "neuroscience":  NeuroscienceScene(p: palette)
        case "history":       HistoryScene(p: palette)
        case "philosophy":    PhilosophyScene(p: palette)
        case "language":      LanguageScene(p: palette)
        case "anthropology":  AnthropologyScene(p: palette)
        case "geography":     GeographyScene(p: palette)
        case "psychology":    PsychologyScene(p: palette)
        case "politics":      PoliticsScene(p: palette)
        case "social-issues": SocialIssuesScene(p: palette)
        case "education":     EducationScene(p: palette)
        case "economics":     EconomicsScene(p: palette)
        case "finance":       FinanceScene(p: palette)
        case "health":        HealthScene(p: palette)
        case "productivity":  ProductivityScene(p: palette)
        case "curiosities":   CuriositiesScene(p: palette)
        default:              BigIdeasScene(p: palette)
        }
    }
}

// MARK: - STEM

/// An atom: still nucleus, two tilted orbital shells, an electron riding each.
private struct PhysicsScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.glow(p.primary, 62, opacity: 0.35).at(50, 50)
            shell(tilt: 28)
            shell(tilt: -28)
            shell(tilt: 88)
            Art.orb(p.primary, 15).at(50, 50)
            Art.orb(p.detail, 7).at(50, 50).artPulse(1.18, 2.2)
            Art.sparkles(p.secondary, [(16, 22, 3), (84, 30, 2.5), (24, 80, 2.5), (80, 76, 3)])
        }
    }

    /// The electron is parented to the shell and rotated with it, so it tracks
    /// the ellipse exactly instead of needing its own path maths.
    private func shell(tilt: Double) -> some View {
        ZStack {
            Ellipse()
                .strokeBorder(p.secondary.opacity(0.85), lineWidth: 1.6)
                .frame(width: 72, height: 28)
            Art.orb(p.detail, 6.5).offset(x: 36)
        }
        .rotationEffect(.degrees(tilt))
        .at(50, 50)
        .artSpin(tilt > 0 ? 6 : 8, clockwise: tilt > 0)
    }
}

/// Graph paper, a plotted curve, and a pair of drafting instruments.
private struct MathematicsScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            grid
            Art.stroke(p.detail.opacity(0.5), width: 1.4) { path in
                path.move(to: CGPoint(x: 14, y: 50)); path.addLine(to: CGPoint(x: 88, y: 50))
                path.move(to: CGPoint(x: 20, y: 20)); path.addLine(to: CGPoint(x: 20, y: 84))
            }
            plot
        }
    }

    private var grid: some View {
        ZStack {
            ForEach(0..<5) { index in
                Art.box(p.primary, 78, 0.8, radius: 0, opacity: 0.14).at(50, 26 + CGFloat(index) * 14)
            }
            ForEach(0..<5) { index in
                Art.box(p.primary, 0.8, 62, radius: 0, opacity: 0.14).at(22 + CGFloat(index) * 14, 52)
            }
        }
    }

    private var plot: some View {
        ZStack {
            Art.stroke(p.primary, width: 2.6) { path in
                Art.wave(from: 20, to: 86, mid: 50, amplitude: 17, cycles: 1.1,
                         phase: .pi, into: &path)
            }
            Art.orb(p.secondary, 8).at(36, 33).artPulse(1.22, 1.8)
            Art.orb(p.secondary, 7).at(64, 67).artPulse(1.22, 1.8, delay: 0.6)
            Art.orb(p.detail, 6).at(80, 50).artPulse(1.22, 1.8, delay: 1.2)
        }
        .frame(width: 100, height: 100)
        .artFloat(1.2, 3.4)
    }
}

/// A flask of coloured liquid, boiling.
private struct ChemistryScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.plate(p.ground.opacity(0.5), w: 68, h: 18).at(50, 82)
            Art.contact(44).at(50, 80)
            flask
            liquid
            bubbles
            Art.box(p.primary, 16, 3.5, radius: 2, opacity: 0.95).at(50, 27)
            Art.orb(p.detail, 5).at(72, 34).artFloat(3, 2.6)
            Art.orb(p.secondary, 3.5).at(28, 40).artFloat(2.4, 3.2, delay: 0.5)
        }
    }

    private var flaskShape: Path {
        var path = Path()
        path.move(to: CGPoint(x: 44, y: 29))
        path.addLine(to: CGPoint(x: 44, y: 48))
        path.addCurve(to: CGPoint(x: 32, y: 76),
                      control1: CGPoint(x: 44, y: 60), control2: CGPoint(x: 32, y: 62))
        path.addQuadCurve(to: CGPoint(x: 68, y: 76), control: CGPoint(x: 50, y: 86))
        path.addCurve(to: CGPoint(x: 56, y: 48),
                      control1: CGPoint(x: 68, y: 62), control2: CGPoint(x: 56, y: 60))
        path.addLine(to: CGPoint(x: 56, y: 29))
        return path
    }

    private var flask: some View {
        flaskShape
            .fill(p.primary.opacity(0.18))
            .overlay(flaskShape.stroke(p.primary.opacity(0.9), lineWidth: 2.2))
            .frame(width: 100, height: 100)
    }

    private var liquid: some View {
        Art.fill(p.secondary.opacity(0.95)) { path in
            path.move(to: CGPoint(x: 34, y: 64))
            path.addCurve(to: CGPoint(x: 32, y: 76),
                          control1: CGPoint(x: 33, y: 68), control2: CGPoint(x: 32, y: 70))
            path.addQuadCurve(to: CGPoint(x: 68, y: 76), control: CGPoint(x: 50, y: 86))
            path.addCurve(to: CGPoint(x: 66, y: 64),
                          control1: CGPoint(x: 68, y: 70), control2: CGPoint(x: 67, y: 68))
            path.closeSubpath()
        }
    }

    private var bubbles: some View {
        ForEach(Array([(45, 3.0, 0.0), (52, 4.0, 0.7), (57, 2.6, 1.4)].enumerated()), id: \.offset) { index, spec in
            Art.orb(p.primary, spec.1, opacity: 0.9)
                .at(CGFloat(spec.0), 70)
                .artEmit(to: CGSize(width: 0, height: -22), scale: 0.5, 2.2, delay: spec.2)
        }
    }
}

/// A ringed planet with a moon, against a starfield.
private struct SpaceScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.sparkles(p.secondary, [(14, 18, 2.5), (30, 30, 1.8), (72, 16, 2.2),
                                       (88, 34, 2.6), (20, 66, 2), (84, 72, 2.4), (58, 14, 1.8)])
            Art.glow(p.primary, 74, opacity: 0.3).at(50, 54)
            Ellipse()
                .strokeBorder(p.detail.opacity(0.75), lineWidth: 3)
                .frame(width: 82, height: 26)
                .rotationEffect(.degrees(-16))
                .at(50, 54)
            Circle()
                .fill(RadialGradient(colors: [p.secondary, p.primary],
                                     center: .init(x: 0.35, y: 0.3), startRadius: 2, endRadius: 30))
                .frame(width: 40, height: 40)
                .at(50, 54)
            Art.orb(p.primary.opacity(0.35), 12).at(41, 47)
            Art.orb(p.primary.opacity(0.3), 8).at(58, 61)
            moon
        }
    }

    private var moon: some View {
        ZStack {
            Art.orb(p.secondary, 8).offset(x: 42)
        }
        .at(50, 54)
        .artSpin(9)
    }
}

/// A three-layer network with the signal sweeping across it.
private struct AITechScene: View {
    let p: TopicPalette

    private let columns: [(x: CGFloat, ys: [CGFloat])] = [
        (24, [34, 50, 66]),
        (50, [28, 43, 58, 73]),
        (76, [40, 60])
    ]

    var body: some View {
        ZStack {
            edges
            nodes
            Art.glow(p.secondary, 56, opacity: 0.28).at(50, 53)
        }
    }

    private var edges: some View {
        Art.stroke(p.primary.opacity(0.3), width: 1) { path in
            for (index, column) in columns.enumerated() where index < columns.count - 1 {
                let next = columns[index + 1]
                for y in column.ys {
                    for ny in next.ys {
                        path.move(to: CGPoint(x: column.x, y: y))
                        path.addLine(to: CGPoint(x: next.x, y: ny))
                    }
                }
            }
        }
    }

    private var nodes: some View {
        ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
            ForEach(Array(column.ys.enumerated()), id: \.offset) { row, y in
                Art.orb(index == 1 ? p.secondary : p.primary, index == 1 ? 8 : 9)
                    .overlay(Art.ring(p.detail, index == 1 ? 8 : 9, width: 1.4, opacity: 0.8))
                    .at(column.x, y)
                    // Layer index drives the delay, so activation reads as a
                    // wave moving left to right through the network.
                    .artPulse(1.3, 1.6, delay: Double(index) * 0.4 + Double(row) * 0.1)
            }
        }
    }
}

/// Two meshed gears turning against each other, and a piston.
private struct EngineeringScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.plate(p.secondary.opacity(0.45), w: 74, h: 18).at(50, 84)
            Art.contact(56).at(50, 82)
            gear(size: 44, teeth: 10, color: p.primary).at(40, 48).artSpin(7)
            gear(size: 30, teeth: 8, color: p.detail).at(72, 62).artSpin(5, clockwise: false)
            Art.orb(p.secondary, 11).at(86, 30).artFloat(2.4, 2.8)
        }
    }

    private func gear(size: CGFloat, teeth: Int, color: Color) -> some View {
        ZStack {
            ForEach(0..<teeth, id: \.self) { index in
                Art.box(color, 6, size + 9, radius: 2)
                    .rotationEffect(.degrees(Double(index) * 180.0 / Double(teeth)))
            }
            Circle().fill(color).frame(width: size, height: size)
            Circle().fill(p.sky.opacity(0.9)).frame(width: size * 0.34, height: size * 0.34)
        }
        .frame(width: size + 10, height: size + 10)
    }
}

/// A double helix, its two strands sliding through each other.
private struct BiologyScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            rungs
            strand(phase: 0, color: p.primary)
            strand(phase: .pi, color: p.secondary)
        }
        .rotationEffect(.degrees(-14))
        .artFloat(2, 4)
    }

    private func strand(phase: Double, color: Color) -> some View {
        Art.stroke(color, width: 3) { path in
            Art.wave(from: 18, to: 82, mid: 50, amplitude: 20, cycles: 1.6, phase: phase, into: &path)
        }
    }

    /// Rungs are drawn at the crossings where the two sines meet, so they line
    /// up with the strands instead of being spaced by eye.
    private var rungs: some View {
        Art.stroke(p.detail.opacity(0.75), width: 1.6) { path in
            let steps = 9
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let x = 18 + (82 - 18) * CGFloat(t)
                let angle = t * 1.6 * 2 * .pi
                let dy = 20 * CGFloat(sin(angle))
                path.move(to: CGPoint(x: x, y: 50 + dy))
                path.addLine(to: CGPoint(x: x, y: 50 - dy))
            }
        }
    }
}

/// An ECG trace with a beating heart behind it.
private struct MedicineScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.glow(p.secondary, 60, opacity: 0.3).at(50, 50)
            heart.at(50, 46).artPulse(1.12, 0.9)
            Art.stroke(p.primary, width: 2.6) { path in
                path.move(to: CGPoint(x: 12, y: 70))
                path.addLine(to: CGPoint(x: 34, y: 70))
                path.addLine(to: CGPoint(x: 40, y: 58))
                path.addLine(to: CGPoint(x: 46, y: 82))
                path.addLine(to: CGPoint(x: 53, y: 62))
                path.addLine(to: CGPoint(x: 60, y: 70))
                path.addLine(to: CGPoint(x: 88, y: 70))
            }
            Art.orb(p.detail, 5).at(46, 82).artPulse(1.5, 0.9)
            Art.box(p.primary, 14, 4, radius: 2, opacity: 0.9).at(74, 34)
            Art.box(p.primary, 4, 14, radius: 2, opacity: 0.9).at(74, 34)
        }
    }

    private var heart: some View {
        Art.shape(p.secondary, 28, 28) { path in
            path.move(to: CGPoint(x: 14, y: 26))
            path.addCurve(to: CGPoint(x: 0, y: 9),
                          control1: CGPoint(x: 5, y: 20), control2: CGPoint(x: 0, y: 15))
            path.addArc(center: CGPoint(x: 7, y: 8), radius: 7,
                        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            path.addArc(center: CGPoint(x: 21, y: 8), radius: 7,
                        startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            path.addCurve(to: CGPoint(x: 14, y: 26),
                          control1: CGPoint(x: 28, y: 15), control2: CGPoint(x: 23, y: 20))
            path.closeSubpath()
        }
    }
}

/// A petri dish of cells, one of them dividing.
private struct GeneticsScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Circle().fill(p.primary.opacity(0.16)).frame(width: 66, height: 66).at(50, 52)
            Art.ring(p.primary, 66, width: 2.4, opacity: 0.85).at(50, 52)
            Art.ring(p.primary, 54, width: 1, opacity: 0.3).at(50, 52)
            cell(at: CGPoint(x: 38, y: 40), size: 15, delay: 0)
            cell(at: CGPoint(x: 62, y: 46), size: 12, delay: 0.6)
            cell(at: CGPoint(x: 44, y: 65), size: 13, delay: 1.2)
            Art.orb(p.detail, 6).at(64, 66).artPulse(1.4, 2, delay: 0.3)
        }
    }

    /// Two lobes pulling apart and back — mitosis, in the smallest number of
    /// moving parts that still reads as division.
    private func cell(at point: CGPoint, size: CGFloat, delay: Double) -> some View {
        ZStack {
            Art.orb(p.secondary, size, opacity: 0.9)
                .overlay(Art.orb(p.detail, size * 0.35))
                .artDrift(x: -size * 0.22, 2.6, delay: delay)
            Art.orb(p.secondary, size, opacity: 0.9)
                .overlay(Art.orb(p.detail, size * 0.35))
                .artDrift(x: size * 0.22, 2.6, delay: delay)
        }
        .at(point.x, point.y)
    }
}

/// A trail of paw prints crossing the frame, appearing in sequence.
private struct ZoologyScene: View {
    let p: TopicPalette

    private let prints: [(CGFloat, CGFloat)] = [(20, 74), (34, 64), (48, 70), (62, 58), (76, 64)]

    var body: some View {
        ZStack {
            Art.plate(p.ground.opacity(0.4), w: 86, h: 26).at(50, 76)
            tuft.at(84, 62).artSway(9, 3.2, anchor: .bottom)
            tuft.at(15, 68).artSway(-8, 3.8, anchor: .bottom)
            ForEach(Array(prints.enumerated()), id: \.offset) { index, point in
                paw.at(point.0, point.1)
                    .artPulse(1.2, 2.6, delay: Double(index) * 0.45)
            }
        }
    }

    /// Flat and squashed on purpose: a print is pressed *into* the ground, so
    /// it takes no highlight. Shading these made every toe a marble.
    private var paw: some View {
        ZStack {
            pad(10, 7).offset(y: 2)
            pad(4, 3.4).offset(x: -5, y: -5)
            pad(4, 3.4).offset(x: 0, y: -6.5)
            pad(4, 3.4).offset(x: 5, y: -5)
        }
        .frame(width: 14, height: 16)
    }

    private func pad(_ w: CGFloat, _ h: CGFloat) -> some View {
        Ellipse().fill(p.primary.opacity(0.9)).frame(width: w, height: h)
    }

    /// Three blades fanning from one point on the ground.
    private var tuft: some View {
        ZStack {
            ForEach([-22.0, 0.0, 20.0], id: \.self) { angle in
                Art.box(p.secondary, 3, 18, radius: 1.5, opacity: 0.9)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
            }
        }
        .frame(width: 20, height: 18)
    }
}

/// A sprout coming up between two hills, under a low sun.
private struct EcologyScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.orb(p.detail, 18, opacity: 0.9).at(78, 26).artPulse(1.1, 3.4)
            Art.glow(p.detail, 46, opacity: 0.35).at(78, 26)
            hill(w: 72, h: 34, color: p.secondary.opacity(0.55)).at(30, 84)
            hill(w: 60, h: 26, color: p.ground.opacity(0.8)).at(72, 88)
            stem
            sproutLeaf(flip: false).at(41, 58).artSway(9, 2.8, anchor: .bottomTrailing)
            sproutLeaf(flip: true).at(59, 53).artSway(-9, 3.2, anchor: .bottomLeading)
        }
    }

    private func hill(w: CGFloat, h: CGFloat, color: Color) -> some View {
        Ellipse().fill(color).frame(width: w, height: h)
    }

    private var stem: some View {
        Art.stroke(p.primary, width: 3) { path in
            path.move(to: CGPoint(x: 50, y: 78))
            path.addQuadCurve(to: CGPoint(x: 50, y: 50), control: CGPoint(x: 46, y: 64))
        }
    }

    /// An ellipse reads as a leaf at 20pt where a drawn sliver read as a
    /// bracket. Cheaper, too.
    private func sproutLeaf(flip: Bool) -> some View {
        Ellipse()
            .fill(p.primary)
            .frame(width: 22, height: 12)
            .rotationEffect(.degrees(flip ? 26 : -26))
    }
}

/// A neuron: soma, dendrites, and a spike running down the axon.
private struct NeuroscienceScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.glow(p.primary, 58, opacity: 0.3).at(36, 48)
            dendrites
            axon
            Art.orb(p.primary, 22).at(36, 48)
            Art.orb(p.detail, 9, opacity: 0.85).at(36, 48).artPulse(1.2, 1.5)
            spike
            Art.orb(p.secondary, 7).at(86, 66)
        }
    }

    private var dendrites: some View {
        Art.stroke(p.primary.opacity(0.85), width: 2.2) { path in
            for angle in stride(from: 110.0, through: 250.0, by: 35.0) {
                let radians = angle * .pi / 180
                path.move(to: CGPoint(x: 36, y: 48))
                path.addLine(to: CGPoint(x: 36 + 26 * cos(radians), y: 48 + 26 * sin(radians)))
            }
        }
    }

    private var axon: some View {
        Art.stroke(p.secondary.opacity(0.9), width: 2.6) { path in
            path.move(to: CGPoint(x: 52, y: 52))
            path.addQuadCurve(to: CGPoint(x: 86, y: 66), control: CGPoint(x: 70, y: 46))
        }
    }

    /// Rides the axon as an emitted pulse: it fades out before the offset
    /// resets, so the return trip is never visible.
    private var spike: some View {
        Art.orb(p.detail, 7)
            .at(54, 52)
            .artEmit(to: CGSize(width: 32, height: 14), scale: 0.7, 1.6)
    }
}

// MARK: - Humanities

/// A classical temple with dust drifting in the light.
private struct HistoryScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.glow(p.detail, 72, opacity: 0.3).at(50, 40)
            Art.fill(p.primary) { path in
                path.move(to: CGPoint(x: 50, y: 22))
                path.addLine(to: CGPoint(x: 82, y: 40))
                path.addLine(to: CGPoint(x: 18, y: 40))
                path.closeSubpath()
            }
            ForEach(0..<5) { index in
                Art.box(p.primary, 8, 30, radius: 1).at(26 + CGFloat(index) * 12, 57)
            }
            Art.box(p.primary, 70, 5, radius: 1.5).at(50, 43)
            Art.box(p.primary, 76, 6, radius: 2).at(50, 75)
            Art.box(p.secondary.opacity(0.7), 84, 5, radius: 2).at(50, 81)
            Art.contact(72, opacity: 0.26).at(50, 85)
            Art.sparkles(p.detail, [(24, 30, 2.4), (74, 28, 2), (34, 62, 1.8), (68, 60, 2.2)])
        }
    }
}

/// Thought bubbles rising from a plinth.
private struct PhilosophyScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.plate(p.ground.opacity(0.5), w: 56, h: 16).at(50, 84)
            Art.contact(38).at(50, 82)
            Art.box(p.primary.opacity(0.9), 24, 26, radius: 3).at(50, 68)
            Art.box(p.primary, 32, 5, radius: 2).at(50, 53)
            Art.orb(p.detail, 13, opacity: 0.9).at(50, 40).artFloat(3, 3.2)
            bubble(24, 5).artFloat(4, 2.6, delay: 0.2)
            bubble(30, 8).artFloat(5, 3, delay: 0.6)
            bubble(20, 11).artFloat(6, 3.6, delay: 1)
            Art.sparkles(p.secondary, [(72, 34, 2.6), (28, 28, 2.2), (78, 60, 2)])
        }
    }

    private func bubble(_ y: CGFloat, _ size: CGFloat) -> some View {
        Art.ring(p.primary, size, width: 1.6, opacity: 0.8).at(50 + size * 0.9, y)
    }
}

/// Speech bubbles carrying glyphs from different scripts.
private struct LanguageScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            bubble(w: 46, h: 30, color: p.primary, glyph: "あ", glyphColor: p.sky, size: 15)
                .at(38, 42).artFloat(2, 3)
            bubble(w: 38, h: 26, color: p.secondary, glyph: "文", glyphColor: p.sky, size: 13)
                .at(66, 66).artFloat(2.4, 3.6, delay: 0.6)
            Art.orb(p.detail, 6).at(20, 74).artPulse(1.3, 2)
            Art.orb(p.detail, 4).at(84, 30).artPulse(1.3, 2.4, delay: 0.4)
        }
    }

    private func bubble(w: CGFloat, h: CGFloat, color: Color,
                        glyph: String, glyphColor: Color, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: h / 2.6).fill(color).frame(width: w, height: h)
            Text(glyph)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(glyphColor)
        }
        .frame(width: w, height: h)
    }
}

/// A carved stone head standing on excavated strata.
private struct AnthropologyScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Art.box(index == 1 ? p.secondary : p.ground, 92, 9, radius: 2,
                        opacity: 0.55 + Double(index) * 0.12)
                    .at(50, 70 + CGFloat(index) * 10)
            }
            head.at(50, 44).artFloat(1.4, 4.2)
            Art.orb(p.detail, 5).at(78, 40).artPulse(1.4, 2.2)
            Art.orb(p.detail, 3.5).at(22, 34).artPulse(1.4, 2.6, delay: 0.5)
        }
    }

    private var head: some View {
        ZStack {
            Art.shape(p.primary, 30, 44) { path in
                path.addRoundedRect(in: CGRect(x: 0, y: 0, width: 30, height: 44),
                                    cornerSize: CGSize(width: 11, height: 14))
            }
            Art.box(p.sky.opacity(0.75), 5, 6, radius: 2).offset(x: -6, y: -5)
            Art.box(p.sky.opacity(0.75), 5, 6, radius: 2).offset(x: 6, y: -5)
            Art.box(p.sky.opacity(0.55), 12, 3, radius: 1.5).offset(y: 9)
        }
        .frame(width: 30, height: 44)
    }
}

/// A wireframe globe turning, with a dropped pin.
private struct GeographyScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.glow(p.secondary, 70, opacity: 0.28).at(50, 52)
            Circle().fill(p.primary.opacity(0.2)).frame(width: 56, height: 56).at(50, 52)
            Art.ring(p.primary, 56, width: 2.2, opacity: 0.9).at(50, 52)
            ForEach(0..<3) { index in
                Ellipse()
                    .strokeBorder(p.primary.opacity(0.4), lineWidth: 1.2)
                    .frame(width: 56, height: 18 + CGFloat(index) * 0)
                    .at(50, 38 + CGFloat(index) * 14)
            }
            meridians
            landmass.at(44, 48)
            pin.at(64, 40).artFloat(2.4, 2.2)
        }
    }

    private var meridians: some View {
        ZStack {
            Ellipse().strokeBorder(p.primary.opacity(0.5), lineWidth: 1.2)
                .frame(width: 22, height: 56)
            Ellipse().strokeBorder(p.primary.opacity(0.3), lineWidth: 1.2)
                .frame(width: 44, height: 56)
        }
        .at(50, 52)
        .artSpin(14)
    }

    private var landmass: some View {
        Art.shape(p.secondary.opacity(0.9), 22, 16) { path in
            path.move(to: CGPoint(x: 2, y: 8))
            path.addQuadCurve(to: CGPoint(x: 14, y: 1), control: CGPoint(x: 7, y: 0))
            path.addQuadCurve(to: CGPoint(x: 18, y: 12), control: CGPoint(x: 21, y: 6))
            path.addQuadCurve(to: CGPoint(x: 2, y: 8), control: CGPoint(x: 9, y: 15))
        }
    }

    private var pin: some View {
        ZStack {
            Art.shape(p.detail, 12, 16) { path in
                path.move(to: CGPoint(x: 6, y: 16))
                path.addQuadCurve(to: CGPoint(x: 0, y: 6), control: CGPoint(x: 0, y: 12))
                path.addArc(center: CGPoint(x: 6, y: 6), radius: 6,
                            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                path.addQuadCurve(to: CGPoint(x: 6, y: 16), control: CGPoint(x: 12, y: 12))
            }
            Art.orb(p.primary, 4).offset(y: -2)
        }
        .frame(width: 12, height: 16)
    }
}

// MARK: - Society

/// A head with the mind turning inside it.
///
/// Drawn front-on. The profile version needed a brow, nose, lips and chin
/// inside 40pt and resolved into an unreadable blob; a sphere with a spiral in
/// it says "mind" at any size. The spiral is authored around the canvas centre
/// and spun without being repositioned — offsetting it would make it orbit the
/// frame centre rather than turn on its own axis, which is what broke it.
private struct PsychologyScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.glow(p.detail, 68, opacity: 0.3).at(50, 50)
            // The shoulders overlap the head's lower edge rather than meeting
            // it. Any visible gap turned the neck into a stick and the head
            // into a lollipop.
            Ellipse()
                .fill(Art.shade(p.primary.mix(with: .white, by: 0.1), lift: 0, drop: 0.05))
                .frame(width: 90, height: 34)
                .at(50, 81)
            Art.orb(p.primary, 39).at(50, 47)
            spiral.artSpin(14)
            Art.orb(p.secondary, 6).at(80, 27).artFloat(2.6, 2.4)
            Art.orb(p.secondary, 4).at(88, 41).artFloat(2, 2.8, delay: 0.4)
            Art.orb(p.secondary, 3).at(73, 17).artFloat(1.6, 3.2, delay: 0.8)
        }
    }

    private var spiral: some View {
        Art.stroke(p.sky.opacity(0.9), width: 2.6) { path in
            var radius: CGFloat = 1
            path.move(to: CGPoint(x: 50, y: 50))
            for step in 0...52 {
                let angle = Double(step) * 0.42
                radius += 0.3
                path.addLine(to: CGPoint(x: 50 + radius * CGFloat(cos(angle)),
                                         y: 50 + radius * CGFloat(sin(angle))))
            }
        }
    }
}

/// A speaker's podium with a flag stirring above it.
private struct PoliticsScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.plate(p.ground.opacity(0.45), w: 76, h: 18).at(50, 86)
            Art.contact(52).at(50, 83)
            Art.box(p.secondary, 3, 40, radius: 1.5).at(30, 50)
            flag.at(52, 34).artSway(5, 2.4, anchor: .leading)
            Art.fill(p.primary) { path in
                path.move(to: CGPoint(x: 34, y: 82))
                path.addLine(to: CGPoint(x: 40, y: 58))
                path.addLine(to: CGPoint(x: 74, y: 58))
                path.addLine(to: CGPoint(x: 80, y: 82))
                path.closeSubpath()
            }
            Art.box(p.detail, 40, 4, radius: 2).at(57, 56)
            Art.orb(p.secondary, 8).at(57, 46).artPulse(1.12, 2)
        }
    }

    private var flag: some View {
        Art.shape(p.detail, 34, 22) { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 34, y: 4))
            path.addLine(to: CGPoint(x: 34, y: 22))
            path.addLine(to: CGPoint(x: 0, y: 18))
            path.closeSubpath()
        }
    }
}

/// A balance tipping slowly between two pans.
private struct SocialIssuesScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.box(p.primary, 4, 44, radius: 2).at(50, 56)
            Art.box(p.primary, 34, 5, radius: 2.5).at(50, 82)
            Art.orb(p.detail, 9).at(50, 30)
            beam.at(50, 34).artSway(9, 3.4)
        }
    }

    /// Beam and pans rotate as one group; the pans counter-rotate so they hang
    /// level however far the beam tips.
    private var beam: some View {
        ZStack {
            Art.box(p.primary, 62, 4, radius: 2)
            pan.offset(x: -28, y: 14)
            pan.offset(x: 28, y: 14)
        }
        .frame(width: 62, height: 32)
    }

    private var pan: some View {
        ZStack {
            Art.box(p.primary.opacity(0.6), 1.5, 12, radius: 0.5).offset(y: -6)
            Art.shape(p.secondary, 20, 10) { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: 20, y: 0), control: CGPoint(x: 10, y: 10))
                path.closeSubpath()
            }
            .offset(y: 4)
        }
        .frame(width: 20, height: 22)
    }
}

/// A mortarboard over a stack of books, tassel swinging.
private struct EducationScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.contact(54).at(50, 84)
            Art.box(p.secondary, 46, 8, radius: 2).at(50, 78)
            Art.box(p.detail, 40, 8, radius: 2).at(50, 69)
            Art.box(p.primary.opacity(0.85), 34, 8, radius: 2).at(50, 60)
            Art.fill(p.primary) { path in
                path.move(to: CGPoint(x: 50, y: 26))
                path.addLine(to: CGPoint(x: 86, y: 40))
                path.addLine(to: CGPoint(x: 50, y: 52))
                path.addLine(to: CGPoint(x: 14, y: 40))
                path.closeSubpath()
            }
            Art.box(p.primary.opacity(0.9), 22, 10, radius: 2).at(50, 50)
            tassel
            Art.sparkles(p.detail, [(22, 22, 2.6), (80, 20, 2.2), (88, 60, 2)])
        }
    }

    private var tassel: some View {
        ZStack {
            Art.stroke(p.detail, width: 1.8) { path in
                path.move(to: CGPoint(x: 78, y: 40))
                path.addQuadCurve(to: CGPoint(x: 84, y: 58), control: CGPoint(x: 84, y: 48))
            }
            Art.orb(p.detail, 6).at(84, 60)
        }
        .artSway(8, 2.6, anchor: .init(x: 0.78, y: 0.4))
    }
}

// MARK: - Business

/// Bars stepping up under a rising trend line.
private struct EconomicsScene: View {
    let p: TopicPalette

    private let bars: [(x: CGFloat, h: CGFloat)] = [(28, 20), (43, 32), (58, 44), (73, 58)]

    var body: some View {
        ZStack {
            Art.box(p.primary, 76, 2, radius: 1, opacity: 0.35).at(50, 80)
            ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                Art.box(index == bars.count - 1 ? p.secondary : p.primary, 12, bar.h, radius: 3)
                    .at(bar.x, 79 - bar.h / 2)
                    .artFloat(1.6, 2.2, delay: Double(index) * 0.25)
            }
            Art.stroke(p.detail, width: 2.4) { path in
                path.move(to: CGPoint(x: 22, y: 62))
                path.addLine(to: CGPoint(x: 43, y: 46))
                path.addLine(to: CGPoint(x: 58, y: 34))
                path.addLine(to: CGPoint(x: 80, y: 18))
            }
            arrow.at(80, 18).artPulse(1.2, 1.8)
        }
    }

    private var arrow: some View {
        Art.shape(p.detail, 11, 11) { path in
            path.move(to: CGPoint(x: 0, y: 11))
            path.addLine(to: CGPoint(x: 11, y: 11))
            path.addLine(to: CGPoint(x: 11, y: 0))
            path.closeSubpath()
        }
    }
}

/// A stack of coins with one flipping above it.
private struct FinanceScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.glow(p.primary, 62, opacity: 0.3).at(50, 58)
            Art.contact(48).at(50, 85)
            ForEach(0..<4) { index in
                coin(p.ground).at(50, 78 - CGFloat(index) * 8)
            }
            coin(p.primary).at(50, 34).artFloat(4, 2.4)
            Art.orb(p.detail, 5).at(78, 46).artPulse(1.4, 2)
            Art.orb(p.detail, 3.5).at(22, 40).artPulse(1.4, 2.4, delay: 0.4)
        }
    }

    /// The rim is what separates one coin from the next — without it a stack of
    /// same-coloured ellipses blurs into a single lump.
    private func coin(_ color: Color) -> some View {
        ZStack {
            Ellipse().fill(color).frame(width: 38, height: 14)
            Ellipse().strokeBorder(p.sky.opacity(0.55), lineWidth: 1.2).frame(width: 38, height: 14)
            Ellipse().strokeBorder(p.sky.opacity(0.28), lineWidth: 1.2).frame(width: 24, height: 7)
        }
        .frame(width: 38, height: 14)
    }
}

// MARK: - Lifestyle

/// A dumbbell with an expanding pulse ring behind it.
private struct HealthScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            ForEach(0..<2) { index in
                Art.ring(p.secondary, 30, width: 2.6, opacity: 0.75)
                    .at(50, 52)
                    .artEmit(scale: 1.85, 2.2, delay: Double(index) * 1.1)
            }
            Art.contact(46).at(50, 74)
            Art.box(p.primary, 34, 7, radius: 3.5).at(50, 52)
            weight(18).at(30, 52)
            weight(18).at(70, 52)
            Art.orb(p.detail, 6).at(76, 26).artFloat(2.6, 2.2)
            Art.stroke(p.detail, width: 2.2) { path in
                path.move(to: CGPoint(x: 18, y: 80))
                path.addLine(to: CGPoint(x: 30, y: 80))
                path.addLine(to: CGPoint(x: 36, y: 72))
                path.addLine(to: CGPoint(x: 42, y: 86))
                path.addLine(to: CGPoint(x: 48, y: 80))
                path.addLine(to: CGPoint(x: 82, y: 80))
            }
        }
    }

    private func weight(_ size: CGFloat) -> some View {
        Art.box(p.primary, size * 0.55, size, radius: 4)
    }
}

/// A checklist ticking itself off, with a bolt above.
private struct ProductivityScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.box(p.primary, 60, 60, radius: 8, opacity: 0.95).at(50, 56)
            ForEach(0..<3) { index in
                row(y: 42 + CGFloat(index) * 14, delay: Double(index) * 0.7)
            }
            bolt.at(76, 22).artPulse(1.18, 1.6)
        }
    }

    private func row(y: CGFloat, delay: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(p.detail)
                .frame(width: 10, height: 10)
                .at(32, y)
                .artPulse(1.2, 2.4, delay: delay)
            Art.box(p.sky.opacity(0.35), 26, 4, radius: 2).at(56, y)
        }
    }

    private var bolt: some View {
        Art.shape(p.secondary, 16, 24) { path in
            path.move(to: CGPoint(x: 10, y: 0))
            path.addLine(to: CGPoint(x: 2, y: 13))
            path.addLine(to: CGPoint(x: 8, y: 13))
            path.addLine(to: CGPoint(x: 5, y: 24))
            path.addLine(to: CGPoint(x: 15, y: 9))
            path.addLine(to: CGPoint(x: 9, y: 9))
            path.closeSubpath()
        }
    }
}

// MARK: - General

/// A crystal ball on a stand, mist turning inside it.
private struct CuriositiesScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            Art.fill(p.ground.opacity(0.9)) { path in
                path.move(to: CGPoint(x: 34, y: 84))
                path.addLine(to: CGPoint(x: 40, y: 72))
                path.addLine(to: CGPoint(x: 60, y: 72))
                path.addLine(to: CGPoint(x: 66, y: 84))
                path.closeSubpath()
            }
            Art.glow(p.secondary, 76, opacity: 0.35).at(50, 46)
            Circle()
                .fill(RadialGradient(colors: [p.primary.opacity(0.95), p.secondary.opacity(0.5)],
                                     center: .init(x: 0.36, y: 0.3), startRadius: 2, endRadius: 34))
                .frame(width: 48, height: 48)
                .at(50, 46)
            mist.at(50, 46).artSpin(13)
            Art.orb(.white, 8, opacity: 0.55).at(40, 36)
            Art.sparkles(p.detail, [(20, 30, 3), (80, 34, 2.6), (26, 66, 2.2), (78, 66, 2.8), (50, 16, 2.4)])
        }
    }

    private var mist: some View {
        ZStack {
            Ellipse().fill(p.secondary.opacity(0.35)).frame(width: 34, height: 12).offset(y: -5)
            Ellipse().fill(p.detail.opacity(0.25)).frame(width: 26, height: 10).offset(y: 7)
        }
        .clipShape(Circle())
    }
}

/// A filament bulb with rays coming off it.
private struct BigIdeasScene: View {
    let p: TopicPalette

    var body: some View {
        ZStack {
            rays.artSpin(24)
            Art.glow(p.detail, 78, opacity: 0.4).at(50, 48)
            Circle().fill(p.primary).frame(width: 40, height: 40).at(50, 44)
            Art.box(p.secondary.opacity(0.85), 18, 6, radius: 2).at(50, 68)
            Art.box(p.secondary.opacity(0.7), 14, 5, radius: 2).at(50, 75)
            Art.stroke(p.secondary, width: 2.2) { path in
                path.move(to: CGPoint(x: 43, y: 56))
                path.addLine(to: CGPoint(x: 45, y: 44))
                path.addLine(to: CGPoint(x: 50, y: 50))
                path.addLine(to: CGPoint(x: 55, y: 44))
                path.addLine(to: CGPoint(x: 57, y: 56))
            }
            .artPulse(1.06, 1.4)
        }
    }

    private var rays: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Art.box(p.detail, 3, 12, radius: 1.5, opacity: 0.85)
                    .offset(y: -34)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
        .frame(width: 92, height: 92)
        .at(50, 44)
    }
}
