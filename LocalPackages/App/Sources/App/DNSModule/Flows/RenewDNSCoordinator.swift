import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKUIKit
import TonSwift
import UIKit

final class RenewDNSCoordinator: RouterCoordinator<WindowRouter> {
    var didCancel: (() -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private let nft: NFT
    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        router: WindowRouter,
        nft: NFT,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.nft = nft
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator = walletTransferSignCoordinator else { return false }
        walletTransferSignCoordinator.externalSignHandler?(sign)
        walletTransferSignCoordinator.externalSignHandler = nil
        return true
    }

    override func start() {
        guard let windowScene = router.window.windowScene else { return }

        SignRawPresenter.presentSignRaw(
            windowScene: windowScene,
            windowLevel: .signRaw,
            wallet: wallet,
            transferProvider: { [nft] in
                .renewDNS(nft: nft)
            },
            resultHandler: nil,
            sendFrom: .tonconnectRemote,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            didRequireSign: { [weak self] transferData, wallet, coordinator, router throws(WalletTransferSignError) in
                guard let self else {
                    throw .cancelled
                }
                return try await didRequireSign(
                    transferData: transferData,
                    wallet: wallet,
                    coordinator: coordinator,
                    router: router
                )
            }
        )
    }

    @MainActor
    func didRequireSign(
        transferData: TransferData,
        wallet: Wallet,
        coordinator: Coordinator,
        router: ViewControllerRouter
    ) async throws(WalletTransferSignError) -> SignedTransactions {
        let signCoordinator = WalletTransferSignCoordinator(
            router: router,
            wallet: wallet,
            transferData: transferData,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        self.walletTransferSignCoordinator = signCoordinator

        return try await signCoordinator
            .handleSign(parentCoordinator: coordinator)
            .get()
    }
}
