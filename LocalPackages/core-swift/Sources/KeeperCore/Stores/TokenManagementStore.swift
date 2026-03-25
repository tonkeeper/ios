import Foundation

public final class TokenManagementStore: Store<TokenManagementStore.Event, TokenManagementStore.State> {
    public typealias State = [Wallet: TokenManagementState]

    public enum Event {
        case didUpdateState(wallet: Wallet)
    }

    private let walletsStore: WalletsStore
    private let tokenManagementRepository: TokenManagementRepository

    init(
        walletsStore: WalletsStore,
        tokenManagementRepository: TokenManagementRepository
    ) {
        self.walletsStore = walletsStore
        self.tokenManagementRepository = tokenManagementRepository
        super.init(state: State())

        walletsStore.addObserver(self) { _, event in
            switch event {
            case let .didAddWallets(wallets):
                self.updateState { state in
                    var updatedState = state
                    for wallet in wallets {
                        let walletState = tokenManagementRepository.getState(wallet: wallet)
                        updatedState[wallet] = walletState
                    }
                    return StateUpdate(newState: updatedState)
                } completion: { [weak self] _ in
                    for wallet in wallets {
                        self?.sendEvent(.didUpdateState(wallet: wallet))
                    }
                }
            default: break
            }
        }
    }

    override public func createInitialState() -> State {
        let wallets = walletsStore.wallets
        var state = State()
        for wallet in wallets {
            let walletState = tokenManagementRepository.getState(wallet: wallet)
            state[wallet] = walletState
        }
        return state
    }

    public func pinItem(
        identifier: String,
        wallet: Wallet,
        completion: (() -> Void)? = nil
    ) {
        updateState { [tokenManagementRepository] state in
            guard let walletState = state[wallet] else {
                return nil
            }
            var updatedPinnedItems = walletState.pinnedItems
            updatedPinnedItems.append(identifier)

            let updatedUnpinnedItems = walletState.unpinnedItems.filter { $0 != identifier }

            let walletUpdatedState = TokenManagementState(
                pinnedItems: updatedPinnedItems,
                unpinnedItems: updatedUnpinnedItems,
                hiddenState: walletState.hiddenState
            )
            var updatedState = state
            updatedState[wallet] = walletUpdatedState
            try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
            return StateUpdate(newState: updatedState)
        } completion: { [weak self] _ in
            self?.sendEvent(.didUpdateState(wallet: wallet))
            completion?()
        }
    }

    public func unpinItem(
        identifier: String,
        wallet: Wallet,
        completion: (() -> Void)? = nil
    ) {
        updateState { [tokenManagementRepository] state in
            guard let walletState = state[wallet] else {
                return nil
            }

            var updatedUnpinnedItems = walletState.unpinnedItems
            updatedUnpinnedItems.append(identifier)

            let updatedPinnedItems = walletState.pinnedItems.filter { $0 != identifier }
            let walletUpdatedState = TokenManagementState(
                pinnedItems: updatedPinnedItems,
                unpinnedItems: updatedUnpinnedItems,
                hiddenState: walletState.hiddenState
            )
            var updatedState = state
            updatedState[wallet] = walletUpdatedState
            try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
            return StateUpdate(newState: updatedState)
        } completion: { _ in
            self.sendEvent(.didUpdateState(wallet: wallet))
            completion?()
        }
    }

    public func hideItem(
        identifier: String,
        wallet: Wallet,
        completion: (() -> Void)? = nil
    ) {
        updateState { [tokenManagementRepository] state in
            guard let walletState = state[wallet] else {
                return nil
            }
            var updatedHiddenItems = walletState.hiddenState
            updatedHiddenItems[identifier] = true
            let walletUpdatedState = TokenManagementState(
                pinnedItems: walletState.pinnedItems,
                unpinnedItems: walletState.unpinnedItems,
                hiddenState: updatedHiddenItems
            )
            var updatedState = state
            updatedState[wallet] = walletUpdatedState
            try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
            return StateUpdate(newState: updatedState)
        } completion: { _ in
            self.sendEvent(.didUpdateState(wallet: wallet))
            completion?()
        }
    }

    public func unhideItem(
        identifier: String,
        wallet: Wallet,
        completion: (() -> Void)? = nil
    ) {
        updateState { [tokenManagementRepository] state in
            guard let walletState = state[wallet] else {
                return nil
            }
            var updatedHiddenItems = walletState.hiddenState
            updatedHiddenItems[identifier] = false
            let walletUpdatedState = TokenManagementState(
                pinnedItems: walletState.pinnedItems,
                unpinnedItems: walletState.unpinnedItems,
                hiddenState: updatedHiddenItems
            )
            var updatedState = state
            updatedState[wallet] = walletUpdatedState
            try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
            return StateUpdate(newState: updatedState)
        } completion: { _ in
            self.sendEvent(.didUpdateState(wallet: wallet))
            completion?()
        }
    }

    public func movePinnedItem(
        from: Int,
        to: Int,
        wallet: Wallet,
        completion: (() -> Void)? = nil
    ) {
        updateState { [tokenManagementRepository] state in
            guard let walletState = state[wallet] else {
                return nil
            }
            var pinnedItems = walletState.pinnedItems
            let item = pinnedItems.remove(at: from)
            pinnedItems.insert(item, at: to)
            let walletUpdatedState = TokenManagementState(
                pinnedItems: pinnedItems,
                unpinnedItems: walletState.unpinnedItems,
                hiddenState: walletState.hiddenState
            )
            var updatedState = state
            updatedState[wallet] = walletUpdatedState
            try? tokenManagementRepository.setState(walletUpdatedState, wallet: wallet)
            return StateUpdate(newState: updatedState)
        } completion: { _ in
            self.sendEvent(.didUpdateState(wallet: wallet))
            completion?()
        }
    }
}
