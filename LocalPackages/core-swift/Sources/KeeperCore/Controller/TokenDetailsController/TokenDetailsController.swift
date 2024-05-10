import Foundation
import TonSwift

public final class TokenDetailsController {
  public struct TokenModel {
    public let tokenTitle: String
    public let tokenSubtitle: String?
    public let image: TokenImage
    public let tokenAmount: String
    public let convertedAmount: String?
    public let buttons: [IconButton]
  }
  
  public var didUpdate: ((TokenModel) -> Void)?
  
  private let configurator: TokenDetailsControllerConfigurator
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let currencyStore: CurrencyStore
  private let tonRatesStore: TonRatesStore
  
  init(configurator: TokenDetailsControllerConfigurator, 
       walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       currencyStore: CurrencyStore,
       tonRatesStore: TonRatesStore) {
    self.configurator = configurator
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.currencyStore = currencyStore
    self.tonRatesStore = tonRatesStore
  }
  
  public func start() async {
    await startObservations()
    await setInitialState()
  }
}

private extension TokenDetailsController {
  func startObservations() async {
    _ = await walletBalanceStore.addEventObserver(self) { [walletsStore] observer, event in
      switch event {
      case .balanceUpdate(let balance, let walletAddress):
        Task {
          guard let address = try? walletsStore.activeWallet.address, address == walletAddress else { return }
          await observer.didUpdateBalanceState(balanceState: balance, address: walletAddress)
        }
      }
    }
    
    _ = await tonRatesStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateRates(let tonRates):
        Task { await observer.didUpdateTonRates(tonRates) }
      }
    }
    
    _ = walletsStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateActiveWallet:
        Task { await observer.setInitialState() }
      default: break
      }
    }
  }
  
  func setInitialState() async {
    let tonRates = await tonRatesStore.getTonRates()
    let currency = await currencyStore.getActiveCurrency()
    let balance = await getBalance()
    let model = configurator.getTokenModel(
      balance: balance,
      tonRates: tonRates,
      currency: currency
    )
    didUpdate?(model)
  }
  
  func didUpdateBalanceState(balanceState: WalletBalanceState, address: Address) async {
    let tonRates = await tonRatesStore.getTonRates()
    let currency = await currencyStore.getActiveCurrency()
    let model = configurator.getTokenModel(
      balance: balanceState.walletBalance.balance,
      tonRates: tonRates,
      currency: currency
    )
    didUpdate?(model)
  }
  
  func didUpdateTonRates(_ tonRates: [Rates.Rate]) async {
    let currency = await currencyStore.getActiveCurrency()
    let balance = await getBalance()
    let model = configurator.getTokenModel(balance: balance, tonRates: tonRates, currency: currency)
    didUpdate?(model)
  }
  
  func getBalance() async -> Balance {
    do {
      return try await walletBalanceStore.getBalanceState(walletAddress: walletsStore.activeWallet.address)
        .walletBalance
        .balance
    } catch {
      return Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
    }
  }
}
