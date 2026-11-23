import KeeperCore
import TKCoordinator
import TKCore
import TKLogging
import TKUIKit
import TonSwift
import UIKit

final class PairSignerCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didCancel: (() -> Void)?
    var didPaired: (() -> Void)?

    private let scannerAssembly: KeeperCore.ScannerAssembly
    private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
    private let multichainAssembly: MultichainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let pairingAnalytics: WalletImportPairingAnalyticsSession
    private let analyticsContext: WalletFlowAnalyticsContext
    private let publicKeyImportCoordinatorProvider: (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator

    init(
        scannerAssembly: KeeperCore.ScannerAssembly,
        walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
        multichainAssembly: MultichainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext,
        publicKeyImportCoordinatorProvider: @escaping (NavigationControllerRouter, TonSwift.PublicKey, String) -> PublicKeyImportCoordinator
    ) {
        self.scannerAssembly = scannerAssembly
        self.walletUpdateAssembly = walletUpdateAssembly
        self.multichainAssembly = multichainAssembly
        self.coreAssembly = coreAssembly
        self.pairingAnalytics = WalletImportPairingAnalyticsSession(
            analyticsProvider: coreAssembly.analyticsProvider,
            walletMode: .single, walletSource: .signer, from: analyticsContext.from
        )
        self.analyticsContext = analyticsContext
        self.publicKeyImportCoordinatorProvider = publicKeyImportCoordinatorProvider
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

    override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
        guard pairingAnalytics.isActive, let signerDeeplink = deeplink as? Deeplink else { return false }
        switch signerDeeplink {
        case let .externalSign(externalSign):
            switch externalSign {
            case let .link(publicKey, name):
                pairingAnalytics.setBlocked(.cameraPermissionDenied, isBlocked: false)
                pairingAnalytics.setBlocked(.cameraError, isBlocked: false)
                pairingAnalytics.advance(to: .connected)
                openImportCoordinator(publicKey: publicKey, name: name, isDevice: true)
            }
            return true
        default:
            return false
        }
    }
}

private extension PairSignerCoordinator {
    func openScanner() {
        let module = SignerImportScanAssembly.module(
            scannerAssembly: scannerAssembly,
            coreAssembly: coreAssembly
        )

        module.output.didUpdateCameraState = { [weak self] state in
            self?.pairingAnalytics.cameraStateChanged(state)
        }
        module.output.didOpenSigner = { [weak self] in
            self?.pairingAnalytics.action(.signerAppOpened)
        }

        module.output.didScanLinkQRCode = { [weak self] publicKey, name in
            guard let self, pairingAnalytics.isActive else { return }
            pairingAnalytics.setBlocked(.cameraPermissionDenied, isBlocked: false)
            pairingAnalytics.setBlocked(.cameraError, isBlocked: false)
            pairingAnalytics.advance(to: .connected)
            coreAssembly.analyticsProvider.log(WalletImportSignerScanned(
                walletMode: .single,
                walletSource: .signer,
                from: analyticsContext.from
            ))
            openImportCoordinator(publicKey: publicKey, name: name, isDevice: false)
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

    func openImportCoordinator(publicKey: TonSwift.PublicKey, name: String, isDevice: Bool) {
        let coordinator = publicKeyImportCoordinatorProvider(router, publicKey, name)

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
                        revisions: revisions,
                        model: model,
                        isDevice: isDevice
                    )
                    self.pairingAnalytics.success()
                    await MainActor.run {
                        self.didPaired?()
                    }
                } catch {
                    Log.e("pair signer: wallet import failed", extraInfo: [
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
        model: CustomizeWalletModel,
        isDevice: Bool
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
            isDevice: isDevice
        )
    }
}
