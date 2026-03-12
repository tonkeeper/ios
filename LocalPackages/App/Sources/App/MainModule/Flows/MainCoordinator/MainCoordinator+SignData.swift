import BigInt
import KeeperCore
import TKCoordinator
import UIKit

extension MainCoordinator {
    func openSignData(
        wallet: Wallet,
        dappUrl: String,
        signRequest: TonConnect.SignDataRequest,
        resultHandler: SignDataResultHandler
    ) {
        guard let windowScene = router.rootViewController.windowScene else { return }

        SignDataPresenter.presentSignData(
            windowScene: windowScene,
            windowLevel: .signData,
            wallet: wallet,
            dappUrl: dappUrl,
            request: signRequest,
            resultHandler: resultHandler,
            didRequireSign: { [weak self] request, dappUrl, wallet, router in
                guard let self else {
                    throw DidRequireSignError.unknown
                }
                return try await self.didRequireSign(
                    request: request,
                    dappUrl: dappUrl,
                    wallet: wallet,
                    coordinator: self,
                    router: router
                )
            },
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
    ) async throws -> SignedDataResult? {
        let signDataSignCoordinator = SignDataSignCoordinator(router: router, wallet: wallet, dappUrl: dappUrl, request: request, keeperCoreMainAssembly: keeperCoreMainAssembly, coreAssembly: coreAssembly)

        let result = await signDataSignCoordinator.handleSign(parentCoordinator: coordinator)

        switch result {
        case let .signed(data):
            return data
        case .cancel:
            return nil
        case let .failed(error):
            throw error
        }
    }
}
