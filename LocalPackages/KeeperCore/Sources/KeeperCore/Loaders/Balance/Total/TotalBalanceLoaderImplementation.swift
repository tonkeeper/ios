import Foundation

/// The wallets list asks for every wallet at once, which is the heaviest request the app makes.
/// This is where that sweep is paced: who is stale enough to be worth asking for, which of the two
/// mechanics answers for them, and how many go out at a time. What either mechanic actually does is
/// handed in, so this type holds the policy and nothing else.
actor TotalBalanceLoaderImplementation {
    typealias LoadPortfolioTotal = (Wallet, MultichainWalletState, Currency) async -> Void
    typealias LoadWalletBalance = (Wallet, Currency, Bool) async -> Void

    private enum Constants {
        static let chunkSize = 2
        static let interChunkDelay: TimeInterval = 0.5
    }

    private let balanceStore: BalanceStore
    private let multichainPortfolioStore: MultichainPortfolioStore
    private let loadPortfolioTotal: LoadPortfolioTotal
    private let loadWalletBalance: LoadWalletBalance
    private let hidesDustBalances: @Sendable () -> Bool
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async throws -> Void

    private var run: Task<Void, Never>?
    private var lastRunId: UInt64 = 0

    init(
        balanceStore: BalanceStore,
        multichainPortfolioStore: MultichainPortfolioStore,
        loadPortfolioTotal: @escaping LoadPortfolioTotal,
        loadWalletBalance: @escaping LoadWalletBalance,
        hidesDustBalances: @escaping @Sendable () -> Bool = { false },
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = TotalBalanceLoaderImplementation.defaultSleep
    ) {
        self.balanceStore = balanceStore
        self.multichainPortfolioStore = multichainPortfolioStore
        self.loadPortfolioTotal = loadPortfolioTotal
        self.loadWalletBalance = loadWalletBalance
        self.hidesDustBalances = hidesDustBalances
        self.now = now
        self.sleep = sleep
    }
}

extension TotalBalanceLoaderImplementation: TotalBalanceLoader {
    /// Replaces the sweep in flight: the wallets it was still working through are the ones this
    /// request covers anyway, and two sweeps at once would double the heaviest traffic there is.
    func reloadBalances(wallets: [Wallet], activeWallet: Wallet?, currency: Currency) async {
        let targets = TotalBalanceLoaderTarget.from(
            wallets: wallets,
            balanceStates: balanceStore.state,
            portfolioTotals: multichainPortfolioStore.getState(),
            currencyCode: currency.code.lowercased(),
            hidesDustBalances: hidesDustBalances(),
            now: now()
        )
        guard !targets.isEmpty else { return }

        run?.cancel()
        lastRunId &+= 1
        let runId = lastRunId
        let task = Task { [weak self] in
            guard let self else { return }
            await load(targets: targets, activeWallet: activeWallet, currency: currency)
        }
        run = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        retireRun(runId)
    }
}

extension TotalBalanceLoaderImplementation {
    private func retireRun(_ id: UInt64) {
        guard lastRunId == id else { return }
        run = nil
    }

    /// Chunked with a pause between chunks: the point is to keep a wallets list of any size from
    /// reaching the backend as one burst.
    private nonisolated func load(
        targets: [TotalBalanceLoaderTarget],
        activeWallet: Wallet?,
        currency: Currency
    ) async {
        let chunks = targets.chunked(into: Constants.chunkSize)
        for (index, chunk) in chunks.enumerated() {
            guard !Task.isCancelled else { return }
            await withTaskGroup(of: Void.self) { group in
                for target in chunk {
                    group.addTask {
                        await self.load(target: target, activeWallet: activeWallet, currency: currency)
                    }
                }
                await group.waitForAll()
            }
            guard !Task.isCancelled, index < chunks.count - 1 else { continue }
            do {
                try await sleep(Constants.interChunkDelay)
            } catch {
                return
            }
        }
    }

    private nonisolated func load(
        target: TotalBalanceLoaderTarget,
        activeWallet: Wallet?,
        currency: Currency
    ) async {
        guard !Task.isCancelled else { return }
        switch target {
        case let .portfolioTotal(wallet, state):
            await loadPortfolioTotal(wallet, state, currency)
        case let .walletBalance(wallet):
            // The active wallet keeps a full refresh, battery included. A lightweight list refresh
            // must not overwrite a fresher active battery with cache.
            await loadWalletBalance(wallet, currency, wallet == activeWallet)
        }
    }
}

extension TotalBalanceLoaderImplementation {
    static let defaultSleep: @Sendable (TimeInterval) async throws -> Void = { delay in
        try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
