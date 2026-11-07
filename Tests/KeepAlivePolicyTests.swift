import XCTest
@testable import FluxCore

final class KeepAlivePolicyTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testPlaysWhileTheHotspotIsOn() {
        XCTAssertTrue(KeepAlivePolicy.plays(waitingSince: nil, now: start))
    }

    func testKeepsPlayingForTenMinutesAfterTheHotspotGoes() {
        XCTAssertTrue(KeepAlivePolicy.plays(waitingSince: start, now: start.addingTimeInterval(9 * 60)))
    }

    func testStopsTenMinutesAfterTheHotspotGoes() {
        XCTAssertFalse(KeepAlivePolicy.plays(waitingSince: start, now: start.addingTimeInterval(10 * 60)))
        XCTAssertFalse(KeepAlivePolicy.plays(waitingSince: start, now: start.addingTimeInterval(8 * 3600)), "a night in airplane mode")
    }

    func testABackgroundWakeIsRarerThanOnScreen() {
        XCTAssertEqual(KeepAlivePolicy.watchInterval(sceneActive: true).every, .seconds(5))
        XCTAssertEqual(KeepAlivePolicy.watchInterval(sceneActive: false).every, .seconds(15))
    }
}
