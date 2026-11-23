@testable import KeeperCore
import XCTest

final class EarnPortfolioStoreTests: XCTestCase {
    private var directory: URL!
    private let wallet = EarnPortfolioFixtures.wallet()
    private let otherWallet = EarnPortfolioFixtures.wallet(id: "other-wallet")

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EarnPortfolioStoreTests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    func testNothingIsKnownBeforeTheFirstAnswer() {
        XCTAssertNil(makeStore().portfolioState(wallet: wallet))
    }

    func testAnsweredPortfolioIsCachedForItsWalletOnly() async {
        let portfolio = EarnPortfolioFixtures.portfolio()
        await makeStore().setPortfolio(portfolio, wallet: wallet)

        let relaunched = makeStore()

        XCTAssertEqual(relaunched.portfolioState(wallet: wallet), .loaded(portfolio, isStale: false))
        XCTAssertNil(relaunched.portfolioState(wallet: otherWallet))
    }

    func testEmptyAnswerIsKnownToBeEmpty() async {
        let empty = EarnPortfolio(walletId: EarnPortfolioFixtures.multichainWalletId, totalFiat: ["USD": 0], positions: [])
        await makeStore().setPortfolio(empty, wallet: wallet)

        XCTAssertEqual(makeStore().portfolioState(wallet: wallet), .loaded(empty, isStale: false))
    }

    func testFailedLoadKeepsTheLastPortfolioMarkedStale() async {
        let portfolio = EarnPortfolioFixtures.portfolio()
        let store = makeStore()
        await store.setPortfolio(portfolio, wallet: wallet)

        await store.setLoadFailed(wallet: wallet)

        XCTAssertEqual(store.portfolioState(wallet: wallet), .loaded(portfolio, isStale: true))
        XCTAssertEqual(makeStore().portfolioState(wallet: wallet), .loaded(portfolio, isStale: false))
    }

    func testFailedLoadWithNothingToFallBackOnIsUnavailable() async {
        let store = makeStore()

        await store.setLoadFailed(wallet: wallet)

        XCTAssertEqual(store.portfolioState(wallet: wallet), .unavailable)
    }

    func testFailedLoadDoesNotFallBackOnAnotherMultichainWalletsPortfolio() async {
        let store = makeStore()
        await store.setPortfolio(EarnPortfolioFixtures.portfolio(walletId: "aiprevious"), wallet: wallet)

        await store.setLoadFailed(wallet: wallet)

        XCTAssertEqual(store.portfolioState(wallet: wallet), .unavailable)
    }

    func testPortfolioOfAnotherMultichainWalletIsNotTheWallets() async {
        await makeStore().setPortfolio(EarnPortfolioFixtures.portfolio(walletId: "aiprevious"), wallet: wallet)

        XCTAssertNil(makeStore().portfolioState(wallet: wallet))
    }

    func testAnswerIsAnnounced() async {
        let store = makeStore()
        let announced = expectation(description: "Portfolio announced")
        store.addObserver(self) { [wallet] _, event in
            guard case let .didUpdatePortfolio(updated) = event, updated == wallet else { return }
            announced.fulfill()
        } onRegistered: { [wallet] in
            Task { await store.setPortfolio(EarnPortfolioFixtures.portfolio(), wallet: wallet) }
        }

        await fulfillment(of: [announced], timeout: 1)
    }
}

private extension EarnPortfolioStoreTests {
    func makeStore() -> EarnPortfolioStore {
        EarnPortfolioFixtures.store(wallets: [wallet, otherWallet], directory: directory)
    }
}
