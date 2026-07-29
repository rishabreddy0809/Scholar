//
//  MorphingTabBar.swift
//  Scholar
//
//  Created by Rishab Reddy on 2/20/26.
//
//  The only part changed from the original is the background: the hand-rolled
//  `GlassEffectPlaceholder` is now real Liquid Glass, built on the SwiftUI API
//  (`GlassEffectContainer` + `.glassEffect(_:in:)`, both iOS 26+, which this
//  app already targets).
//

import SwiftUI
import UIKit

protocol MorphingTabProtocol: CaseIterable, Hashable {
    var symbolImage: String { get }
}

struct MorphingTabBar<Tab: MorphingTabProtocol, ExpandedContent: View>: View {
    @Binding var activeTab: Tab
    @Binding var isExpanded: Bool
    @ViewBuilder var expandedContent: ExpandedContent
    @State private var viewWidth: CGFloat?
    var body: some View {

        ZStack {
            Spacer()
            let symbols = Array(Tab.allCases).compactMap({ $0.symbolImage})
            let selectedIndex = Binding {
                return symbols.firstIndex(of: activeTab.symbolImage) ?? 0
            } set: { Index in
                activeTab = Array(Tab.allCases)[Index]
            }


            if let viewWidth {

                let progress: CGFloat = isExpanded ? 1 : 0
                let labelSize: CGSize = CGSize(width: viewWidth, height: 52)
                let cornerRadius: CGFloat = labelSize.height / 2

                ZStack {
                    GlassEffectBackground(
                        alignment: .center,
                        progress: CGFloat(progress),
                        labelSize: labelSize,
                        cornerRadius: cornerRadius
                    )

                    CustomTabBar(symbols: symbols, index: selectedIndex) { image in
                        let font = UIFont.systemFont(ofSize: 21)
                        let configuration = UIImage.SymbolConfiguration(font: font)
                        return UIImage(systemName: image, withConfiguration: configuration)
                    }
                }
                .frame(width: labelSize.width, height: labelSize.height)
                // No manual border: Liquid Glass draws its own specular edge,
                // and a hand-drawn stroke on top of it reads as a hard white
                // outline rather than a lit rim.
                .shadow(color: Color.black.opacity(0.03), radius: 14, x: 0, y: 10) // stronger drop shadow under
                .shadow(color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1) // subtle contact shadow


            }
        }
        // Matches the bar itself. At 64 the extra 12pt was split above and
        // below the 52pt bar, holding it clear of the bottom of the screen.
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: { newValue in
            viewWidth = newValue
        }
        .frame(height: viewWidth == nil ? 52 : nil)

    }
}

fileprivate struct CustomTabBar: UIViewRepresentable {
    /// Selection pill, matched to the app's accent rather than system blue.
    var tint: Color = Theme.accent
    var symbols: [String]
    @Binding var index: Int
    var image: (String) -> UIImage?

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: symbols.map { title in
            if let img = image(title) {
                return img
            } else {
                return UIImage(systemName: title) ?? UIImage()
            }
        })

        control.selectedSegmentIndex = index
        control.backgroundColor = .clear
        control.selectedSegmentTintColor = UIColor(tint).withAlphaComponent(0.32)
        // Increase vertical padding to make the control appear taller
        control.setContentOffset(.zero, forSegmentAt: 0) // no-op safeguard
        control.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 18, weight: .medium)], for: .normal)
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)

        applyIconTint(control)

        DispatchQueue.main.async {
            for view in control.subviews.dropLast() {
                if view is UIImageView {
                    view.alpha = 0
                }
            }
        }

        return control
    }

    private func applyIconTint(_ control: UISegmentedControl) {
        for i in symbols.indices {
            let isSelected = i == index
            let color = isSelected ? UIColor(Theme.text) : UIColor(Theme.textFaint)
            if let base = image(symbols[i]) ?? UIImage(systemName: symbols[i]) {
                let tinted = base.withTintColor(color, renderingMode: .alwaysOriginal)
                control.setImage(tinted, forSegmentAt: i)
            }
        }
    }

    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        // Keep selection in sync
        if uiView.selectedSegmentIndex != index {
            uiView.selectedSegmentIndex = index
        }
        applyIconTint(uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: CustomTabBar
        init(parent: CustomTabBar) {
            self.parent = parent
        }
        @objc func valueChanged(_ sender: UISegmentedControl) {
            parent.index = sender.selectedSegmentIndex
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return proposal.replacingUnspecifiedDimensions()
    }
}

/// The real Liquid Glass background, in place of the hand-rolled material.
///
/// `.glassEffect(_:in:)` renders the system material — refraction, specular
/// edge and adaptive tint — in the shape it is given, and `GlassEffectContainer`
/// is what lets glass in the same container blend rather than stack. The
/// original's `.opacity(progress)` fade is gone: real glass carries its own
/// translucency, and dimming it just makes the material look switched off.
fileprivate struct GlassEffectBackground: View {
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize
    var cornerRadius: CGFloat

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            Color.clear
                .frame(width: max(labelSize.width, 0),
                       height: max(labelSize.height, 0),
                       alignment: alignment)
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: max(8, cornerRadius), style: .continuous)
                )
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ContentView().environment(Store())
}
