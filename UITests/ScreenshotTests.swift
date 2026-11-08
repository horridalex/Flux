import XCTest

/// Takes the README's screenshots, from the demo scenarios. Each is an attachment named after its
/// file in docs/: the Screenshots workflow exports them and puts them on the `screenshots` branch.
/// Not a check of anything, so it's skipped unless the run asks for it (FLUX_SCREENSHOTS=1).
final class ScreenshotTests: FluxUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FLUX_SCREENSHOTS"] == "1",
                          "screenshots only in the Screenshots workflow")
    }

    private func shoot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Waits for animations and the glass to settle.
    private func settle() {
        _ = app.wait(for: .runningForeground, timeout: 2)
        Thread.sleep(forTimeInterval: 1.5)
    }

    func testMainScreen() {
        for appearance in ["dark", "light"] {
            launch(.sharing, arguments: ["-FluxAppearance", appearance], korean: true)
            settle()
            shoot("main-\(appearance)")
        }
    }

    func testWaitingAndTheQRCode() {
        launch(.waiting, arguments: ["-FluxAppearance", "dark"], korean: true)
        settle()
        shoot("waiting-dark")
    }

    func testAddDevice() {
        launch(.sharing, arguments: ["-FluxAppearance", "dark"], korean: true)
        reveal(element("add.showQR")).tap()
        XCTAssertTrue(element("add.qr").waitForExistence(timeout: 5))
        settle()
        shoot("add-dark")
    }

    func testDevice() {
        launch(.sharing, arguments: ["-FluxAppearance", "dark"], korean: true)
        reveal(element("device.iPad")).tap()
        XCTAssertTrue(element("device.status").waitForExistence(timeout: 5))
        settle()
        shoot("device-dark")
    }
}
