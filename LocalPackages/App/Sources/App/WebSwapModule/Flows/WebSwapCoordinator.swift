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
  
  private weak var signTransactionConfirmationCoordinator: SignTransactionConfirmationCoordinator?
  
  private let wallet: Wallet
  private let fromToken: String?
  private let toToken: String?
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(wallet: Wallet,
              fromToken: String?,
              toToken: String?,
              router: NavigationControllerRouter,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.wallet = wallet
    self.fromToken = fromToken
    self.toToken = toToken
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openSwap()
  }
  
  public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
    if let signTransactionConfirmationCoordinator = signTransactionConfirmationCoordinator {
      return signTransactionConfirmationCoordinator.handleTonkeeperPublishDeeplink(sign: sign)
    }
    return false
  }
}

private extension WebSwapCoordinator {
  func openSwap() {
    let messageHandler = DefaultStonfiSwapMessageHandler()
    let module = StonfiSwapAssembly.module(
      wallet: wallet,
      fromToken: fromToken,
      toToken: toToken,
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
    guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.getActiveWallet() else {
      return
    }

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
      confirmTransactionController: keeperCoreMainAssembly.confirmTransactionController(
        wallet: wallet,
        bocProvider: keeperCoreMainAssembly.tonConnectAssembly.tonConnectConfirmTransactionControllerBocProvider(
          signTransactionParams: signRequest.params
        )
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
    
    self.signTransactionConfirmationCoordinator = coordinator
    
    addChild(coordinator)
    coordinator.start()
  }
}
