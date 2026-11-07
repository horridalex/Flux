import CoreImage.CIFilterBuiltins
import SwiftUI

/// The QR code for the next device, always on the main screen. It's the ready device's config: the
/// first time something connects with it, that device is listed and a new code takes its place.
struct AddDeviceSection: View {
    @ObservedObject var model: Model
    let first: Bool

    var body: some View {
        if let ready = model.wireGuardReady {
            let code = ReadyCode.for(config: model.wireGuardConfig(for: ready))
            Tile(title: first ? LocalizedStringKey("Add a device") : LocalizedStringKey("Add another device")) {
                if let qr = code.qr {
                    // Black on white whatever the theme, with a quiet zone, so any camera reads it.
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .frame(maxWidth: 240)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("QR code for the next device")
                        .accessibilityIdentifier("add.qr")
                }
                if let file = code.file {
                    ShareLink(item: file) {
                        Label("Share as a file, for a Mac or a router", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("add.share")
                }
                Text("Install WireGuard on it, tap + > Create from QR code and scan this. Then edit the tunnel and turn On-Demand on for this iPhone's hotspot only. A travel router imports the file and turns its VPN on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("add.steps")
            }
        }
    }
}

/// Why WireGuard isn't running, with the way out when the saved keys can't be read.
struct WireGuardProblemSection: View {
    @ObservedObject var model: Model

    var body: some View {
        if let problem = model.wireGuardProblem {
            Tile(title: "WireGuard isn't running", tint: .orange) {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("wireguard.problem")
                if model.wireGuardNeedsReset {
                    Button("Start over with new keys", role: .destructive) { model.resetWireGuard() }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("wireguard.reset")
                }
            }
        }
    }
}

/// One device: whether it's connected, and removing it. Tapping the title renames it.
struct DeviceView: View {
    @ObservedObject var model: Model
    let peer: WireGuardSetup.Peer
    @State private var confirmRemove = false
    /// The device's own config as a QR code and a file, made when asked for, see `showCode`.
    @State private var code: (qr: UIImage?, file: URL?)?
    @Environment(\.dismiss) private var dismiss

    /// The saved device, so a new name shows at once.
    private var current: WireGuardSetup.Peer { model.wireGuardPeers.first { $0.id == peer.id } ?? peer }
    private var connected: Bool { model.wireGuardConnected.contains(peer.address) }

    var body: some View {
        List {
            Section {
                ConnectedLabel(connected: connected)
                    .accessibilityIdentifier("device.status")
                if connected {
                    SpeedRow(down: model.deviceSpeeds[peer.address]?.down ?? 0, up: model.deviceSpeeds[peer.address]?.up ?? 0)
                        .accessibilityIdentifier("device.speeds")
                }
                UsageRow(title: "Used today", bytes: model.usageToday.devices[peer.id.uuidString] ?? Usage.Bytes())
                    .accessibilityIdentifier("device.usage")
            } footer: {
                Text("A travel router's figures include every device behind it.")
            }
            Section {
                if let code {
                    if let qr = code.qr {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .frame(maxWidth: 240)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .accessibilityLabel("QR code for this device")
                            .accessibilityIdentifier("device.qr")
                    }
                    if let file = code.file {
                        ShareLink(item: file) {
                            Label("Share as a file, for a Mac or a router", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("Hide QR code") { self.code = nil }
                } else {
                    Button {
                        showCode()
                    } label: {
                        Label("Show QR code", systemImage: "qrcode")
                    }
                    .accessibilityIdentifier("device.showQR")
                }
            } header: {
                Text("Set up again")
            } footer: {
                Text("Scan it on this device to set it up again, after a DNS change say. Then delete its old tunnel in WireGuard. The code holds the device's key, so show it only to the device.")
            }
            Section {
                Button("Remove device", role: .destructive) { confirmRemove = true }
                    .accessibilityIdentifier("device.remove")
            } footer: {
                Text("It can't connect any more. Delete its tunnel in its WireGuard app too.")
            }
        }
        .auroraList(flowing: model.sharing)
        .navigationTitle(Binding(get: { current.name }, set: { model.renameWireGuardDevice(peer.id, to: $0) }))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
        .onDisappear { code = nil } // the key doesn't stay on screen for the next visit
        .confirmationDialog("Remove \(current.name)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                model.removeWireGuardDevice(peer.id)
                dismiss()
            }
        }
    }

    /// Made once when asked for, not on every redraw: the screen redraws every second with the
    /// speeds. It has the DNS servers chosen now, so scanning it again brings a DNS change over.
    private func showCode() {
        let text = model.wireGuardConfig(for: current)
        code = (QRCode.image(text), ConfigFile.write(text, named: current.name))
    }
}

/// "Connected" or "Not connected". The text keeps the normal colours, since green text on the
/// grouped background fails the contrast audit. The icon carries the green.
struct ConnectedLabel: View {
    let connected: Bool

    var body: some View {
        Label {
            Text(connected ? LocalizedStringKey("Connected") : LocalizedStringKey("Not connected"))
                .foregroundStyle(connected ? .primary : .secondary)
        } icon: {
            Image(systemName: connected ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(connected ? .green : .secondary)
        }
    }
}

/// The ready device's QR code and file, made once for each config. The main screen redraws
/// every second with the speeds, and making them on each redraw cost a CIContext and a file write
/// every second.
@MainActor
enum ReadyCode {
    private static var made: (config: String, qr: UIImage?, file: URL?)?

    /// `config` is the ready device's config. It changes with the device, and with the DNS servers.
    static func `for`(config text: String) -> (qr: UIImage?, file: URL?) {
        // The system may clear the temporary directory, so a missing file is written again.
        if let made, made.config == text, made.file.map({ FileManager.default.fileExists(atPath: $0.path) }) ?? false {
            return (made.qr, made.file)
        }
        let code = (config: text, qr: QRCode.image(text), file: ConfigFile.write(text, named: "Flux"))
        made = code
        return (code.qr, code.file)
    }
}

/// The config as a .conf file to share. WireGuard names the tunnel after the file. It holds a
/// private key, so it lives in the temporary directory, can't be read while the iPhone is locked,
/// and the next ready device's config replaces it under the same name.
enum ConfigFile {
    static func write(_ config: String, named name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(WireGuardSetup.fileName(for: name))
        do {
            try Data(config.utf8).write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
        }
    }
}

enum QRCode {
    static func image(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// The DNS servers devices added from now on use. A device already added keeps the ones in its
/// own config, since Flux can't change what's imported there.
struct DNSView: View {
    @ObservedObject var model: Model
    @State private var custom = ""
    @State private var invalid = false

    private struct Preset: Identifiable {
        let name: LocalizedStringKey
        let servers: String
        var id: String { servers }
    }

    private let presets = [
        Preset(name: "Cloudflare", servers: WireGuardSetup.defaultDNS),
        Preset(name: "Google", servers: "8.8.8.8, 8.8.4.4"),
        Preset(name: "Quad9", servers: "9.9.9.9, 149.112.112.112"),
        Preset(name: "AdGuard (blocks ads)", servers: "94.140.14.14, 94.140.15.15"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(presets) { preset in
                    Button {
                        invalid = false
                        model.setWireGuardDNS(preset.servers)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name).foregroundStyle(Color.primary)
                                Text(verbatim: preset.servers).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.wireGuardDNS == preset.servers {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .accessibilityAddTraits(model.wireGuardDNS == preset.servers ? .isSelected : [])
                }
            } footer: {
                Text("Devices you add from now on use these. A device already added keeps its own: change DNS in its WireGuard tunnel, or remove it and add it again.")
            }

            Section {
                TextField("For example 192.168.8.1", text: $custom)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(useCustom)
                    .accessibilityIdentifier("dns.custom")
                Button("Use these servers", action: useCustom)
                    .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Other servers")
            } footer: {
                if invalid {
                    Text("Enter one to four IPv4 addresses, separated by commas.")
                        .foregroundStyle(.red)
                }
            }
        }
        .auroraList(flowing: model.sharing)
        .navigationTitle("DNS")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !presets.contains(where: { $0.servers == model.wireGuardDNS }) { custom = model.wireGuardDNS }
        }
    }

    private func useCustom() {
        guard let servers = WireGuardSetup.normalizedDNS(custom) else {
            invalid = true
            return
        }
        invalid = false
        custom = servers
        model.setWireGuardDNS(servers)
    }
}
