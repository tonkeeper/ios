import Foundation

public final class BackupController {
  
  public struct BackupModel {
    public enum BackupState {
      case notBackedUp
      case backedUp(date: String)
    }
    public let backupState: BackupState
  }
  
  public var didUpdateBackupState: (() -> Void)?
  
  private var walletsStoreObservationToken: ObservationToken?
  
  private var wallet: Wallet {
    didSet {
      reload()
    }
  }
  
  private let backupStore: BackupStore
  private let walletsStore: WalletsStore
  private let dateFormatter: DateFormatter
  
  init(wallet: Wallet,
       backupStore: BackupStore,
       walletsStore: WalletsStore,
       dateFormatter: DateFormatter) {
    self.wallet = wallet
    self.backupStore = backupStore
    self.walletsStore = walletsStore
    self.dateFormatter = dateFormatter
    
    walletsStoreObservationToken = walletsStore.addEventObserver(self) { observer, event in
      observer.didGetWalletsStoreEvent(event)
    }
  }
  
  deinit {
    walletsStoreObservationToken?.cancel()
  }
  
  public func reload() {
    didUpdateBackupState?()
  }
  
  public func getBackupModel() -> BackupModel {
    createBackupModel()
  }
  
  public func setDidBackup() throws {
    try backupStore.setDidBackup(for: wallet)
  }
}

private extension BackupController {
  func createBackupModel() -> BackupModel {
    let backupState: BackupModel.BackupState
    if let backupDate = wallet.setupSettings.backupDate {
      dateFormatter.dateFormat = "MMM d yyyy, H:mm"
      backupState = .backedUp(date: dateFormatter.string(from: backupDate))
    } else {
      backupState = .notBackedUp
    }
    return BackupModel(backupState: backupState)
  }
  
  func didGetWalletsStoreEvent(_ event: WalletsStore.Event) {
    switch event {
    case .didUpdateWalletBackupState(let wallet):
      guard let wallet = walletsStore.wallets.first(where: { $0.identity == wallet.identity }) else { return }
      self.wallet = wallet
    default:
      break
    }
  }
}
