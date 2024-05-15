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
      swapItem: SwapItem(
        sendToken: .ton,
        recieveToken: nil
      )
    )
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    module.output.didTapSwapSettings = {
      print("didTapSwapSettings")
    }
    
    module.output.didTapTokenButton = { token, swapInput in
      print("token: \(String(describing: token?.title)) swapInput: \(swapInput)")
    }
    
    module.output.didTapBuyTon = {
      print("open buy ton")
    }
    
    module.output.didTapContinue = {
      print("didTapContinue")
    }
    
    router.push(viewController: module.view, animated: false)
  }
}
