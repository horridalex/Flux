import Foundation

// Compiled into both the app and the widget extension (Widgets/): what the home screen widget
// shows. Flux writes it to the App Group both share (see the entitlements), and the widget reads it.
// Where the signing left out the App Group, the widget never finds anything and asks to open Flux.

struct FluxWidgetData: Codable, Equatable {
    /// Sharing now, and kept awake to go on sharing.
    var sharing: Bool
    /// Devices connected now.
    var devices: Int
    /// Bytes shared today, and this month with today.
    var today: UInt64
    var month: UInt64
    /// The monthly limit in bytes, 0 for none.
    var limit: UInt64
    /// When Flux wrote it.
    var updated: Date

    static let kind = "flux.status"
    private static let key = "widget.status"

    /// `group.` and the app's bundle ID, from the Info.plist of the app and of the extension.
    static var group: String {
        Bundle.main.object(forInfoDictionaryKey: "FluxAppGroup") as? String ?? "group.com.personal.flux"
    }

    private static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    static func load() -> FluxWidgetData? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FluxWidgetData.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults?.set(data, forKey: Self.key)
    }

    /// What the widget shows at `now`: Flux writes at least every 15 minutes while it shares, so
    /// "sharing" older than half an hour means Flux was closed or stopped without a word.
    func current(now: Date) -> FluxWidgetData {
        var data = self
        if data.sharing, now.timeIntervalSince(updated) > 30 * 60 {
            data.sharing = false
            data.devices = 0
        }
        // Today's and this month's figures start again at midnight and on the 1st.
        let calendar = Calendar.current
        if !calendar.isDate(updated, inSameDayAs: now) { data.today = 0 }
        if !calendar.isDate(updated, equalTo: now, toGranularity: .month) { data.month = 0 }
        return data
    }
}
