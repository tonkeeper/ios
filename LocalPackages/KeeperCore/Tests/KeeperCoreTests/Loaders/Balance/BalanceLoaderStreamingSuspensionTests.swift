import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

/// TK-2837: the migration flow asks for quiet while it broadcasts, but streaming updates kept
/// driving full reloads — rates included — because the suspension only covered the list and idle
/// timers.
final class BalanceLoaderStreamingSuspensionTests: XCTestCase {
    private let migration = BalanceQuietOwner.flow(id: "migration")

    func test_backgroundRefreshIsIgnoredWhileQuiet() async {
        let context = makeContext()
        context.balanceLoader.setQuiet(true, owner: migration)

        await expectRatesRequest(context: context, expected: false) {
            Task { [balanceLoader = context.balanceLoader, wallet = context.wallet] in
                await balanceLoader.reloadBalance(wallet: wallet, priority: .background)
            }
        }
    }

    /// Quiet is a budget handed to a flow, not a reason to ignore the user: a purchase or a pull to
    /// refresh inside the flow still reloads.
    func test_aRefreshSomeoneIsWaitingOnStillRunsWhileQuiet() async {
        let context = makeContext()
        context.balanceLoader.setQuiet(true, owner: migration)

        await expectRatesRequest(context: context, expected: true) {
            Task { [balanceLoader = context.balanceLoader, wallet = context.wallet] in
                await balanceLoader.reloadBalance(wallet: wallet, priority: .userInitiated)
            }
        }
    }

    /// A request the gate refuses still answers, and says it never ran rather than reporting on an
    /// amount it knows nothing about.
    func test_aRefusedRequestIsAnsweredAsDropped() async {
        let context = makeContext()
        context.balanceLoader.setQuiet(true, owner: migration)

        let result = await context.balanceLoader.reloadBalance(
            wallet: context.wallet,
            priority: .background
        )

        XCTAssertEqual(result, .dropped)
    }

    /// No per-wallet loader is registered for this wallet, so the run has nothing to load — and the
    /// caller has to be told rather than left waiting.
    func test_aRunWithNothingToLoadStillAnswers() async {
        let context = makeContext()

        let result = await context.balanceLoader.reloadBalance(
            wallet: context.wallet,
            priority: .userInitiated
        )

        XCTAssertEqual(result, .dropped)
    }

    private func expectRatesRequest(
        context: Context,
        expected: Bool,
        trigger: () -> Task<Void, Never>
    ) async {
        let request = expectation(description: "rates request started")
        request.isInverted = !expected
        context.ratesService.didStartLoad = { request.fulfill() }
        let reload = trigger()
        await fulfillment(of: [request], timeout: expected ? 1 : 0.05)
        reload.cancel()
    }

    private struct Context {
        let balanceLoader: BalanceLoader
        let ratesService: SuspensionRatesServiceSpy
        let wallet: Wallet
    }

    /// The store starts empty on purpose: with no per-wallet loader registered, a reload reaches
    /// the rates request and stops there, which keeps the assertions on traffic alone.
    private func makeContext() -> Context {
        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: SuspensionKeeperInfoRepositoryStub())
        let walletsStore = WalletsStore(keeperInfoStore: keeperInfoStore)
        let ratesService = SuspensionRatesServiceSpy()
        let balanceLoader = BalanceLoaderImplementation(
            walletStore: walletsStore,
            currencyStore: CurrencyStore(keeperInfoStore: keeperInfoStore),
            ratesStore: TonRatesStore(repository: SuspensionRatesRepositoryStub()),
            ratesService: ratesService,
            walletStateLoaderProvider: { _ in
                fatalError("No wallet is registered, so no per-wallet loader should be requested")
            },
            makeTotalBalanceLoader: { loadWalletBalance in
                TotalBalanceLoaderImplementation(
                    balanceStore: BalanceStore(
                        walletsStore: walletsStore,
                        repository: SuspensionWalletBalanceRepositoryStub()
                    ),
                    multichainPortfolioStore: MultichainPortfolioStore.makeStub(),
                    loadPortfolioTotal: { _, _, _ in },
                    loadWalletBalance: loadWalletBalance
                )
            }
        )
        balanceLoader.setQuiet(false, owner: .appLifecycle)
        return Context(
            balanceLoader: balanceLoader,
            ratesService: ratesService,
            wallet: makeWallet()
        )
    }

    private func makeWallet() -> Wallet {
        Wallet(
            id: "balance-loader-suspension-test",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class SuspensionRatesServiceSpy: RatesService, @unchecked Sendable {
    var didStartLoad: (() -> Void)?

    func loadRates(jettons _: [String], currencies _: [Currency]) async throws -> Rates {
        didStartLoad?()
        return Rates(ton: [], usdt: [], jettonRates: [:])
    }
}

private enum SuspensionStubError: Error {
    case missing
}

private final class SuspensionKeeperInfoRepositoryStub: KeeperInfoRepository {
    func getKeeperInfo() throws -> KeeperInfo {
        throw SuspensionStubError.missing
    }

    func saveKeeperInfo(_: KeeperInfo) throws {}

    func removeKeeperInfo() throws {}
}

private struct SuspensionWalletBalanceRepositoryStub: WalletBalanceRepositoryV2 {
    func getBalance(address _: FriendlyAddress) throws -> WalletBalance {
        throw SuspensionStubError.missing
    }
}

private struct SuspensionRatesRepositoryStub: RatesRepository {
    func saveRates(_: Rates) throws {}

    func getRates() throws -> Rates {
        throw SuspensionStubError.missing
    }
}
