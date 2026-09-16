import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import TonSwift
import TonTransport
import UIKit

final class LedgerImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didCancel: (() -> Void)?
    var didImport: ((_ accounts: [LedgerAccount], _ model: CustomizeWalletModel) -> Void)?

    private let ledgerAccounts: [LedgerAccount]
    private let activeWalletModels: [ActiveWalletModel]
    private let name: String
    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let customizeWalletModule: () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>

    init(
        ledgerAccounts: [LedgerAccount],
        activeWalletModels: [ActiveWalletModel],
        name: String,
        router: NavigationControllerRouter,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        customizeWalletModule: @escaping () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    ) {
        self.ledgerAccounts = ledgerAccounts
        self.activeWalletModels = activeWalletModels
        self.name = name
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.customizeWalletModule = customizeWalletModule
        super.init(router: router)
    }

    override func start() {
        openChooseWalletToAdd()
    }
}

private extension LedgerImportCoordinator {
    func openChooseWalletToAdd() {
        let module = ChooseWalletToAddAssembly.module(
            activeWalletModels: activeWalletModels,
            configuration: ChooseWalletToAddConfiguration(
                showRevision: false,
                selectLastRevision: false
            ),
            amountFormatter: walletsUpdateAssembly.formattersAssembly.amountFormatter,
            network: .mainnet
        )

        module.output.didSelectWallets = { [weak self] selectedWalletModels in
            guard let self else { return }
            let selectedIds = selectedWalletModels.map { $0.id }
            let selectedLedgerAccounts = self.ledgerAccounts.filter { selectedIds.contains($0.id) }
            self.openNotifications(accounts: selectedLedgerAccounts)
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

    func openNotifications(accounts: [LedgerAccount]) {
        OnboardingNotificationsStep.push(router: router) { [weak self] in
            self?.openCustomizeWallet(accounts: accounts)
        }
    }

    func openCustomizeWallet(accounts: [LedgerAccount]) {
        let module = customizeWalletModule()

        module.output.didCustomizeWallet = { [weak self] model in
            guard let self else { return }
            self.didImport?(accounts, model)
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
