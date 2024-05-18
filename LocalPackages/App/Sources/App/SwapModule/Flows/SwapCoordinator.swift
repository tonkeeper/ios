import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore

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
      swapOperationItem: SwapOperationItem(
        sendToken: .tonStub
      )
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapSwapSettings = {
      print("didTapSwapSettings")
    }
    
    module.output.didTapTokenButton = { [weak self, weak view = module.view] contractAddressForPair, swapInput in
      self?.openSwapTokenList(
        sourceViewController: view,
        contractAddressForPair: contractAddressForPair ?? "",
        completion: { swapAsset in
          module.input.didChooseToken(swapAsset, forInput: swapInput)
        })
    }
    
    module.output.didTapBuyTon = {
      print("open buy ton")
    }
    
    module.output.didTapContinue = {
      print("didTapContinue")
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openSwapTokenList(sourceViewController: UIViewController?,
                         contractAddressForPair: String,
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
}
