import Foundation
import UIKit

final class SettingsManuallyBackupCoordinator: Coordinator<NavigationRouter> {
  
  var didCancel: (() -> Void)?
  var didFinish: (() -> Void)?
  
  private let walletCoreAssembly: WalletCoreAssembly
  
  private var rootViewController: UIViewController?
  
  init(router: NavigationRouter,
       walletCoreAssembly: WalletCoreAssembly) {
    self.walletCoreAssembly = walletCoreAssembly
    super.init(router: router)
    self.rootViewController = router.rootViewController.topViewController
  }
  
  override func start() {
    openRecoveryPhrase()
  }
}

private extension SettingsManuallyBackupCoordinator {
  func openRecoveryPhrase () {
    let module = SettingsRecoveryPhraseAssembly.module(
      walletProvider: walletCoreAssembly.walletProvider,
      isBackup: true,
      output: self
    )
    module.view.setupBackButton()
    router.push(presentable: module.view, dismiss: { [weak self] in
      self?.didCancel?()
    })
  }
}

extension SettingsManuallyBackupCoordinator: SettingsRecoveryPhraseModuleOutput {
  func settingsRecoveryPhraseModuleCheckBackup() {
    let module = BackupCheckAssembly.create(walletProvider: walletCoreAssembly.walletProvider, output: self)
    
    module.view.setupBackButton()
    
    router.push(presentable: module.view)
  }
}

extension SettingsManuallyBackupCoordinator: BackupCheckModuleOutput {
  func didCheckBackup() {
    let settings = AppSettings()
    settings.backUpDate = Date()
    settings.isNeedToMakeBackup = false
    if let rootViewController = rootViewController {
      router.rootViewController.popToViewController(rootViewController, animated: true)
    }
    didFinish?()
  }
}
