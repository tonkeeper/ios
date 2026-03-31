import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
public final class SignRawPresenter {
    static var currentCoordinators = [UIWindowScene: SignRawConfirmationCoordinator]()
    static func presentSignRaw(
        windowScene: UIWindowScene,
        windowLevel: UIWindow.Level,
        wallet: Wallet,
        transferProvider: @escaping () async throws -> Transfer,
        resultHandler: SignRawControllerResultHandler?,
        sendFrom: SendOpen.From,
        appId: String? = nil,
        redAnalyticsConfiguration: RedAnalyticsConfiguration? = nil,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        didRequireSign: ((TransferData, Wallet, Coordinator, ViewControllerRouter) async throws(WalletTransferSignError) -> SignedTransactions)?,
        didRequestReplanishWallet: ((Wallet, Bool) -> Void)? = nil
    ) {
        hideSignRawForWindowSceneIfNeed(windowScene)
        let window = TKWindow(windowScene: windowScene)
        window.windowLevel = windowLevel
        let router = WindowRouter(window: window)
        let coordinator = SignRawConfirmationCoordinator(
            router: router,
            wallet: wallet,
            transferProvider: transferProvider,
            resultHandler: resultHandler,
            sendFrom: sendFrom,
            appId: appId,
            redAnalyticsConfiguration: redAnalyticsConfiguration,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
        coordinator.didRequireSign = { [weak coordinator] transferData, wallet, viewController throws(WalletTransferSignError) in
            guard let coordinator, let didRequireSign else {
                throw .cancelled
            }
            return try await didRequireSign(transferData, wallet, coordinator, ViewControllerRouter(rootViewController: viewController))
        }

        coordinator.didFinish = { _ in
            currentCoordinators[windowScene] = nil
        }

        coordinator.didRequestReplanishWallet = didRequestReplanishWallet

        currentCoordinators[windowScene] = coordinator
        coordinator.start()
    }

    private static func hideSignRawForWindowSceneIfNeed(_ windowScene: UIWindowScene) {
        currentCoordinators[windowScene] = nil
    }
}
