import XCTest
@testable import FluxCore

final class UsageTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func totals(_ up: UInt64, _ down: UInt64) -> TrafficTotals {
        TrafficTotals(bytesUp: up, bytesDown: down)
    }

    func testTheFirstReadingOnlySetsTheStart() {
        var meter = UsageMeter(today: Usage(day: "2026-11-07"))
        meter.record(total: totals(500, 9000), devices: ["10.7.0.2": totals(500, 9000)],
                     owners: ["10.7.0.2": "ipad"], now: date(7, 12), calendar: calendar)
        XCTAssertEqual(meter.today.all, Usage.Bytes())
        XCTAssertTrue(meter.today.devices.isEmpty)
    }

    func testWhatMovedIsAddedInAllAndByDevice() {
        var meter = UsageMeter(today: Usage(day: "2026-11-07"))
        let owners = ["10.7.0.2": "ipad", "10.7.0.3": "mac"]
        meter.record(total: totals(100, 1000), devices: ["10.7.0.2": totals(100, 1000)],
                     owners: owners, now: date(7, 12), calendar: calendar)
        meter.record(total: totals(300, 6000), devices: ["10.7.0.2": totals(150, 3000), "10.7.0.3": totals(150, 2000)],
                     owners: owners, now: date(7, 12), calendar: calendar)
        XCTAssertEqual(meter.today.all, Usage.Bytes(up: 200, down: 5000))
        XCTAssertEqual(meter.today.devices["ipad"], Usage.Bytes(up: 50, down: 2000))
        XCTAssertEqual(meter.today.devices["mac"], Usage.Bytes(up: 150, down: 2000), "a device new since the last reading counts from zero")
    }

    func testADeviceCounterThatStartsAgainCountsFromZero() {
        var meter = UsageMeter(today: Usage(day: "2026-11-07"))
        let owners = ["10.7.0.2": "ipad"]
        meter.record(total: totals(0, 0), devices: ["10.7.0.2": totals(100, 5000)], owners: owners, now: date(7, 12), calendar: calendar)
        // The server started again: the device's own counter is back near zero.
        meter.record(total: totals(10, 300), devices: ["10.7.0.2": totals(10, 300)], owners: owners, now: date(7, 12), calendar: calendar)
        XCTAssertEqual(meter.today.devices["ipad"], Usage.Bytes(up: 10, down: 300))
    }

    func testAnAddressWithNoDeviceCountsOnlyInAll() {
        var meter = UsageMeter(today: Usage(day: "2026-11-07"))
        meter.record(total: totals(0, 0), devices: [:], owners: [:], now: date(7, 12), calendar: calendar)
        meter.record(total: totals(5, 50), devices: ["10.7.0.9": totals(5, 50)], owners: [:], now: date(7, 12), calendar: calendar)
        XCTAssertEqual(meter.today.all, Usage.Bytes(up: 5, down: 50))
        XCTAssertTrue(meter.today.devices.isEmpty)
    }

    func testANewDayStartsFromZero() {
        var meter = UsageMeter(today: Usage(day: "2026-11-07"))
        let owners = ["10.7.0.2": "ipad"]
        meter.record(total: totals(0, 0), devices: [:], owners: owners, now: date(7, 23), calendar: calendar)
        meter.record(total: totals(10, 100), devices: ["10.7.0.2": totals(10, 100)], owners: owners, now: date(7, 23), calendar: calendar)
        meter.record(total: totals(30, 400), devices: ["10.7.0.2": totals(30, 400)], owners: owners, now: date(8, 1), calendar: calendar)
        XCTAssertEqual(meter.today.day, "2026-11-08")
        XCTAssertEqual(meter.today.all, Usage.Bytes(up: 20, down: 300))
        XCTAssertEqual(meter.today.devices["ipad"], Usage.Bytes(up: 20, down: 300))
    }

    func testForgettingADevice() {
        var meter = UsageMeter(today: Usage(day: "2026-11-07", all: Usage.Bytes(up: 1, down: 2), devices: ["ipad": Usage.Bytes(up: 1, down: 2)]))
        meter.forget(device: "ipad")
        XCTAssertNil(meter.today.devices["ipad"])
        XCTAssertEqual(meter.today.all, Usage.Bytes(up: 1, down: 2), "what it used stays in all")
    }

    func testTheStoreKeepsOnlyToday() {
        let defaults = UserDefaults(suiteName: "UsageTests")!
        defaults.removePersistentDomain(forName: "UsageTests")
        let store = UsageStore(defaults: defaults)
        let today = Usage.day(of: Date())
        XCTAssertEqual(store.load(), Usage(day: today))
        store.save(Usage(day: today, all: Usage.Bytes(up: 7, down: 70)))
        XCTAssertEqual(store.load().all, Usage.Bytes(up: 7, down: 70))
        store.save(Usage(day: "2000-01-01", all: Usage.Bytes(up: 7, down: 70)))
        XCTAssertEqual(store.load(), Usage(day: today), "yesterday's figures don't carry over")
    }

    func testTheDayIsTheLocalOne() {
        XCTAssertEqual(Usage.day(of: date(7, 0), calendar: calendar), "2026-11-07")
        XCTAssertEqual(Usage.day(of: date(7, 23), calendar: calendar), "2026-11-07")
    }
}
