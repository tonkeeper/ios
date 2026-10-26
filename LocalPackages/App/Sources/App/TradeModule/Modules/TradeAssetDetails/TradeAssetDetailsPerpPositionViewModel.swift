import Foundation
import KeeperCore
import Perps
import PerpsModels

@MainActor
final class TradeAssetDetailsPerpPositionViewModel: ObservableObject {
    enum State: Equatable {
        case unknown
        case loading
        case noPosition
        case position(PerpsPositionRowItem)
    }

    @Published private(set) var state: State = .unknown

    private let walletScope: PerpsWalletScope?
    private let accountStore: any PerpsAccountStoring
    private let format = PerpsFormatting.live
    private var marketId: Int64?
    private var iconURL: URL?
    private var isOnScreen = false
    private var isWalletActive = true
    private var isSubscribedToPositions = false
    private var needsRefreshOnAppear = false

    init(
        accountStore: any PerpsAccountStoring,
        walletScope: PerpsWalletScope? = nil,
        walletsStore: WalletsStore? = nil
    ) {
        self.walletScope = walletScope
        self.accountStore = accountStore
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.applyAccount() }
        }
        // The page outlives its wallet's turn as the active one: a send signed for another wallet
        // makes that one active and pushes history over this page. Every event re-reads the active
        // wallet, since `makeWalletActive` reports a change even when the wallet stays the same.
        if let walletsStore, let wallet = walletScope?.wallet {
            walletsStore.addObserver(self) { [weak walletsStore] observer, _ in
                guard let walletsStore else { return }
                Task { @MainActor in
                    observer.setWalletActive((try? walletsStore.activeWallet) == wallet)
                }
            }
        }
    }

    deinit {
        if isSubscribedToPositions {
            accountStore.unsubscribePositions(cadence: .ambient)
        }
    }

    func setMarket(_ marketId: Int64?, iconURL: URL?) {
        guard self.marketId != marketId || self.iconURL != iconURL else { return }
        if self.marketId != marketId {
            state = .unknown
        }
        self.marketId = marketId
        self.iconURL = iconURL
        resolveIfNeeded()
        applyAccount()
    }

    func didAppear() {
        guard !isOnScreen else { return }
        isOnScreen = true
        if needsRefreshOnAppear {
            needsRefreshOnAppear = false
            refresh()
        } else {
            resolveIfNeeded()
        }
        applyAccount()
    }

    func didDisappear() {
        guard isOnScreen else { return }
        isOnScreen = false
        unsubscribeFromPositions()
    }

    /// A refresh asked for while the page is covered (a send pushes history over it) is held
    /// until the page is back, so a hidden page never reads the account.
    func refresh() {
        guard marketId != nil, isWalletActive else { return }
        guard isOnScreen else {
            needsRefreshOnAppear = true
            return
        }
        switch accountStore.currentWalletState() {
        case .unresolved, .resolving:
            accountStore.resolveIfNeeded()
        case .active:
            accountStore.refresh()
        case .unbound, .inactive:
            break
        }
    }

    func setWalletActive(_ isActive: Bool) {
        guard isWalletActive != isActive else { return }
        isWalletActive = isActive
        resolveIfNeeded()
        applyAccount()
    }
}

private extension TradeAssetDetailsPerpPositionViewModel {
    func resolveIfNeeded() {
        guard isOnScreen, isWalletActive, marketId != nil else { return }
        accountStore.resolveIfNeeded()
    }

    func applyAccount() {
        guard let marketId, isWalletActive else {
            unsubscribeFromPositions()
            state = .unknown
            return
        }
        switch accountStore.currentWalletState() {
        case .unresolved, .resolving:
            if state == .unknown { state = .loading }
        case .unbound, .inactive:
            unsubscribeFromPositions()
            state = .noPosition
        case let .active(account):
            subscribeToPositionsIfNeeded()
            guard account.positionsLoaded || !account.hasReadOnlyToken else {
                if state == .unknown { state = .loading }
                return
            }
            let row = account.positions
                .first { $0.marketId == marketId }
                .flatMap { PerpsPositionRowMapping.rows(from: [$0], format: format) { [iconURL] _ in iconURL }.first }
            state = row.map(State.position) ?? .noPosition
        }
    }

    func subscribeToPositionsIfNeeded() {
        guard isOnScreen, !isSubscribedToPositions else { return }
        isSubscribedToPositions = true
        accountStore.subscribePositions(cadence: .ambient)
    }

    func unsubscribeFromPositions() {
        guard isSubscribedToPositions else { return }
        isSubscribedToPositions = false
        accountStore.unsubscribePositions(cadence: .ambient)
    }
}
