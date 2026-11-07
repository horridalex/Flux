import UserNotifications

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

    /// Right before iOS suspends Flux. Nothing shows if notifications were turned down.
    static func post() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Flux is asleep")
        content.body = String(localized: "No device used the hotspot for 10 minutes, so Flux stopped to save battery. Open Flux or run Start Flux before you turn the hotspot on again.")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    /// Flux is awake again, so the notice no longer applies.
    static func clear() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}
