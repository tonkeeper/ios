import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore

final class BackupCheckCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  
  private let wallet: Wallet
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    var provider = BackupRecoveryPhraseDataProvider(
      recoveryPhraseController: keeperCoreMainAssembly.recoveryPhraseController(wallet: wallet)
    )
    
    provider.didTapNext = { [weak self] in
      self?.openCheckInput()
    }
    
    let module = TKRecoveryPhraseAssembly.module(
      provider: provider
    )
    
    if router.rootViewController.viewControllers.isEmpty {
      module.viewController.setupLeftCloseButton { [weak self] in
        self?.didFinish?()
      }
    } else {
      module.viewController.setupBackButton()
    }
    
    router.push(viewController: module.viewController, onPopClosures: { [weak self] in
      self?.didFinish?()
    })
  }
  
  func openCheckInput() {
    let module = TKCheckRecoveryPhraseAssembly.module(
      provider: BackupCheckRecoveryPhraseProvider(
        recoveryPhraseController: keeperCoreMainAssembly.recoveryPhraseController(
          wallet: wallet
        )
      )
    )
    
    module.output.didCheckRecoveryPhrase = { [weak self] in
      self?.setDidBackup()
    }
    
    module.viewController.setupBackButton()
    
    router.push(viewController: module.viewController)
  }
  
  func setDidBackup() {
    do {
      try keeperCoreMainAssembly.backupController(wallet: wallet).setDidBackup()
      didFinish?()
    } catch {
      print("Log: Backup failed failed")
    }
  }
}
