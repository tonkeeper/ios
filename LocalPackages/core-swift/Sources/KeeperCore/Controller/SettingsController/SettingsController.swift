import Foundation

public final class SettingsController {
  
  public var didUpdateActiveWallet: (() -> Void)?
  public var didUpdateActiveCurrency: (() -> Void)?
  public var didDeleteWallet: (() -> Void)?
  public var didDeleteLastWallet: (() -> Void)?
  
  private var walletsStoreToken: ObservationToken?
  private var currencyStoreToken: ObservationToken?
  
  private let walletsStore: WalletsStore
  private let updateStore: WalletsStoreUpdate
  private let currencyStore: CurrencyStore
  private let configurationStore: ConfigurationStore
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletsStore: WalletsStore,
       updateStore: WalletsStoreUpdate,
       currencyStore: CurrencyStore,
       configurationStore: ConfigurationStore,
       mnemonicsRepository: MnemonicsRepository) {
    self.walletsStore = walletsStore
    self.updateStore = updateStore
    self.currencyStore = currencyStore
    self.configurationStore = configurationStore
    self.mnemonicsRepository = mnemonicsRepository
    
    walletsStoreToken = walletsStore.addEventObserver(self) { observer, event in
      observer.didGetWalletsStoreEvent(event)
    }
  }
  
  public func hasSecurity() -> Bool {
    mnemonicsRepository.hasMnemonics()
  }
  
  public func activeWallet() -> Wallet {
    walletsStore.activeWallet
  }
  
  public func activeCurrency() async -> Currency {
    await currencyStore.getActiveCurrency()
  }
  
  public func getAvailableCurrencies() -> [Currency] {
    Currency.allCases
  }
  
  public func setCurrency(_ currency: Currency) async {
    await currencyStore.setActiveCurrency(currency)
  }
  
  public func canDeleteAccount() -> Bool {
    walletsStore.wallets.count > 1
  }
  
  public func deleteAccount() throws {
    try updateStore.deleteWallet(walletsStore.activeWallet)
  }
  
  public var supportURL: URL? {
    get async throws {
      guard let string = try await configurationStore.getConfiguration().directSupportUrl else { return nil }
      return URL(string: string)
    }
  }
  
  public var contactUsURL: URL? {
    get async throws {
      guard let string = try await configurationStore.getConfiguration().supportLink else { return nil }
      return URL(string: string)
    }
  }
  
  public var tonkeeperNewsURL: URL? {
    get async throws {
      guard let string = try await configurationStore.getConfiguration().tonkeeperNewsUrl else { return nil }
      return URL(string: string)
    }
  }
}

private extension SettingsController {
  func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
    switch event {
    case .didUpdateWalletMetadata(let wallet):
      guard wallet == walletsStore.activeWallet else { return }
      didUpdateActiveWallet?()
    case .didUpdateActiveWallet:
      didUpdateActiveWallet?()
    case .didDeleteWallet:
      didDeleteWallet?()
    case .didDeleteLastWallet:
      didDeleteLastWallet?()
    default:
      break
    }
  }
  
  func didGetCurrencyStoreEvent(_ event: CurrencyStore.Event) {
    didUpdateActiveCurrency?()
  }
}
