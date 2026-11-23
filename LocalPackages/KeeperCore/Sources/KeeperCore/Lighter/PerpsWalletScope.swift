import Foundation
import PerpsModels

public final class PerpsWalletScope {
    public let wallet: Wallet
    public let accountService: PerpsAccountService
    let journal: PerpsPendingJournal
    let readOnlyToken: PerpsReadOnlyToken
    private let liveFeed: PerpsLiveFeed
    private let fundingRecovery: PerpsFundingRecovery

    /// A trade form asks for the market's orders and for a quote as it opens; both read the same screen.
    /// `PerpsAccountStore.refresh()` drops them, so a reload after the user's action never gets an earlier screen.
    private let tradingScreenReads = PerpsTradingScreenReads()

    private lazy var tkTradingService: PerpsTkTradingService = PerpsTkTradingService(
        accountService: accountService,
        wallet: wallet,
        journal: journal,
        readOnlyToken: readOnlyToken,
        perpsAPI: perpsAPI,
        markPriceProvider: markPriceProvider,
        marketProvider: marketProvider,
        tradingScreenReads: tradingScreenReads,
        operationJournaled: { [weak self] in self?.tradingRecovery.recover() },
        tradeBegan: { [weak self] operationId, marketId, trade in
            self?.accountStore.tradeBegan(operationId: operationId, marketId: marketId, trade)
        },
        tradeSettled: { [weak self] operationId, succeeded in
            self?.accountStore.tradeSettled(operationId: operationId, succeeded: succeeded)
        },
        positionCounted: { [weak self] operationId, position in
            self?.accountStore.positionCounted(operationId: operationId, position)
        },
        positionClosed: { [weak self] operationId, marketId in
            await self?.accountStore.positionClosed(operationId: operationId, marketId: marketId)
        },
        liveFeed: liveFeed
    )

    private lazy var tradingRecovery: PerpsTradingRecovery = PerpsTradingRecovery(
        recover: { [tkTradingService] in
            await tkTradingService.recoverInterruptedOperations()
        },
        renewAutoClose: { [tkTradingService] marketIds in
            await tkTradingService.renewExpiringAutoClose(marketIds: marketIds)
        },
        sleep: { [wait = liveFeed.waits(on: [.anyMarket, .account])] nanoseconds in
            _ = await wait(nanoseconds)
        }
    )

    public private(set) lazy var tradingService: PerpsTradingService = tkTradingService

    /// Absent for a wallet the multichain backend has no id for: nothing can be quoted,
    /// signed or registered for it, and a deposit screen has nothing to show.
    public private(set) lazy var depositService: PerpsDepositService? = accountService.depositService(
        wallet: wallet,
        journal: journal,
        recovery: fundingRecovery,
        readOnlyToken: readOnlyToken
    )
    public private(set) lazy var withdrawService: PerpsWithdrawService? = accountService.withdrawService(
        wallet: wallet,
        journal: journal,
        recovery: fundingRecovery,
        readOnlyToken: readOnlyToken
    )

    public private(set) lazy var accountStore = PerpsAccountStore(
        service: PerpsTkAccountReading(
            api: perpsAPI,
            tradingScreenReads: tradingScreenReads,
            liveFeed: liveFeed,
            markPrices: markPrices,
            isRealtimeEnabled: isRealtimeEnabled,
            unlistedPositions: unlistedPositions
        ),
        wallet: wallet,
        recoverOperations: { [weak tradingRecovery] in
            tradingRecovery?.recover()
        },
        renewAutoClose: { [weak tradingRecovery] marketIds in
            tradingRecovery?.renewAutoClose(marketIds: marketIds)
        },
        reissueReadOnlyToken: { [readOnlyToken] in
            await readOnlyToken.issue()
        },
        holdsTradingKey: { [accountService, wallet, readOnlyToken] in
            if (try? await accountService.tradingSession(wallet: wallet)) != nil { return true }
            return await accountService.adoptRegisteredTradingKey(wallet: wallet, readOnlyToken: readOnlyToken)
        },
        ensureAccountTier: { [accountService, wallet, readOnlyToken] in
            await accountService.ensurePlusTier(wallet: wallet, trigger: .resolve, readOnlyToken: readOnlyToken)
        },
        loadHistory: { [historyFeed] marketId, limit in
            try await historyFeed.recent(marketId: marketId, limit: limit)
        },
        observeHistoryChanges: { [historyFeed] observer, onChange in
            historyFeed.events.observeChanges(by: observer, onChange: onChange)
        },
        persistDepositAcknowledgements: { [journal, fundingRecovery] ids in
            try await journal.acknowledgeDepositStatuses(ids)
            await fundingRecovery.refresh()
        }
    )

