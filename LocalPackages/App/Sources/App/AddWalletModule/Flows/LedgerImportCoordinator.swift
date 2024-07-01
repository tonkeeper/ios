import UIKit
import KeeperCore
import TKCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import TonSwift
import TonTransport

public final class LedgerImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  public var didCancel: (() -> Void)?
  public var didImport: ((_ accounts: [LedgerAccount], _ model: CustomizeWalletModel) -> Void)?
  
  private let ledgerAccounts: [LedgerAccount]
  private let activeWalletModels: [ActiveWalletModel]
  private let name: String
  private let walletsUpdateAssembly: WalletsUpdateAssembly
  private let customizeWalletModule: () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>
  
  init(ledgerAccounts: [LedgerAccount],
       activeWalletModels: [ActiveWalletModel],
       name: String,
       router: NavigationControllerRouter,
       walletsUpdateAssembly: WalletsUpdateAssembly,
       customizeWalletModule: @escaping () -> MVVMModule<UIViewController, CustomizeWalletModuleOutput, Void>) {
    self.ledgerAccounts = ledgerAccounts
    self.activeWalletModels = activeWalletModels
    self.name = name
    self.walletsUpdateAssembly = walletsUpdateAssembly
    self.customizeWalletModule = customizeWalletModule
    super.init(router: router)
  }

  public override func start() {
    openChooseWalletToAdd()
  }
}

private extension LedgerImportCoordinator {
  func openChooseWalletToAdd() {
    let controller = walletsUpdateAssembly.chooseWalletController(activeWalletModels: activeWalletModels, isLedger: true)
    let module = ChooseWalletToAddAssembly.module(controller: controller)
    
    module.output.didSelectRevisions = { [weak self] _, selectedWalletModels in
      guard let self else { return }
      let selectedIndexes = selectedWalletModels.map { $0.ledgerIndex }
      let selectedAccounts = self.ledgerAccounts.filter { selectedIndexes.contains($0.path.index) }
      self.openCustomizeWallet(accounts: selectedAccounts)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(
      viewController: module.view,
      animated: true,
      onPopClosures: { [weak self] in self?.didCancel?() },
      completion: nil)
  }
  
  func openCustomizeWallet(accounts: [LedgerAccount]) {
    let module = customizeWalletModule()
    
    module.output.didCustomizeWallet = { [weak self] model in
      guard let self else { return }
      self.didImport?(accounts, model)
    }
    
    if router.rootViewController.viewControllers.isEmpty {
      module.view.setupLeftCloseButton { [weak self] in
        self?.didCancel?()
      }
    } else {
      module.view.setupBackButton()
    }
    
    router.push(viewController: module.view, animated: true)
  }
}
