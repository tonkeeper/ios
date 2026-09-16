import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class BalanceLoadingEdgesTests: XCTestCase {
    private let wallet = BalanceLoadingEdgesTests.makeWallet(id: "wallet")
    private let siblingWallet = BalanceLoadingEdgesTests.makeWallet(id: "sibling")

    func test_aLoadReportsItsStartAndThenItsResult() {
        let edges = BalanceLoadingEdges()
        let observer = UpdateObserver()
        edges.addObserver(observer) { observer, update in observer.record(update) }

        edges.begin(wallet: wallet)
        edges.end(wallet: wallet, result: .failed)

        XCTAssertEqual(observer.updates.map(\.isLoading), [true, false])
        XCTAssertEqual(observer.updates.map(\.result), [nil, .failed])
    }

    /// A wallet loading for its own screen and for the wallets-list sweep at once must not stop
    /// looking busy when the first of the two lands.
    func test_aWalletStaysLoadingWhileASecondLoadIsStillRunning() {
        let edges = BalanceLoadingEdges()
        let observer = UpdateObserver()
        edges.addObserver(observer) { observer, update in observer.record(update) }

        edges.begin(wallet: wallet)
        edges.begin(wallet: wallet)
        edges.end(wallet: wallet, result: .failed)

        XCTAssertEqual(observer.updates.map(\.isLoading), [true, true, true])

        edges.end(wallet: wallet, result: .failed)

        XCTAssertEqual(observer.updates.last?.isLoading, false)
    }

    func test_oneWalletsLoadSaysNothingAboutAnother() {
        let edges = BalanceLoadingEdges()
        let observer = UpdateObserver()
        edges.addObserver(observer) { observer, update in observer.record(update) }

        edges.begin(wallet: wallet)
        edges.begin(wallet: siblingWallet)
        edges.end(wallet: siblingWallet, result: .failed)

        XCTAssertEqual(observer.updates.map(\.wallet.id), [wallet.id, siblingWallet.id, siblingWallet.id])
        XCTAssertEqual(observer.updates.map(\.isLoading), [true, true, false])
    }

    /// An end without a start would otherwise drive the count negative and leave the wallet unable
    /// to report itself busy again.
    func test_anUnmatchedEndLeavesTheWalletIdle() {
        let edges = BalanceLoadingEdges()
        let observer = UpdateObserver()
        edges.addObserver(observer) { observer, update in observer.record(update) }

        edges.end(wallet: wallet, result: .failed)
        edges.begin(wallet: wallet)

        XCTAssertEqual(observer.updates.map(\.isLoading), [false, true])
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

private final class UpdateObserver {
    private(set) var updates = [BalanceLoaderUpdate]()

    func record(_ update: BalanceLoaderUpdate) {
        updates.append(update)
    }
}
