import Foundation

/// When the silent sound in `KeepAlive` plays. It keeps Flux running in the background, which
/// costs battery all the time, also with nothing to share: a night in airplane mode cost more than
/// any other app. So it plays while Personal Hotspot is on, and stops once the hotspot has been
/// gone for a while. iOS then suspends Flux until it is opened again.
enum KeepAlivePolicy {
    /// Long enough for a USB cable or a Wi-Fi drop to come back, and for turning on Personal
    /// Hotspot in Settings after opening Flux.
    static let grace: TimeInterval = 10 * 60

    /// `waitingSince` is when the hotspot went away, or when Flux was last opened if that was later.
    /// Nil while the hotspot is on. `grace` is the wait chosen in Settings, nil for never stopping.
    static func plays(waitingSince: Date?, now: Date, grace: TimeInterval? = KeepAlivePolicy.grace) -> Bool {
        guard let waitingSince, let grace else { return true }
        return now.timeIntervalSince(waitingSince) < grace
    }

    /// The hotspot is watched every 5 seconds on screen, where starting at once shows. In the
    /// background a device that joins waits a little longer, and Flux wakes a sixth as often.
    static func watchInterval(sceneActive: Bool) -> (every: Duration, tolerance: Duration) {
        sceneActive ? (.seconds(5), .seconds(1)) : (.seconds(30), .seconds(10))
    }
}

/// Settings > Auto-stop: how long Flux waits with no hotspot before it stops, see `KeepAlivePolicy`.
/// Longer saves opening Flux again after a short break, at the cost of battery.
enum AutoStop: Int, CaseIterable, Identifiable {
    case five = 5, ten = 10, thirty = 30, never = 0

    static let key = "autoStop"
    var id: Int { rawValue }

    /// The wait, nil for never.
    var grace: TimeInterval? { self == .never ? nil : TimeInterval(rawValue) * 60 }

    /// The saved choice, 5 minutes until one is made: the least battery for the common case.
    static func saved(in defaults: UserDefaults = .standard) -> AutoStop {
        (defaults.object(forKey: key) as? Int).flatMap(AutoStop.init(rawValue:)) ?? .five
    }
}
