#if DEBUG
import Foundation
import SwiftUI

// Fixed, fake app state for the UI tests (UITests/). On the simulator there is no Personal Hotspot
// and nothing to share, so a test launches the app with `-FluxDemo <scenario>` and gets one of
// these states instead.
//
// A demo launch starts nothing real: no WireGuard server, keep-alive audio, hotspot watcher, 1 s
// sampler or scene observers. Model.swift has the few hooks, all inside `#if DEBUG`.
// This whole file is compiled out of Release builds.

enum DemoScenario: String, CaseIterable {
    /// Hotspot off.
    case waiting
    /// Hotspot on, no device yet: only the QR code.
    case noDevices
    /// Two devices, the iPad connected and the MacBook not, and a speed.
    case sharing
    /// Like `sharing`, but the Keychain is locked: WireGuard isn't running and there's no QR code.
    case wireGuardLocked
    /// Like `sharing`, but the saved WireGuard keys can't be decoded, so only starting over gets past it.
    case wireGuardNeedsReset
    /// Like `sharing`, with two days left before this build stops opening.
    case expiring

    static let argument = "-FluxDemo"

    /// Local 2026-10-17 18:00. The expiry warning is relative to this.
    static let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 18))!

    /// `-FluxAppearance dark` or `light` forces one, for the README's screenshots. Nil follows the
    /// system.
    static var appearance: ColorScheme? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-FluxAppearance"), args.indices.contains(flag + 1) else { return nil }
        return args[flag + 1] == "dark" ? .dark : .light
    }

    /// The scenario named after `-FluxDemo` in the launch arguments, nil in a normal launch.
    static var current: DemoScenario? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: argument) else { return nil }
        guard args.indices.contains(flag + 1), let scenario = DemoScenario(rawValue: args[flag + 1]) else {
            fatalError("\(argument) needs one of: \(allCases.map(\.rawValue).joined(separator: ", "))")
        }
        return scenario
    }
}

/// A Keychain that is locked until the first unlock after a restart: it can't be read or written.
final class LockedSecrets: SecretStore {
    struct Locked: Error {}
    func load() throws -> Data? { throw Locked() }
    func save(_ data: Data) throws { throw Locked() }
}

struct DemoState {
    let scenario: DemoScenario
    private(set) var running = true
    private(set) var downSpeed = 0.0
    private(set) var upSpeed = 0.0

    static func fromLaunchArguments() -> DemoState? {
        DemoScenario.current.map(DemoState.init)
    }

    init(_ scenario: DemoScenario) {
        self.scenario = scenario
        guard scenario != .waiting else {
            running = false
            return
        }
        if scenario == .noDevices { return }
        downSpeed = 3_200_000
        upSpeed = 400_000
    }

    /// Where the WireGuard setup is "kept". Never the Keychain.
    func secrets() -> SecretStore {
        let secrets = InMemorySecrets()
        switch scenario {
        case .sharing, .wireGuardLocked, .expiring:
            var setup = WireGuardSetup.new()
            _ = setup.addPeer(name: "iPad")
            _ = setup.addPeer(name: "MacBook")
            secrets.data = try? JSONEncoder().encode(setup)
        case .wireGuardNeedsReset:
            secrets.data = Data("not a WireGuard setup".utf8) // undecodable, like a setup from a newer version
        default: break
        }
        return scenario == .wireGuardLocked ? LockedSecrets() : secrets
    }

    @MainActor
    func apply(to model: Model) {
        model.running = running
        model.downSpeed = downSpeed
        model.upSpeed = upSpeed
        // The iPad's tunnel is up, the MacBook's isn't, so the list shows both states.
        model.wireGuardConnected = [.sharing, .expiring].contains(scenario) ? ["10.7.0.2"] : []
        model.expires = scenario == .expiring ? DemoScenario.now.addingTimeInterval(2 * 86_400) : nil
        // Today's figures, the iPad's most of them, its speed, and two weeks of history before today.
        if [.sharing, .expiring].contains(scenario), let iPad = model.wireGuardPeers.first {
            model.usageToday = Usage(day: Usage.day(of: DemoScenario.now),
                                     all: Usage.Bytes(up: 96_000_000, down: 1_250_000_000),
                                     devices: [iPad.id.uuidString: Usage.Bytes(up: 80_000_000, down: 1_100_000_000)])
            model.deviceSpeeds = [iPad.address: DeviceSpeed(down: 2_900_000, up: 380_000)]
            model.usageHistory = (1...14).reversed().map { back in
                let day = Calendar.current.date(byAdding: .day, value: -back, to: DemoScenario.now)!
                let gb = UInt64([0.4, 1.2, 0.0, 2.1, 0.8, 1.6, 3.0, 0.2, 1.1, 0.9, 2.4, 0.0, 1.3, 0.7][back - 1] * 1e9)
                return Usage(day: Usage.day(of: day), all: Usage.Bytes(up: gb / 10, down: gb - gb / 10))
            }
        }
    }
}
#endif
