import XCTest
@testable import Voxprint_macOS

/// The keyboard handoff (v3.0): the text arrives once, the state round-trips, and a Darwin signal reaches the other side.
final class DictationBridgeTests: XCTestCase {
    private var saved: UserDefaults!

    override func setUp() {
        saved = DictationBridge.defaults
        DictationBridge.defaults = UserDefaults(suiteName: "echo-tests-dictation")!
        DictationBridge.defaults.removePersistentDomain(forName: "echo-tests-dictation")
    }

    override func tearDown() { DictationBridge.defaults = saved }

    func testResultIsTypedOnceAndStateResets() {
        XCTAssertEqual(DictationBridge.state, .idle)
        DictationBridge.state = .listening
        XCTAssertEqual(DictationBridge.state, .listening)
        DictationBridge.publish("Pick up oat milk.")
        XCTAssertEqual(DictationBridge.state, .idle, "publishing ends the dictation")
        XCTAssertEqual(DictationBridge.takeResult(), "Pick up oat milk.")
        XCTAssertNil(DictationBridge.takeResult(), "a second look must not type it twice")
    }

    func testSignalReachesObserver() {
        let heard = expectation(description: "stop signal")
        DictationBridge.observe(.stop) { heard.fulfill() }
        DictationBridge.post(.stop)
        wait(for: [heard], timeout: 2)
    }
}
