import Foundation

/// How much was shared today, in all and by device. Kept across launches, and starts again at
/// midnight. Foundation only, so `swift test` covers it.
struct Usage: Codable, Equatable {
    struct Bytes: Codable, Equatable {
        var up: UInt64 = 0
        var down: UInt64 = 0
        var total: UInt64 { up &+ down }

        mutating func add(up: UInt64, down: UInt64) {
            self.up &+= up
            self.down &+= down
        }
    }

    /// The local day it counts, as yyyy-MM-dd.
    var day: String
    var all = Bytes()
    /// By the device's id, `WireGuardSetup.Peer.id`. A router's clients count as the router.
    var devices: [String: Bytes] = [:]

    static func day(of date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Turns the server's counters into today's `Usage`. The server's total only grows (see
/// `CarriedTotals`), but a device's own counter starts from zero again when the server restarts or
/// the device is removed, so a counter that went down counts from zero.
struct UsageMeter {
    private(set) var today: Usage
    private var lastTotal: TrafficTotals?
    /// Each device's counter at the last reading, by tunnel address.
    private var lastDevices: [String: TrafficTotals] = [:]

    init(today: Usage) {
        self.today = today
    }

    /// Adds what moved since the last reading. The first reading only sets where counting starts,
    /// since nothing says when the bytes before it moved. `owners` gives each tunnel address's
    /// device id. Traffic from an address with no device counts in all, not by device.
    mutating func record(total: TrafficTotals, devices: [String: TrafficTotals], owners: [String: String],
                         now: Date, calendar: Calendar = .current) {
        let day = Usage.day(of: now, calendar: calendar)
        if today.day != day { today = Usage(day: day) }
        defer {
            lastTotal = total
            lastDevices = devices
        }
        guard let last = lastTotal else { return }
        today.all.add(up: Self.moved(total.bytesUp, last.bytesUp), down: Self.moved(total.bytesDown, last.bytesDown))
        for (address, current) in devices {
            guard let id = owners[address] else { continue }
            let before = lastDevices[address] ?? TrafficTotals()
            let up = Self.moved(current.bytesUp, before.bytesUp)
            let down = Self.moved(current.bytesDown, before.bytesDown)
            guard up > 0 || down > 0 else { continue }
            today.devices[id, default: Usage.Bytes()].add(up: up, down: down)
        }
    }

    /// Today's figures for a device that's gone.
    mutating func forget(device id: String) {
        today.devices[id] = nil
    }

    /// A counter that went down started again from zero.
    private static func moved(_ now: UInt64, _ before: UInt64) -> UInt64 {
        now >= before ? now - before : now
    }
}

/// Where today's `Usage` is kept between launches.
struct UsageStore {
    var defaults: UserDefaults = .standard
    private static let key = "usage.today"

    func load(now: Date = Date()) -> Usage {
        let today = Usage.day(of: now)
        guard let data = defaults.data(forKey: Self.key),
              let saved = try? JSONDecoder().decode(Usage.self, from: data), saved.day == today else {
            return Usage(day: today)
        }
        return saved
    }

    func save(_ usage: Usage) {
        if let data = try? JSONEncoder().encode(usage) { defaults.set(data, forKey: Self.key) }
    }
}
