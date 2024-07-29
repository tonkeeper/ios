import Foundation
import KeeperCore

final class WalletBalanceSetupModel {
  enum State {
    case none
    case setup(Setup)
  }
  
  struct Setup {
    let isFinishEnable: Bool
    let isBiometryVisible: Bool
    let isBackupVisible: Bool
    let isTelegramChannelVisible: Bool
  }
  
  private let actor = SerialActor<Void>()
  
  var didUpdateState: ((State) -> Void)? {
    didSet {
      Task {
        await actor.addTask(block: {
          let wallet = await self.walletsStore.getState().activeWallet
          let isSetupFinished = await self.setupStore.getIsSetupFinished()
          let isBiometryEnable = await self.securityStore.getIsBiometryEnable()
          let state = self.calculateState(
            wallet: wallet,
            isSetupFinished: isSetupFinished,
            isBiometryEnable: isBiometryEnable
          )
          self.update(state: state)
        })
      }
    }
  }
  
  private let walletsStore: WalletsStore
  private let setupStore: SetupStore
  private let securityStore: SecurityStore
  private let mnemonicsRepository: MnemonicsRepository
  
  init(walletsStore: WalletsStore,
       setupStore: SetupStore,
       securityStore: SecurityStore,
       mnemonicsRepository: MnemonicsRepository) {
    self.walletsStore = walletsStore
    self.setupStore = setupStore
    self.securityStore = securityStore
    self.mnemonicsRepository = mnemonicsRepository
    walletsStore.addObserver(self, notifyOnAdded: true) { observer, newState, oldState in
      observer.didUpdateWalletsState(newState, oldWalletsState: oldState)
    }
    setupStore.addObserver(self, notifyOnAdded: true) { observer, newState, oldState in
      observer.didUpdateSetupStoreState(newState, oldState: oldState)
    }
    securityStore.addObserver(self, notifyOnAdded: true) { observer, newState, oldState in
      observer.didUpdateSecurityStoreState(newState, oldState: oldState)
    }
  }
  
  func finishSetup() {
    Task {
      await setupStore.setIsSetupFinished(true)
    }
  }
  
  func turnOnBiometry(passcode: String) async throws {
    try mnemonicsRepository.savePassword(passcode)
    await self.securityStore.setIsBiometryEnable(true)
  }
  
  func turnOffBiometry() async throws {
    try self.mnemonicsRepository.deletePassword()
    await self.securityStore.setIsBiometryEnable(false)
  }
}

private extension WalletBalanceSetupModel {
  func didUpdateWalletsState(_ walletsState: WalletsState, oldWalletsState: WalletsState?) {
    guard walletsState.activeWallet != oldWalletsState?.activeWallet else { return }
    Task {
      await actor.addTask {
        let isSetupFinished = await self.setupStore.getIsSetupFinished()
        let isBiometryEnable = await self.securityStore.getIsBiometryEnable()
        let state = self.calculateState(
          wallet: walletsState.activeWallet,
          isSetupFinished: isSetupFinished,
          isBiometryEnable: isBiometryEnable
        )
        self.update(state: state)
      }
    }
  }
  
  func didUpdateSetupStoreState(_ state: SetupStore.State, oldState: SetupStore.State?) {
    Task {
      await actor.addTask {
        let isBiometryEnable = await self.securityStore.getIsBiometryEnable()
        let wallet = await self.walletsStore.getState().activeWallet
        let state = self.calculateState(
          wallet: wallet,
          isSetupFinished: state.isSetupFinished,
          isBiometryEnable: isBiometryEnable
        )
        self.update(state: state)
      }
    }
  }
  
  func didUpdateSecurityStoreState(_ state: SecurityStore.State, oldState: SecurityStore.State?) {
    Task {
      await actor.addTask {
        let isSetupFinished = await self.setupStore.getIsSetupFinished()
        let wallet = await self.walletsStore.getState().activeWallet
        let state = self.calculateState(
          wallet: wallet,
          isSetupFinished: isSetupFinished,
          isBiometryEnable: state.isBiometryEnable
        )
        self.update(state: state)
      }
    }
  }
  
  func update(state: State) {
    didUpdateState?(state)
  }
  
  func calculateState(wallet: Wallet, isSetupFinished: Bool, isBiometryEnable: Bool) -> State {
    if isSetupFinished && (!wallet.isBackupAvailable || wallet.hasBackup)  {
      return .none
    }
    
    let isFinishEnable: Bool = {
      !wallet.isBackupAvailable || wallet.setupSettings.backupDate != nil
    }()
    
    let isBackupVisible: Bool = {
      wallet.isBackupAvailable && wallet.setupSettings.backupDate == nil
    }()
    
    let isBiometryVisible: Bool = {
      !isSetupFinished && wallet.isBiometryAvailable && !isBiometryEnable
    }()
    
    let isTelegramChannelVisible: Bool = {
      !isSetupFinished
    }()
    
    let setup = Setup(
      isFinishEnable: isFinishEnable,
      isBiometryVisible: isBiometryVisible,
      isBackupVisible: isBackupVisible,
      isTelegramChannelVisible: isTelegramChannelVisible
    )
    return .setup(setup)
  }
}
