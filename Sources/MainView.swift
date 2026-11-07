import SwiftUI

struct MainView: View {
    @ObservedObject private var model = Model.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                // A bento grid of glass tiles: the status across the top, the numbers side by side,
                // then the devices, the QR code for the next one, and the settings.
                VStack(spacing: 12) {
                    StatusCard(model: model)

                    if let warning = model.expiryWarning {
                        Tile(tint: .orange) {
                            Label {
                                Text(warning)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("app.expiry")
                        }
                    }

                    // Above the QR code, so a reason it doesn't work and the way out are both here.
                    WireGuardProblemSection(model: model)

                    if model.sharing || model.usageThisMonth.total > 0 {
                        HStack(spacing: 12) {
                            if model.sharing {
                                Tile(title: "Now") {
                                    SpeedRow(down: model.downSpeed, up: model.upSpeed)
                                }
                            }
                            // The tile opens the last 30 days and the monthly limit.
                            NavigationLink { UsageView(model: model) } label: {
                                Tile(title: "Used today") {
                                    UsageSummary(bytes: model.usageToday.all, month: model.usageThisMonth.total,
                                                 limit: model.usageLimit.bytes)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("usage.today")
                        }
                        .fixedSize(horizontal: false, vertical: true) // both tiles as tall as the taller one
                    }

                    if !model.wireGuardPeers.isEmpty {
                        Tile(title: "Devices") {
                            VStack(spacing: 0) {
                                ForEach(Array(model.wireGuardPeers.enumerated()), id: \.element.id) { index, peer in
                                    if index > 0 { Divider() }
                                    NavigationLink { DeviceView(model: model, peer: peer) } label: {
                                        TileRow {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(peer.name)
                                                // While it moves data, how fast: who's using the hotspot most.
                                                if let speed = model.deviceSpeeds[peer.address], speed.down + speed.up >= 1000 {
                                                    DeviceSpeedText(speed: speed)
                                                }
                                            }
                                            Spacer()
                                            ConnectedLabel(connected: model.wireGuardConnected.contains(peer.address))
                                                .font(.subheadline)
                                        }
                                    }
                                    .accessibilityIdentifier("device.\(peer.name)")
                                }
                            }
                        }
                    }

                    AddDeviceSection(model: model, first: model.wireGuardPeers.isEmpty)

                    Tile(title: "Settings") {
                        NavigationLink { DNSView(model: model) } label: {
                            TileRow {
                                Text("DNS")
                                Spacer()
                                Text(verbatim: model.wireGuardDNS)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .accessibilityIdentifier("settings.dns")
                    }
                }
                .padding(16)
                .animation(.smooth, value: model.sharing)
            }
            .background(AuroraBackground(flowing: model.sharing))
            // The status card says what this screen is, so the root drops the big title. It's still set,
            // because the screens pushed from here use it for their back button.
            .navigationTitle("Flux")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// A row in a tile that opens another screen: the label, then a chevron like a List's.
struct TileRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            content
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.primary)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Today's total, big, with the download and upload under it, and this month's, for the main
/// screen's tile.
struct UsageSummary: View {
    let bytes: Usage.Bytes
    /// This month so far, and the monthly limit, 0 for none.
    let month: UInt64
    let limit: UInt64

    private var monthText: Text {
        limit > 0
            ? Text("This month \(Format.bytes(month)) of \(Format.bytes(limit))")
            : Text("This month \(Format.bytes(month))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: Format.bytes(bytes.total))
                .font(.title2.weight(.bold).monospacedDigit())
            Text("\(Image(systemName: "arrow.down")) \(Format.bytes(bytes.down))  \(Image(systemName: "arrow.up")) \(Format.bytes(bytes.up))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            monthText
                .font(.caption.monospacedDigit())
                .foregroundStyle(limit > 0 && month >= limit ? Color.orange : Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Used today"))
        .accessibilityValue(Text("\(Format.bytes(bytes.total)), download \(Format.bytes(bytes.down)), upload \(Format.bytes(bytes.up))"))
        .accessibilityHint(Text("Shows the last 30 days and the monthly limit"))
    }
}

/// A device's speed now, small, under its name.
struct DeviceSpeedText: View {
    let speed: DeviceSpeed

    var body: some View {
        Text("\(Image(systemName: "arrow.down")) \(Format.speed(speed.down))  \(Image(systemName: "arrow.up")) \(Format.speed(speed.up))")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Download \(Format.speed(speed.down)), upload \(Format.speed(speed.up))"))
    }
}

/// How fast data moves right now, down and up.
struct SpeedRow: View {
    let down: Double
    let up: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Image(systemName: "arrow.down")) \(Format.speed(down))")
                .foregroundStyle(Direction.download)
            Text("\(Image(systemName: "arrow.up")) \(Format.speed(up))")
                .foregroundStyle(Direction.upload)
        }
        .font(.headline.monospacedDigit())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Download \(Format.speed(down)), upload \(Format.speed(up))")
        .accessibilityIdentifier("traffic.speeds")
    }
}

/// How much was downloaded and uploaded, for today's figures.
struct UsageRow: View {
    let title: LocalizedStringKey
    let bytes: Usage.Bytes

    var body: some View {
        LabeledContent(title) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: Format.bytes(bytes.total))
                Text("\(Image(systemName: "arrow.down")) \(Format.bytes(bytes.down))  \(Image(systemName: "arrow.up")) \(Format.bytes(bytes.up))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(Format.bytes(bytes.total)), download \(Format.bytes(bytes.down)), upload \(Format.bytes(bytes.up))"))
    }
}

/// Download and upload colours, the brand's cyan and violet, the same in every speed. Darker in
/// light mode and lighter in dark mode, so both keep a 4.5:1 contrast on glass. Orange and red stay
/// for warnings.
enum Direction {
    static let download = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.88, blue: 1.00, alpha: 1)
            : UIColor(red: 0.00, green: 0.38, blue: 0.68, alpha: 1)
    })
    static let upload = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.80, green: 0.68, blue: 1.00, alpha: 1)
            : UIColor(red: 0.42, green: 0.22, blue: 0.80, alpha: 1)
    })
}

