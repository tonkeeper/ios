import Combine
import Foundation
import KeeperCore

@MainActor
final class TradeAssetDetailsTronFeesViewModel: ObservableObject {
    @Published private(set) var snapshot: TronUsdtFeesSnapshot?

    private let wallet: Wallet
    private let feesService: TronUsdtFeesService
    private let balanceStore: ProcessedBalanceStore

    init(
        wallet: Wallet,
        feesService: TronUsdtFeesService,
        balanceStore: ProcessedBalanceStore
    ) {
        self.wallet = wallet
        self.feesService = feesService
        self.balanceStore = balanceStore

        feesService.addUpdateObserver(self) { observer, updatedWallet in
            Task { @MainActor in
                observer.handleUpdate(wallet: updatedWallet)
            }
        }

        balanceStore.addObserver(self) { observer, event in
            Task { @MainActor in
                switch event {
                case let .didUpdateProccessedBalance(wallet):
                    observer.handleUpdate(wallet: wallet)
                }
            }
        }
    }

    func scheduleUpdate() {
        refreshSnapshot()
        Task { [feesService, wallet] in
            await feesService.refresh(wallet: wallet)
        }
    }
}

private extension TradeAssetDetailsTronFeesViewModel {
    func handleUpdate(wallet: Wallet) {
        guard wallet == self.wallet else {
            return
        }
        refreshSnapshot()
    }

    func refreshSnapshot() {
        snapshot = balanceStore.getState()[wallet]
            .flatMap { state in
                feesService.snapshot(wallet: wallet, balance: state.balance)
            }
    }
}
