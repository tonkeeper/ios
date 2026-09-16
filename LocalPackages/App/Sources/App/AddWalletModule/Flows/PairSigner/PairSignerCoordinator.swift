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
        self.analyticsContext = analyticsContext
        self.publicKeyImportCoordinatorProvider = publicKeyImportCoordinatorProvider
        super.init(router: router)
    }

    override func start() {
        openScanner()
    }

    override func handleDeeplink(deeplink: CoordinatorDeeplink?) -> Bool {
        guard let signerDeeplink = deeplink as? Deeplink else { return false }
        switch signerDeeplink {
        case let .externalSign(externalSign):
            switch externalSign {
            case let .link(publicKey, name):
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

        module.output.didScanLinkQRCode = { [weak self] publicKey, name in
            self?.openImportCoordinator(publicKey: publicKey, name: name, isDevice: false)
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

    func openImportCoordinator(publicKey: TonSwift.PublicKey, name: String, isDevice: Bool) {
        let coordinator = publicKeyImportCoordinatorProvider(router, publicKey, name)

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
                        model: model,
                        isDevice: isDevice
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
                    Log.e("pair signer: wallet import failed", extraInfo: [
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
