import XCTest

/// The settings at the bottom of the main screen: Auto-stop and Connection alerts.
final class SettingsTests: FluxUITestCase {
    func testAutoStopKeepsTheChoice() {
        launch(.sharing)
        reveal(element("settings.autoStop")).tap()
        XCTAssertTrue(element("autoStop.10").waitForExistence(timeout: 5))
        XCTAssertTrue(element("autoStop.10").isSelected, "10 minutes until a choice is made")
        element("autoStop.30").tap()
        XCTAssertTrue(element("autoStop.30").isSelected)
        XCTAssertTrue(app.staticTexts["With no hotspot for this long, Flux stops to save battery."].exists)
        element("autoStop.0").tap()
        XCTAssertTrue(app.staticTexts["Never stopping uses more battery."].waitForExistence(timeout: 5))
        goBack(to: "Flux")
        XCTAssertTrue(reveal(element("settings.autoStop")).label.contains("Never"))
        // Back to the default for the other tests.
        element("settings.autoStop").tap()
        element("autoStop.10").tap()
        goBack(to: "Flux")
        XCTAssertTrue(reveal(element("settings.autoStop")).label.contains("10 minutes"))
    }

    func testConnectionAlertsIsASwitchThatStartsOn() {
        launch(.sharing)
        let toggle = reveal(element("settings.connectionNotices"))
        XCTAssertEqual(value(of: toggle), "1")
        XCTAssertTrue(toggle.label.contains("Connection alerts"))
    }
}
