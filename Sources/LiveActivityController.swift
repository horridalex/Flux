import ActivityKit
import Foundation

/// Runs the Live Activity (Shared/FluxActivity.swift) while Flux shares: starts it, keeps it up to
/// date, and ends it when sharing stops. iOS lets an app start one only while it's on screen, so it
/// starts the next time Flux is opened while sharing; after that it updates from the background too.
@MainActor
final class LiveActivityController {
    private var activity: Activity<FluxActivityAttributes>?
    private var shown: FluxActivityAttributes.ContentState?
    private var shownAt = Date.distantPast
    /// Updates any closer together cost battery for nothing anyone reads.
    private static let every: TimeInterval = 5

    init() {
        // One left from before Flux was last ended describes nothing now.
        Task {
            for old in Activity<FluxActivityAttributes>.activities {
                await old.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Call with every sample. `onScreen` is whether one may be started now.
    func show(_ state: FluxActivityAttributes.ContentState, onScreen: Bool, now: Date = Date()) {
        guard let activity else {
            guard onScreen, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                activity = try Activity.request(attributes: FluxActivityAttributes(),
                                                content: ActivityContent(state: state, staleDate: nil))
                shown = state
                shownAt = now
            } catch {
                // Turned off in Settings, or too many activities: Flux shares all the same.
            }
            return
        }
        guard state != shown, now.timeIntervalSince(shownAt) >= Self.every else { return }
        shown = state
        shownAt = now
        // Stale after two minutes without an update: suspended, say, so it doesn't claim to share.
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(120))
        Task { await activity.update(content) }
    }

    /// Sharing stopped.
    func end() {
        guard let activity else { return }
        self.activity = nil
        shown = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
