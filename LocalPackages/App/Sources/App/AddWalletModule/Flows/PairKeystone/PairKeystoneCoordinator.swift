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
    private let pairingAnalytics: WalletImportPairingAnalyticsSession
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
        self.pairingAnalytics = WalletImportPairingAnalyticsSession(
            analyticsProvider: coreAssembly.analyticsProvider,
            walletMode: .single, walletSource: .keystone, from: analyticsContext.from
        )
        self.analyticsContext = analyticsContext
        self.keystoneImportCoordinatorProvider = keystoneImportCoordinatorProvider
        super.init(router: router)
    }

    override func start() {
        pairingAnalytics.start()
        openScanner()
    }

    @discardableResult
    func cancelPairing() -> Bool {
        pairingAnalytics.exit()
    }
}

private extension PairKeystoneCoordinator {
    func openScanner() {
        let module = KeystoneImportScanAssembly.module(
            scannerAssembly: scannerAssembly,
            coreAssembly: coreAssembly
        )

        module.output.didUpdateCameraState = { [weak self] state in
            self?.pairingAnalytics.cameraStateChanged(state)
        }

        module.output.didScanQRCode = { [weak self] publicKey, xfp, path, name in
            guard let self, pairingAnalytics.isActive else { return }
            pairingAnalytics.setBlocked(.cameraPermissionDenied, isBlocked: false)
            pairingAnalytics.setBlocked(.cameraError, isBlocked: false)
            pairingAnalytics.advance(to: .connected)
            coreAssembly.analyticsProvider.log(WalletImportKeystoneScanned(
                walletMode: .single,
                walletSource: .keystone,
                from: analyticsContext.from
            ))
            openImportCoordinator(publicKey: publicKey, xfp: xfp, path: path, name: name)
        }

        if router.rootViewController.viewControllers.isEmpty {
            module.view.setupSwipeDownButton { [weak self] in
                guard let self else { return }
                if cancelPairing() {
                    didCancel?()
                } else {
                    router.dismiss(animated: true)
                }
            }
        } else {
            module.view.setupBackButton()
        }

        router.push(viewController: module.view, animated: false, onPopClosures: { [weak self] in
            if self?.cancelPairing() == true { self?.didCancel?() }
        })
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
            guard let self, pairingAnalytics.beginImport() else { return }
            Task {
                do {
                    try await self.importWallet(
                        publicKey: publicKey,
                        xfp: xfp,
                        path: path,
                        revisions: revisions,
                        model: model
                    )
                    self.pairingAnalytics.success()
                    await MainActor.run {
                        self.didPaired?()
                    }
                } catch {
                    Log.e("keystone: wallet import failed", extraInfo: [
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
