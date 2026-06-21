import XCTest

@MainActor
final class MacScreenshot: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMacScreenshot() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(3)

        app.activate()
        sleep(1)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "App window never appeared")
        let screenshot = window.screenshot()
        let dir = NSTemporaryDirectory() + "echo-mac-screenshots"
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/1-main.png"))
        } catch {
            XCTFail("Screenshot write failed: \(error)")
        }
    }
}
