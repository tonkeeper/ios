import UIKit
import TKUIKit
import TKCore
import TKCoordinator
import KeeperCore

@MainActor
public final class SignRawPresenter {
  static var currentCoordinators = [UIWindowScene: SignRawConfirmationCoordinator]()
  public static func presentSignRaw(windowScene: UIWindowScene,
                                    windowLevel: UIWindow.Level,
                                    wallet: Wallet,
                                    signRawRequest: SignRawRequest,
                                    coreAssembly: TKCore.CoreAssembly,
                                    keeperCoreMainAssembly: KeeperCore.MainAssembly,
                                    didRequireSign: ((TransferData, Wallet, Coordinator, ViewControllerRouter) async throws -> String?)?) {
    hideSignRawForWindowSceneIfNeed(windowScene)
    let window = TKWindow(windowScene: windowScene)
    window.windowLevel = windowLevel
    let router = WindowRouter(window: window)
    let coordinator = SignRawConfirmationCoordinator(
      router: router,
      wallet: wallet,
      signRawRequest: signRawRequest,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly
    )
    coordinator.didRequireSign = { [weak coordinator] transferData, wallet, viewController in
      guard let coordinator else { return nil}
      return try await didRequireSign?(transferData, wallet, coordinator, ViewControllerRouter(rootViewController: viewController))
    }
    
    coordinator.didFinish = { _ in
      currentCoordinators[windowScene] = nil
    }
    
    currentCoordinators[windowScene] = coordinator
    coordinator.start()
  }
  
  private static func hideSignRawForWindowSceneIfNeed(_ windowScene: UIWindowScene) {
    currentCoordinators[windowScene] = nil
  }
}
