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
        var app = launch(extraArgs: ["UITEST_RECORDING"])
        sleep(3)
        snapshot("1-live-recording")
        app.terminate()

        app = launch(extraArgs: ["UITEST_FINISHED"])
        sleep(3)
        snapshot("2-finished-transcript")
        app.terminate()

        app = launch(extraArgs: ["UITEST_HISTORY"])
        sleep(3)
        let historyButton = app.buttons["history-button"]
        if historyButton.waitForExistence(timeout: 5) {
            historyButton.tap()
            sleep(2)
            snapshot("3-history")
        }
        app.terminate()

        app = launch(extraArgs: ["UITEST_PAYWALL"])
        sleep(3)
        snapshot("4-paywall")
        app.terminate()

        app = launch(extraArgs: [])
        sleep(3)
        let settingsButton = app.buttons["settings-button"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(2)
            snapshot("5-settings")
        }
    }
}
