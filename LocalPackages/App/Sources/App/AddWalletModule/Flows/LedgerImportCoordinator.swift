import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import TonSwift
import TonTransport
import UIKit

final class LedgerImportCoordinator: RouterCoordinator<NavigationControllerRouter> {
    /// What the user chooses the accounts to add from.
    enum Choice {
        /// TON-only pairing: the TON app's accounts with their activity.
        case wallets([LedgerAccount], [ActiveWalletModel])
        /// Multichain pairing: the accounts read in every app on the Ledger.
        case accounts(LedgerAccountsViewModel)

        var selectedChains: [MultichainChain]? {
            guard case let .accounts(viewModel) = self else {
                return nil
            }
            return viewModel.selectedChains
        }
    }

    var didCancel: (() -> Void)?
    var didImport: ((_ accounts: [LedgerAccount], _ model: CustomizeWalletModel) -> Void)?

    private let choice: Choice
    private let name: String
    private let walletsUpdateAssembly: WalletsUpdateAssembly
    private let customizeWalletModule: () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>

    init(
        choice: Choice,
        name: String,
        router: NavigationControllerRouter,
        walletsUpdateAssembly: WalletsUpdateAssembly,
        customizeWalletModule: @escaping () -> MVVMModule<CustomizeWalletHostingViewController, CustomizeWalletModuleOutput, Void>
    ) {
        self.choice = choice
        self.name = name
        self.walletsUpdateAssembly = walletsUpdateAssembly
        self.customizeWalletModule = customizeWalletModule
        super.init(router: router)
    }

    override func start() {
        switch choice {
        case let .wallets(accounts, activeWalletModels):
            openChooseWalletToAdd(accounts: accounts, activeWalletModels: activeWalletModels)
        case let .accounts(viewModel):
            openChooseAccounts(viewModel: viewModel)
        }
    }
}

private extension LedgerImportCoordinator {
    func openChooseWalletToAdd(accounts: [LedgerAccount], activeWalletModels: [ActiveWalletModel]) {
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
            let selectedLedgerAccounts = accounts.filter { selectedIds.contains($0.id) }
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

    func openChooseAccounts(viewModel: LedgerAccountsViewModel) {
        let viewController = LedgerAccountsViewController(viewModel: viewModel)
        viewModel.didChoose = { [weak self] accounts in
            self?.openNotifications(accounts: accounts)
        }
        viewModel.didCancel = { [weak self] in
            self?.didCancel?()
        }

        if router.rootViewController.viewControllers.isEmpty {
            viewController.setupHeaderLeftCloseButton { [weak self] in
                self?.didCancel?()
            }
        } else {
            viewController.setupHeaderBackButton()
        }

        router.push(
            viewController: viewController,
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
