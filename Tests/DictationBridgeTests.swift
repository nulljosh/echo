import XCTest
@testable import Voxprint_macOS

/// The keyboard handoff (v3.0): the text arrives once, the state round-trips, and a Darwin signal reaches the other side.
final class DictationBridgeTests: XCTestCase {
    private var saved = DictationBridge.store

    override func setUp() {
        saved = DictationBridge.store
        let box = Box()
        DictationBridge.store = ({ box.values[$0] }, { box.values[$0] = $1 })
    }

    override func tearDown() { DictationBridge.store = saved }

    private final class Box { var values: [String: String] = [:] }

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
