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

/// Where the last 31 days' `Usage` is kept between launches, today's included.
struct UsageStore {
    var defaults: UserDefaults = .standard
    private static let key = "usage.days"
    /// Where 1.1 kept today's alone. Read once, so today's figures survive the update.
    private static let oldKey = "usage.today"
    static let daysKept = 31

    /// The days kept, oldest first, none older than `daysKept` days before `now`.
    func history(now: Date = Date(), calendar: Calendar = .current) -> [Usage] {
        var days = (defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([Usage].self, from: $0) }) ?? []
        if days.isEmpty, let data = defaults.data(forKey: Self.oldKey),
           let old = try? JSONDecoder().decode(Usage.self, from: data) {
            days = [old]
        }
        let oldest = calendar.date(byAdding: .day, value: -(Self.daysKept - 1), to: now).map { Usage.day(of: $0, calendar: calendar) } ?? ""
        return days.filter { $0.day >= oldest }.sorted { $0.day < $1.day }
    }

    /// Today's figures so far, or none.
    func load(now: Date = Date(), calendar: Calendar = .current) -> Usage {
        let today = Usage.day(of: now, calendar: calendar)
        return history(now: now, calendar: calendar).first { $0.day == today } ?? Usage(day: today)
    }

    /// Puts `usage` in for its day and lets the days past `daysKept` go.
    func save(_ usage: Usage, now: Date = Date(), calendar: Calendar = .current) {
        var days = history(now: now, calendar: calendar).filter { $0.day != usage.day }
        days.append(usage)
        days.sort { $0.day < $1.day }
        if let data = try? JSONEncoder().encode(days) {
            defaults.set(data, forKey: Self.key)
            defaults.removeObject(forKey: Self.oldKey)
        }
    }
}

extension Usage {
    /// The month a day is in, as yyyy-MM.
    var month: String { String(day.prefix(7)) }

    /// What `days` add up to in the month of `today`, with `today`'s figures as they are now rather
    /// than as last saved.
    static func monthTotal(_ days: [Usage], today: Usage) -> Bytes {
        var total = today.all
        for day in days where day.month == today.month && day.day != today.day {
            total.add(up: day.all.up, down: day.all.down)
        }
        return total
    }
}

/// A monthly data limit, and when to warn about it: at 80 % and at 100 %, once each a month.
struct UsageLimit: Equatable {
    /// Bytes a month. Zero means no limit.
    var bytes: UInt64
    static let warnings = [80, 100]

    /// The warning to give now, if any: the highest level `used` has reached that wasn't given this
    /// month. `given` is the highest given this month, 0 for none.
    func warning(used: UInt64, given: Int) -> Int? {
        guard bytes > 0 else { return nil }
        let percent = Double(used) / Double(bytes) * 100
        return Self.warnings.last { Double($0) <= percent && $0 > given }
    }
}

/// Where the limit, and the warnings already given this month, are kept.
struct UsageLimitStore {
    var defaults: UserDefaults = .standard
    private static let bytesKey = "usage.limitBytes"
    private static let givenKey = "usage.limitWarned" // "yyyy-MM:80"

    var limit: UsageLimit {
        get { UsageLimit(bytes: UInt64(max(0, defaults.integer(forKey: Self.bytesKey)))) }
        nonmutating set { defaults.set(Int(clamping: newValue.bytes), forKey: Self.bytesKey) }
    }

    /// The highest warning given in `month`, 0 for none.
    func given(in month: String) -> Int {
        let saved = defaults.string(forKey: Self.givenKey) ?? ""
        let parts = saved.split(separator: ":")
        guard parts.count == 2, parts[0] == month else { return 0 }
        return Int(parts[1]) ?? 0
    }

    func setGiven(_ level: Int, in month: String) {
        defaults.set("\(month):\(level)", forKey: Self.givenKey)
    }
}
