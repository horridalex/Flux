import ActivityKit
import AppIntents
import Foundation

// Compiled into both the app and the widget extension (Widgets/): what the Live Activity shows,
// and the intent behind the Control Center button.

/// The Live Activity while Flux shares: on the Lock Screen and in the Dynamic Island.
struct FluxActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Devices connected now.
        var devices: Int
        /// Bits per second, all devices together.
        var down: Double
        var up: Double
        /// Shared today so far.
        var today: UInt64
    }
}

/// Start Flux from Control Center: the same as the Start Flux action, without its reply. A
/// LiveActivityIntent runs in the app's process, which the widget extension can't share from.
struct WakeFluxIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start Flux"
    static var description = IntentDescription("Wakes Flux, so it shares when a device joins Personal Hotspot.")
    /// Shortcuts already has Start Flux.
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        await MainActor.run { _ = Model.shared.wake() }
        #endif
        return .result()
    }
}
