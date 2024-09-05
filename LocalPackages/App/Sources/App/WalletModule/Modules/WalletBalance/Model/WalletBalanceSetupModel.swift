import Foundation
import KeeperCore

final class WalletBalanceSetupModel {
  struct State {
    enum Item: String {
      case telegramChannel
      case backup
      case biometry
    }
    
    let wallet: Wallet
    let isFinishEnable: Bool
    let items: [Item]
  }
  
  private let actor = SerialActor<Void>()
  
  var didUpdateState: ((State?) -> Void)?
  
  private let walletsStore: WalletsStoreV3
  private let appSettingsStore: AppSettingsV3Store
  private let securityStore: SecurityStoreV3
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletsStore: WalletsStoreV3,
       appSettingsStore: AppSettingsV3Store,
       securityStore: SecurityStoreV3,
       mnemonicsRepository: MnemonicsRepository) {
    self.walletsStore = walletsStore
    self.appSettingsStore = appSettingsStore
    self.securityStore = securityStore
    self.mnemonicsRepository = mnemonicsRepository
    
    walletsStore.addObserver(self) { observer, event in
      observer.didGetWalletsStoreEvent(event)
    }
    
    appSettingsStore.addObserver(self) { observer, event in
      observer.didGetAppSettingsStoreEvent(event)
    }
    
    securityStore.addObserver(self) { observer, event in
      observer.didGetSecurityStoreEvent(event)
    }
  }
  
  func getState() -> State? {
    guard let wallet = try? walletsStore.getActiveWallet() else {
      return nil
    }
    let isSetupFinished = appSettingsStore.getState().isSetupFinished
    let isBiometryEnable = securityStore.getState().isBiometryEnable
    return calculateState(
      wallet: wallet,
      isSetupFinished: isSetupFinished,
      isBiometryEnable: isBiometryEnable
    )
  }
  
  func finishSetup() {
    Task {
      await appSettingsStore.setIsSetupFinished(true)
    }
  }
  
  func turnOnBiometry(passcode: String) throws {
    Task {
      try mnemonicsRepository.savePassword(passcode)
      await self.securityStore.setIsBiometryEnable(true)
    }
  }
  
  func turnOffBiometry() throws {
    Task {
      try self.mnemonicsRepository.deletePassword()
      await self.securityStore.setIsBiometryEnable(false)
    }
  }
  
  private func didGetWalletsStoreEvent(_ event: WalletsStoreV3.Event) {
    Task {
      switch event {
      case .didChangeActiveWallet:
        await self.actor.addTask(block: { await self.updateState() })
      default: break
      }
    }
  }
  
  private func didGetAppSettingsStoreEvent(_ event: AppSettingsV3Store.Event) {
    Task {
      switch event {
      case .didUpdateIsSetupFinished:
        await self.actor.addTask(block: { await self.updateState() })
      default: break
      }
    }
  }
  
  private func didGetSecurityStoreEvent(_ event: SecurityStoreV3.Event) {
    Task {
      switch event {
      case .didUpdateIsBiometryEnabled:
        await self.actor.addTask(block: { await self.updateState() })
      default: break
      }
    }
  }
  
  private func updateState() async {
    let walletsStoreState = await walletsStore.getState()
    switch walletsStoreState {
    case .empty: break
    case .wallets(let walletsState):
      let isSetupFinished = await appSettingsStore.getState().isSetupFinished
      let isBiometryEnable = await securityStore.getState().isBiometryEnable
      let state = calculateState(
        wallet: walletsState.activeWalelt,
        isSetupFinished: isSetupFinished,
        isBiometryEnable: isBiometryEnable
      )
      didUpdateState?(state)
    }
  }
  
  private func calculateState(wallet: Wallet, isSetupFinished: Bool, isBiometryEnable: Bool) -> State? {
    if isSetupFinished && (!wallet.isBackupAvailable || wallet.hasBackup)  {
      return nil
    }
    
    var items = [State.Item]()
    
    let isFinishEnable: Bool = {
      !wallet.isBackupAvailable || wallet.setupSettings.backupDate != nil
    }()
    
    let isTelegramChannelVisible: Bool = {
      !isSetupFinished
    }()
    if isTelegramChannelVisible {
      items.append(.telegramChannel)
    }
    
    let isBiometryVisible: Bool = {
      !isSetupFinished && wallet.isBiometryAvailable && !isBiometryEnable
    }()
    if isBiometryVisible {
      items.append(.biometry)
    }
    
    let isBackupVisible: Bool = {
      wallet.isBackupAvailable && wallet.setupSettings.backupDate == nil
    }()
    if isBackupVisible {
      items.append(.backup)
    }
    
    let state = State(
      wallet: wallet,
      isFinishEnable: isFinishEnable,
      items: items
    )
    return state
  }
}
