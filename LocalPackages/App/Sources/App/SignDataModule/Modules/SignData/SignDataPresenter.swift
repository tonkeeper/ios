import UIKit
import TKUIKit
import TKCore
import TKCoordinator
import KeeperCore

@MainActor
public final class SignDataPresenter {
  
  static var currentCoordinators = [UIWindowScene: SignDataCoordinator]()
  public static func presentSignData(
    windowScene: UIWindowScene,
    windowLevel: UIWindow.Level,
    wallet: Wallet,
    dappUrl: String,
    request: TonConnect.SignDataRequest,
    resultHandler: SignDataResultHandler,
    didRequireSign: ((TonConnect.SignDataRequest, String, Wallet, ViewControllerRouter) async throws -> String?)?
  ) {
    
    let window = TKWindow(windowScene: windowScene)
    window.windowLevel = windowLevel
    
    let router = WindowRouter(window: window)
    let coordinator = SignDataCoordinator(
      router: router,
      wallet: wallet,
      dappUrl: dappUrl,
      signRequest: request,
      resultHandler: resultHandler,
      didRequireSign: { signDataRequest, dappUrl, wallet, viewController in
        return try await didRequireSign?(signDataRequest, dappUrl, wallet, ViewControllerRouter(rootViewController: viewController))
      }
    )
    
    coordinator.didFinish = { _ in
      currentCoordinators[windowScene] = nil
    }
    
    currentCoordinators[windowScene] = coordinator
    coordinator.start()
  }
}
