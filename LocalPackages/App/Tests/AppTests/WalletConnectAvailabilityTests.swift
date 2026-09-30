@testable import App
import XCTest

final class WalletConnectAvailabilityTests: XCTestCase {
    func test_deeplinkPairsWhenActiveWalletIsMultichain() {
        XCTAssertEqual(
            makeAvailability(isActiveWalletMultichain: true).deeplinkDecision,
            .pair
        )
    }

    /// The store may still hold another multichain wallet, but a pairing started from a deeplink
    /// connects the wallet the user is looking at — it must not silently bind to a different one.
    func test_deeplinkIsRefusedWhenActiveWalletIsNotMultichain() {
        XCTAssertEqual(
            makeAvailability(isActiveWalletMultichain: false).deeplinkDecision,
            .activeWalletNotMultichain
        )
    }
}

private extension WalletConnectAvailabilityTests {
    func makeAvailability(isActiveWalletMultichain: Bool) -> WalletConnectAvailability {
        WalletConnectAvailability(isActiveWalletMultichain: isActiveWalletMultichain)
    }
}
