import Foundation
import TKLogging

/// One wallet's portfolio as the last `getAllWalletAssets` response delivered it: the fiat total the
/// wallets list and header render, plus the visible assets the wallet screen lists. The scope fields
/// record what the response was requested for, so a reader can reject a snapshot that no longer
/// matches the current account set, display currency or dust filter.
public struct MultichainPortfolio: Equatable, Codable {
    public let fiatPrice: [String: String]
    public let assets: [MultichainAsset]
    public let accountsIdentifier: String
    public let currencyCode: String
    public let hidesDustBalances: Bool
    public let date: Date

    public init(
        fiatPrice: [String: String],
        assets: [MultichainAsset],
        accountsIdentifier: String,
        currencyCode: String,
        hidesDustBalances: Bool,
        date: Date = Date()
    ) {
        self.fiatPrice = fiatPrice
        self.assets = assets
        self.accountsIdentifier = accountsIdentifier
        self.currencyCode = currencyCode
        self.hidesDustBalances = hidesDustBalances
        self.date = date
    }
}

public final class MultichainPortfolioStore: Store<MultichainPortfolioStore.Event, MultichainPortfolioStore.State> {
    public typealias State = [Wallet: MultichainPortfolio]

    public enum Event {
        case didUpdatePortfolio(wallet: Wallet)
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
                state[wallet] = try repository.getPortfolio(walletId: wallet.id)
            } catch {
                continue
            }
        }
        return state
    }

    public func setPortfolio(
        _ portfolio: MultichainPortfolio,
        wallet: Wallet,
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
            updatedState[wallet] = portfolio
            self.save(portfolio, wallet: wallet)
            return StateUpdate(newState: updatedState)
        } completion: { [weak self] _ in
            guard let self,
                  self.isLatestRequestToken(requestToken, wallet: wallet)
            else { return }
            self.sendEvent(.didUpdatePortfolio(wallet: wallet))
        }
    }

    private func save(_ portfolio: MultichainPortfolio, wallet: Wallet) {
        do {
            try repository.savePortfolio(portfolio, walletId: wallet.id)
        } catch {
            Log.w("MultichainPortfolioStore: failed to save portfolio: \(error)")
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
