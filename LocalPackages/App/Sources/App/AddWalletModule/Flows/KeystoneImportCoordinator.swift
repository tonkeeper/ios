import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class KeystoneImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didPrepareForPresent: (() -> Void)?
    var didCancel: (() -> Void)?
    var didImport: ((_ publicKey: TonSwift.PublicKey, _ revisions: [WalletContractVersion], _ model: CustomizeWalletModel) -> Void)?

    private let publicKey: TonSwift.PublicKey
    private let name: String?
    private let path: String?
    private let xfp: String?
    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let customizeWalletModule: () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>

    init(
        publicKey: TonSwift.PublicKey,
        xfp: String?,
        path: String?,
        name: String?,
        router: NavigationControllerRouter,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        customizeWalletModule: @escaping () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    ) {
        self.publicKey = publicKey
        self.name = name
        self.xfp = xfp
        self.path = path
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.customizeWalletModule = customizeWalletModule
        super.init(router: router)
    }

    override func start() {
        Task {
            await MainActor.run {
                openNotifications(publicKey: publicKey, revisions: [.v4R2])
                didPrepareForPresent?()
            }
        }
    }
}

private extension KeystoneImportCoordinator {
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
