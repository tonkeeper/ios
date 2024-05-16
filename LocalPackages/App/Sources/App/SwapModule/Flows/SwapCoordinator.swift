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
    
    module.output.didTapTokenButton = { [weak self, weak view = module.view] token, swapInput in
      self?.openSwapTokenList(fromViewController: view, didChooseTokenClosure: {
        print("token did choose")
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
  
  func openSwapTokenList(fromViewController: UIViewController?, didChooseTokenClosure: (() -> Void)?) {
    let module = SwapTokenListAssembly.module(
      swapTokenListController: keeperCoreMainAssembly.swapTokenListController()
    )
    
    module.view.setupRightCloseButton {
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didTapCloseButton = {
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didChooseToken = {
      didChooseTokenClosure?()
    }
    
    fromViewController?.present(module.view, animated: true)
  }
  
  func openCurrencyList(fromViewController: UIViewController?,
                        currencyListItem: CurrencyListItem,
                        didChangeCurrencyClosure: ((Currency) -> Void)?) {
    let module = CurrencyListAssembly.module(
      currencyListController: keeperCoreMainAssembly.currencyListController(),
      currencyListItem: currencyListItem
    )
    
    module.view.setupRightCloseButton {
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didChangeCurrency = { newCurrency in
      didChangeCurrencyClosure?(newCurrency)
    }
    
    fromViewController?.present(module.view, animated: true)
  }
}
