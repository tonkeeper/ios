@testable import KeeperCore
import XCTest

final class TransferServiceSignMessageTimeoutTests: XCTestCase {
    private let now: UInt64 = 1_800_000_000

    func test_missingValidUntil_expiresAfterDefaultTTL() throws {
        XCTAssertEqual(try TransferService.signMessageTimeout(validUntil: nil, now: now), now + 300)
    }

    func test_validUntilWithinCap_isSignedAsRequested() throws {
        XCTAssertEqual(try TransferService.signMessageTimeout(validUntil: now + 590, now: now), now + 590)
    }

    func test_validUntilBeyondCap_isCappedAtTenMinutes() throws {
        XCTAssertEqual(try TransferService.signMessageTimeout(validUntil: now + 3600, now: now), now + 600)
    }

    func test_expiredValidUntil_isRejectedBeforeSigning() {
        XCTAssertThrowsError(try TransferService.signMessageTimeout(validUntil: now, now: now))
    }
}
