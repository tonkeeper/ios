import Foundation

actor WalletBalanceLoaderImplementation {
    /// A lightweight list refresh must not displace the full load the active wallet is getting, so
    /// the run in flight is compared against the one asking.
    private enum LoadPriority: Int, Comparable {
        case lightweight
        case full

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private struct Run {
        let id: UInt64
        let priority: LoadPriority
        let task: Task<BalanceRefreshResult, Never>
    }

    private let wallet: Wallet
    private let balanceStore: BalanceStore
    private let stakingPoolsStore: StakingPoolsStore
    private let walletNFTSStore: WalletNFTStore
    private let balanceService: BalanceService
    private let stackingService: StakingService
    private let accountNFTService: AccountNFTService

    private var run: Run?
    private var lastRunId: UInt64 = 0

    init(
        wallet: Wallet,
        balanceStore: BalanceStore,
        stakingPoolsStore: StakingPoolsStore,
        walletNFTSStore: WalletNFTStore,
        balanceService: BalanceService,
        stackingService: StakingService,
        accountNFTService: AccountNFTService
    ) {
        self.wallet = wallet
        self.balanceStore = balanceStore
        self.stakingPoolsStore = stakingPoolsStore
        self.walletNFTSStore = walletNFTSStore
        self.balanceService = balanceService
        self.stackingService = stackingService
        self.accountNFTService = accountNFTService
    }
}

extension WalletBalanceLoaderImplementation: WalletBalanceLoader {
    @discardableResult
    func reloadBalance(
        currency: Currency,
        includingTransferFees: Bool = true
    ) async -> BalanceRefreshResult {
        guard let run = startRun(
            priority: includingTransferFees ? .full : .lightweight,
            currency: currency,
            includingTransferFees: includingTransferFees
        ) else {
            return .dropped
        }
        let result = await withTaskCancellationHandler {
            await run.task.value
        } onCancel: {
            run.task.cancel()
        }
        retireRun(run.id)
        return result
    }
}

extension WalletBalanceLoaderImplementation {
    private func startRun(
        priority: LoadPriority,
        currency: Currency,
        includingTransferFees: Bool
    ) -> Run? {
        if let run {
            guard priority >= run.priority else { return nil }
            run.task.cancel()
        }
        lastRunId &+= 1
        let run = Run(
            id: lastRunId,
            priority: priority,
            task: Task { [weak self] in
                guard let self else { return .dropped }
                return await load(currency: currency, includingTransferFees: includingTransferFees)
            }
        )
        self.run = run
        return run
    }

    private func retireRun(_ id: UInt64) {
        guard run?.id == id else { return }
        run = nil
    }

    /// The three loads share a run but not a verdict: only the balance answers for what the caller
    /// asked, while the pools and the NFTs are along for the same trip.
    private nonisolated func load(
        currency: Currency,
        includingTransferFees: Bool
    ) async -> BalanceRefreshResult {
        async let balance = loadBalance(
            currency: currency,
            includingTransferFees: includingTransferFees
        )
        async let stakingPools: Void = loadStakingPools()
        async let nfts: Void = loadNFTs()

        let result = await balance
        _ = await(stakingPools, nfts)
        return result
    }

    private nonisolated func loadBalance(
        currency: Currency,
        includingTransferFees: Bool
    ) async -> BalanceRefreshResult {
        do {
            let balance = try await balanceService.loadWalletBalance(
                wallet: wallet,
                currency: currency,
                includingTransferFees: includingTransferFees
            )
            let enrichedBalance = enrichBalanceWithJettons(balance: balance)
            try Task.checkCancellation()
            let state = WalletBalanceState.current(enrichedBalance)
            await balanceStore.setBalanceState(state, wallet: wallet)
            return .delivered(state)
        } catch {
            // A run that never reached its verdict says nothing about the amount on screen.
            guard !error.isCancelledError else { return .dropped }
            guard let balanceState = balanceStore.state[wallet] else { return .failed }
            // The republished balance is the value the caller already had: a failure, not a delivery.
            await balanceStore.setBalanceState(.previous(balanceState.walletBalance), wallet: wallet)
            return .failed
        }
    }

    private nonisolated func loadStakingPools() async {
        guard let stackingPools = try? await stackingService.loadStakingPools(wallet: wallet),
              !Task.isCancelled
        else {
            return
        }
        await stakingPoolsStore.setStackingPools(stackingPools, wallet: wallet)
    }

    private nonisolated func loadNFTs() async {
        guard !Task.isCancelled else { return }
        await walletNFTSStore.loadNFTs()
    }

    private nonisolated func enrichBalanceWithJettons(balance: WalletBalance) -> WalletBalance {
        var jettonsBalance = balance.balance.jettonsBalance

        if !jettonsBalance.contains(where: { $0.item.jettonInfo.address == JettonMasterAddress.USDe }) {
            jettonsBalance.append(
                JettonBalance(
                    item: JettonItem(
                        jettonInfo: JettonInfo(
                            isTransferable: true,
                            hasCustomPayload: false,
                            address: JettonMasterAddress.USDe,
                            fractionDigits: USDe.fractionDigits,
                            name: USDe.name,
                            symbol: USDe.symbol,
                            verification: .whitelist,
                            imageURL: nil
                        ),
                        walletAddress: nil
                    ),
                    quantity: 0,
                    rates: [:]
                )
            )
        }

        return WalletBalance(
            date: balance.date,
            balance: Balance(
                tonBalance: balance.balance.tonBalance,
                jettonsBalance: jettonsBalance
            ),
            stacking: balance.stacking,
            batteryBalance: balance.batteryBalance,
            tronBalance: balance.tronBalance
        )
    }
}
