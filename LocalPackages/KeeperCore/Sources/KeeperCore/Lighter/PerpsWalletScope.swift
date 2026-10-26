import Foundation
import PerpsModels

public final class PerpsWalletScope {
    public let wallet: Wallet
    public let accountService: PerpsAccountService

    private lazy var tkTradingService = PerpsTkTradingService(
        accountService: accountService,
        wallet: wallet,
        perpsAPI: perpsAPI,
        markPriceProvider: markPriceProvider,
        marketProvider: marketProvider
    )

    public private(set) lazy var tradingService: PerpsTradingService = tkTradingService

    /// Absent for a wallet the multichain backend has no id for: nothing can be quoted,
    /// signed or registered for it, and a deposit screen has nothing to show.
    public private(set) lazy var depositService: PerpsDepositService? = accountService.depositService(wallet: wallet)
    public private(set) lazy var withdrawService: PerpsWithdrawService? = accountService.withdrawService(wallet: wallet)

    public private(set) lazy var accountStore = PerpsAccountStore(
        service: PerpsTkAccountReading(
            api: perpsAPI
        ),
        wallet: wallet,
        recoverOperations: { [tkTradingService] in
            await tkTradingService.recoverInterruptedOperations()
        },
        renewAutoClose: { [tkTradingService] marketIds in
            await tkTradingService.renewExpiringAutoClose(marketIds: marketIds)
        },
        refreshOrderAccess: { [accountService, wallet] in
            await accountService.refreshReadOnlyToken(wallet: wallet)
        },
        reissueReadOnlyToken: { [accountService, wallet] in
            await accountService.refreshReadOnlyToken(wallet: wallet, force: true)
        },
        holdsTradingKey: { [accountService, wallet] in
            if (try? await accountService.tradingSession(wallet: wallet)) != nil { return true }
            return await accountService.adoptRegisteredTradingKey(wallet: wallet)
        },
        ensureAccountTier: { [accountService, wallet] in
            await accountService.ensurePlusTier(wallet: wallet, trigger: .resolve)
        },
        loadHistory: { [historyFeed] marketId, limit in
            try await historyFeed.recent(marketId: marketId, limit: limit)
        }
    )

    public func recoverFunding(while enabledStates: AsyncStream<Bool>) async {
        let recovery = accountService.fundingRecovery(wallet: wallet)
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
        await accountService.fundingRecovery(wallet: wallet).refresh()
    }

    public func pendingActivityOperations() async throws -> (
        trading: [PerpsPendingTradingAction],
        funding: [PerpsPendingFundingOperation]
    ) {
        let journal = accountService.pendingJournal(wallet: wallet)
        let trading = try await journal.allPending()
        let funding = try await journal.allFunding()
        return (trading, funding)
    }

    public func marketSymbol(marketId: Int64) async -> String? {
        await marketProvider(marketId)?.symbol
    }

    private let markPriceProvider: @Sendable (Int64) async -> Double?
    private let marketProvider: @Sendable (Int64) async -> PerpsMarketMetadata?
    private let perpsAPI: PerpsAPI
    private let historyFeed: PerpsHistoryFeed

    init(
        wallet: Wallet,
        accountService: PerpsAccountService,
        perpsAPI: PerpsAPI,
        multichainService: MultichainService,
        markPriceProvider: @escaping @Sendable (Int64) async -> Double?,
        marketProvider: @escaping @Sendable (Int64) async -> PerpsMarketMetadata?
    ) {
        self.wallet = wallet
        self.accountService = accountService
        self.perpsAPI = perpsAPI
        self.historyFeed = PerpsHistoryFeed(multichainService: multichainService, wallet: wallet)
        self.markPriceProvider = markPriceProvider
        self.marketProvider = marketProvider
    }
}
