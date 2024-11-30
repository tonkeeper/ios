import UIKit
import TKUIKit
import TKCore
import TKCoordinator
import KeeperCore

@MainActor
public final class SignRawConfirmationCoordinator: RouterCoordinator<WindowRouter> {
//  
//  private var didFinish: ((SignRawConfirmationCoordinator) -> Void)?
//  
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  private let coreAssembly: TKCore.CoreAssembly
  
  public init(router: WindowRouter,
              keeperCoreMainAssembly: KeeperCore.MainAssembly,
              coreAssembly: TKCore.CoreAssembly) {
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

public extension SignRawConfirmationCoordinator {
  static func startCoordinator(windowScene: UIWindowScene,
                               parentCoordinator: Coordinator,
                               keeperCoreMainAssembly: KeeperCore.MainAssembly,
                               coreAssembly: TKCore.CoreAssembly) {
    let signRawWindow = TKWindow(windowScene: windowScene)
    let signRawCoordinator = SignRawConfirmationCoordinator(
      router: WindowRouter(window: signRawWindow),
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    
    signRawCoordinator.didFinish = { [weak parentCoordinator] signRawCoordinator in
      print("🤡signRawCoordinator did finish")
      parentCoordinator?.removeChild(signRawCoordinator)
    }
    
    parentCoordinator.addChild(signRawCoordinator)
    signRawCoordinator.start()
  }
}
