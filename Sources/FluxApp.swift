import SwiftUI

@main
struct FluxApp: App {
    @AppStorage(Appearance.key) private var appearance: Appearance = .automatic

    /// The choice under Settings > Appearance. In a demo launch, `-FluxAppearance` comes first, for the
    /// screenshots (see DemoMode.swift).
    private var scheme: ColorScheme? {
        #if DEBUG
        if let forced = DemoScenario.appearance { return forced }
        #endif
        return appearance.scheme
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(scheme)
        }
    }
}
