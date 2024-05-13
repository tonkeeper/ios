import UIKit
import KeeperCore
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore

public final class TonConnectConnectCoordinator: RouterCoordinator<ViewControllerRouter> {
  
  public var didConnect: (() -> Void)?
  public var didCancel: (() -> Void)?
  
  private let parameters: TonConnectParameters
  private let manifest: TonConnectManifest
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: ViewControllerRouter,
              parameters: TonConnectParameters,
              manifest: TonConnectManifest,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.parameters = parameters
    self.manifest = manifest
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openTonConnectConnect()
  }
}

private extension TonConnectConnectCoordinator {
  func openTonConnectConnect() {
    let module = TonConnectConnectAssembly.module(
      tonConnectConnectController: keeperCoreMainAssembly.tonConnectConnectController(
        parameters: parameters,
        manifest: manifest
      )
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(
      contentViewController: module.view
    )
    
    module.output.didRequireConfirmation = { [weak self, weak bottomSheetViewController] in
      guard let bottomSheetViewController else { return false }
      return (await self?.openConfirmation(fromViewController: bottomSheetViewController)) ?? false
    }
    
    module.output.didConnect = { [weak self, weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss {
        self?.didConnect?()
      }
    }
    
    module.output.didTapWalletPicker = { [weak self, weak bottomSheetViewController] wallet in
      guard let bottomSheetViewController else { return }
      self?.openWalletPicker(
        wallet: wallet,
        fromViewController: bottomSheetViewController,
        didSelectWallet: { [weak input = module.input] wallet in
          input?.setWallet(wallet)
        }
      )
    }
    
    bottomSheetViewController.didClose = { [weak self] isInteractivly in
      guard isInteractivly else { return }
      self?.didCancel?()
    }
    
    bottomSheetViewController.present(fromViewController: router.rootViewController)
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
  
  func openWalletPicker(wallet: Wallet, fromViewController: UIViewController, didSelectWallet: @escaping (Wallet) -> Void) {
    let module = WalletsListAssembly.module(
      walletListController: keeperCoreMainAssembly.walletSelectWalletLisController(
        selectedWallet: wallet,
        didSelectWallet: { wallet in
          didSelectWallet(wallet)
        }
      )
    )
    
    let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)
    
    module.output.didTapAddWalletButton = { [weak self, unowned bottomSheetViewController] in
      self?.openAddWallet(router: ViewControllerRouter(rootViewController: bottomSheetViewController)) {
      }
    }
    
    module.output.didSelectWallet = { [weak bottomSheetViewController] in
      bottomSheetViewController?.dismiss()
    }
    
    bottomSheetViewController.present(fromViewController: fromViewController)
  }
  
  func openAddWallet(router: ViewControllerRouter, onAddWallets: @escaping () -> Void) {
    let module = AddWalletModule(
      dependencies: AddWalletModule.Dependencies(
        walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
        coreAssembly: coreAssembly,
        scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
        passcodeAssembly: keeperCoreMainAssembly.passcodeAssembly
      )
    )
    
    let coordinator = module.createAddWalletCoordinator(
      options: [.createRegular, .importRegular, .importWatchOnly, .signer],
      router: router
    )
    coordinator.didAddWallets = {
      onAddWallets()
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
