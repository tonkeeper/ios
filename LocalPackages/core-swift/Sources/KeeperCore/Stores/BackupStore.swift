import Foundation

final class BackupStore {
  typealias ObservationClosure = (Event) -> Void
  enum Event {
    case didBackup(wallet: Wallet)
  }
  
  private let walletService: WalletsService
  
  init(walletService: WalletsService) {
    self.walletService = walletService
  }
  
  func setDidBackup(for wallet: Wallet) throws {
    try walletService.updateWallet(
      wallet: wallet,
      setupSettings: WalletSetupSettings(backupDate: Date())
    )
    observations.values.forEach { $0(.didBackup(wallet: wallet)) }
  }
  
  private var observations = [UUID: ObservationClosure]()
  
  func addEventObserver<T: AnyObject>(_ observer: T,
                                      closure: @escaping (T, Event) -> Void) -> ObservationToken {
    let id = UUID()
    let eventHandler: (Event) -> Void = { [weak self, weak observer] event in
      guard let self else { return }
      guard let observer else {
        observations.removeValue(forKey: id)
        return
      }
      
      closure(observer, event)
    }
    observations[id] = eventHandler
    
    return ObservationToken { [weak self] in
      guard let self else { return }
      observations.removeValue(forKey: id)
    }
  }
}
