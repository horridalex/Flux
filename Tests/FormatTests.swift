import XCTest
@testable import FluxCore

final class FormatTests: XCTestCase {
    func testSpeedUsesTheUnitOfASpeedTest() {
        XCTAssertEqual(Format.speed(0), "0 bit/s")
        XCTAssertEqual(Format.speed(999), "999 bit/s")
        XCTAssertEqual(Format.speed(400_000), "400 kbit/s")
        XCTAssertEqual(Format.speed(3_200_000), "3.2 Mbit/s")
    }

    func testBytesAreReadable() {
        XCTAssertEqual(Format.bytes(2_000_000), "2 MB")
        XCTAssertFalse(Format.bytes(0).contains("Zero"), Format.bytes(0))
        XCTAssertEqual(Format.bytes(UInt64.max), Format.bytes(UInt64(Int64.max)), "a huge count doesn't trap")
    }

    func testADevicesSpeedComesFromItsCounters() {
        let speed = DeviceSpeed(from: TrafficTotals(bytesUp: 1000, bytesDown: 5000),
                                to: TrafficTotals(bytesUp: 2000, bytesDown: 30000), seconds: 2)
        XCTAssertEqual(speed, DeviceSpeed(down: 100_000, up: 4000), "down is what went to the device")
        let restarted = DeviceSpeed(from: TrafficTotals(bytesUp: 9000, bytesDown: 9000),
                                    to: TrafficTotals(bytesUp: 10, bytesDown: 10), seconds: 1)
        XCTAssertEqual(restarted, DeviceSpeed(down: 0, up: 0), "a counter that went down isn't a jump")
    }
}
