import UIKit
import TKUIKit
import TKScreenKit
import TKCoordinator
import TKCore
import KeeperCore
import TonSwift

public final class SwapCoordinator: RouterCoordinator<NavigationControllerRouter> {
    
  var didFinish: (() -> Void)?
  
  private var externalSignHandler: ((Data) async -> Void)?
  
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
  
  public func handleTonkeeperPublishDeeplink(model: TonkeeperPublishModel) -> Bool {
    guard let externalSignHandler else { return false }
    Task {
      await externalSignHandler(model.boc)
    }
    self.externalSignHandler = nil
    return true
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
        fromViewController: view,
        swapSettingsModel: currentSwapSettings,
        didUpdateSettingsClosure: { swapSettingsModel in
          input?.didUpdateSwapSettings(swapSettingsModel)
        }
      )
    }
    
    module.output.didTapTokenButton = { [weak self, weak view = module.view, weak input = module.input] contractAddressForPair, swapInput in
      self?.openSwapTokenList(
        fromViewController: view,
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
        fromViewController: view,
        swapModel: swapModel,
        completion: nil
      )
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openSwapSettings(fromViewController: UIViewController?,
                        swapSettingsModel: SwapSettingsModel,
                        didUpdateSettingsClosure: ((SwapSettingsModel) -> Void)?) {
    let module = SwapSettingsAssembly.module(
      swapSettingsController: keeperCoreMainAssembly.swapSettingsController(),
      swapSettingsModel: swapSettingsModel
    )
    
    module.view.setupRightCloseButton {
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didTapSave = { swapSettingsModel in
      didUpdateSettingsClosure?(swapSettingsModel)
    }
    
    module.output.didFinish = {
      fromViewController?.dismiss(animated: true)
    }
    
    fromViewController?.present(module.view, animated: true)
  }
  
  func openSwapTokenList(fromViewController: UIViewController?,
                         contractAddressForPair: Address?,
                         completion: ((SwapAsset) -> Void)?) {
    let module = SwapTokenListAssembly.module(
      swapTokenListController: keeperCoreMainAssembly.swapTokenListController(),
      swapTokenListItem: SwapTokenListItem(
        contractAddressForPair: contractAddressForPair
      )
    )
    
    module.view.setupRightCloseButton {
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didFinish = {
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didChooseToken = { swapAsset in
      completion?(swapAsset)
    }
    
    fromViewController?.present(module.view, animated: true)
  }
  
  func openSwapConfirmation(fromViewController: UIViewController?,
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
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didFinish = {
      fromViewController?.dismiss(animated: true)
    }
    
    module.output.didRequireConfirmation = { [weak self, weak view = module.view] in
      guard let self, let view else { return false }
      return await self.openConfirmation(fromViewController: view)
    }
    
    module.output.didSendTransaction = { [weak self] in
      NotificationCenter.default.post(Notification(name: Notification.Name("DID SEND TRANSACTION")))
      fromViewController?.presentingViewController?.dismiss(animated: true) {
        self?.didFinish?()
      }
    }
    
    module.output.didRequireExternalWalletSign = { [weak self] transferURL, wallet in
      guard let self else { return Data() }
      return try await self.handleExternalSign(
        url: transferURL,
        wallet: wallet,
        fromViewController: self.router.rootViewController
      )
    }
    
    fromViewController?.present(module.view, animated: true)
  }
  
  func openConfirmation(fromViewController: UIViewController) async -> Bool {
    return await Task<Bool, Never> { @MainActor in
      return await withCheckedContinuation { [weak self, keeperCoreMainAssembly] (continuation: CheckedContinuation<Bool, Never>) in
        guard let self = self else { return }
        let coordinator = PasscodeModule(
          dependencies: PasscodeModule.Dependencies(
            passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
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
  
  func handleExternalSign(url: URL, wallet: Wallet, fromViewController: UIViewController) async throws -> Data? {
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        if self.coreAssembly.urlOpener().canOpen(url: url) {
          self.externalSignHandler = { data in
            continuation.resume(returning: data)
          }
          self.coreAssembly.urlOpener().open(url: url)
        } else {
          let module = SignerSignAssembly.module(
            url: url,
            wallet: wallet,
            assembly: self.keeperCoreMainAssembly,
            coreAssembly: self.coreAssembly
          )
          let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
          
          bottomSheetViewController.didClose = { isInteractivly in
            guard isInteractivly else { return }
            continuation.resume(returning: nil)
          }
          
          module.output.didScanSignedTransaction = { [weak bottomSheetViewController] model in
            bottomSheetViewController?.dismiss(completion: {
              continuation.resume(returning: model.boc)
            })
          }
          
          bottomSheetViewController.present(fromViewController: fromViewController)
        }
      }
    }
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
