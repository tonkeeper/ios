import Foundation

public final class WalletBalanceController {
  
  actor State {
    var totalBalanceState: TotalBalanceState?
    var backgroundUpdateState: BackgroundUpdateState = .disconnected
    
    func setTotalBalanceState(_ totalBalanceState: TotalBalanceState?) {
      self.totalBalanceState = totalBalanceState
    }
    
    func setBackgroundUpdateState(_ backgroundUpdateState: BackgroundUpdateState) {
      self.backgroundUpdateState = backgroundUpdateState
    }
  }
  
  actor BalanceState {
    var walletBalance: WalletBalance?
    
    func setWalletBalance(_ walletBalance: WalletBalance?) {
      self.walletBalance = walletBalance
    }
  }
  
  public struct StateModel {
    public let totalBalance: String
    public let stateDate: String?
    public let backgroundUpdateState: BackgroundUpdateState
    public let wallet: Wallet
    public let shortAddress: String?
    public let fullAddress: String?
  }
  
  public var didChangeWallet: (() -> Void)?
  private var didUpdateState: ((StateModel) -> Void)?
  private var didUpdateBalanceState: ((WalletBalanceItemsModel) -> Void)?
  private var didUpdateSetupState: ((WalletBalanceSetupModel?) -> Void)?

  private let state = State()
  private let balanceState = BalanceState()
  
  public private(set) var wallet: Wallet {
    didSet {
      Task {
        await setInitialState()
        didChangeWallet?()
      }
    }
  }
  
  private let walletsStore: WalletsStore
  private let walletBalanceStore: WalletBalanceStore
  private let walletTotalBalanceStore: WalletTotalBalanceStore
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let setupStore: SetupStore
  private let securityStore: SecurityStore
  private let backgroundUpdateStore: BackgroundUpdateStore
  private let walletBalanceMapper: WalletBalanceMapper
  
  init(walletsStore: WalletsStore,
       walletBalanceStore: WalletBalanceStore,
       walletTotalBalanceStore: WalletTotalBalanceStore,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       setupStore: SetupStore,
       securityStore: SecurityStore,
       backgroundUpdateStore: BackgroundUpdateStore,
       walletBalanceMapper: WalletBalanceMapper) {
    self.walletsStore = walletsStore
    self.walletBalanceStore = walletBalanceStore
    self.walletTotalBalanceStore = walletTotalBalanceStore
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.setupStore = setupStore
    self.securityStore = securityStore
    self.backgroundUpdateStore = backgroundUpdateStore
    self.walletBalanceMapper = walletBalanceMapper
    
    self.wallet = walletsStore.activeWallet
  }
  
  public func start(didUpdateState: ((StateModel) -> Void)?,
                    didUpdateBalanceState: ((WalletBalanceItemsModel) -> Void)?,
                    didUpdateSetupState: ((WalletBalanceSetupModel?) -> Void)?) async {
    self.didUpdateState = didUpdateState
    self.didUpdateBalanceState = didUpdateBalanceState
    self.didUpdateSetupState = didUpdateSetupState
    await startObservations()
    await setInitialState()
  }
  
  public func setIsBiometryEnabled(_ isBiometryEnabled: Bool) async -> Bool {
    do {
      try await securityStore.setIsBiometryEnabled(isBiometryEnabled)
      return isBiometryEnabled
    } catch {
      return !isBiometryEnabled
    }
  }
  
  public func finishSetup() async {
    try? await setupStore.setSetupIsFinished()
  }
}

