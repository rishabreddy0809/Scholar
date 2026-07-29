//
//  Theme.swift
//  Scholar
//

import SwiftUI

enum Theme {
    static let bg = Color(hex: 0x0B0B0F)
    static let surface = Color(hex: 0x16161D)
    static let surfaceHi = Color(hex: 0x22222C)
    static let stroke = Color.white.opacity(0.08)

    static let text = Color.white
    static let textDim = Color.white.opacity(0.62)
    static let textFaint = Color.white.opacity(0.38)

    static let accent = Color(hex: 0x7C5CFF)
    static let accentSoft = Color(hex: 0x9B84FF)
    static let up = Color(hex: 0x4ADE80)
    static let down = Color(hex: 0xF87171)
    static let flame = Color(hex: 0xFF8A3D)

    /// The purple "Welcome back!" header gradient from the dashboard.
    static let welcomeGradient = LinearGradient(
        colors: [Color(hex: 0x6D4AFF), Color(hex: 0x8E6BFF)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    nonisolated init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension View {
    /// Card treatment used across the dashboard and library.
    func cardSurface(_ radius: CGFloat = 18) -> some View {
        background(Theme.surface, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}
