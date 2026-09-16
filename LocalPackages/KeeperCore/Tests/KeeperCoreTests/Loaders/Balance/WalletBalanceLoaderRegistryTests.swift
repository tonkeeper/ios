import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class WalletBalanceLoaderRegistryTests: XCTestCase {
    private let wallet = WalletBalanceLoaderRegistryTests.makeWallet(id: "wallet")
    private let siblingWallet = WalletBalanceLoaderRegistryTests.makeWallet(id: "sibling")

    func test_theWalletsKnownAtTheStartAreReadyToLoad() {
        let registry = makeRegistry(wallets: [wallet])

        XCTAssertNotNil(registry.loader(for: wallet))
        XCTAssertNil(registry.loader(for: siblingWallet))
    }

    /// A wallet already known may have a run in flight on its loader, so an add must not hand it
    /// a fresh one.
    func test_addingAWalletAlreadyKnownKeepsTheLoaderItHas() {
        var created = [String]()
        let registry = WalletBalanceLoaderRegistry(wallets: [wallet]) { wallet in
            created.append(wallet.id)
            return WalletBalanceLoaderStub()
        }

        registry.add(wallets: [wallet, siblingWallet])

        XCTAssertEqual(created, [wallet.id, wallet.id, siblingWallet.id])
        XCTAssertNotNil(registry.loader(for: siblingWallet))
    }

    func test_aRemovedWalletHasNothingLeftToLoadWith() {
        let registry = makeRegistry(wallets: [wallet])

        registry.remove(wallet: wallet)

        XCTAssertNil(registry.loader(for: wallet))
    }

    private func makeRegistry(wallets: [Wallet]) -> WalletBalanceLoaderRegistry {
        WalletBalanceLoaderRegistry(wallets: wallets) { _ in WalletBalanceLoaderStub() }
    }

    private static func makeWallet(id: String) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        return Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(publicKeyData.prefix(32))), .v5R1)
            ),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class WalletBalanceLoaderStub: WalletBalanceLoader {
    func reloadBalance(currency _: Currency, includingTransferFees _: Bool) async -> BalanceRefreshResult {
        .dropped
    }
}
