import XCTest

/// Adding a device: the QR code, the shared file and the steps that are always on the main screen.
final class AddDeviceTests: FluxUITestCase {
    private let steps = "Install WireGuard on it, tap + > Create from QR code and scan this. Then edit the tunnel and turn On-Demand on for this iPhone's hotspot only. A travel router imports the file and turns its VPN on."

    func testBeforeAnyDeviceTheMainScreenShowsTheQRCodeTheFileAndTheSteps() {
        launch(.waiting)
        XCTAssertTrue(reveal(element("add.qr")).exists)
        XCTAssertEqual(element("add.qr").label, "QR code for the next device")
        let share = reveal(element("add.share"))
        XCTAssertTrue(share.label.contains("Share as a file, for a Mac or a router"), share.label)
        XCTAssertEqual(reveal(element("add.steps")).label, steps)
        XCTAssertTrue(app.staticTexts["ADD A DEVICE"].exists)
        XCTAssertFalse(app.staticTexts["ADD ANOTHER DEVICE"].exists)
    }

    func testTheQRCodeShowsWithTheHotspotOnButNoDevice() {
        launch(.noDevices)
        XCTAssertTrue(reveal(element("add.qr")).exists)
        XCTAssertTrue(app.staticTexts["ADD A DEVICE"].exists)
    }

    func testOnceADeviceExistsTheHeaderSaysAddAnotherDevice() {
        launch(.sharing)
        XCTAssertTrue(reveal(element("add.qr")).exists, "the code stays for the next device")
        XCTAssertTrue(app.staticTexts["ADD ANOTHER DEVICE"].exists)
        XCTAssertFalse(app.staticTexts["ADD A DEVICE"].exists)
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
