import Foundation
import TonSwift

actor WalletTotalBalanceStore {
  typealias ObservationClosure = (Event) -> Void
  enum Event {
    case didUpdateTotalBalance(totalBalanceState: TotalBalanceState, wallet: Wallet)
  }
  
  private var totalBalanceStates = [Currency: [FriendlyAddress: TotalBalanceState]]()
  
  private var balanceStoreObservationToken: ObservationToken?
  private var tonRatesStoreObservationToken: ObservationToken?
  private var currencyStoreObservationToken: ObservationToken?
  
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let totalBalanceService: TotalBalanceService
  
  init(walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       totalBalanceService: TotalBalanceService) {
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.totalBalanceService = totalBalanceService
    
    Task {
      await startObservations()
    }
  }
  
  deinit {
    balanceStoreObservationToken?.cancel()
    tonRatesStoreObservationToken?.cancel()
  }
  
  func getTotalBalanceState(wallet: Wallet) async throws -> TotalBalanceState? {
    guard let address = try? wallet.friendlyAddress else { return nil }
    let activeCurrency = await currencyStore.getActiveCurrency()
    if let totalBalanceState = totalBalanceStates[activeCurrency]?[address] {
      return totalBalanceState
    } else {
      return try await Task {
        let walletBalanceState = try await walletBalanceStore.getBalanceState(wallet: wallet)
        let tonRates = await tonRatesStore.getTonRates()
        let totalBalanceState = calculateTotalBalanceState(
          walletBalanceState: walletBalanceState,
          currency: activeCurrency,
          tonRates: tonRates
        )
        if var walletTotalBalances = totalBalanceStates[activeCurrency] {
          walletTotalBalances[address] = totalBalanceState
          totalBalanceStates[activeCurrency] = walletTotalBalances
        } else {
          let walletTotalBalances = [address: totalBalanceState]
          totalBalanceStates[activeCurrency] = walletTotalBalances
        }
        return totalBalanceState
      }.value
    }
  }
  
  private var observations = [UUID: ObservationClosure]()
  
  func addEventObserver<T: AnyObject>(_ observer: T,
                                      closure: @escaping (T, Event) -> Void) -> ObservationToken {
    let id = UUID()
    let eventHandler: (Event) -> Void = { [weak self, weak observer] event in
      guard let self else { return }
      guard let observer else {
        Task { await self.removeObservation(key: id) }
        return
      }
      
      closure(observer, event)
    }
    observations[id] = eventHandler
    
    return ObservationToken { [weak self] in
      guard let self else { return }
      Task { await self.removeObservation(key: id) }
    }
  }
  
  func removeObservation(key: UUID) {
    observations.removeValue(forKey: key)
  }
}

private extension WalletTotalBalanceStore {
  func startObservations() async {
    balanceStoreObservationToken = await walletBalanceStore.addEventObserver(self) { observer, event in
      switch event {
      case .balanceUpdate(let balance, let wallet):
        Task { await observer.didUpdateBalanceState(balance, wallet: wallet) }
      }
    }
    
    tonRatesStoreObservationToken = await tonRatesStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateRates(let tonRates):
        Task { await observer.didUpdateTonRates(tonRates) }
      }
    }
  }
  
  func didUpdateBalanceState(_ balanceState: WalletBalanceState, wallet: Wallet) async {
    let tonRates = await tonRatesStore.getTonRates()
    await updateTotalBalance(
      walletBalanceState: balanceState,
      wallet: wallet,
      tonRates: tonRates
    )
  }
  
  func didUpdateTonRates(_ tonRates: [Rates.Rate]) async {
    for wallet in walletsStore.wallets {
      guard let balanceState = try? await walletBalanceStore.getBalanceState(wallet: wallet) else { continue }
      await updateTotalBalance(
        walletBalanceState: balanceState,
        wallet: wallet,
        tonRates: tonRates
      )
    }
  }
  
  func updateTotalBalance(walletBalanceState: WalletBalanceState,
                          wallet: Wallet,
                          tonRates: [Rates.Rate]) async {
    guard let address = try? wallet.friendlyAddress else { return }
    let currency = await currencyStore.getActiveCurrency()
    let totalBalanceState = calculateTotalBalanceState(
      walletBalanceState: walletBalanceState,
      currency: currency,
      tonRates: tonRates
    )
    if var walletTotalBalances = totalBalanceStates[currency] {
      walletTotalBalances[address] = totalBalanceState
      totalBalanceStates[currency] = walletTotalBalances
    } else {
      let walletTotalBalances = [address: totalBalanceState]
      totalBalanceStates[currency] = walletTotalBalances
    }
    observations.values.forEach {
      $0(
        .didUpdateTotalBalance(
          totalBalanceState: totalBalanceState,
          wallet: wallet
        )
      )
    }
  }
  
  func calculateTotalBalanceState(walletBalanceState: WalletBalanceState,
                                  currency: Currency,
                                  tonRates: [Rates.Rate]) -> TotalBalanceState {
    .current(.init(amount: 1, currency: .AED, date: Date()))
//    let balance = walletBalanceState.walletBalance.balance
//    let totalBalance = totalBalanceService.calculateTotalBalance(
//      balance: balance,
//      currency: currency,
//      rates: Rates(ton: tonRates, jettonsRates: [])
//    )
//    switch walletBalanceState {
//    case .current:
//      return .current(totalBalance)
//    case .previous:
//      return .previous(totalBalance)
//    }
  }
}
