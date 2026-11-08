import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// The widget extension: the home screen and Lock Screen widget, the Live Activity while Flux
// shares, and the Control Center button.
// Flux itself starts, updates and ends the activity (LiveActivityController.swift).

@main
struct FluxWidgets: WidgetBundle {
    var body: some Widget {
        FluxStatusWidget()
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

// MARK: the home screen widget

struct StatusEntry: TimelineEntry {
    let date: Date
    /// Nil until Flux has written anything (or when the App Group was left out at signing).
    let data: FluxWidgetData?
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), data: FluxWidgetData(sharing: true, devices: 1, today: 1_350_000_000,
                                                        month: 17_050_000_000, limit: 50_000_000_000, updated: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(context.isPreview && FluxWidgetData.load() == nil ? placeholder(in: context) : entry(at: Date()))
    }

    /// Flux reloads the widget when something changes. Until then, one entry now and one when
    /// "sharing" would be too old to believe, see `FluxWidgetData.current`.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let now = Date()
        var entries = [entry(at: now)]
        if let data = FluxWidgetData.load(), data.sharing {
            let stale = data.updated.addingTimeInterval(30 * 60 + 1)
            if stale > now { entries.append(entry(at: stale)) }
        }
        completion(Timeline(entries: entries, policy: .never))
    }

    private func entry(at date: Date) -> StatusEntry {
        StatusEntry(date: date, data: FluxWidgetData.load()?.current(now: date))
    }
}

struct FluxStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: FluxWidgetData.kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(Brand.card, for: .widget)
        }
        .configurationDisplayName("Flux status")
        .description("Whether Flux is sharing, the devices connected and the data used.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct StatusWidgetView: View {
    let entry: StatusEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let data = entry.data {
            switch family {
            case .accessoryRectangular: lockScreen(data)
            case .systemMedium: medium(data)
            default: small(data)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                header
                Spacer(minLength: 0)
                Text("Open Flux once")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "water.waves")
                .foregroundStyle(Brand.accent)
            Text(verbatim: "Flux")
                .font(.subheadline.weight(.heavy))
        }
    }

    /// A dot and "1 device" while sharing, "Not sharing" otherwise.
    private func status(_ data: FluxWidgetData) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(data.sharing ? Brand.accent : Color.orange)
                .frame(width: 8, height: 8)
            Text(data.sharing ? devicesText(data.devices) : "Not sharing")
                .font(.headline.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func figure(_ title: LocalizedStringKey, _ bytes: UInt64) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Brand.subtext)
            Text(verbatim: Format.bytes(bytes))
                .font(.title3.weight(.heavy).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private func limitBar(_ data: FluxWidgetData) -> some View {
        if data.limit > 0 {
            ProgressView(value: min(1, Double(data.month) / Double(data.limit)))
                .tint(data.month >= data.limit ? .orange : Brand.action)
        }
    }

    private func small(_ data: FluxWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            status(data)
            Spacer(minLength: 0)
            figure("Today", data.today)
            limitBar(data)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func medium(_ data: FluxWidgetData) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                header
                status(data)
                Spacer(minLength: 0)
                if !data.sharing {
                    // Wakes Flux in its own process, like the Control Center button.
                    Button(intent: WakeFluxIntent()) {
                        Text("Start Flux")
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                    }
                    .tint(Brand.action)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 8) {
                figure("Today", data.today)
                figure("This month", data.month)
                limitBar(data)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func lockScreen(_ data: FluxWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(data.sharing ? devicesText(data.devices) : "Not sharing")
                .font(.headline)
            Text(verbatim: Format.bytes(data.today))
                .font(.subheadline.monospacedDigit())
            if data.limit > 0 {
                ProgressView(value: min(1, Double(data.month) / Double(data.limit)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
