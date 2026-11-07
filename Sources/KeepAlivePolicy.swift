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
    /// Nil while the hotspot is on.
    static func plays(waitingSince: Date?, now: Date) -> Bool {
        guard let waitingSince else { return true }
        return now.timeIntervalSince(waitingSince) < grace
    }

    /// The hotspot is watched every 5 seconds on screen, where starting at once shows. In the
    /// background a device that joins waits a little longer, and Flux wakes a third as often.
    static func watchInterval(sceneActive: Bool) -> (every: Duration, tolerance: Duration) {
        sceneActive ? (.seconds(5), .seconds(1)) : (.seconds(15), .seconds(5))
    }
}
