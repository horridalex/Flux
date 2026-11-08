import UserNotifications

// The notifications Flux sends: when it goes to sleep, when a device connects or leaves, and near
// the monthly data limit.

/// Says so when Flux goes to sleep. With nothing on the hotspot for 10 minutes the silent sound stops
/// (see `KeepAlivePolicy`) and iOS suspends Flux, and turning the hotspot on then shares nothing until
/// Flux is opened again. Without a word, that looks like Flux broke.
enum SleepNotice {
    private static let id = "flux.asleep"

    /// Asks once, the first time Flux shares while on screen: by then it's clear what Flux does, and
    /// asking never lands in the middle of a launch or a UI test, which has no hotspot.
    static func askOnce() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Right before iOS suspends Flux, after `minutes` with no hotspot (Settings > Auto-stop).
    /// Nothing shows if notifications were turned down.
    static func post(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Flux is asleep")
        content.body = String(localized: "No device used the hotspot for \(minutes) minutes, so Flux stopped to save battery. Open Flux or run Start Flux before you turn the hotspot on again.")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    /// Flux is awake again, so the notice no longer applies.
    static func clear() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}

/// Says when a device connects or leaves while Flux is off the screen, where there's nothing else
/// to see it by. Settings > Connection alerts turns it off. Quiet: a banner, no sound.
enum ConnectionNotice {
    static let key = "connectionNotices"

    static func enabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    /// One notification per device, so a device that comes back replaces its "disconnected".
    static func post(device id: String, name: String, connected: Bool) {
        guard enabled() else { return }
        let content = UNMutableNotificationContent()
        if connected {
            content.title = String(localized: "\(name) connected")
            content.body = String(localized: "It's using this iPhone's internet through Flux.")
        } else {
            content.title = String(localized: "\(name) disconnected")
            content.body = String(localized: "It's no longer sharing through Flux.")
        }
        content.threadIdentifier = "flux.devices"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "flux.device.\(id)", content: content, trigger: nil))
    }
}

/// Warns as this month's data comes near the monthly limit, see `UsageLimit`.
enum UsageNotice {
    static func post(level: Int, used: UInt64, limit: UInt64) {
        let content = UNMutableNotificationContent()
        let usedText = Format.bytes(used), limitText = Format.bytes(limit)
        if level >= 100 {
            content.title = String(localized: "Monthly data limit reached")
            content.body = String(localized: "Flux has shared \(usedText) this month, over your limit of \(limitText).")
        } else {
            content.title = String(localized: "\(level) percent of this month's data used")
            content.body = String(localized: "Flux has shared \(usedText) of your \(limitText) limit this month.")
        }
        content.sound = .default
        // One per level, so the 100 % warning doesn't replace the 80 % one unseen.
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "flux.limit.\(level)", content: content, trigger: nil))
    }
}