    public func activate(passcode: String) async -> PerpsAccountActivationOutcome {
        await accountService.activate(wallet: wallet, passcode: passcode, readOnlyToken: readOnlyToken)
    }

    public func adoptRegisteredTradingKey() async -> Bool {
        await accountService.adoptRegisteredTradingKey(wallet: wallet, readOnlyToken: readOnlyToken)
    }

    public func recoverFunding(while enabledStates: AsyncStream<Bool>) async {
        let recovery = fundingRecovery
        let store = accountStore
        let observerId = UUID()
        let updates = await recovery.updates(for: observerId)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                var wasEnabled = false
                for await enabled in enabledStates {
                    guard !Task.isCancelled else { break }
                    if enabled, !wasEnabled { store.retryFundingRefreshIfNeeded() }
                    wasEnabled = enabled
                    await recovery.setEnabled(enabled, for: observerId)
                }
            }
            group.addTask {
                for await state in updates {
                    guard !Task.isCancelled else { break }
                    store.applyFundingState(state)
                }
            }
            await group.next()
            group.cancelAll()
        }
        await recovery.removeObserver(observerId)
    }

    /// The journal's wake-up side, not only a pull-to-refresh: call it right after saving a
    /// funding operation or advancing its stage. See `PerpsFundingRecovery.refresh()`.
    public func refreshFunding() async {
        accountStore.retryFundingRefreshIfNeeded()
        await fundingRecovery.refresh()
    }

    public func pendingActivityOperations() async throws -> (
        trading: [PerpsPendingTradingAction],
        funding: [PerpsPendingFundingOperation]
    ) {
        let trading = try await journal.allPending().filter {
            if case .autoCloseRebase = $0.payload { return false }
            return true
        }
        let funding = try await journal.allFunding()
        return (trading, funding)
    }

    public func marketSymbol(marketId: Int64) async -> String? {
        await marketProvider(marketId)?.symbol
    }

    private let markPriceProvider: @Sendable (Int64) async -> Double?
    private let markPrices: @Sendable (Set<Int64>) -> AsyncStream<[Int64: Double]>
    private let isRealtimeEnabled: @Sendable () -> Bool
    private let marketProvider: @Sendable (Int64) async -> PerpsMarketMetadata?
    private let unlistedPositions: PerpsUnlistedPositionsReport?
    private let perpsAPI: PerpsAPI
    private let historyFeed: PerpsHistoryFeed

    init(
        wallet: Wallet,
        accountService: PerpsAccountService,
        perpsAPI: PerpsAPI,
        multichainService: MultichainService,
        historyEvents: PerpsHistoryEvents,
        markPriceProvider: @escaping @Sendable (Int64) async -> Double?,
        marketProvider: @escaping @Sendable (Int64) async -> PerpsMarketMetadata?,
        markPrices: @escaping @Sendable (Set<Int64>) -> AsyncStream<[Int64: Double]>,
        perpsSignals: @escaping @Sendable (_ walletId: String) -> AsyncStream<PerpsRealtimeSignal>,
        isRealtimeEnabled: @escaping @Sendable () -> Bool,
        unlistedPositions: PerpsUnlistedPositionsReport? = nil
    ) {
        self.wallet = wallet
        self.unlistedPositions = unlistedPositions
        let multichainWalletId = wallet.multichainWalletState?.walletId
        let liveFeed = PerpsLiveFeed(signals: {
            guard let multichainWalletId, !multichainWalletId.isEmpty else { return AsyncStream { $0.finish() } }
            return perpsSignals(multichainWalletId)
        })
        self.liveFeed = liveFeed
        self.accountService = accountService
        let journal = PerpsPendingJournal(walletId: wallet.id, environment: PerpsEnvironment.storage)
        self.journal = journal
        readOnlyToken = PerpsReadOnlyToken(mint: { [accountService, wallet] in
            await accountService.mintReadOnlyToken(wallet: wallet)
        })
        fundingRecovery = accountService.fundingRecovery(
            wallet: wallet,
            journal: journal,
            awaitChange: liveFeed.waits(on: [.deposit, .withdrawal])
        )
        self.perpsAPI = perpsAPI
        self.historyFeed = PerpsHistoryFeed(multichainService: multichainService, wallet: wallet, events: historyEvents)
        self.markPriceProvider = markPriceProvider
        self.markPrices = markPrices
        self.isRealtimeEnabled = isRealtimeEnabled
        self.marketProvider = marketProvider
        _ = accountStore
    }
}
