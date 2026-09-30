import KeeperCore
import TKCoordinator
import TKCore
import TKScreenKit
import TKUIKit
import UIKit

@MainActor
final class WalletConnectProposal: RouterCoordinator<ViewControllerRouter> {
    var didApprove: ((Wallet) async throws -> Void)?
    var didReject: (() async throws -> Void)?
    var didDeliverResponse: (() -> Void)?

    private let proposal: WalletConnectSessionProposal
    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private weak var proposalViewController: WalletConnectProposalHostingViewController?

    init(
        proposal: WalletConnectSessionProposal,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: ViewControllerRouter
    ) {
        self.proposal = proposal
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override func start() {
        openProposal()
    }

    func matchesProposal(id: String, pairingTopic: String) -> Bool {
        proposal.id == id
            && proposal.pairingTopic == pairingTopic
            && (proposalViewController?.matchesProposal(id: id, pairingTopic: pairingTopic) ?? true)
    }

    func dismissAfterProposalExpired() {
        guard let proposalViewController else {
            finish()
            return
        }
        proposalViewController.dismissAfterProposalExpired(animated: true) { [weak self] in
            self?.finish()
        }
    }
}

private extension WalletConnectProposal {
    func openProposal() {
        let module = WalletConnectProposalAssembly.module(
            proposal: proposal,
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )
        let viewController = module.view
        proposalViewController = viewController

        module.output.didTapWalletPicker = { [weak self, weak viewController, weak input = module.input] wallet in
            guard let self, let viewController else { return }
            self.openWalletPicker(
                wallet: wallet,
                fromViewController: viewController,
                didSelectWallet: { wallet in
                    input?.setWallet(wallet)
                }
            )
        }

        module.output.didReject = { [weak self] in
            guard let self else { return }
            try await self.didReject?()
        }

        module.output.didApprove = { [weak self] wallet in
            guard let self else { return }
            try await self.didApprove?(wallet)
        }

        module.output.didOpenDAppHost = { [weak self] url in
            self?.coreAssembly.urlOpener().open(url: url)
        }

        module.output.didRequestValidationConfirmation = { [weak viewController] validation, connect in
            guard let viewController else {
                connect()
                return
            }

            WalletConnectConfirmationPresenter.present(
                validation: validation,
                from: viewController,
                connect: connect
            )
        }

        module.output.didComplete = { [weak self, weak viewController] in
            guard let self else { return }
            let completion = { [weak self] in
                self?.didDeliverResponse?()
                self?.finish()
            }
            guard let viewController,
                  viewController.presentingViewController != nil
            else {
                completion()
                return
            }
            viewController.dismiss(animated: true, completion: completion)
        }

        router.rootViewController.topPresentedViewController().present(viewController, animated: true)
    }

    func openWalletPicker(
        wallet: Wallet,
        fromViewController: UIViewController,
        didSelectWallet: @escaping (Wallet) -> Void
    ) {
        let model = WalletConnectWalletsPickerListModel(
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            selectedWallet: wallet
        )
        model.didSelectWallet = { wallet in
            didSelectWallet(wallet)
        }

        let module = WalletsListAssembly.module(
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly
        )

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

        module.output.addButtonEvent = { [weak self, unowned bottomSheetViewController] in
            self?.openAddWallet(router: ViewControllerRouter(rootViewController: bottomSheetViewController)) {}
        }

        module.output.didSelectWallet = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(fromViewController: fromViewController)
    }

    func openAddWallet(router: ViewControllerRouter, onAddWallets: @escaping () -> Void) {
        let module = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                multichainAssembly: keeperCoreMainAssembly.multichainAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        )
        let coordinator = module.createAddWalletCoordinator(
            options: [
                .createMultichain,
                .importRegular,
                .importWatchOnly,
                .signer,
            ],
            router: router,
            analyticsContext: module.makeWalletFlowAnalyticsContext(from: .main)
        )
        coordinator.didAddWallets = {
            onAddWallets()
        }

        addChild(coordinator)
        coordinator.start()
    }

    func finish() {
        didFinish?(self)
    }
}

final class WalletConnectWalletsPickerListModel: WalletsListModel {
    var didSelectWallet: ((Wallet) -> Void)?
    var didUpdateState: ((WalletsListModelState) -> Void)?

    private let walletsStore: WalletsStore
    private let selectedWallet: Wallet

    init(
        walletsStore: WalletsStore,
        selectedWallet: Wallet
    ) {
        self.walletsStore = walletsStore
        self.selectedWallet = selectedWallet
        walletsStore.addObserver(self) { observer, event in
            DispatchQueue.main.async {
                switch event {
                case .didAddWallets,
                     .didDeleteWallet,
                     .didDeleteAll,
                     .didMoveWallet,
                     .didUpdateWalletMetaData,
                     .didUpdateWalletMultichain:
                    observer.updateState()
                default: break
                }
            }
        }
    }

    var isEditable: Bool {
        false
    }

    func getState() -> WalletsListModelState {
        let wallets = filteredWallets()
        let currentWallet = wallets.first(where: { $0 == selectedWallet }) ?? wallets.first
        return WalletsListModelState(wallets: wallets, selectedWalletIdentifier: currentWallet?.id)
    }

    func selectWallet(wallet: Wallet) {
        DispatchQueue.main.async {
            self.didSelectWallet?(wallet)
        }
    }

    func moveWallet(fromIndex: Int, toIndex: Int) {}

    func getWallet(id: String) -> Wallet? {
        filteredWallets().first { $0.id == id }
    }

    private func updateState() {
        didUpdateState?(getState())
    }

    private func filteredWallets() -> [Wallet] {
        walletsStore.state.wallets.filter(\.isMultichain)
    }
}
