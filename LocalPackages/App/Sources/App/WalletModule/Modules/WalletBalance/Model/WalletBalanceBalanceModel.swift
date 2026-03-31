import BigInt
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TonSwift

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

    private let actor = SerialActor<Void>()

    private let walletsStore: WalletsStore
    private let balanceStore: ManagedBalanceStore
    private let stackingPoolsStore: StakingPoolsStore
    private let appSettingsStore: AppSettingsStore
    private let configuration: Configuration

    init(
        walletsStore: WalletsStore,
        balanceStore: ManagedBalanceStore,
        stackingPoolsStore: StakingPoolsStore,
        appSettingsStore: AppSettingsStore,
        configuration: Configuration
    ) {
        self.walletsStore = walletsStore
        self.balanceStore = balanceStore
        self.stackingPoolsStore = stackingPoolsStore
        self.appSettingsStore = appSettingsStore
        self.configuration = configuration

        walletsStore.addObserver(self) { observer, event in
            observer.didGetWalletsStoreEvent(event)
        }

        balanceStore.addObserver(self) { observer, event in
            observer.didGetBalanceStoreEvent(event)
        }

        stackingPoolsStore.addObserver(self) { observer, event in
            observer.didGetStackingPoolsStoreEvent(event)
        }

        appSettingsStore.addObserver(self) { observer, event in
            observer.didGetAppSettingsStoreEvent(event)
        }
    }

    func getItems() throws -> BalanceListItems {
        let activeWallet = try walletsStore.activeWallet
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let balanceState = balanceStore.getState()[activeWallet]
        let stakingPools = stackingPoolsStore.getState()[activeWallet]
        return createItems(
            wallet: activeWallet,
            balanceState: balanceState,
            stakingPools: stakingPools ?? [],
            isSecureMode: isSecureMode
        )
    }

    private func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
        Task {
            switch event {
            case .didChangeActiveWallet:
                await self.actor.addTask(block: { await self.updateItems() })
            case .didUpdateWalletMetaData:
                await self.actor.addTask(block: { await self.updateItems() })
            default: break
            }
        }
    }

    private func didGetBalanceStoreEvent(_ event: ManagedBalanceStore.Event) {
        Task {
            switch event {
            case let .didUpdateManagedBalance(wallet):
                switch walletsStore.getState() {
                case .empty: break
                case let .wallets(state):
                    guard state.activeWallet == wallet else { return }
                    await self.actor.addTask(block: { await self.updateItems() })
                }
            }
        }
    }

    private func didGetStackingPoolsStoreEvent(_ event: StakingPoolsStore.Event) {
        Task {
            switch event {
            case let .didUpdateStakingPools(wallet):
                switch walletsStore.getState() {
                case .empty: break
                case let .wallets(state):
                    guard state.activeWallet == wallet else { return }
                    await self.actor.addTask(block: { await self.updateItems() })
                }
            }
        }
    }

    private func didGetAppSettingsStoreEvent(_ event: AppSettingsStore.Event) {
        Task {
            await self.actor.addTask(block: { await self.updateItems() })
        }
    }

    private func updateItems() async {
        let walletsStoreState = walletsStore.state
        switch walletsStoreState {
        case .empty: break
        case let .wallets(walletsState):
            let isSecureMode = appSettingsStore.state.isSecureMode
            let balanceState = balanceStore.state[walletsState.activeWallet]
            let stakingPools = stackingPoolsStore.state[walletsState.activeWallet]
            let items = createItems(
                wallet: walletsState.activeWallet,
                balanceState: balanceState,
                stakingPools: stakingPools ?? [],
                isSecureMode: isSecureMode
            )
            didUpdateItems?(items)
        }
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
