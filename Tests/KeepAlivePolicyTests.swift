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
        XCTAssertEqual(KeepAlivePolicy.watchInterval(sceneActive: false).every, .seconds(30))
    }

    func testTheChosenWaitAndNever() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(KeepAlivePolicy.plays(waitingSince: start, now: start.addingTimeInterval(29 * 60), grace: AutoStop.thirty.grace))
        XCTAssertFalse(KeepAlivePolicy.plays(waitingSince: start, now: start.addingTimeInterval(5 * 60), grace: AutoStop.five.grace))
        XCTAssertTrue(KeepAlivePolicy.plays(waitingSince: start, now: start.addingTimeInterval(8 * 3600), grace: AutoStop.never.grace))
    }

    func testTheSavedChoiceIsFiveMinutesUntilOneIsMade() {
        let defaults = UserDefaults(suiteName: "autostop-\(UUID())")!
        XCTAssertEqual(AutoStop.saved(in: defaults), .five)
        defaults.set(0, forKey: AutoStop.key)
        XCTAssertEqual(AutoStop.saved(in: defaults), .never)
        defaults.set(7, forKey: AutoStop.key)
        XCTAssertEqual(AutoStop.saved(in: defaults), .five, "an unknown value falls back")
    }
}
