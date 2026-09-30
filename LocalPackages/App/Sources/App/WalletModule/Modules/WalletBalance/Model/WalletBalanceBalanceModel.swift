import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TonSwift

@MainActor
final class WalletBalanceBalanceModel {
    struct Item {
        let balanceItem: ProcessedBalanceItem
        let isPinned: Bool

        init(
            balanceItem: ProcessedBalanceItem,
            isPinned: Bool = false
        ) {
            self.balanceItem = balanceItem
            self.isPinned = isPinned
        }
    }

    struct BalanceListItems {
        let wallet: Wallet
        let items: [Item]
        let canManage: Bool
        let isSecure: Bool
    }

    var didUpdateItems: ((BalanceListItems) -> Void)?

    private(set) var wallet: Wallet

    private let balanceStore: ManagedBalanceStore
    private let stackingPoolsStore: StakingPoolsStore
    private let appSettingsStore: AppSettingsStore
    private let configuration: Configuration

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
        balanceStore: ManagedBalanceStore,
        stackingPoolsStore: StakingPoolsStore,
        appSettingsStore: AppSettingsStore,
        configuration: Configuration
    ) {
        self.wallet = wallet
        self.balanceStore = balanceStore
        self.stackingPoolsStore = stackingPoolsStore
        self.appSettingsStore = appSettingsStore
        self.configuration = configuration

        walletsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                observer.didGetWalletsStoreEvent(event)
            }
        }

        balanceStore.addObserver(self) { observer, event in
            Task { @MainActor in
                switch event {
                case let .didUpdateManagedBalance(wallet):
                    guard observer.wallet == wallet else { return }
                    observer.notifyItems()
                }
            }
        }

        stackingPoolsStore.addObserver(self) { observer, event in
            Task { @MainActor in
                switch event {
                case let .didUpdateStakingPools(wallet):
                    guard observer.wallet == wallet else { return }
                    observer.notifyItems()
                }
            }
        }

        appSettingsStore.addObserver(self) { observer, _ in
            Task { @MainActor in
                observer.notifyItems()
            }
        }
    }

    func getItems() -> BalanceListItems {
        createItems(
            wallet: wallet,
            balanceState: balanceStore.getState()[wallet],
            stakingPools: stackingPoolsStore.getState()[wallet] ?? [],
            isSecureMode: appSettingsStore.getState().isSecureMode
        )
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        switch event {
        case let .didUpdateWalletMetaData(wallet),
             let .didUpdateWalletMultichain(wallet):
            guard self.wallet == wallet else { return }
            self.wallet = wallet
            notifyItems()
        default:
            break
        }
    }

    private func notifyItems() {
        didUpdateItems?(getItems())
    }

    private func createItems(
        wallet: Wallet,
        balanceState: ManagedBalanceState?,
        stakingPools: [StackingPoolInfo],
        isSecureMode: Bool
    ) -> BalanceListItems {
        guard let balance = balanceState?.balance else {
            return BalanceListItems(wallet: wallet, items: [], canManage: false, isSecure: isSecureMode)
        }

        let items = balance.tonItems.map { Item(balanceItem: .ton($0), isPinned: false) }
            + balance.pinnedItems.map { Item(balanceItem: $0, isPinned: true) }
            + balance.unpinnedItems.map { Item(balanceItem: $0, isPinned: false) }

        let isUSDeAvailable = isUSDeAvailable(wallet: wallet)

        let filteredItems = items
            .filter { item in
                if case .ethena = item.balanceItem, item.balanceItem.isZeroBalance, !isUSDeAvailable {
                    return false
                }
                return true
            }

        return BalanceListItems(
            wallet: wallet,
            items: filteredItems,
            canManage: balance.isManagable,
            isSecure: isSecureMode
        )
    }

    private func isUSDeAvailable(wallet: Wallet) -> Bool {
        !configuration.flag(\.usdeDisabled, network: wallet.network)
    }
}
