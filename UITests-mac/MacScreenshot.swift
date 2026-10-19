import XCTest

@MainActor
final class MacScreenshot: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Three Mac App Store shots from mock data: a labelled meeting with history, its summary, and live recording.
    func testCaptureMacScreenshot() throws {
        let dir = NSTemporaryDirectory() + "voxprint-mac-screenshots"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (name, arg) in [("1-meeting", "UITEST_FINISHED"), ("2-summary", "UITEST_SUMMARY"), ("3-recording", "UITEST_RECORDING")] {
            let app = XCUIApplication()
            app.launchArguments = [arg, "-ApplePersistenceIgnoreState", "YES"]
            app.launch()
            sleep(3)
            app.activate()
            sleep(1)
            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 10), "App window never appeared for \(name)")
            try window.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
            app.terminate()
        }
    }
}
