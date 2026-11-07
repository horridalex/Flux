import Foundation

/// The WireGuard server's byte counters. They only grow, so a reader can take the difference of two.
struct TrafficTotals: Equatable {
    var bytesUp: UInt64 = 0
    var bytesDown: UInt64 = 0
}

/// One device's speed now, in bits per second: `down` to the device, `up` from it.
struct DeviceSpeed: Equatable {
    var down: Double
    var up: Double

    /// From two readings of a device's counters `seconds` apart. A counter that went down (the
    /// server started again) gives zero, not a jump.
    init(from before: TrafficTotals, to now: TrafficTotals, seconds: TimeInterval) {
        func bps(_ new: UInt64, _ old: UInt64) -> Double {
            seconds > 0 && new >= old ? Double(new - old) * 8 / seconds : 0
        }
        // The server's up is what came from the device, its down what went to it.
        down = bps(now.bytesDown, before.bytesDown)
        up = bps(now.bytesUp, before.bytesUp)
    }

    init(down: Double, up: Double) {
        self.down = down
        self.up = up
    }
}

/// The WireGuard server starts from zero each time the hotspot comes back, while readers expect
/// counters that only grow. This carries what earlier runs counted.
struct CarriedTotals {
    private var carried = TrafficTotals()

    /// Call with a run's last counters when it stops.
    mutating func absorb(_ last: TrafficTotals) {
        carried.bytesUp += last.bytesUp
        carried.bytesDown += last.bytesDown
    }

    func apply(to current: TrafficTotals) -> TrafficTotals {
        TrafficTotals(bytesUp: carried.bytesUp + current.bytesUp, bytesDown: carried.bytesDown + current.bytesDown)
    }
}
