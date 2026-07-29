//
//  ScholarApp.swift
//  Scholar
//

import SwiftUI

@main
struct ScholarApp: App {
    @State private var store = Store()

    init() {
        // `.playback` has to be live before the first web view or AVPlayer
        // starts, otherwise audio is silenced by the ring switch.
        AudioEngine.activateSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
