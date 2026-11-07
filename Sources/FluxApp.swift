import SwiftUI

@main
struct FluxApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                #if DEBUG
                .preferredColorScheme(DemoScenario.appearance) // for the screenshots, see DemoMode.swift
                #endif
        }
    }
}
