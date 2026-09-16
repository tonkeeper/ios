@testable import KeeperCore
import XCTest

final class WalletScopedContentWalletIdTests: XCTestCase {
    func test_disabledMultichainDoesNotProvideWalletId() {
        var didReadWalletId = false

        let walletId = walletIdForWalletScopedContent(
            isMultichainEnabled: false,
            walletId: {
                didReadWalletId = true
                return "wallet-id"
            }()
        )

        XCTAssertNil(walletId)
        XCTAssertFalse(didReadWalletId)
    }

    func test_enabledMultichainProvidesWalletId() {
        let walletId = walletIdForWalletScopedContent(
            isMultichainEnabled: true,
            walletId: "wallet-id"
        )

        XCTAssertEqual(walletId, "wallet-id")
    }
}
