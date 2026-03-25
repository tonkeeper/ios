import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
final class SignDataPresenter {
    static var currentCoordinators = [UIWindowScene: SignDataCoordinator]()

    static func presentSignData(
        windowScene: UIWindowScene,
        windowLevel: UIWindow.Level,
        wallet: Wallet,
        dappUrl: String,
        request: TonConnect.SignDataRequest,
        resultHandler: SignDataResultHandler,
        didRequireSign: ((TonConnect.SignDataRequest, String, Wallet, ViewControllerRouter) async throws(SignDataSignError) -> SignedDataResult?)?,
        analyticsProvider: AnalyticsProvider,
        redAnalyticsConfiguration: RedAnalyticsConfiguration? = nil,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        let window = TKWindow(windowScene: windowScene)
        window.windowLevel = windowLevel

        let coordinatorDidRequireSign: (
            (
                TonConnect.SignDataRequest,
                String,
                Wallet,
                UIViewController
            ) async throws(SignDataSignError) -> SignedDataResult?
        )?
        if let didRequireSign {
            coordinatorDidRequireSign = { signDataRequest, dappUrl, wallet, viewController async throws(SignDataSignError) in
                try await didRequireSign(
                    signDataRequest,
                    dappUrl,
                    wallet,
                    ViewControllerRouter(rootViewController: viewController)
                )
            }
        } else {
            coordinatorDidRequireSign = nil
        }
        let router = WindowRouter(window: window)
        let coordinator = SignDataCoordinator(
            router: router,
            wallet: wallet,
            dappUrl: dappUrl,
            signRequest: request,
            resultHandler: resultHandler,
            didRequireSign: coordinatorDidRequireSign,
            analyticsProvider: analyticsProvider,
            redAnalyticsConfiguration: redAnalyticsConfiguration,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        coordinator.didFinish = { _ in
            currentCoordinators[windowScene] = nil
        }

        currentCoordinators[windowScene] = coordinator
        coordinator.start()
    }
}
