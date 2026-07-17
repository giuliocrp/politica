//
//  PoliticiApp.swift
//  Politici
//
//  Created by Giulio Carpi Lapi on 16/07/2026.
//

import SwiftUI

@main
struct PoliticiApp: App {
    /// Composition root: services are constructed once here and injected
    /// into the view hierarchy via the environment (see `ServiceContainer`).
    private let services = ServiceContainer.live

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.services, services)
        }
    }
}
