import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore

final class BackupCheckCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  
  private let wallet: Wallet
  private let phrase: [String]
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(wallet: Wallet,
       phrase: [String],
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly,
       router: NavigationControllerRouter) {
    self.wallet = wallet
    self.phrase = phrase
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    var provider = BackupRecoveryPhraseDataProvider(
      phrase: phrase
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
      provider: BackupCheckRecoveryPhraseProvider(phrase: phrase
      )
    )
    
    module.output.didCheckRecoveryPhrase = { [weak self] in
      guard let self else { return }
      Task {
        await self.setDidBackup()
        await MainActor.run(body: {
          self.didFinish?()
        })
      }
    }
    
    module.viewController.setupBackButton()
    
    router.push(viewController: module.viewController)
  }
  
  func setDidBackup() async {
    await keeperCoreMainAssembly.walletUpdateAssembly.walletsStoreUpdater.updateWallet(
      wallet,
      setupSettings: WalletSetupSettings(backupDate: Date())
    )
  }
}
