import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// The widget extension: the Live Activity while Flux shares, and the Control Center button.
// Flux itself starts, updates and ends the activity (LiveActivityController.swift).

@main
struct FluxWidgets: WidgetBundle {
    var body: some Widget {
        FluxLiveActivity()
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

struct FluxLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FluxActivityAttributes.self) { context in
            LockScreenActivity(state: context.state)
                .activityBackgroundTint(Color(red: 0.05, green: 0.07, blue: 0.20).opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(devicesText(context.state.devices))
                    } icon: {
                        Image(systemName: "water.waves").foregroundStyle(Brand.flow)
                    }
                    .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Speeds(state: context.state).font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Used today: \(Format.bytes(context.state.today))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "water.waves").foregroundStyle(Brand.flow)
            } compactTrailing: {
                Text("\(context.state.devices)").monospacedDigit()
            } minimal: {
                Image(systemName: "water.waves").foregroundStyle(Brand.flow)
            }
            .keylineTint(Brand.cyan)
        }
    }
}

private func devicesText(_ n: Int) -> LocalizedStringKey {
    n == 1 ? "1 device" : "\(n) devices"
}

/// Download and upload now, one over the other.
private struct Speeds: View {
    let state: FluxActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(Image(systemName: "arrow.down")) \(Format.speed(state.down))")
            Text("\(Image(systemName: "arrow.up")) \(Format.speed(state.up))")
        }
    }
}

private struct LockScreenActivity: View {
    let state: FluxActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "water.waves")
                .font(.title.weight(.semibold))
                .foregroundStyle(Brand.flow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Flux is sharing")
                    .font(.headline)
                Text(devicesText(state.devices))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Used today: \(Format.bytes(state.today))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Speeds(state: state)
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding()
    }
}
