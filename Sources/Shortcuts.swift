import AppIntents

// Actions for the Shortcuts app, Siri, Spotlight and the Action button. iOS suspends Flux once
// nothing has been on the hotspot for 10 minutes (KeepAlivePolicy), and Shortcuts has no trigger
// for Personal Hotspot turning on. So a shortcut turns the hotspot on with Shortcuts' own Set Personal Hotspot
// action, then runs Start Flux, which wakes Flux in the background without opening it.

struct StartFluxIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Flux"
    static var description = IntentDescription(
        "Wakes Flux in the background, the same as opening it. It shares as soon as a device joins Personal Hotspot in the next 10 minutes. Put it after Set Personal Hotspot.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let model = Model.shared
        let keptAlive = model.wake()
        let state = model.shortcutState()
        return .result(value: state.sharing, dialog: "\(ShortcutReply.start(state, keptAlive: keptAlive))")
    }
}

struct FluxStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Is Flux Sharing?"
    static var description = IntentDescription(
        "True while Flux is sharing Personal Hotspot, for an If in a shortcut. It also says how many devices are connected.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let model = Model.shared
        model.syncWithHotspot() // a cold launch for this action hasn't looked at the hotspot yet
        let state = model.shortcutState()
        return .result(value: state.sharing, dialog: "\(ShortcutReply.status(state))")
    }
}

/// Ready in Shortcuts, Siri and Spotlight as soon as Flux is installed, with nothing to set up.
struct FluxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartFluxIntent(),
                    phrases: ["Start \(.applicationName)", "Share internet with \(.applicationName)"],
                    shortTitle: "Start Flux", systemImageName: "link")
        AppShortcut(intent: FluxStatusIntent(),
                    phrases: ["Is \(.applicationName) sharing", "\(.applicationName) status"],
                    shortTitle: "Is Flux Sharing?", systemImageName: "link.circle")
    }
}
