import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit
import UIKit

@MainActor
final class SignDataCoordinator: RouterCoordinator<WindowRouter> {
    private let wallet: Wallet
    private let dappUrl: String
    private let signRequest: TonConnect.SignDataRequest
    private let didRequireSign: ((TonConnect.SignDataRequest, String, Wallet, UIViewController) async throws(SignDataSignError) -> SignedDataResult?)?
    private let resultHandler: SignDataResultHandler
    private let analyticsProvider: AnalyticsProvider
    private let redAnalyticsConfiguration: RedAnalyticsConfiguration?
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    init(
        router: WindowRouter,
        wallet: Wallet,
        dappUrl: String,
        signRequest: TonConnect.SignDataRequest,
        resultHandler: SignDataResultHandler,
        didRequireSign: ((TonConnect.SignDataRequest, String, Wallet, UIViewController) async throws(SignDataSignError) -> SignedDataResult?)?,
        analyticsProvider: AnalyticsProvider,
        redAnalyticsConfiguration: RedAnalyticsConfiguration? = nil,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.wallet = wallet
        self.dappUrl = dappUrl
        self.signRequest = signRequest
        self.didRequireSign = didRequireSign
        self.resultHandler = resultHandler
        self.analyticsProvider = analyticsProvider
        self.redAnalyticsConfiguration = redAnalyticsConfiguration
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        super.init(router: router)
    }

    override func start() {
        let redSession = redAnalyticsConfiguration.map { _ in
            RedAnalyticsSessionHolder(
                analytics: self.analyticsProvider,
                configurationAssembly: self.keeperCoreMainAssembly.configurationAssembly
            )
        }
        let resultHandler = RedAwareSignDataResultHandler(
            base: resultHandler,
            redSession: redSession
        )
        let module = SignDataAssembly.module(
            wallet: wallet,
            dappUrl: dappUrl,
            signRequest: signRequest,
            resultHandler: resultHandler,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        weak let moduleInput = module.input

        let containerViewController = TKBottomSheetViewController(contentViewController: module.view)
        containerViewController.didClose = { [weak self] isInteractivly in
            guard let self else { return }
            guard isInteractivly else { return }
            moduleInput?.cancel()
            redSession?.finish(
                outcome: .cancel,
                stage: "confirm"
            )
            self.didFinish?(self)
        }

        if let didRequireSign {
            module.output.didRequireSign = { signDataRequest, dappUrl, wallet async throws(SignDataSignError) in
                return try await didRequireSign(
                    signDataRequest,
                    dappUrl,
                    wallet,
                    containerViewController
                )
            }
        } else {
            module.output.didRequireSign = nil
        }

        module.output.didStartConfirm = { [weak self] in
            guard let self, let redAnalyticsConfiguration else {
                return
            }
            redSession?.start(
                flow: redAnalyticsConfiguration.flow,
                operation: redAnalyticsConfiguration.operation,
                attemptSource: redAnalyticsConfiguration.attemptSource,
                otherMetadata: redAnalyticsConfiguration.staticMetadata.merging(
                    [
                        .dappUrl: dappUrl,
                    ]
                ) { _, newValue in newValue }
            )
        }

        module.output.didCancelAttempt = {
            redSession?.finish(
                outcome: .cancel,
                stage: "confirm"
            )
        }

        module.output.didConfirm = { [weak self] in
            guard let self else { return }
            self.didFinish?(self)
        }

        let rootViewController = UIViewController()
        router.window.rootViewController = rootViewController
        router.window.makeKeyAndVisible()

        containerViewController.present(fromViewController: rootViewController)
    }
}

private struct RedAwareSignDataResultHandler: SignDataResultHandler {
    let base: SignDataResultHandler
    let redSession: RedAnalyticsSessionHolder?

    func didSign(signedData: SignedDataResult) {
        redSession?.finish(
            outcome: .success,
            stage: "send"
        )
        base.didSign(signedData: signedData)
    }

    func didFail(error: SignDataRequestFailure) {
        redSession?.finish(
            outcome: .fail,
            error: error,
            stage: "send"
        )
        base.didFail(error: error)
    }

    func didCancel() {
        redSession?.finish(
            outcome: .cancel,
            stage: "confirm"
        )
        base.didCancel()
    }
}
