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

    private func freshDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testTheStoreKeepsTheLast31Days() {
        let store = UsageStore(defaults: freshDefaults("UsageTests.history"))
        let now = date(30, 12)
        XCTAssertEqual(store.load(now: now, calendar: calendar), Usage(day: "2026-11-30"))
        for day in 1...30 {
            store.save(Usage(day: Usage.day(of: date(day, 12), calendar: calendar), all: Usage.Bytes(up: 1, down: UInt64(day))),
                       now: now, calendar: calendar)
        }
        // A day from the month before, outside the 31 days, goes.
        store.save(Usage(day: "2026-10-01", all: Usage.Bytes(up: 9, down: 9)), now: now, calendar: calendar)
        let days = store.history(now: now, calendar: calendar)
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days.first?.day, "2026-11-01")
        XCTAssertEqual(days.last?.day, "2026-11-30")
        XCTAssertEqual(store.load(now: now, calendar: calendar).all, Usage.Bytes(up: 1, down: 30))
        store.save(Usage(day: "2026-11-30", all: Usage.Bytes(up: 5, down: 50)), now: now, calendar: calendar)
        XCTAssertEqual(store.history(now: now, calendar: calendar).count, 30, "saving a day again replaces it")
        XCTAssertEqual(store.load(now: now, calendar: calendar).all, Usage.Bytes(up: 5, down: 50))
    }

    func testTodayFromTheOlderVersionIsKept() throws {
        let defaults = freshDefaults("UsageTests.old")
        let today = Usage(day: Usage.day(of: date(7, 12), calendar: calendar), all: Usage.Bytes(up: 3, down: 30))
        defaults.set(try JSONEncoder().encode(today), forKey: "usage.today")
        let store = UsageStore(defaults: defaults)
        XCTAssertEqual(store.load(now: date(7, 13), calendar: calendar), today)
        store.save(today, now: date(7, 13), calendar: calendar)
        XCTAssertNil(defaults.data(forKey: "usage.today"), "moved over once")
    }

    func testTheMonthAddsUpItsOwnDaysAndTodayAsItIsNow() {
        let days = [
            Usage(day: "2026-10-31", all: Usage.Bytes(up: 100, down: 100)),
            Usage(day: "2026-11-01", all: Usage.Bytes(up: 1, down: 10)),
            Usage(day: "2026-11-06", all: Usage.Bytes(up: 2, down: 20)),
            Usage(day: "2026-11-07", all: Usage.Bytes(up: 1, down: 1)), // saved a while ago
        ]
        let today = Usage(day: "2026-11-07", all: Usage.Bytes(up: 4, down: 40))
        XCTAssertEqual(Usage.monthTotal(days, today: today), Usage.Bytes(up: 7, down: 70))
    }

    func testTheLimitWarnsAt80AndAt100OnceEach() {
        let limit = UsageLimit(bytes: 1000)
        XCTAssertNil(limit.warning(used: 799, given: 0))
        XCTAssertEqual(limit.warning(used: 800, given: 0), 80)
        XCTAssertNil(limit.warning(used: 900, given: 80))
        XCTAssertEqual(limit.warning(used: 1000, given: 80), 100)
        XCTAssertEqual(limit.warning(used: 1500, given: 0), 100, "straight past 80 says 100 only")
        XCTAssertNil(limit.warning(used: 2000, given: 100))
        XCTAssertNil(UsageLimit(bytes: 0).warning(used: 2000, given: 0), "no limit, no warning")
    }

    func testTheWarningsGivenStartAgainEachMonth() {
        let store = UsageLimitStore(defaults: freshDefaults("UsageTests.limit"))
        XCTAssertEqual(store.limit, UsageLimit(bytes: 0))
        store.limit = UsageLimit(bytes: 50_000_000_000)
        XCTAssertEqual(store.limit.bytes, 50_000_000_000)
        store.setGiven(80, in: "2026-11")
        XCTAssertEqual(store.given(in: "2026-11"), 80)
        XCTAssertEqual(store.given(in: "2026-12"), 0)
    }

    func testTheDayIsTheLocalOne() {
        XCTAssertEqual(Usage.day(of: date(7, 0), calendar: calendar), "2026-11-07")
        XCTAssertEqual(Usage.day(of: date(7, 23), calendar: calendar), "2026-11-07")
    }
}
