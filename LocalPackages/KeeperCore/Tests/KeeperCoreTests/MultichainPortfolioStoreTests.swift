import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class MultichainPortfolioStoreTests: XCTestCase {
    private let wallet = MultichainPortfolioStoreTests.makeWallet(id: "wallet", contractVersion: .v5R1)
    private let siblingWallet = MultichainPortfolioStoreTests.makeWallet(
        id: "sibling-wallet",
        contractVersion: .v4R2
    )

    func testOlderRequestCannotOverwriteNewerTotal() async {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolio total updated")
        let olderRequestToken = store.makeRequestToken()
        let newerRequestToken = store.makeRequestToken()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet] in
            store.setPortfolioTotal(
                ["usd": "20"],
                wallet: wallet,
                hidesDustBalances: false,
                requestToken: newerRequestToken
            )
            store.setPortfolioTotal(
                ["usd": "10"],
                wallet: wallet,
                hidesDustBalances: false,
                requestToken: olderRequestToken
            )
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        XCTAssertEqual(store.getState()[wallet]?.fiatPrice, ["usd": "20"])
    }

    func testNewerRequestOverwritesOlderTotal() async {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolio totals updated")
        updateExpectation.expectedFulfillmentCount = 2
        let olderRequestToken = store.makeRequestToken()
        let newerRequestToken = store.makeRequestToken()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet] in
            store.setPortfolioTotal(
                ["usd": "10"],
                wallet: wallet,
                hidesDustBalances: false,
                requestToken: olderRequestToken
            )
            store.setPortfolioTotal(
                ["usd": "20"],
                wallet: wallet,
                hidesDustBalances: false,
                requestToken: newerRequestToken
            )
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        XCTAssertEqual(store.getState()[wallet]?.fiatPrice, ["usd": "20"])
    }

    func testFreshnessDateUsesCompletionTime() async throws {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolio total updated")
        let requestToken = store.makeRequestToken()
        let beforeUpdate = Date()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet] in
            store.setPortfolioTotal(
                ["usd": "20"],
                wallet: wallet,
                hidesDustBalances: false,
                requestToken: requestToken
            )
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        let total = try XCTUnwrap(store.getState()[wallet])
        XCTAssertGreaterThanOrEqual(total.date, beforeUpdate)
    }

    func testWalletsSharingMultichainWalletIdKeepSeparateTotals() async {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolio totals updated")
        updateExpectation.expectedFulfillmentCount = 2

        XCTAssertEqual(
            wallet.multichainWalletState?.walletId,
            siblingWallet.multichainWalletState?.walletId
        )

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet, siblingWallet] in
            store.setPortfolioTotal(
                ["usd": "20"],
                wallet: wallet,
                hidesDustBalances: false
            )
            store.setPortfolioTotal(
                ["usd": "0.6"],
                wallet: siblingWallet,
                hidesDustBalances: false
            )
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        XCTAssertEqual(store.getState()[wallet]?.fiatPrice, ["usd": "20"])
        XCTAssertEqual(store.getState()[siblingWallet]?.fiatPrice, ["usd": "0.6"])
    }

    func testRequestTokensAreScopedPerWallet() async {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolio totals updated")
        updateExpectation.expectedFulfillmentCount = 2
        let olderRequestToken = store.makeRequestToken()
        let newerRequestToken = store.makeRequestToken()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet, siblingWallet] in
            store.setPortfolioTotal(
                ["usd": "20"],
                wallet: wallet,
                hidesDustBalances: false,
                requestToken: newerRequestToken
            )
            store.setPortfolioTotal(
                ["usd": "0.6"],
                wallet: siblingWallet,
                hidesDustBalances: false,
                requestToken: olderRequestToken
            )
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        XCTAssertEqual(store.getState()[siblingWallet]?.fiatPrice, ["usd": "0.6"])
    }

    private static let sharedMultichainWalletId = "shared-multichain-wallet-id"

    private static func makeWallet(
        id: String,
        contractVersion: WalletContractVersion,
        multichainWalletId: String = sharedMultichainWalletId
    ) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, contractVersion)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(
                    walletId: multichainWalletId,
                    addresses: [
                        MultichainWalletAddress(
                            chain: .ton,
                            address: "\(id)-ton-address",
                            type: contractVersion == .v5R1 ? .tonV5R1 : .tonV4R2
                        ),
                    ]
                )
            )
        )
    }
}
