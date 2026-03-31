import Foundation

public final class WalletBalanceLoader {
    public private(set) var isLoading: Bool = false
    private var balanceLoadTask: Task<Void, Never>?
    private let lock = NSLock()
    private var observers = [UUID: () -> Void]()

    private let wallet: Wallet
    private let balanceStore: BalanceStore
    private let stakingPoolsStore: StakingPoolsStore
    private let walletNFTSStore: WalletNFTStore
    private let balanceService: BalanceService
    private let stackingService: StakingService
    private let accountNFTService: AccountNFTService

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

    public func reloadBalance(currency: Currency, includingTransferFees: Bool = true) async {
        lock.withLock {
            self.balanceLoadTask?.cancel()

            self.isLoading = true
            self.observers.forEach { $0.value() }
            let task = Task {
                await loadAll(currency: currency, includingTransferFees: includingTransferFees)
                lock.withLock {
                    self.isLoading = false
                    self.observers.forEach { $0.value() }
                    self.balanceLoadTask = nil
                }
            }
            self.balanceLoadTask = task
        }
    }

    public func addUpdateObserver<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T) -> Void
    ) {
        let id = UUID()
        let observerClosure: () -> Void = { [weak self, weak observer] in
            guard let self else { return }
            guard let observer else {
                self.observers.removeValue(forKey: id)
                return
            }
            closure(observer)
        }
        lock.withLock {
            self.observers[id] = observerClosure
        }
    }

    private func loadAll(currency: Currency, includingTransferFees: Bool) async {
        async let balanceTask: Void = loadBalance(currency: currency, includingTransferFees: includingTransferFees)
        async let stakingPoolsTask: Void = loadStakingPools()
        async let nftsTask: Void = loadNFTs()

        await balanceTask
        await stakingPoolsTask
        await nftsTask
    }

    private func loadBalance(currency: Currency, includingTransferFees: Bool) async {
        do {
            let balance = try await balanceService.loadWalletBalance(
                wallet: wallet,
                currency: currency,
                includingTransferFees: includingTransferFees
            )
            let enrichedBalance = enrichBalanceWithJettons(balance: balance)
            try Task.checkCancellation()
            await balanceStore.setBalanceState(.current(enrichedBalance), wallet: wallet)
        } catch {
            guard !error.isCancelledError else { return }
            guard let balanceState = self.balanceStore.state[wallet] else {
                return
            }
            await self.balanceStore.setBalanceState(.previous(balanceState.walletBalance), wallet: wallet)
        }
    }

    private func loadStakingPools() async {
        guard let stackingPools = try? await self.stackingService.loadStakingPools(wallet: wallet),
              !Task.isCancelled
        else {
            return
        }
        await stakingPoolsStore.setStackingPools(stackingPools, wallet: wallet)
    }

    private func loadNFTs() async {
        await walletNFTSStore.loadNFTs()
    }

    private func enrichBalanceWithJettons(balance: WalletBalance) -> WalletBalance {
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
