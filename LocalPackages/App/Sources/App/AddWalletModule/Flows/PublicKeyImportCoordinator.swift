import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class PublicKeyImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didPrepareForPresent: (() -> Void)?
    var didCancel: (() -> Void)?
    var didImport: ((_ publicKey: TonSwift.PublicKey, _ revisions: [WalletContractVersion], _ model: CustomizeWalletModel) -> Void)?

    private let publicKey: TonSwift.PublicKey
    private let name: String?
    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let customizeWalletModule: () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>

    init(
        publicKey: TonSwift.PublicKey,
        name: String?,
        router: NavigationControllerRouter,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        customizeWalletModule: @escaping () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    ) {
        self.publicKey = publicKey
        self.name = name
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.customizeWalletModule = customizeWalletModule
        super.init(router: router)
    }

    override func start() {
        ToastPresenter.showToast(configuration: .loading)
        Task {
            do {
                let activeWalletModels = try await detectActiveWallets(publicKey: publicKey)
                await MainActor.run {
                    ToastPresenter.hideAll()
                    if activeWalletModels.count == 1, activeWalletModels[0].revision == WalletContractVersion.currentVersion {
                        openNotifications(publicKey: publicKey, revisions: [.currentVersion])
                    } else {
                        openChooseWalletToAdd(publicKey: publicKey, activeWalletModels: activeWalletModels)
                    }
                    didPrepareForPresent?()
                }
            } catch {
                await MainActor.run {
                    ToastPresenter.hideAll()
                    openNotifications(publicKey: publicKey, revisions: [.currentVersion])
                    didPrepareForPresent?()
                }
            }
        }
    }
}

private extension PublicKeyImportCoordinator {
    func detectActiveWallets(publicKey: TonSwift.PublicKey) async throws -> [ActiveWalletModel] {
        try await walletsUpdateAssembly.walletImportController().findActiveWallets(publicKey: publicKey, network: .mainnet, checkHistory: false)
    }

    func openChooseWalletToAdd(publicKey: TonSwift.PublicKey, activeWalletModels: [ActiveWalletModel]) {
        let module = ChooseWalletToAddAssembly.module(
            activeWalletModels: activeWalletModels,
            configuration: ChooseWalletToAddConfiguration(
                showRevision: true,
                selectLastRevision: true
            ),
            amountFormatter: walletsUpdateAssembly.formattersAssembly.amountFormatter,
            network: .mainnet
        )

        module.output.didSelectWallets = { [weak self] wallets in
            let revisions = wallets.map { $0.revision }
            self?.openNotifications(publicKey: publicKey, revisions: revisions)
        }

        if router.rootViewController.viewControllers.isEmpty {
            module.view.setupLeftCloseButton { [weak self] in
                self?.didCancel?()
            }
        } else {
            module.view.setupBackButton()
        }

        router.push(
            viewController: module.view,
            animated: true,
            onPopClosures: { [weak self] in self?.didCancel?() },
            completion: nil
        )
    }

    func openNotifications(publicKey: TonSwift.PublicKey, revisions: [WalletContractVersion]) {
        OnboardingNotificationsStep.push(router: router) { [weak self] in
            self?.openCustomizeWallet(publicKey: publicKey, revisions: revisions)
        }
    }

    func openCustomizeWallet(publicKey: TonSwift.PublicKey, revisions: [WalletContractVersion]) {
        let module = customizeWalletModule()

        module.output.didCustomizeWallet = { [weak self] model in
            self?.didImport?(publicKey, revisions, model)
        }

        if router.rootViewController.viewControllers.isEmpty {
            module.view.setupHeaderLeftCloseButton { [weak self] in
                self?.didCancel?()
            }
        } else {
            module.view.setupHeaderBackButton()
        }

        router.push(viewController: module.view, animated: true)
    }
}
