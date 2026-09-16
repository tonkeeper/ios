import KeeperCore
import TKCoordinator
import TKCore
import TKLogging
import TKUIKit
import TonSwift
import UIKit

final class PairSignerDeeplinkCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didPrepareToPresent: (() -> Void)?
    var didCancel: (() -> Void)?
    var didPaired: (() -> Void)?

    private let publicKey: TonSwift.PublicKey
    private let name: String
    private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let multichainAssembly: MultichainAssembly
    private let analyticsContext: WalletFlowAnalyticsContext
    private let publicKeyImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator

    init(
        publicKey: TonSwift.PublicKey,
        name: String,
        walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
        multichainAssembly: MultichainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext,
        publicKeyImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator
    ) {
        self.publicKey = publicKey
        self.name = name
        self.walletUpdateAssembly = walletUpdateAssembly
        self.coreAssembly = coreAssembly
        self.multichainAssembly = multichainAssembly
        self.analyticsContext = analyticsContext
        self.publicKeyImportCoordinatorProvider = publicKeyImportCoordinatorProvider
        super.init(router: router)
    }

    override func start() {
        openImport()
    }
}

private extension PairSignerDeeplinkCoordinator {
    func openImport() {
        coreAssembly.analyticsProvider.logWalletImportStarted(
            walletMode: .single,
            walletSource: .signer,
            from: analyticsContext.from
        )
        let coordinator = publicKeyImportCoordinatorProvider(router, publicKey, name)

        coordinator.didPrepareForPresent = { [weak self] in
            self?.didPrepareToPresent?()
        }

        coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
        }

        coordinator.didImport = { [weak self] publicKey, revisions, model in
            guard let self else { return }
            Task {
                do {
                    try await self.importWallet(
                        publicKey: publicKey,
                        revisions: revisions,
                        model: model
                    )
                    self.coreAssembly.analyticsProvider.logWalletImportSuccess(
                        walletMode: .single,
                        walletSource: .signer,
                        from: self.analyticsContext.from
                    )
                    await MainActor.run {
                        self.didPaired?()
                    }
                } catch {
                    Log.e("deeplink pair signer: wallet import failed", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                    self.coreAssembly.analyticsProvider.logWalletImportError(
                        walletMode: .single,
                        walletSource: .signer,
                        from: self.analyticsContext.from,
                        error: error
                    )
                }
            }
        }

        addChild(coordinator)
        coordinator.start()
    }

    func importWallet(
        publicKey: TonSwift.PublicKey,
        revisions: [WalletContractVersion],
        model: CustomizeWalletModel
    ) async throws {
        let addController = walletUpdateAssembly.walletAddController(
            multichainAssembly: multichainAssembly
        )
        let metaData = WalletMetaData(
            label: model.name,
            tintColor: model.tintColor,
            icon: model.icon
        )
        try await addController.importSignerWallet(
            publicKey: publicKey,
            revisions: revisions,
            metaData: metaData,
            isDevice: true
        )
    }
}
