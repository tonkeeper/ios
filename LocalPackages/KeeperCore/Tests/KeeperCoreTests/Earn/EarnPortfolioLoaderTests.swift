@testable import KeeperCore
import TKEarnAPI
import XCTest

final class EarnPortfolioLoaderTests: XCTestCase {
    private var directory: URL!
    private let wallet = EarnPortfolioFixtures.wallet()

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EarnPortfolioLoaderTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testAnswerBecomesTheWalletsPortfolio() async throws {
        let api = EarnAPIStub(balance: .success(EarnFixtures.balance(
            totalFiat: ["USD": "0.2002", "rub": "16.25"],
            positions: [EarnFixtures.position(
                vault: EarnFixtures.vault(image: "https://example.com/usdc.png"),
                balanceFiat: ["USD": "0.2002", "RUB": "16.25"],
                earnedFiat: ["USD": "0.000239", "RUB": "not a number"]
            )]
        )))
        let store = makeStore()

        try await makeLoader(api: api, store: store).loadPortfolio(wallet: wallet, currency: XCTUnwrap(Currency(code: "RUB")))

        XCTAssertEqual(store.portfolioState(wallet: wallet), try .loaded(
            EarnPortfolio(
                walletId: EarnPortfolioFixtures.multichainWalletId,
                totalFiat: ["USD": XCTUnwrap(Decimal(string: "0.2002")), "RUB": XCTUnwrap(Decimal(string: "16.25"))],
                positions: [EarnPosition(
                    network: "mainnet",
                    vaultId: "0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c",
                    protocolName: "Aave",
                    assetSymbol: "USDC",
                    assetIconURL: URL(string: "https://example.com/usdc.png"),
                    balanceFiat: ["USD": XCTUnwrap(Decimal(string: "0.2002")), "RUB": XCTUnwrap(Decimal(string: "16.25"))],
                    earnedFiat: ["USD": XCTUnwrap(Decimal(string: "0.000239"))]
                )]
            ),
            isStale: false
        ))
        let requests = await api.balanceRequests
        XCTAssertEqual(requests, [.init(walletId: EarnPortfolioFixtures.multichainWalletId, currencies: ["rub", "usd"])])
    }

    func testDefaultCurrencyIsAskedForOnce() async {
        let api = EarnAPIStub()

        await makeLoader(api: api).loadPortfolio(wallet: wallet, currency: .USD)

        let requests = await api.balanceRequests
        XCTAssertEqual(requests.map(\.currencies), [["usd"]])
    }

    func testFailedLoadKeepsTheLastPortfolioMarkedStale() async {
        let api = EarnAPIStub()
        let store = makeStore()
        let loader = makeLoader(api: api, store: store)
        await loader.loadPortfolio(wallet: wallet, currency: .USD)
        await api.setBalance(.failure(.badStatus(403, code: "wallet_proof_required")))

        await loader.loadPortfolio(wallet: wallet, currency: .USD)

        guard case .loaded(_, isStale: true) = store.portfolioState(wallet: wallet) else {
            return XCTFail("expected the last portfolio, marked stale")
        }
    }

    func testWalletWithoutAMultichainWalletAsksNothing() async {
        let api = EarnAPIStub()
        let wallet = EarnPortfolioFixtures.wallet(multichainWalletId: nil)
        let store = makeStore(wallets: [wallet])

        await makeLoader(api: api, store: store).loadPortfolio(wallet: wallet, currency: .USD)

        let requests = await api.balanceRequests
        XCTAssertEqual(requests, [])
        XCTAssertNil(store.portfolioState(wallet: wallet))
    }

    func testWalletNotSyncedWithTheMultichainBackendAsksNothing() async {
        let api = EarnAPIStub()
        let wallet = EarnPortfolioFixtures.wallet(syncState: .pending)
        let store = makeStore(wallets: [wallet])

        await makeLoader(api: api, store: store).loadPortfolio(wallet: wallet, currency: .USD)

        let requests = await api.balanceRequests
        XCTAssertEqual(requests, [])
        XCTAssertNil(store.portfolioState(wallet: wallet))
    }

    func testDisabledEarnAsksNothing() async {
        let api = EarnAPIStub()
        let store = makeStore()

        await makeLoader(api: api, store: store, isEnabled: false).loadPortfolio(wallet: wallet, currency: .USD)

        let requests = await api.balanceRequests
        XCTAssertEqual(requests, [])
        XCTAssertNil(store.portfolioState(wallet: wallet))
    }

    func testLoadsWithinAMinuteOfAnEarnTransactionAskForReloadedPositions() async {
        let api = EarnAPIStub()
        let clock = ControlledClock()
        let dirtyFlags = EarnPortfolioDirtyFlags(uptime: { clock.uptime() })
        let loader = makeLoader(api: api, dirtyFlags: dirtyFlags)
        await loader.loadPortfolio(wallet: wallet, currency: .USD)
        await dirtyFlags.markDirty(wallet: wallet)

        await loader.loadPortfolio(wallet: wallet, currency: .USD)
        clock.advance(by: 59)
        await loader.loadPortfolio(wallet: wallet, currency: .USD)
        clock.advance(by: 1)
        await loader.loadPortfolio(wallet: wallet, currency: .USD)

        let requests = await api.balanceRequests
        XCTAssertEqual(requests.map(\.refresh), [false, true, true, false])
    }

    func testCancelledLoadLeavesTheStoreAlone() async {
        let api = EarnAPIStub(balance: .failure(.transport(URLError(.cancelled))))
        let store = makeStore()
        let loader = makeLoader(api: api, store: store)

        await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await loader.loadPortfolio(wallet: wallet, currency: .USD)
        }.value

        XCTAssertNil(store.portfolioState(wallet: wallet))
    }
}

private extension EarnPortfolioLoaderTests {
    func makeStore(wallets: [Wallet]? = nil) -> EarnPortfolioStore {
        EarnPortfolioFixtures.store(wallets: wallets ?? [wallet], directory: directory)
    }

    func makeLoader(
        api: EarnAPI,
        store: EarnPortfolioStore? = nil,
        dirtyFlags: EarnPortfolioDirtyFlags = EarnPortfolioDirtyFlags(),
        isEnabled: Bool = true
    ) -> EarnPortfolioLoader {
        EarnPortfolioLoader(api: api, store: store ?? makeStore(), dirtyFlags: dirtyFlags, isEnabled: { isEnabled })
    }
}

private final class ControlledClock: @unchecked Sendable {
    private let lock = NSLock()
    private var elapsed: TimeInterval = 0

    func uptime() -> TimeInterval {
        lock.withLock { elapsed }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock {
            elapsed += interval
        }
    }
}
