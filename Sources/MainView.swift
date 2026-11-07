import SwiftUI

struct MainView: View {
    @ObservedObject private var model = Model.shared
    @AppStorage(Appearance.key) private var appearance: Appearance = .automatic

    var body: some View {
        NavigationStack {
            ScrollView {
                // A column of cards: the status, the speed, today's usage, the devices, adding one,
                // and the settings.
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

                    // Above adding a device, so a reason it doesn't work and the way out are both here.
                    WireGuardProblemSection(model: model)

                    if model.sharing {
                        Tile(title: "Now", subtitle: "Measured every second") {
                            SpeedRow(down: model.downSpeed, up: model.upSpeed)
                        }
                    }

                    if model.sharing || model.usageThisMonth.total > 0 {
                        UsageCard(model: model)
                    }

                    if !model.wireGuardPeers.isEmpty {
                        Tile(title: "Devices", subtitle: "Tap a device to rename or remove it") {
                            VStack(spacing: 4) {
                                ForEach(model.wireGuardPeers) { peer in
                                    NavigationLink { DeviceView(model: model, peer: peer) } label: {
                                        DeviceRow(peer: peer, connected: model.wireGuardConnected.contains(peer.address),
                                                  speed: model.deviceSpeeds[peer.address])
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("device.\(peer.name)")
                                }
                            }
                        }
                    }

                    AddDeviceSection(model: model, first: model.wireGuardPeers.isEmpty)

                    VStack(spacing: 4) {
                        NavigationLink { AppearanceView() } label: {
                            SettingRow(icon: "circle.lefthalf.filled", title: "Appearance") {
                                Text(appearance.title)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.appearance")
                        NavigationLink { DNSView(model: model) } label: {
                            SettingRow(icon: "globe", title: "DNS") {
                                Text(verbatim: model.wireGuardDNS).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.dns")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .card()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .animation(.smooth, value: model.sharing)
            }
            .background(Brand.page)
            // The status card says what this screen is, so the root drops the big title. It's still set,
            // because the screens pushed from here use it for their back button.
            .navigationTitle("Flux")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// A device in the list: its icon tile, its name, and whether it's connected and how fast it goes.
struct DeviceRow: View {
    let peer: WireGuardSetup.Peer
    let connected: Bool
    let speed: DeviceSpeed?

    /// A symbol from the name people gave it, a screen otherwise.
    private var symbol: String {
        let name = peer.name.lowercased()
        if name.contains("ipad") { return "ipad" }
        if name.contains("iphone") { return "iphone" }
        if name.contains("mac") { return "laptopcomputer" }
        if name.contains("router") || name.contains("gl.inet") || name.contains("unifi") || name.contains("라우터") { return "wifi.router" }
        return "display"
    }

    private var detail: Text {
        guard connected else { return Text("Not connected") }
        if let speed, speed.down + speed.up >= 1000 {
            return Text("Connected · \(Format.speed(speed.down + speed.up))")
        }
        return Text("Connected")
    }

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: symbol, color: connected ? Brand.accent : Brand.subtext)
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.name)
                    .font(.body.weight(.bold))
                detail
                    .font(.subheadline)
                    .foregroundStyle(Brand.subtext)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A settings row: an icon tile, the name, and the current value in grey.
struct SettingRow<Value: View>: View {
    let icon: String
    let title: LocalizedStringKey
    @ViewBuilder var value: Value

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: icon, color: Brand.subtext, size: 40)
            Text(title)
                .font(.body.weight(.semibold))
            Spacer(minLength: 8)
            value
                .foregroundStyle(Brand.subtext)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Today's usage: a chart tile, the figure, and a button to the last 30 days and the monthly limit.
struct UsageCard: View {
    @ObservedObject var model: Model

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: "chart.bar.fill", color: Brand.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Used today")
                    .font(.subheadline)
                    .foregroundStyle(Brand.subtext)
                Text(verbatim: Format.bytes(model.usageToday.all.total))
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.usageToday.all.total)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            NavigationLink { UsageView(model: model) } label: {
                Text("History")
            }
            .buttonStyle(ViewButtonStyle())
            .accessibilityIdentifier("usage.today")
            .accessibilityHint(Text("Shows the last 30 days and the monthly limit"))
        }
        .padding(24)
        .card()
    }
}

/// How fast data moves right now, down and up.
struct SpeedRow: View {
    let down: Double
    let up: Double

    var body: some View {
        HStack(spacing: 12) {
            box("Download", bps: down)
            box("Upload", bps: up)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Download \(Format.speed(down)), upload \(Format.speed(up))")
        .accessibilityIdentifier("traffic.speeds")
    }

    private func box(_ title: LocalizedStringKey, bps: Double) -> some View {
        let parts = Format.speedParts(bps)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Brand.subtext)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: parts.number)
                    .font(.system(size: 28, weight: .heavy).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.snappy, value: bps)
                Text(verbatim: parts.unit)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Brand.subtext)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Brand.tile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

/// Download and upload colours, the brand's blue and a violet, the same in every speed. Darker in
/// light mode and lighter in dark mode, so both keep a 4.5:1 contrast on glass. Orange and red stay
/// for warnings.
enum Direction {
    static let download = Brand.accent
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

    /// The headline with its number in blue, "1 device is connected" with the 1 blue.
    private var headlineHighlighted: AttributedString {
        var text = AttributedString(headline)
        let count = model.wireGuardConnected.count
        if count > 0, let range = text.range(of: String(count)) {
            text[range].foregroundColor = Brand.accent
        }
        return text
    }

    private var title: LocalizedStringKey {
        if sharing { return "Sharing" }
        return model.running ? "Flux can't share yet" : "Turn on Personal Hotspot"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.subtext)
                    .accessibilityIdentifier("status.title")
            }
            if sharing {
                Text(headlineHighlighted)
                    .font(.title2.weight(.heavy))
                    .accessibilityLabel(headline)
                    .accessibilityIdentifier("status.headline")
                Text("To stop, turn off Personal Hotspot.")
                    .font(.subheadline)
                    .foregroundStyle(Brand.subtext)
                    .accessibilityIdentifier("status.stopHint")
            } else if model.running {
                // The WireGuard card under this one says why, and what to do.
                Text("Personal Hotspot is on, but WireGuard isn't running.")
                    .font(.title3.weight(.heavy))
                    .accessibilityIdentifier("status.headline")
            } else {
                Button(action: Self.openHotspotSettings) {
                    Text("Settings > Personal Hotspot > Allow Others to Join")
                        .font(.subheadline.weight(.semibold))
                        .underline()
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(Color.primary) // inside a button, .primary is the button's tint
                }
                .accessibilityIdentifier("status.hotspotPath")
                .accessibilityHint("Opens Settings")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .card(tint: sharing ? nil : .orange)
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
