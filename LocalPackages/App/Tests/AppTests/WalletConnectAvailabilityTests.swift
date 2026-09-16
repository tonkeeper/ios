@testable import App
import XCTest

final class WalletConnectAvailabilityTests: XCTestCase {
    func test_deeplinkPairsWhenActiveWalletIsMultichain() {
        XCTAssertEqual(
            makeAvailability(isMultichainEnabled: true, isActiveWalletMultichain: true).deeplinkDecision,
            .pair
        )
    }

    /// The store may still hold another multichain wallet, but a pairing started from a deeplink
    /// connects the wallet the user is looking at — it must not silently bind to a different one.
    func test_deeplinkIsRefusedWhenActiveWalletIsNotMultichain() {
        XCTAssertEqual(
            makeAvailability(isMultichainEnabled: true, isActiveWalletMultichain: false).deeplinkDecision,
            .activeWalletNotMultichain
        )
    }

    func test_deeplinkIsUnavailableWhenMultichainIsDisabled() {
        XCTAssertEqual(
            makeAvailability(isMultichainEnabled: false, isActiveWalletMultichain: true).deeplinkDecision,
            .featureUnavailable
        )
        XCTAssertEqual(
            makeAvailability(isMultichainEnabled: false, isActiveWalletMultichain: false).deeplinkDecision,
            .featureUnavailable
        )
    }

    /// Sessions name their own wallet, so events keep flowing while a non-multichain wallet is
    /// active — otherwise an incoming request would be dropped instead of reaching the per-item
    /// wallet checks that reject and clean it up.
    func test_eventsAreHandledRegardlessOfTheActiveWallet() {
        XCTAssertTrue(
            makeAvailability(isMultichainEnabled: true, isActiveWalletMultichain: false).canHandleEvents
        )
        XCTAssertTrue(
            makeAvailability(isMultichainEnabled: true, isActiveWalletMultichain: true).canHandleEvents
        )
    }

    func test_eventsAreDroppedWhenMultichainIsDisabled() {
        XCTAssertFalse(
            makeAvailability(isMultichainEnabled: false, isActiveWalletMultichain: true).canHandleEvents
        )
    }
}

private extension WalletConnectAvailabilityTests {
    func makeAvailability(
        isMultichainEnabled: Bool,
        isActiveWalletMultichain: Bool
    ) -> WalletConnectAvailability {
        WalletConnectAvailability(
            isMultichainEnabled: isMultichainEnabled,
            isActiveWalletMultichain: isActiveWalletMultichain
        )
    }
}
