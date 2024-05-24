import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore
import TonSwift

public final class SwapCoordinator: RouterCoordinator<NavigationControllerRouter> {
    
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
  
  public override func start() {
    openSwap()
  }
}

private extension SwapCoordinator {
  func openSwap() {
    let module = SwapAssembly.module(
      swapController: keeperCoreMainAssembly.swapController(),
      swapOperationItem: SwapOperationItem(),
      swapSettingsModel: SwapSettingsModel()
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapSwapSettings = { [weak self, weak view = module.view, weak input = module.input] currentSwapSettings in
      self?.openSwapSettings(
        sourceViewController: view,
        swapSettingsModel: currentSwapSettings,
        didUpdateSettingsClosure: { swapSettingsModel in
          input?.didUpdateSwapSettings(swapSettingsModel)
        }
      )
    }
    
    module.output.didTapTokenButton = { [weak self, weak view = module.view, weak input = module.input] contractAddressForPair, swapInput in
      self?.openSwapTokenList(
        sourceViewController: view,
        contractAddressForPair: contractAddressForPair,
        completion: { swapAsset in
          input?.didChooseToken(swapAsset, forInput: swapInput)
        })
    }
    
    module.output.didTapBuyTon = { [weak self, weak input = module.input] in
      guard let self else { return }
      self.openBuy(
        wallet: wallet,
        completion: {
          input?.didBuyTon()
        }
      )
    }
    
    module.output.didTapContinue = { [weak self, weak view = module.view] swapModel in
      self?.openSwapConfirmation(
        sourceViewController: view,
        swapModel: swapModel,
        completion: nil
      )
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openSwapSettings(sourceViewController: UIViewController?,
                        swapSettingsModel: SwapSettingsModel,
                        didUpdateSettingsClosure: ((SwapSettingsModel) -> Void)?) {
    let module = SwapSettingsAssembly.module(
      swapSettingsController: keeperCoreMainAssembly.swapSettingsController(),
      swapSettingsModel: swapSettingsModel
    )
    
    module.view.setupRightCloseButton {
      sourceViewController?.dismiss(animated: true)
    }
    
    module.output.didTapSave = { swapSettingsModel in
      didUpdateSettingsClosure?(swapSettingsModel)
    }
    
    module.output.didFinish = {
      sourceViewController?.dismiss(animated: true)
    }
    
    sourceViewController?.present(module.view, animated: true)
  }
  
  func openSwapTokenList(sourceViewController: UIViewController?,
                         contractAddressForPair: Address?,
                         completion: ((SwapAsset) -> Void)?) {
    let module = SwapTokenListAssembly.module(
      swapTokenListController: keeperCoreMainAssembly.swapTokenListController(),
      swapTokenListItem: SwapTokenListItem(
        contractAddressForPair: contractAddressForPair
      )
    )
    
    module.view.setupRightCloseButton {
      sourceViewController?.dismiss(animated: true)
    }
    
    module.output.didFinish = {
      sourceViewController?.dismiss(animated: true)
    }
    
    module.output.didChooseToken = { swapAsset in
      completion?(swapAsset)
    }
    
    sourceViewController?.present(module.view, animated: true)
  }
  
  func openSwapConfirmation(sourceViewController: UIViewController?,
                            swapModel: SwapModel,
                            completion: (() -> Void)?) {
    let module = SwapConfirmationAssembly.module(
      swapConfirmationController: keeperCoreMainAssembly.swapConfirmationController(
        wallet: wallet,
        swapModel: swapModel
      ),
      swapConfirmationItem: swapModel.confirmationItem
    )
    
    module.view.setupRightCloseButton {
      sourceViewController?.dismiss(animated: true)
    }
    
    module.output.didFinish = {
      sourceViewController?.dismiss(animated: true)
    }
    
    module.output.didTapConfirm = {
      print("didTapConfirm")
    }
    
    sourceViewController?.present(module.view, animated: true)
  }
  
  func openBuy(wallet: Wallet, completion: (() -> Void)?) {
    let navigationController = TKNavigationController()
    navigationController.configureDefaultAppearance()
    
    let coordinator = BuyCoordinator(
      wallet: wallet,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly,
      router: NavigationControllerRouter(rootViewController: navigationController)
    )
    
    coordinator.didFinish = { [weak self, weak coordinator, weak navigationController] in
      navigationController?.dismiss(animated: true)
      guard let coordinator else { return }
      self?.removeChild(coordinator)
      completion?()
    }
    
    addChild(coordinator)
    coordinator.start()
      
    self.router.present(navigationController)
  }
}
