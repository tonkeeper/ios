import UIKit
import TKUIKit
import TKCore
import TKCoordinator
import KeeperCore

@MainActor
final class SignRawConfirmationCoordinator: RouterCoordinator<WindowRouter> {
  
  private var didFinish: ((SignRawConfirmationCoordinator) -> Void)?
  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  init(router: WindowRouter,
       keeperCoreMainAssembly: KeeperCore.MainAssembly,
       coreAssembly: TKCore.CoreAssembly) {
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    self.coreAssembly = coreAssembly
    super.init(router: router)
  }
  
  override func start() {
    openConfirmation()
  }
  
  private func openConfirmation() {
    let rootViewController = UIViewController()
    router.window.rootViewController = rootViewController
    router.window.makeKeyAndVisible()
    
    let module = SignRawConfirmationAssembly.module(
      keeperCoreMainAssembly: keeperCoreMainAssembly
    )
    
    let containerViewController = TKBottomSheetViewController(contentViewController: module.view)
    containerViewController.didClose = { [weak self] isInteractivly in
      guard let self else { return }
      guard isInteractivly else { return }
      self.didFinish?(self)
      // TODO: Module call cancel
    }
    
    containerViewController.present(fromViewController: rootViewController)
  }
}

extension SignRawConfirmationCoordinator {
  static func show(coordinator: Coordinator, 
                   window: UIWindow,
                   keeperCoreMainAssembly: KeeperCore.MainAssembly,
                   coreAssembly: TKCore.CoreAssembly) {
    guard let windowScene = window.windowScene else { return }
    
    let signRawWindow = TKWindow(windowScene: windowScene)
    let signRawCoordinator = SignRawConfirmationCoordinator(
      router: WindowRouter(window: signRawWindow),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    signRawCoordinator.didFinish = { signRawCoordinator in
      coordinator.removeChild(signRawCoordinator)
    }
    
    coordinator.addChild(signRawCoordinator)
    signRawCoordinator.start()
  }
}
