import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class WebSwapCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  var didClose: (() -> Void)?
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: NavigationControllerRouter,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openSwap()
  }
}

private extension WebSwapCoordinator {
  func openSwap() {
    let messageHandler = DefaultStonfiSwapMessageHandler()
    let module = StonfiSwapAssembly.module(
      keeperCoreAssembly: keeperCoreMainAssembly,
      messageHandler: messageHandler
    )
    
    messageHandler.send = {
      [weak self] request, completion in
      guard let self else { return }
      self.openSend(signRequest: request, completion: completion)
    }
    
    messageHandler.close = {
      [weak self] in
      guard let self else { return }
      self.didClose?()
    }
    
    module.view.overrideUserInterfaceStyle = .dark
    module.view.modalPresentationStyle = .fullScreen
    router.push(viewController: module.view)
  }
  
  func openSend(signRequest: SendTransactionSignRequest,
                completion: @escaping (SendTransactionSignResult) -> Void) {
    let wallet = self.keeperCoreMainAssembly.walletAssembly.walletStore.activeWallet

    guard let windowScene = UIApplication.keyWindowScene else { return }
    let window = TKWindow(windowScene: windowScene)
    let coordinator = SignTransactionConfirmationCoordinator(
      router: WindowRouter(window: window),
      wallet: wallet,
      confirmator: StonfiSwapSignTransactionConfirmationCoordinatorConfirmator(
        signRequest: signRequest,
        sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
        tonConnectService: keeperCoreMainAssembly.tonConnectAssembly.tonConnectService(),
        responseHandler: { result in
          completion(result)
        }
      ),
      tonConnectConfirmationController: keeperCoreMainAssembly.tonConnectAssembly.tonConnectConfirmationController(
        wallet: wallet,
        signTransactionParams: signRequest.params
      ),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    coordinator.didCancel = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    coordinator.didConfirm = { [weak self, weak coordinator] in
      guard let coordinator else { return }
      self?.removeChild(coordinator)
    }
    
    addChild(coordinator)
    coordinator.start()
  }
}
