import Foundation
import CoreComponents
import TonSwift

public final class WalletListController {
  actor State {
    var wallets = [Wallet]()
    var selectedWallet: Wallet?
    var models = [ItemModel]()
    
    func setWallets(_ wallets: [Wallet]) {
      self.wallets = wallets
    }
    
    func setSelectedWallet(_ wallet: Wallet?) {
      self.selectedWallet = wallet
    }
    
    func setModels(_ models: [ItemModel]) {
      self.models = models
    }
  }
  
  public struct Model {
    public let items: [ItemModel]
    public let selectedIndex: Int?
    public let isEditable: Bool
    
    public init(items: [ItemModel], selectedIndex: Int?, isEditable: Bool) {
      self.items = items
      self.selectedIndex = selectedIndex
      self.isEditable = isEditable
    }
  }
  
  public struct ItemModel {
    public let id: String
    public let wallet: Wallet
    public let totalBalance: String
  }
  
  public var didUpdateState: ((Model) -> Void)?
  
  private let state = State()
  
  private let walletsStore: WalletsStore
  private let walletTotalBalanceStore: WalletTotalBalanceStore
  private let currencyStore: CurrencyStore
  private let configurator: WalletListControllerConfigurator
  private let walletListMapper: WalletListMapper
  
  init(walletsStore: WalletsStore, 
       walletTotalBalanceStore: WalletTotalBalanceStore,
       currencyStore: CurrencyStore,
       configurator: WalletListControllerConfigurator,
       walletListMapper: WalletListMapper) {
    self.walletsStore = walletsStore
    self.walletTotalBalanceStore = walletTotalBalanceStore
    self.currencyStore = currencyStore
    self.configurator = configurator
    self.walletListMapper = walletListMapper
  }
  
  public func start() async {
    await startObservations()
    await setInitialState()
  }
  
  public func selectWallet(identifier: String) async {
    guard let index = await state.wallets.firstIndex(where: { $0.id == identifier }) else { return }
    configurator.selectWallet(at: index)
  }
  
  public func moveWallet(from: Int, to: Int) async {
    do {
      try configurator.moveWallet(fromIndex: from, toIndex: to)
    } catch {
      await didUpdateState()
    }
  }
  
  public func getWallet(at index: Int) async -> Wallet? {
    let wallets = await state.wallets
    guard index < wallets.count else { return nil }
    return wallets[index]
  }
}

private extension WalletListController {
  func startObservations() async {
    _ = await walletTotalBalanceStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateTotalBalance(let totalBalanceState, let wallet):
        Task { await observer.didUpdateTotalBalanceState(totalBalanceState,
                                                         wallet: wallet)
        }
      }
    }

    configurator.didUpdateWallets = { [weak self] in
      guard let self else { return }
      Task {
        await self.didUpdateWalletsOrder()
      }
    }
  }
  
  func setInitialState() async {
    let wallets = configurator.getWallets()
    let selectedWallet = configurator.getSelectedWallet()
    let models = wallets.map {
      ItemModel(id: $0.id, wallet: $0, totalBalance: "-")
    }
    
    await state.setWallets(wallets)
    await state.setSelectedWallet(selectedWallet)
    await state.setModels(models)
    
    await didUpdateState()
    
    await updateWalletModels()
  }
  
  func didUpdateTotalBalanceState(_ totalBalanceState: TotalBalanceState,
                                  wallet: Wallet) async {
    await updateWalletModels()
  }
  
  func didUpdateWalletsOrder() async {
    await state.setWallets(walletsStore.wallets)
    await updateWalletModels()
  }
  
  func didUpdateState() async {
    let models = await state.models
    
    let selectedIndex: Int?
    if let selectedWallet = await state.selectedWallet {
      selectedIndex = await state.wallets.firstIndex(of: selectedWallet)
    } else {
      selectedIndex = nil
    }
    
    let model = Model(
      items: models,
      selectedIndex: selectedIndex,
      isEditable: models.count > 1 && configurator.isEditable
    )
    
    didUpdateState?(model)
  }
  
  func updateWalletModels() async {
    let wallets = await state.wallets
    let currency = await currencyStore.getActiveCurrency()
    var modelsWithBalance = [ItemModel]()
    for wallet in wallets {
      if let walletTotalBalanceState = try? await walletTotalBalanceStore.getTotalBalanceState(wallet: wallet) {
        let balance = walletListMapper.mapTotalBalance(
          walletTotalBalanceState.totalBalance,
          currency: currency
        )
        let model = ItemModel(
          id: wallet.id,
          wallet: wallet,
          totalBalance: balance
        )
        modelsWithBalance.append(model)

      } else {
        let model = ItemModel(
          id: wallet.id,
          wallet: wallet,
          totalBalance: "-"
        )
        modelsWithBalance.append(model)
      }
    }
    await state.setModels(modelsWithBalance)
    await didUpdateState()
  }
}
