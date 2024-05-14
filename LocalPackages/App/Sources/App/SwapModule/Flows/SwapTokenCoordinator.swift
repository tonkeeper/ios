import UIKit
import TKCoordinator
import TKCore
import TKUIKit
import KeeperCore

final class SwapTokenCoordinator: RouterCoordinator<NavigationControllerRouter> {
  var didFinish: (() -> Void)?
  private let token: Token
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  init(router: NavigationControllerRouter,
       coreAssembly: TKCore.CoreAssembly,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       token: Token) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.token = token
    super.init(router: router)
  }

  public override func start() {
    openSwap()
  }
}

private extension SwapTokenCoordinator {
  func openSwap() {
    let module = SwapAssembly.module(
      token: token,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    module.output.didTapToken = { [weak self] swapField in
      guard let self else { return }
      self.openTokenPicker(
        sourceViewController: self.router.rootViewController,
        completion: { token in
          module.input.update(swapField: swapField, token: token)
        })
    }
    router.push(viewController: module.view, animated: false)
  }

  func openTokenPicker(sourceViewController: UIViewController, completion: @escaping (Token) -> Void) {
    // TODO: Change to new Token Picker
    let module = TokenPickerAssembly.module(
      tokenPickerController: keeperCoreMainAssembly.tokenPickerController(
        wallet: keeperCoreMainAssembly.walletAssembly.walletStore.activeWallet,
        selectedToken: .ton
      )
    )
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    module.output.didSelectToken = { token in
      completion(token)
    }
    module.output.didFinish = {  [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    bottomSheetViewController.present(fromViewController: sourceViewController)
  }
}
