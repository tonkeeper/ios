import Foundation
import TKLogging

public struct MultichainPortfolioTotal: Equatable, Codable {
    public let fiatPrice: [String: String]
    public let date: Date
    public let hidesDustBalances: Bool

    public init(
        fiatPrice: [String: String],
        date: Date,
        hidesDustBalances: Bool = false
    ) {
        self.fiatPrice = fiatPrice
        self.date = date
        self.hidesDustBalances = hidesDustBalances
    }
}

public final class MultichainPortfolioStore: Store<MultichainPortfolioStore.Event, MultichainPortfolioStore.State> {
    public typealias State = [Wallet: MultichainPortfolioTotal]

    public enum Event {
        case didUpdatePortfolioTotal(wallet: Wallet)
    }

    private let walletsStore: WalletsStore
    private let repository: MultichainPortfolioRepository

    private let requestTokenLock = NSLock()
    private var requestToken: UInt64 = 0
    private var latestRequestTokens = [Wallet: UInt64]()

    init(
        walletsStore: WalletsStore,
        repository: MultichainPortfolioRepository
    ) {
        self.walletsStore = walletsStore
        self.repository = repository
        super.init(state: [:])
    }

    override public func createInitialState() -> State {
        var state = State()
        for wallet in walletsStore.wallets {
            do {
                state[wallet] = try repository.getPortfolioTotal(walletId: wallet.id)
            } catch {
                continue
            }
        }
        return state
    }

    public func setPortfolioTotal(
        _ fiatPrice: [String: String],
        wallet: Wallet,
        hidesDustBalances: Bool,
        requestToken: UInt64? = nil
    ) {
        let requestToken = requestToken ?? makeRequestToken()
        updateState { [weak self] state in
            guard let self,
                  self.acceptRequestToken(requestToken, wallet: wallet)
            else {
                return nil
            }
            var updatedState = state
            let total = MultichainPortfolioTotal(
                fiatPrice: fiatPrice,
                date: Date(),
                hidesDustBalances: hidesDustBalances
            )
            updatedState[wallet] = total
            self.save(total, wallet: wallet)
            return StateUpdate(newState: updatedState)
        } completion: { [weak self] _ in
            guard let self,
                  self.isLatestRequestToken(requestToken, wallet: wallet)
            else { return }
            self.sendEvent(.didUpdatePortfolioTotal(wallet: wallet))
        }
    }

    private func save(_ total: MultichainPortfolioTotal, wallet: Wallet) {
        do {
            try repository.savePortfolioTotal(total, walletId: wallet.id)
        } catch {
            Log.w("MultichainPortfolioStore: failed to save portfolio total: \(error)")
        }
    }

    public func makeRequestToken() -> UInt64 {
        requestTokenLock.lock()
        defer { requestTokenLock.unlock() }
        requestToken &+= 1
        return requestToken
    }

    private func acceptRequestToken(_ token: UInt64, wallet: Wallet) -> Bool {
        requestTokenLock.lock()
        defer { requestTokenLock.unlock() }
        guard (latestRequestTokens[wallet] ?? 0) <= token else {
            return false
        }
        latestRequestTokens[wallet] = token
        return true
    }

    private func isLatestRequestToken(_ token: UInt64, wallet: Wallet) -> Bool {
        requestTokenLock.lock()
        defer { requestTokenLock.unlock() }
        return latestRequestTokens[wallet] == token
    }
}
