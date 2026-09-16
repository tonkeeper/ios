import KeeperCore
import TKCoordinator
import TKCore
import TKLogging
import TKUIKit
import TonSwift
import UIKit

final class PairKeystoneCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didCancel: (() -> Void)?
    var didPaired: (() -> Void)?

    private let scannerAssembly: KeeperCore.ScannerAssembly
    private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
    private let multichainAssembly: MultichainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let analyticsContext: WalletFlowAnalyticsContext
    private let keystoneImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String?, String?, String) -> KeystoneImportCoordinator

    init(
        scannerAssembly: KeeperCore.ScannerAssembly,
        walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
        multichainAssembly: MultichainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext,
        keystoneImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String?, String?, String) -> KeystoneImportCoordinator
    ) {
        self.scannerAssembly = scannerAssembly
        self.walletUpdateAssembly = walletUpdateAssembly
        self.multichainAssembly = multichainAssembly
        self.coreAssembly = coreAssembly
        self.analyticsContext = analyticsContext
        self.keystoneImportCoordinatorProvider = keystoneImportCoordinatorProvider
        super.init(router: router)
    }

    override func start() {
        openScanner()
    }
}

private extension PairKeystoneCoordinator {
    func openScanner() {
        let module = KeystoneImportScanAssembly.module(
            scannerAssembly: scannerAssembly,
            coreAssembly: coreAssembly
        )

        module.output.didScanQRCode = { [weak self] publicKey, xfp, path, name in
            self?.openImportCoordinator(publicKey: publicKey, xfp: xfp, path: path, name: name)
        }

        if router.rootViewController.viewControllers.isEmpty {
            module.view.setupSwipeDownButton { [weak self] in
                self?.didCancel?()
            }
        } else {
            module.view.setupBackButton()
        }

        router.push(viewController: module.view, animated: false)
    }

    func openImportCoordinator(
        publicKey: TonSwift.PublicKey,
        xfp: String?,
        path: String?,
        name: String
    ) {
        let coordinator = keystoneImportCoordinatorProvider(router, publicKey, xfp, path, name)

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
                        xfp: xfp,
                        path: path,
                        revisions: revisions,
                        model: model
                    )
                    self.coreAssembly.analyticsProvider.logWalletImportSuccess(
                        walletMode: .single,
                        walletSource: .keystone,
                        from: self.analyticsContext.from
                    )
                    await MainActor.run {
                        self.didPaired?()
                    }
                } catch {
                    Log.e("keystone: wallet import failed", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                    self.coreAssembly.analyticsProvider.logWalletImportError(
                        walletMode: .single,
                        walletSource: .keystone,
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
        xfp: String?,
        path: String?,
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
        try await addController.importKeystoneWallet(
            publicKey: publicKey,
            revisions: revisions,
            xfp: xfp,
            path: path,
            metaData: metaData
        )
    }
}
