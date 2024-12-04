import UIKit
import TKUIKit
import TKCore
import TKCoordinator
import KeeperCore

@MainActor
public final class SignRawConfirmationCoordinator: RouterCoordinator<WindowRouter> {
  
  var didRequireSign: ((TransferData, Wallet, UIViewController) async throws -> String?)?

  private let wallet: Wallet
  private let signRawRequest: SignRawRequest
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  public init(router: WindowRouter,
              wallet: Wallet,
              signRawRequest: SignRawRequest,
              keeperCoreMainAssembly: KeeperCore.MainAssembly,
              coreAssembly: TKCore.CoreAssembly) {
    self.wallet = wallet
    self.signRawRequest = signRawRequest
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  public override func start() {
    openConfirmation()
  }
  
  private func openConfirmation() {
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()
    
    let module = SignRawConfirmationAssembly.module(
      wallet: wallet,
      signRawRequest: signRawRequest,
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    weak var moduleInput = module.input
    let containerViewController = TKBottomSheetViewController(contentViewController: module.view)
    containerViewController.didClose = { [weak self] isInteractivly in
      guard let self else { return }
      guard isInteractivly else { return }
      moduleInput?.cancel()
      self.didFinish?(self)
    }
    
    module.output.didRequireSign = { [weak self] transferData, wallet in
      guard let self else { return nil }
      return try await didRequireSign?(transferData, wallet, containerViewController)
    }
    module.output.didConfirm = { [weak self] in
      guard let self else { return }
      self.didFinish?(self)
    }
    
    containerViewController.present(fromViewController: rootViewController)
  }
}
