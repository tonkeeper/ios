import BigInt
import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class MultichainPortfolioStoreTests: XCTestCase {
    private let wallet = MultichainPortfolioStoreTests.makeWallet(id: "wallet", contractVersion: .v5R1)
    private let siblingWallet = MultichainPortfolioStoreTests.makeWallet(
        id: "sibling-wallet",
        contractVersion: .v4R2
    )

    func testOlderRequestCannotOverwriteNewerPortfolio() async {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolio updated")
        let olderRequestToken = store.makeRequestToken()
        let newerRequestToken = store.makeRequestToken()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet] in
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "20"]), wallet: wallet, requestToken: newerRequestToken)
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "10"]), wallet: wallet, requestToken: olderRequestToken)
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        XCTAssertEqual(store.getState()[wallet]?.fiatPrice, ["usd": "20"])
    }

    func testNewerRequestOverwritesOlderPortfolio() async {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolios updated")
        updateExpectation.expectedFulfillmentCount = 2
        let olderRequestToken = store.makeRequestToken()
        let newerRequestToken = store.makeRequestToken()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet] in
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "10"]), wallet: wallet, requestToken: olderRequestToken)
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "20"]), wallet: wallet, requestToken: newerRequestToken)
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        XCTAssertEqual(store.getState()[wallet]?.fiatPrice, ["usd": "20"])
    }

    func testFreshnessDateUsesCompletionTime() async throws {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolio updated")
        let requestToken = store.makeRequestToken()
        let beforeUpdate = Date()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet] in
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "20"]), wallet: wallet, requestToken: requestToken)
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        let portfolio = try XCTUnwrap(store.getState()[wallet])
        XCTAssertGreaterThanOrEqual(portfolio.date, beforeUpdate)
    }

    func testWalletsSharingMultichainWalletIdKeepSeparatePortfolios() async {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolios updated")
        updateExpectation.expectedFulfillmentCount = 2

        XCTAssertEqual(
            wallet.multichainWalletState?.walletId,
            siblingWallet.multichainWalletState?.walletId
        )

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet, siblingWallet] in
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "20"]), wallet: wallet)
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "0.6"]), wallet: siblingWallet)
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        XCTAssertEqual(store.getState()[wallet]?.fiatPrice, ["usd": "20"])
        XCTAssertEqual(store.getState()[siblingWallet]?.fiatPrice, ["usd": "0.6"])
    }

    func testRequestTokensAreScopedPerWallet() async {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolios updated")
        updateExpectation.expectedFulfillmentCount = 2
        let olderRequestToken = store.makeRequestToken()
        let newerRequestToken = store.makeRequestToken()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet, siblingWallet] in
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "20"]), wallet: wallet, requestToken: newerRequestToken)
            store.setPortfolio(Self.makePortfolio(fiatPrice: ["usd": "0.6"]), wallet: siblingWallet, requestToken: olderRequestToken)
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        XCTAssertEqual(store.getState()[siblingWallet]?.fiatPrice, ["usd": "0.6"])
    }

    func testPortfolioKeepsAssetsAndScope() async throws {
        let store = MultichainPortfolioStore.makeStub()
        let updateExpectation = expectation(description: "Portfolio updated")
        let asset = Self.makeAsset()

        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet] in
            store.setPortfolio(
                MultichainPortfolio(
                    fiatPrice: ["usd": "20"],
                    assets: [asset],
                    accountsIdentifier: "accounts",
                    currencyCode: "usd",
                    hidesDustBalances: true
                ),
                wallet: wallet
            )
        }

        await fulfillment(of: [updateExpectation], timeout: 1)

        let portfolio = try XCTUnwrap(store.getState()[wallet])
        XCTAssertEqual(portfolio.assets, [asset])
        XCTAssertEqual(portfolio.accountsIdentifier, "accounts")
        XCTAssertEqual(portfolio.currencyCode, "usd")
        XCTAssertTrue(portfolio.hidesDustBalances)
    }

    /// The assets ride on the same file as the total, so a second store over the same directory
    /// has to bring them back byte-for-byte, balance and capabilities included.
    func testPersistedPortfolioIsRestoredByAFreshStore() async throws {
        let storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storageDirectory) }
        let makeStore = { [wallet] in
            MultichainPortfolioStore(
                walletsStore: WalletsStore(
                    keeperInfoStore: KeeperInfoStore(
                        keeperInfoRepository: SingleWalletKeeperInfoRepositoryStub(wallet: wallet)
                    )
                ),
                repository: MultichainPortfolioRepositoryImplementation(
                    fileSystemVault: FileSystemVault(fileManager: .default, directory: storageDirectory)
                )
            )
        }
        let portfolio = MultichainPortfolio(
            fiatPrice: ["usd": "20", "eur": "18"],
            assets: [Self.makeAsset()],
            accountsIdentifier: wallet.multichainWalletState?.accountsIdentifier ?? "",
            currencyCode: "eur",
            hidesDustBalances: false,
            date: Date(timeIntervalSince1970: 1_000_000)
        )

        let store = makeStore()
        let updateExpectation = expectation(description: "Portfolio updated")
        store.addObserver(self) { _, _ in
            updateExpectation.fulfill()
        } onRegistered: { [wallet] in
            store.setPortfolio(portfolio, wallet: wallet)
        }
        await fulfillment(of: [updateExpectation], timeout: 1)

        let restored = try XCTUnwrap(makeStore().getState()[wallet])
        XCTAssertEqual(restored, portfolio)
    }

    private static func makePortfolio(fiatPrice: [String: String]) -> MultichainPortfolio {
        MultichainPortfolio(
            fiatPrice: fiatPrice,
            assets: [],
            accountsIdentifier: "accounts",
            currencyCode: "usd",
            hidesDustBalances: false
        )
    }

    private static func makeAsset() -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "eth/mainnet/erc20/0xdAC17F95",
                name: "Tether USD",
                symbol: "USDT",
                decimals: 6,
                image: "https://example.com/usdt.png",
                verification: .trusted,
                capabilities: [.swap, .p2p]
            ),
            price: MultichainAssetPrice(
                prices: ["usd": 1, "eur": 0.9],
                diff24h: ["usd": "+0.1%"],
                diff7d: ["usd": "-0.2%"],
                diff30d: ["usd": "+1%"]
            ),
            balance: BigUInt("123456789012345678901234567890"),
            marketCap: ["usd": "100000000000"]
        )
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

private struct SingleWalletKeeperInfoRepositoryStub: KeeperInfoRepository {
    let wallet: Wallet

    func getKeeperInfo() throws -> KeeperInfo {
        KeeperInfo(
            wallets: [wallet],
            currentWallet: wallet,
            currency: .defaultCurrency,
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: KeeperInfo.AppSettings(
                isSecureMode: false,
                searchEngine: .duckduckgo,
                hidesDustBalances: false
            ),
            country: .auto
        )
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}
