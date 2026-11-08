import ActivityKit
import Foundation

/// Flux 1.4.1 and before showed a Live Activity while sharing (on the Lock Screen and in the
/// Dynamic Island). It's gone; this ends one an update left behind, which would otherwise stay up
/// for hours describing nothing.
enum LiveActivityController {
    static func endLeftovers() {
        Task {
            for old in Activity<FluxActivityAttributes>.activities {
                await old.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
