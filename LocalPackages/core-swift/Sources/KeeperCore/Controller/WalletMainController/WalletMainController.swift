import Foundation
import CoreComponents
import TonSwift

public final class WalletMainController {
  private var didUpdateActiveWallet: ((Wallet) -> Void)?
  private var didUpdateWalletMetaData: ((WalletModel) -> Void)?
  
  private let walletsStore: WalletsStore
  private let walletBalanceLoader: WalletBalanceLoader
  private let nftsStore: NftsStore
  private let nftsLoader: NftsLoader
  private let tonRatesLoader: TonRatesLoader
  private let currencyStore: CurrencyStore
  private let backgroundUpdateStore: BackgroundUpdateStore
  
  init(walletsStore: WalletsStore, 
       walletBalanceLoader: WalletBalanceLoader,
       nftsStore: NftsStore,
       nftsLoader: NftsLoader,
       tonRatesLoader: TonRatesLoader,
       currencyStore: CurrencyStore,
       backgroundUpdateStore: BackgroundUpdateStore) {
    self.walletsStore = walletsStore
    self.walletBalanceLoader = walletBalanceLoader
    self.nftsStore = nftsStore
    self.nftsLoader = nftsLoader
    self.tonRatesLoader = tonRatesLoader
    self.currencyStore = currencyStore
    self.backgroundUpdateStore = backgroundUpdateStore
  }
  
  public func start(didUpdateActiveWallet: ((Wallet) -> Void)?,
                    didUpdateWalletMetaData: ((WalletModel) -> Void)?) async {
    self.didUpdateActiveWallet = didUpdateActiveWallet
    self.didUpdateWalletMetaData = didUpdateWalletMetaData
    await startObservations()
    await reload()
    
    let activeWallet = walletsStore.activeWallet
    didUpdateActiveWallet?(activeWallet)
    didUpdateWalletMetaData?(activeWallet.model)
  }
}

private extension WalletMainController {
  func startObservations() async {
    _ = await currencyStore.addEventObserver(self) { observer, event in
      switch event {
      case .didChangeCurrency(let currency):
        Task { await observer.didChangeActiveCurrency(currency) }
      }
    }
    
    _ = walletsStore.addEventObserver(self) { [walletsStore] observer, event in
      switch event {
      case .didUpdateActiveWallet:
        Task { await observer.didUpdateActiveWallet() }
      case .didUpdateWalletMetadata(let wallet):
        Task {
          guard walletsStore.activeWallet == wallet else { return }
          await observer.didUpdateWalletMetaData(wallet: wallet)
        }
      default: break
      }
    }
    
    _ = await backgroundUpdateStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateState(let backgroundUpdateState):
        Task { await observer.didUpdateBackgroundUpdateState(backgroundUpdateState) }
      case .didReceiveUpdateEvent(let backgroundUpdateEvent):
        Task { await observer.didReceiveBackgroundUpdateEvent(backgroundUpdateEvent)}
      }
    }
  }
  
  func didChangeActiveCurrency(_ activeCurrency: Currency) async {
    Task { await loadWalletsBalances(wallets: walletsStore.wallets, currency: activeCurrency) }
    Task { await loadTonRates(currency: activeCurrency) }
  }
  
  func didUpdateActiveWallet() async {
    let wallet = walletsStore.activeWallet
    didUpdateActiveWallet?(wallet)
    didUpdateWalletMetaData?(wallet.model)
  }
  
  func didUpdateWalletMetaData(wallet: Wallet) async {
    didUpdateWalletMetaData?(wallet.model)
  }
  
  func didUpdateBackgroundUpdateState(_ backgroundUpdateState: BackgroundUpdateState) async {
    switch backgroundUpdateState {
    case .connecting:
      await reload()
    default:
      break
    }
  }
  
  func didReceiveBackgroundUpdateEvent(_ backgroundUpdateEvent: BackgroundUpdateEvent) async {
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    let currency = await currencyStore.getActiveCurrency()
    let wallets = walletsStore.wallets
      .filter { (try? $0.address) == backgroundUpdateEvent.accountAddress }
    await loadWalletsBalances(wallets: wallets, currency: currency)
  }
  
  func reload() async {
    let currency = await currencyStore.getActiveCurrency()
    Task { await loadWalletsBalances(wallets: walletsStore.wallets, currency: currency) }
    Task { await loadTonRates(currency: currency) }
    Task { await loadWalletsNfts(wallets: walletsStore.wallets) }
  }
  
  func loadWalletsBalances(wallets: [Wallet], currency: Currency) async {
    await withTaskGroup(of: Void.self) { [walletBalanceLoader] group in
      for wallet in wallets {
        group.addTask {
          await walletBalanceLoader.loadBalance(wallet: wallet, currency: currency)
        }
      }
    }
  }
  
  func loadWalletsNfts(wallets: [Wallet]) async {
    await withTaskGroup(of: Void.self) { [nftsLoader] group in
      for wallet in wallets {
        group.addTask {
          await nftsLoader.loadNfts(wallet: wallet)
        }
      }
    }
  }
  
  func loadTonRates(currency: Currency) async {
    await tonRatesLoader.loadRate(currency: currency)
  }
}
