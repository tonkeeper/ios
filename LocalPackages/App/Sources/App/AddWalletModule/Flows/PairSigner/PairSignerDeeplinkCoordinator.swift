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

    private let pairingAnalytics: WalletImportPairingAnalyticsSession
    private let publicKey: TonSwift.PublicKey
    private let name: String
    private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
    private let multichainAssembly: MultichainAssembly
    private let publicKeyImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator

    init(
        publicKey: TonSwift.PublicKey,
        name: String,
        walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
        multichainAssembly: MultichainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext,
        pairingEntry: PairingEntry,
        publicKeyImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator
    ) {
        self.pairingAnalytics = WalletImportPairingAnalyticsSession(
            analyticsProvider: coreAssembly.analyticsProvider,
            walletMode: .single, walletSource: .signer, from: analyticsContext.from,
            entry: pairingEntry, hasPairingScreen: false
        )
        self.publicKey = publicKey
        self.name = name
        self.walletUpdateAssembly = walletUpdateAssembly
        self.multichainAssembly = multichainAssembly
        self.publicKeyImportCoordinatorProvider = publicKeyImportCoordinatorProvider
        super.init(router: router)
    }

    override func start() {
        pairingAnalytics.start()
        openImport()
    }

    @discardableResult
    func cancelPairing() -> Bool {
        pairingAnalytics.exit()
    }
}

private extension PairSignerDeeplinkCoordinator {
    func openImport() {
        let coordinator = publicKeyImportCoordinatorProvider(router, publicKey, name)

        coordinator.didPrepareForPresent = { [weak self] in
            guard let self, pairingAnalytics.isActive else { return }
            didPrepareToPresent?()
        }

        coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            guard let self else { return }
            if cancelPairing() {
                didCancel?()
            } else {
                router.dismiss(animated: true)
            }
        }

        coordinator.didImport = { [weak self] publicKey, revisions, model in
            guard let self, pairingAnalytics.beginImport() else { return }
            Task {
                do {
                    try await self.importWallet(
                        publicKey: publicKey,
                        revisions: revisions,
                        model: model
                    )
                    self.pairingAnalytics.success()
                    await MainActor.run {
                        self.didPaired?()
                    }
                } catch {
                    Log.e("deeplink pair signer: wallet import failed", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                    if self.pairingAnalytics.importFailed(error: error) { self.didCancel?() }
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
