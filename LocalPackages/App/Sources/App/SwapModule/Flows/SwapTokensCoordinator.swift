import UIKit
import TKCoordinator
import TKLocalize
import TKUIKit
import KeeperCore
import TKCore
import TonSwift

final class SwapTokensCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didFinish: (() -> Void)?
  
  private var externalSignHandler: ((Data) async -> Void)?
  
  private let mainAssembly: KeeperCore.MainAssembly
  private var sellItem: SwapItem
  private var buyItem: SwapItem?
  private var swapSettings = SwapSettings(slippage: 1, expertMode: false)
  
  init(router: NavigationControllerRouter,
       walletAssembly: KeeperCore.WalletAssembly,
       mainAssembly: KeeperCore.MainAssembly,
       sellItem: SwapItem,
       buyItem: SwapItem?) {
    self.mainAssembly = mainAssembly
    self.sellItem = sellItem
    self.buyItem = buyItem
    super.init(router: router)
  }

  public override func start() {
    openSwap(wallet: mainAssembly.walletAssembly.walletStore.activeWallet)
  }

  func openSwapTokenPicker(wallet: Wallet,
                           mainAssembly: KeeperCore.MainAssembly,
                           selectedToken: SwapToken?,
                           selectedPairToken: SwapToken?,
                           sourceViewController: UIViewController,
                           completion: @escaping (SwapToken) -> Void) {
    let module = SwapTokenPickerAssembly.module(
      swapTokenPickerController: mainAssembly.swapTokenPickerController(
        wallet: wallet,
        selectedToken: selectedToken,
        selectedPairToken: selectedPairToken
      )
    )
    
    module.output.didSelectToken = { token in
      completion(token)
    }
    
    module.output.didFinish = {
      module.view.dismiss(animated: true)
    }
    
    sourceViewController.present(TKNavigationController(rootViewController: module.view), animated: true)
  }
  
}

private extension SwapTokensCoordinator {
  func openSwap(wallet: Wallet) {
    let module = SwapItemsAssembly.module(
      sellItem: sellItem,
      buyItem: buyItem,
      slippage: swapSettings.slippage,
      keeperCoreMainAssembly: mainAssembly
    )
    
    module.output.didContinueSwap = { [weak self] swapModel, estimate in
      self?.openSwapConfirmation(sourceViewController: self!.router.rootViewController, wallet: wallet, swapModel: swapModel, estimate: estimate)
    }
    
    module.output.settingsTapped = { [weak self] in
      guard let self else {return}
      openSettings(sourceViewController: router.rootViewController) { settings in
        module.input.update(with: settings)
      }
    }
    
    module.output.chooseTokenTapped = { [weak self] wallet, position in
      guard let self else { return }
      openSwapTokenPicker(wallet: wallet,
                          mainAssembly: mainAssembly,
                          selectedToken: position == 1 ? sellItem.token : buyItem?.token,
                          selectedPairToken: position == 2 ? sellItem.token : nil,
                          sourceViewController: self.router.rootViewController,
                          completion: { token in
        if position == 1 {
          self.sellItem.token = token
        } else {
          if self.buyItem == nil {
            self.buyItem = SwapItem(token: token, amount: 0)
          } else {
            self.buyItem?.token = token
          }
        }
        module.input.updateWithToken(token, position: position)
      })
    }
    
    module.view.setupRightCloseButton { [weak self] in
      self?.didFinish?()
    }
    
    router.push(viewController: module.view, animated: false)
  }
  func openSettings(
    sourceViewController: UIViewController,
    completion: ((SwapSettings) -> Void)?
  ) {
    let module = SwapSettingsAssembly.module(
      settings: swapSettings,
      keeperCoreMainAssembly: mainAssembly
    )
    
    module.output.didUpdateSettings = { [weak self] settings in
      guard let self else {return}
      swapSettings = settings
      completion?(settings)
    }
    sourceViewController.present(TKNavigationController(rootViewController: module.view), animated: true)
  }
  func openSwapConfirmation(sourceViewController: UIViewController, wallet: Wallet, swapModel: SwapModel, estimate: SwapEstimate) {
    let module = SwapConfirmationAssembly.module(
      wallet: wallet,
      sellItem: swapModel.sellItem,
      buyItem: swapModel.buyItem!,
      estimate: estimate,
      keeperCoreMainAssembly: mainAssembly
    )
    
    module.output.didRequireConfirmation = { [weak self] in
      guard let self else { return false }
      return await self.openConfirmation(fromViewController: self.router.rootViewController)
    }
    
    module.output.swapDone = { [weak self] in
      NotificationCenter.default.post(Notification(name: Notification.Name("DID SEND TRANSACTION")))
      self?.router.dismiss(completion: {
        self?.didFinish?()
      })
    }

    (sourceViewController as? UINavigationController)?.pushViewController(module.view, animated: true)
  }
  
  func openConfirmation(fromViewController: UIViewController) async -> Bool {
    return await Task<Bool, Never> { @MainActor in
      return await withCheckedContinuation { [weak self, mainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
        guard let self = self else { return }
        let coordinator = PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: mainAssembly.passcodeAssembly
          )
        ).passcodeConfirmationCoordinator()
        
        coordinator.didCancel = { [weak self, weak coordinator] in
          continuation.resume(returning: false)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        coordinator.didConfirm = { [weak self, weak coordinator] in
          continuation.resume(returning: true)
          coordinator?.router.dismiss(completion: {
            guard let coordinator else { return }
            self?.removeChild(coordinator)
          })
        }
        
        self.addChild(coordinator)
        coordinator.start()
        
        fromViewController.present(coordinator.router.rootViewController, animated: true)
      }
    }.value
  }
}
