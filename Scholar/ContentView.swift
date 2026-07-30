//
//  ContentView.swift
//  Scholar
//

import SwiftUI

enum AppRoute: Hashable {
    case feed, listen, dashboard, saved
    case topic(String)
    case generated(GeneratedFeed)
    case material(StudyMaterial)

    var tab: Tab? {
        switch self {
        case .feed:      return .feed
        case .listen:    return .listen
        case .dashboard: return .dashboard
        case .saved:     return .saved
        default:         return nil
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case feed, listen, dashboard, saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed:      return "Feed"
        case .listen:    return "Listen"
        case .dashboard: return "Topics"
        case .saved:     return "Saved"
        }
    }

    var icon: String {
        switch self {
        case .feed:      return "play.square.stack.fill"
        case .listen:    return "waveform"
        case .dashboard: return "square.grid.2x2.fill"
        case .saved:     return "bookmark.fill"
        }
    }

    var route: AppRoute {
        switch self {
        case .feed:      return .feed
        case .listen:    return .listen
        case .dashboard: return .dashboard
        case .saved:     return .saved
        }
    }
}

extension Tab: MorphingTabProtocol {
    var symbolImage: String { icon }
}

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var tab: Tab = .feed
    @State private var route: AppRoute = .feed
    @State private var focused: AppRoute?
    @State private var audio = AudioEngine.shared
    @State private var isTabBarExpanded = false

    var body: some View {
        Group {
            if store.hasOnboarded {
                main
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: store.hasOnboarded)
    }

    private var main: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            content

            // Spacing lives on the mini player rather than the stack: as a
            // stack spacing it was still reserved when nothing is pinned,
            // holding the tab bar 8pt off the bottom for no reason.
            VStack(spacing: 0) {
                MiniPlayer()
                    .padding(.bottom, 8)
                tabBar
            }
            .animation(.spring(duration: 0.3), value: audio.isPinned)
        }
        .fullScreenCover(item: $focused) { focusedFeed($0) }
        .task {
            // Catches up any document imported before Apple Intelligence was
            // available. No-op on hardware that doesn't have it.
            await store.analyseMaterialsIfNeeded()
        }
        .onChange(of: route) { _, newRoute in
            if case .material(let material) = newRoute {
                // Focusing a document takes over the main feed rather than
                // opening yet another screen on top of it.
                store.activeMaterialID = material.id
                tab = .feed
            } else if let newTab = newRoute.tab {
                tab = newTab
            } else {
                focused = newRoute
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .feed:
            // The feed tab is shorts only — even in study mode. Episodes for a
            // document live in Listen, so the two tabs never show each other's
            // content.
            if let material = store.activeMaterial {
                PagingFeedView(kind: .shorts, source: .material(material),
                               title: material.title, focusedMaterial: material)
                    .id(material.id)
            } else {
                PagingFeedView(
                    kind: .shorts,
                    source: .interests(Array(store.selectedInterestIDs)),
                    title: "Scholar",
                    followsInterests: true
                )
            }
        case .listen:
            if let material = store.activeMaterial {
                PagingFeedView(kind: .podcasts, source: .material(material),
                               title: material.title, focusedMaterial: material)
                    .id(material.id)
            } else {
                PagingFeedView(
                    kind: .podcasts,
                    source: .interests(Array(store.selectedInterestIDs)),
                    title: "Listen",
                    followsInterests: true
                )
            }
        case .dashboard:
            DashboardView(route: $route)
        case .saved:
            LibraryView()
        }
    }

    @ViewBuilder
    private func focusedFeed(_ route: AppRoute) -> some View {
        switch route {
        case .generated(let feed):
            PagingFeedView(
                kind: .mixed,
                source: .generated(feed),
                title: feed.title,
                onClose: { focused = nil }
            )
        case .topic(let id):
            PagingFeedView(
                kind: .shorts,
                source: .interests([id]),
                title: Interest.find(id)?.name ?? "Topic",
                onClose: { focused = nil }
            )
        case .material:
            EmptyView()
        default:
            EmptyView()
        }
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        MorphingTabBar(activeTab: tabSelection, isExpanded: $isTabBarExpanded) {}
            .padding(.horizontal, 12)
    }

    /// The bar drives `tab` directly, but every selection also has to move
    /// `route` — that is what the dashboard pushes through to open a topic.
    private var tabSelection: Binding<Tab> {
        Binding {
            tab
        } set: { selected in
            tab = selected
            route = selected.route
        }
    }
}

extension AppRoute: Identifiable {
    var id: String {
        switch self {
        case .feed:                return "feed"
        case .listen:              return "listen"
        case .dashboard:           return "dashboard"
        case .saved:               return "saved"
        case .topic(let id):           return "topic-\(id)"
        case .generated(let feed):     return "generated-\(feed.id.uuidString)"
        case .material(let material):  return "material-\(material.id.uuidString)"
        }
    }
}

#Preview {
    ContentView().environment(Store())
}
