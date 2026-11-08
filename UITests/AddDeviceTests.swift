import XCTest

/// Adding a device: the row on the main screen, and the QR code, the shared file and the steps its
/// Show QR button opens.
final class AddDeviceTests: FluxUITestCase {
    /// Opens the sheet with the QR code.
    private func openCode() {
        reveal(element("add.showQR")).tap()
        XCTAssertTrue(element("add.qr").waitForExistence(timeout: 5), "the QR code sheet did not open")
    }

    private let steps = "In WireGuard, tap + > Create from QR code"

    func testBeforeAnyDeviceTheMainScreenShowsTheQRCodeTheFileAndTheSteps() {
        launch(.waiting)
        XCTAssertTrue(app.staticTexts["Add a device"].exists)
        openCode()
        XCTAssertEqual(element("add.qr").label, "QR code for the next device")
        let share = reveal(element("add.share"))
        XCTAssertTrue(share.label.contains("Share as a file, for a Mac or a router"), share.label)
        XCTAssertEqual(reveal(element("add.steps")).label, steps)
        XCTAssertFalse(app.staticTexts["Add another device"].exists)
    }

    func testTheQRCodeShowsWithTheHotspotOnButNoDevice() {
        launch(.noDevices)
        XCTAssertTrue(app.staticTexts["Add a device"].exists)
        openCode()
    }

    func testOnceADeviceExistsTheHeaderSaysAddAnotherDevice() {
        launch(.sharing)
        XCTAssertTrue(reveal(element("add.showQR")).exists, "the code stays for the next device")
        XCTAssertTrue(app.staticTexts["Add another device"].exists)
        XCTAssertFalse(app.staticTexts["Add a device"].exists)
        openCode()
        XCTAssertTrue(reveal(element("add.share")).exists)
        XCTAssertTrue(reveal(element("add.steps")).exists)
    }

    func testNothingElseOffersToAddADevice() {
        launch(.sharing)
        for id in ["add.device", "add.failed", "devices.manage", "status.howToConnect"] {
            XCTAssertFalse(element(id).exists, id)
        }
        XCTAssertFalse(app.buttons["Add a device"].exists)
    }
}
