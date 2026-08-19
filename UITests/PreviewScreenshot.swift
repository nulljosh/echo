import XCTest

@MainActor
final class PreviewScreenshot: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(extraArgs: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments.append(contentsOf: extraArgs)
        app.launch()
        return app
    }

    func testCaptureAppStoreScreenshots() throws {
        var app = launch(extraArgs: ["UITEST_FINISHED"])
        sleep(3)
        snapshot("1-finished-transcript")
        app.terminate()

        app = launch(extraArgs: ["UITEST_HISTORY"])
        sleep(3)
        let historyButton = app.buttons["history-button"]
        // A silent `if waitForExistence` skip here once left a stale, pre-rename
        // 2-history.png in place while the run still exited 0. Fail loudly instead.
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5), "history-button never appeared - 2-history would have been skipped")
        historyButton.tap()
        sleep(2)
        snapshot("2-history")
        app.terminate()

        app = launch(extraArgs: ["UITEST_PAYWALL"])
        sleep(3)
        snapshot("3-paywall")
        app.terminate()

        app = launch(extraArgs: ["UITEST_FINISHED"])
        sleep(3)
        let settingsButton = app.buttons["settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "settings-button never appeared - 4-settings would have been skipped")
        settingsButton.tap()
        sleep(2)
        snapshot("4-settings")
        app.terminate()

        app = launch(extraArgs: ["UITEST_RECORDING"])
        sleep(3)
        snapshot("5-live-recording")
    }
}