private extension WalletBalanceController {
  func startObservations() async {
    _ = await walletTotalBalanceStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateTotalBalance(let totalBalanceState, let wallet):
        guard let walletAddress = try? observer.wallet.friendlyAddress,
              let updateWalletAddress = try? wallet.friendlyAddress else { return }
        guard walletAddress == updateWalletAddress else { return }
        Task { await observer.didUpdateTotalBalanceState(totalBalanceState) }
      }
    }
    
    _ = await backgroundUpdateStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateState(let backgroundUpdateState):
        Task { await observer.didUpdateBackgroundUpdateState(backgroundUpdateState) }
      default: break
      }
    }
    
    _ = await walletBalanceStore.addEventObserver(self) { observer, event in
      switch event {
      case .balanceUpdate(let balance, let wallet):
        guard let walletAddress = try? observer.wallet.friendlyAddress,
              let updateWalletAddress = try? wallet.friendlyAddress else { return }
        guard walletAddress == updateWalletAddress else { return }
        Task { await observer.didUpdateBalanceState(balance)}
      }
    }
    
    _ = await tonRatesStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateRates(let rates):
        Task { await observer.didUpdateTonRates(rates)}
      }
    }
    
    _ = await setupStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateSetupIsFinished:
        Task { await observer.didUpdateSetup(wallet: observer.wallet) }
      }
    }
    
    _ = await securityStore.addEventObserver(self) { observer, event in
      switch event {
      case .didUpdateSecuritySettings:
        Task { await observer.didUpdateSetup(wallet: observer.wallet) }
      }
    }
    
    _ = walletsStore.addEventObserver(self) { [walletsStore] observer, event in
      switch event {
      case .didUpdateActiveWallet:
        observer.wallet = walletsStore.activeWallet
      case .didUpdateWalletBackupState(let wallet):
        guard wallet == self.wallet else { return }
        Task { await observer.didUpdateSetup(wallet: wallet) }
      default: break
      }
    }
  }
  
  func setInitialState() async {
    if let totalBalanceState = try? await walletTotalBalanceStore.getTotalBalanceState(wallet: wallet) {
      await state.setTotalBalanceState(totalBalanceState)
    } else {
      await state.setTotalBalanceState(nil)
    }
    await state.setBackgroundUpdateState(await backgroundUpdateStore.state)
    let model = await getStateModel()
    didUpdateState?(model)
    
    if let walletBalanceState = try? await walletBalanceStore.getBalanceState(wallet: wallet) {
      await balanceState.setWalletBalance(walletBalanceState.walletBalance)
    } else {
      await balanceState.setWalletBalance(nil)
    }
    let balanceModel = await getBalanceModel()
    didUpdateBalanceState?(balanceModel)
    
    let setupModel = await getSetupModel(wallet: wallet)
    didUpdateSetupState?(setupModel)
  }
  
  func didUpdateTotalBalanceState(_ totalBalanceState: TotalBalanceState) async {
    await state.setTotalBalanceState(totalBalanceState)
    let model = await getStateModel()
    didUpdateState?(model)
  }
  
  func didUpdateBackgroundUpdateState(_ backgroundUpdateState: BackgroundUpdateState) async {
    await state.setBackgroundUpdateState(backgroundUpdateState)
    let model = await getStateModel()
    didUpdateState?(model)
  }
  
  func didUpdateBalanceState(_ walletBalanceState: WalletBalanceState) async {
    await balanceState.setWalletBalance(walletBalanceState.walletBalance)
    let model = await getBalanceModel()
    didUpdateBalanceState?(model)
  }
  
  func didUpdateTonRates(_ tonRates: [Rates.Rate]) async {
    let model = await getBalanceModel()
    didUpdateBalanceState?(model)
  }
  
  func didUpdateSetup(wallet: Wallet) async {
    let setupModel = await getSetupModel(wallet: wallet)
    didUpdateSetupState?(setupModel)
  }
  
  func getStateModel() async -> StateModel {
    let formattedTotalBalance: String
    let stateDate: String?
    let currency = await currencyStore.getActiveCurrency()
    switch await state.totalBalanceState {
    case .none:
      formattedTotalBalance = "-"
      stateDate = nil
    case .previous(let totalBalance):
      formattedTotalBalance = walletBalanceMapper.mapTotalBalance(totalBalance, currency: currency)
      stateDate = walletBalanceMapper.makeUpdatedDate(totalBalance.date)
    case .current(let totalBalance):
      formattedTotalBalance = walletBalanceMapper.mapTotalBalance(totalBalance, currency: currency)
      stateDate = nil
    }
    
    return StateModel(
      totalBalance: formattedTotalBalance,
      stateDate: stateDate,
      backgroundUpdateState: await state.backgroundUpdateState,
      wallet: wallet,
      shortAddress: try? wallet.friendlyAddress.toShort(),
      fullAddress: try? wallet.friendlyAddress.toString()
    )
  }
  
  func getBalanceModel() async -> WalletBalanceItemsModel {
    let balance: Balance
    if let walletBalance = await balanceState.walletBalance {
      balance = walletBalance.balance
    } else {
      balance = Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: [])
    }

    let rates = await tonRatesStore.getTonRates()
    let currency = await currencyStore.getActiveCurrency()
    return walletBalanceMapper.mapBalance(
      balance: balance,
      rates: Rates(
        ton: rates,
        jettonsRates: []
      ),
      currency: currency
    )
  }
  
  func getSetupModel(wallet: Wallet) async -> WalletBalanceSetupModel? {
    guard wallet.kind == .regular else { return nil }
    
    let didBackup = wallet.setupSettings.backupDate != nil
    let didFinishSetup = await setupStore.isSetupFinished
    let isBiometryEnabled = await securityStore.isBiometryEnabled
    let isFinishSetupAvailable = didBackup
    
    if (didBackup && didFinishSetup) {
      return nil
    }

    let model = WalletBalanceSetupModel(
      didBackup: didBackup,
      biometry: WalletBalanceSetupModel.Biometry(
        isBiometryEnabled: isBiometryEnabled,
        isRequired: !didFinishSetup && !isBiometryEnabled
      ),
      isFinishSetupAvailable: isFinishSetupAvailable
    )
    return model
  }
}
