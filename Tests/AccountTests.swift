import XCTest
@testable import Voxprint_macOS

final class AccountTests: XCTestCase {
    /// Server errors reach the person as plain sentences, never raw API text.
    func testErrorMessages() {
        XCTAssertEqual(AccountError.server(400, "Invalid login credentials").errorDescription, "That email and password don't match.")
        XCTAssertEqual(AccountError.server(400, "Email not confirmed").errorDescription, "Confirm your email first. The link is in your inbox.")
        XCTAssertEqual(AccountError.server(429, "slow down").errorDescription, "Too many tries. Wait a minute and try again.")
        XCTAssertEqual(AccountError.server(400, "password must be at least 8 characters").errorDescription, "Password must be at least 8 characters.")
        XCTAssertEqual(AccountError.server(500, "").errorDescription, "Something went wrong. Try again.")
    }
}