/// The one-second answer: is this phone sharing right now, and is anyone using it. Turning off
/// Personal Hotspot is how sharing stops, so it says that instead of having a switch.
struct StatusCard: View {
    @ObservedObject var model: Model

    private var tint: Color { model.sharing ? .green : .orange }
    private var sharing: Bool { model.sharing }
    /// Grows with the text size, like the title under it.
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 44

    /// The glass takes a little of the brand's blue while sharing, and of orange, the warning
    /// colour, while waiting.
    private var glassTint: Color { sharing ? Brand.blue.opacity(0.25) : Color.orange.opacity(0.25) }

    /// Opens Settings at its main screen, where Personal Hotspot is near the top. Nothing goes
    /// straight to the Personal Hotspot page any more: on iOS 27, App-prefs:INTERNET_TETHERING and
    /// every App-prefs spelling of it open Settings > Apps, and iOS refuses prefs:root= links from apps.
    static func openHotspotSettings() {
        UIApplication.shared.open(URL(string: "App-prefs:")!)
    }

    private var headline: String {
        switch model.wireGuardConnected.count {
        case 0: return String(localized: "Hotspot is on, no device is using Flux yet")
        case 1: return String(localized: "Sharing with 1 device")
        case let n: return String(localized: "Sharing with \(n) devices")
        }
    }

    private var title: LocalizedStringKey {
        if sharing { return "Sharing" }
        return model.running ? "Flux can't share yet" : "Turn on Personal Hotspot"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "water.waves")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(Brand.flow)
                .symbolEffect(.variableColor.iterative, isActive: sharing)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(tint)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                        .offset(x: 6, y: 4)
                }
                .accessibilityHidden(true)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("status.title")
            if sharing {
                Text(headline)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("status.headline")
                Text("To stop, turn off Personal Hotspot.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("status.stopHint")
            } else if model.running {
                // The WireGuard section under the card says why, and what to do.
                Text("Personal Hotspot is on, but WireGuard isn't running.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("status.headline")
            } else {
                Button(action: Self.openHotspotSettings) {
                    // The tint fails contrast on the orange card, so the text is the label colour and the underline
                    // says "tap". Color.primary, because inside a button `.primary` is the button's tint.
                    Text("Settings > Personal Hotspot > Allow Others to Join")
                        .font(.subheadline.weight(.semibold))
                        .underline()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.primary)
                }
                .accessibilityIdentifier("status.hotspotPath")
                .accessibilityHint("Opens Settings")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .glassTile(cornerRadius: 28, tint: glassTint)
        .animation(.smooth, value: sharing)
    }
}

#Preview("Sharing") {
    let model = Model()
    model.running = true
    model.wireGuardConnected = ["10.7.0.2"]
    return StatusCard(model: model).padding()
}

#Preview("Hotspot on, no device") {
    let model = Model()
    model.running = true
    return StatusCard(model: model).padding()
}

#Preview("Waiting") {
    StatusCard(model: Model()).padding()
}

#Preview("Main screen") {
    MainView()
}
