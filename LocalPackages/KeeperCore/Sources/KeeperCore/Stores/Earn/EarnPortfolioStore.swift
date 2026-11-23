import Foundation

/// Every wallet's Earn portfolio, restored from its cache at launch and replaced by each answer
/// the balance loads bring.
public final class EarnPortfolioStore: Store<EarnPortfolioStore.Event, EarnPortfolioStore.State> {
    public typealias State = [Wallet: EarnPortfolioState]

    @frozen public enum Event {
        case didUpdatePortfolio(wallet: Wallet)
    }

    private let walletsStore: WalletsStore
    private let repository: EarnPortfolioRepository

    init(
        walletsStore: WalletsStore,
        repository: EarnPortfolioRepository
    ) {
        self.walletsStore = walletsStore
        self.repository = repository
        super.init(state: [:])
    }

    override public func createInitialState() -> State {
        walletsStore.wallets.reduce(into: State()) { state, wallet in
            guard let portfolio = repository.portfolio(walletId: wallet.id) else { return }
            state[wallet] = .loaded(portfolio, isStale: false)
        }
    }

    /// A portfolio answered for another multichain wallet than the wallet's current one reads as
    /// nothing known yet.
    public func portfolioState(wallet: Wallet) -> EarnPortfolioState? {
        let state = getState()[wallet]
        if case let .loaded(portfolio, _) = state, portfolio.walletId != wallet.multichainWalletId {
            return nil
        }
        return state
    }

    func setPortfolio(_ portfolio: EarnPortfolio, wallet: Wallet) async {
        repository.savePortfolio(portfolio, walletId: wallet.id)
        await update(wallet: wallet) { _ in .loaded(portfolio, isStale: false) }
    }

    /// The cached portfolio stays on screen, marked as no longer confirmed, while it is still the
    /// wallet's: one answered for another multichain wallet is nothing to fall back on.
    func setLoadFailed(wallet: Wallet) async {
        await update(wallet: wallet) { state in
            guard case let .loaded(portfolio, _) = state,
                  portfolio.walletId == wallet.multichainWalletId
            else {
                return .unavailable
            }
            return .loaded(portfolio, isStale: true)
        }
    }

    private func update(
        wallet: Wallet,
        _ transform: @escaping (EarnPortfolioState?) -> EarnPortfolioState
    ) async {
        await withCheckedContinuation { continuation in
            updateState { state in
                var updatedState = state
                updatedState[wallet] = transform(state[wallet])
                return StateUpdate(newState: updatedState)
            } completion: { [weak self] _ in
                self?.sendEvent(.didUpdatePortfolio(wallet: wallet))
                continuation.resume()
            }
        }
    }
}
