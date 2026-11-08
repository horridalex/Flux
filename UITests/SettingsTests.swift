import XCTest

/// The settings at the bottom of the main screen: Auto-stop.
final class SettingsTests: FluxUITestCase {
    func testAutoStopKeepsTheChoice() {
        launch(.sharing)
        reveal(element("settings.autoStop")).tap()
        XCTAssertTrue(element("autoStop.5").waitForExistence(timeout: 5))
        XCTAssertTrue(element("autoStop.5").isSelected, "5 minutes until a choice is made")
        element("autoStop.30").tap()
        XCTAssertTrue(element("autoStop.30").isSelected)
        XCTAssertTrue(app.staticTexts["After this long without the hotspot, open Flux to share again."].exists)
        element("autoStop.0").tap()
        XCTAssertTrue(app.staticTexts["Always shares when the hotspot comes on, but uses more battery."].waitForExistence(timeout: 5))
        goBack(to: "Flux")
        XCTAssertTrue(reveal(element("settings.autoStop")).label.contains("Never"))
        // Back to the default for the other tests.
        element("settings.autoStop").tap()
        element("autoStop.5").tap()
        goBack(to: "Flux")
        XCTAssertTrue(reveal(element("settings.autoStop")).label.contains("5 minutes"))
    }
}
