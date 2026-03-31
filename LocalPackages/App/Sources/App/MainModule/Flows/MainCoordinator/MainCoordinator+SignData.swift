import BigInt
import KeeperCore
import TKCoordinator
import UIKit

extension MainCoordinator {
    func openSignData(
        wallet: Wallet,
        dappUrl: String,
        signRequest: TonConnect.SignDataRequest,
        resultHandler: SignDataResultHandler,
        redAnalyticsConfiguration: RedAnalyticsConfiguration? = nil
    ) {
        guard let windowScene = router.rootViewController.windowScene else { return }

        let didRequireSignHandler: (TonConnect.SignDataRequest, String, Wallet, ViewControllerRouter) async throws(SignDataSignError) -> SignedDataResult? = { [weak self] request, dappUrl, wallet, router async throws(SignDataSignError) in
            guard let self else {
                throw .cancelled
            }
            return try await self.didRequireSign(
                request: request,
                dappUrl: dappUrl,
                wallet: wallet,
                coordinator: self,
                router: router
            )
        }

        SignDataPresenter.presentSignData(
            windowScene: windowScene,
            windowLevel: .signData,
            wallet: wallet,
            dappUrl: dappUrl,
            request: signRequest,
            resultHandler: resultHandler,
            didRequireSign: didRequireSignHandler,
            analyticsProvider: coreAssembly.analyticsProvider,
            redAnalyticsConfiguration: redAnalyticsConfiguration,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
    }

    @MainActor
    func didRequireSign(
        request: TonConnect.SignDataRequest,
        dappUrl: String,
        wallet: Wallet,
        coordinator: Coordinator,
        router: ViewControllerRouter
    ) async throws(SignDataSignError) -> SignedDataResult? {
        let signDataSignCoordinator = SignDataSignCoordinator(router: router, wallet: wallet, dappUrl: dappUrl, request: request, keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)

        let result = await signDataSignCoordinator.handleSign(parentCoordinator: coordinator)

        switch result {
        case let .signed(data):
            return data
        case .cancel:
            throw SignDataSignError.cancelled
        case let .failed(error):
            throw error
        }
    }
}
