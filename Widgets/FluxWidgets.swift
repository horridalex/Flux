import AppIntents
import SwiftUI
import WidgetKit

// The widget extension: the Control Center button.

@main
struct FluxWidgets: WidgetBundle {
    var body: some Widget {
        FluxControl()
    }
}

/// Start Flux from Control Center, the Lock Screen or the Action button.
struct FluxControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "flux.start") {
            ControlWidgetButton(action: WakeFluxIntent()) {
                Label("Start Flux", systemImage: "water.waves")
            }
        }
        .displayName("Start Flux")
        .description("Wakes Flux, so it shares when a device joins Personal Hotspot.")
    }
}
