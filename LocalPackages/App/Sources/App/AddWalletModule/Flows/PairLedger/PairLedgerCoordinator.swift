import KeeperCore
import LedgerKit
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKLogging
import TKUIKit
import TonSwift
import TonTransport
import UIKit

final class PairLedgerCoordinator: RouterCoordinator<ViewControllerRouter> {
    var didCancel: (() -> Void)?
    var didPaired: (() -> Void)?

    private var isContinuingFromConnection = false
    private var bluetoothStateTask: Task<Void, Never>?
    private let walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly
    private let coreAssembly: TKCore.CoreAssembly
    private let multichainAssembly: MultichainAssembly
    private let pairingAnalytics: WalletImportPairingAnalyticsSession
    private let analyticsContext: WalletFlowAnalyticsContext
    private let ledgerNetworkSelectionConfiguration: LedgerNetworkSelectionConfiguration
    private let ledgerImportCoordinatorProvider: (NavigationControllerRouter, LedgerImportCoordinator.Choice, String) -> LedgerImportCoordinator

    init(
        walletUpdateAssembly: KeeperCore.WalletsUpdateAssembly,
        coreAssembly: TKCore.CoreAssembly,
        multichainAssembly: MultichainAssembly,
        router: ViewControllerRouter,
        analyticsContext: WalletFlowAnalyticsContext,
        ledgerNetworkSelectionConfiguration: LedgerNetworkSelectionConfiguration,
        ledgerImportCoordinatorProvider: @escaping (NavigationControllerRouter, LedgerImportCoordinator.Choice, String) -> LedgerImportCoordinator
    ) {
        self.walletUpdateAssembly = walletUpdateAssembly
        self.coreAssembly = coreAssembly
        self.multichainAssembly = multichainAssembly
        self.pairingAnalytics = WalletImportPairingAnalyticsSession(
            analyticsProvider: coreAssembly.analyticsProvider,
            walletMode: coreAssembly.featureFlags[.ledgerMultichain] ? .multi : .single,
            walletSource: .ledger, from: analyticsContext.from
        )
        self.analyticsContext = analyticsContext
        self.ledgerNetworkSelectionConfiguration = ledgerNetworkSelectionConfiguration
        self.ledgerImportCoordinatorProvider = ledgerImportCoordinatorProvider
        super.init(router: router)
    }

    deinit {
        bluetoothStateTask?.cancel()
    }

    override func start() {
        pairingAnalytics.start()
        let states = coreAssembly.ledgerAssembly.transport.bluetoothState()
        bluetoothStateTask = Task { @MainActor [weak pairingAnalytics] in
            for await state in states {
                guard let pairingAnalytics, pairingAnalytics.isActive, !Task.isCancelled else { return }
                pairingAnalytics.bluetoothStateChanged(state)
            }
        }
        openConnectLedger()
    }

    @discardableResult
    func cancelPairing() -> Bool {
        let didFinish = pairingAnalytics.exit()
        bluetoothStateTask?.cancel()
        return didFinish
    }
}

private extension PairLedgerCoordinator {
    func openConnectLedger() {
        let isMultichain = pairingAnalytics.walletMode == .multi
        let module = LedgerConnectAssembly.module(coreAssembly: coreAssembly, readsAccounts: !isMultichain)

        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: module.view)

        module.output.didStartSearch = { [weak self] in
            self?.pairingAnalytics.action(.deviceSearchStarted)
        }
        module.output.didFindDevice = { [weak self] peripheral in
            self?.pairingAnalytics.deviceFound(
                id: peripheral.id, model: LedgerModel(deviceProductName: peripheral.device.productName)
            )
        }
        module.output.didUpdateConnectionError = { [weak self] isBlocked in
            self?.pairingAnalytics.setBlocked(.connectionError, isBlocked: isBlocked)
        }

        module.output.didConnectBluetooth = { [weak self] deviceProductName in
            guard let self, pairingAnalytics.isActive else { return }
            pairingAnalytics.advance(to: .connected)
            coreAssembly.analyticsProvider.log(WalletImportLedgerBluetoothConnected(
                walletMode: self.pairingAnalytics.walletMode,
                walletSource: .ledger,
                from: analyticsContext.from,
                ledgerModel: LedgerModel(deviceProductName: deviceProductName)
            ))
        }
        module.output.didOpenTonApp = { [weak self] deviceProductName in
            self?.logTonAppOpened(deviceProductName: deviceProductName)
        }

        module.output.didCancel = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        module.output.didConnect = { [weak self, weak bottomSheetViewController] ledgerAccounts, deviceId, deviceProductName, completion in
            guard let self, pairingAnalytics.isActive, let bottomSheetViewController,
                  !bottomSheetViewController.isDismissing,
                  bottomSheetViewController.navigationController?.presentingViewController != nil
            else { return }
            guard !isMultichain else {
                completion()
                isContinuingFromConnection = true
                bottomSheetViewController.dismiss {
                    self.openNetworkSelection(deviceId: deviceId, deviceProductName: deviceProductName)
                }
                return
            }
            Task {
                do {
                    let accounts: [(String, Address, WalletContractVersion)] = ledgerAccounts.compactMap {
                        guard let contractVersion = WalletContractVersion(revision: $0.revision) else { return nil }
                        do {
                            let contract = try self.createContract(ledgerAccount: $0)
                            return try (id: $0.id, contract.address(), contractVersion)
                        } catch {
                            return nil
                        }
                    }
                    let activeWallets = try await self.walletUpdateAssembly
                        .walletImportController()
                        .findActiveWallets(accounts: accounts, network: .mainnet, checkHistory: false)
                    let handledActiveWallets = self.handleActiveWallets(
                        activeWalletModels: activeWallets,
                        ledgerAccounts: ledgerAccounts,
                        deviceId: deviceId
                    )
                    guard self.pairingAnalytics.isActive, !bottomSheetViewController.isDismissing else { return }
                    self.pairingAnalytics.setBlocked(.importError, isBlocked: false)
                    await MainActor.run {
                        guard self.pairingAnalytics.isActive,
                              !bottomSheetViewController.isDismissing,
                              bottomSheetViewController.navigationController?.presentingViewController != nil
                        else { return }
                        completion()
                        self.isContinuingFromConnection = true
                        bottomSheetViewController.dismiss(completion: {
                            self.openImportCoordinator(
                                choice: .wallets(ledgerAccounts, handledActiveWallets),
                                deviceId: deviceId,
                                deviceProductName: deviceProductName
                            )
                        })
                    }
                } catch {
                    self.pairingAnalytics.setBlocked(.importError)
                    await MainActor.run {
                        completion()
                    }
                }
            }
        }

        bottomSheetViewController.present(fromViewController: router.rootViewController)
        (bottomSheetViewController.navigationController as? TKNavigationController)?.didDismiss = { [weak self] in
            guard let self, !isContinuingFromConnection, cancelPairing() else { return }
            didCancel?()
        }
    }

    func openImportCoordinator(
        choice: LedgerImportCoordinator.Choice,
        deviceId: String,
        deviceProductName: String,
        navigationController: TKNavigationController? = nil
    ) {
        guard pairingAnalytics.isActive else { return }
        let navigationController = navigationController ?? TKNavigationController()
        navigationController.configureTransparentAppearance()
        navigationController.didDismiss = { [weak self] in
            guard self?.cancelPairing() == true else { return }
            self?.didCancel?()
        }
        let coordinator = ledgerImportCoordinatorProvider(
            NavigationControllerRouter(
                rootViewController: navigationController
            ),
            choice,
            deviceProductName
        )

        coordinator.didCancel = { [weak self, weak coordinator, weak navigationController] in
            self?.closeImport(navigationController, coordinator: coordinator)
        }

        coordinator.didImport = { [weak self, weak navigationController, weak coordinator] accounts, model in
            guard let self, pairingAnalytics.isActive else { return }
            Task {
                let multichainAccounts: [AccountPath: LedgerMultichainAccount]
                do {
                    multichainAccounts = try await self.multichainAccounts(accounts, choice: choice, deviceId: deviceId, from: navigationController)
                } catch is CancellationError {
                    await MainActor.run {
                        (navigationController?.topViewController as? CustomizeWalletHostingViewController)?.resetContinue()
                    }
                    return
                } catch {
                    guard self.pairingAnalytics.isActive else { return }
                    self.pairingAnalytics.setBlocked(.importError)
                    Log.i("pair ledger: wallet key proofs not signed, closing the import", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                    await MainActor.run {
                        self.closeImport(navigationController, coordinator: coordinator)
                    }
                    return
                }
                guard self.pairingAnalytics.beginImport() else { return }
                do {
                    try await self.importWallet(
                        accounts: accounts,
                        multichainAccounts: multichainAccounts,
                        chains: choice.selectedChains ?? [],
                        deviceId: deviceId,
                        deviceProductName: deviceProductName,
                        model: model
                    )
                    self.bluetoothStateTask?.cancel()
                    self.pairingAnalytics.success(ledgerModel: LedgerModel(deviceProductName: deviceProductName))
                    await MainActor.run {
                        WalletImportPairingNavigation.dismiss(navigationController) {
                            self.didPaired?()
                        }
                    }
                } catch {
                    Log.e("pair ledger: wallet import failed", extraInfo: [
                        "error": error.localizedDescription,
                    ])
                    let didFinish = self.pairingAnalytics.importFailed(
                        error: error, ledgerModel: LedgerModel(deviceProductName: deviceProductName)
                    )
                    await MainActor.run {
                        if didFinish {
                            self.didCancel?()
                            return
                        }
                        ToastPresenter.showToast(configuration: .failed)
                        self.closeImport(navigationController, coordinator: coordinator)
                    }
                }
            }
        }

        addChild(coordinator)
        coordinator.start()
        if navigationController.presentingViewController == nil {
            self.router.present(navigationController)
        }
    }

    /// Ends pairing from the import: closes it while it is still up, then tells the add-wallet flow. The import may be
    /// gone already, taken down with the screens under it.
    func closeImport(_ navigationController: UINavigationController?, coordinator: LedgerImportCoordinator?) {
        guard pairingAnalytics.isActive else { return }
        let didFinish = cancelPairing()
        if let coordinator {
            removeChild(coordinator)
        }
        guard let presentingViewController = navigationController?.presentingViewController else {
            if didFinish { didCancel?() }
            return
        }
        presentingViewController.dismiss(animated: true) { [weak self] in
            if didFinish { self?.didCancel?() }
        }
    }

    func importWallet(
        accounts: [LedgerAccount],
        multichainAccounts: [AccountPath: LedgerMultichainAccount],
        chains: [MultichainChain],
        deviceId: String,
        deviceProductName: String,
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
        try await addController.importLedgerWallets(
            accounts: accounts,
            multichainAccounts: multichainAccounts,
            chains: chains,
            deviceId: deviceId,
            deviceProductName: deviceProductName,
            metaData: metaData
        )
    }

    /// In a multichain pairing each chosen account signs its wallet key proof; its keys were read before the choice.
    /// Throws when the user cancels or the device fails.
    func multichainAccounts(
        _ accounts: [LedgerAccount],
        choice: LedgerImportCoordinator.Choice,
        deviceId: String,
        from viewController: UIViewController?
    ) async throws -> [AccountPath: LedgerMultichainAccount] {
        guard case let .accounts(accountsViewModel) = choice else {
            return [:]
        }
        guard let viewController, let peripheralID = UUID(uuidString: deviceId) else {
            throw CancellationError()
        }
        let proofs = try await LedgerSteps.walletKeyProofs(accounts)
            .perform(peripheralID: peripheralID, transport: coreAssembly.ledgerAssembly.transport, from: viewController)
        return accountsViewModel.multichainAccounts(accounts, proofs: proofs)
    }

    /// Opens the accounts screen, which reads the first accounts in the selected apps on the Ledger and lets the user
    /// choose among them and read more.
    func openAccounts(
        deviceId: String,
        deviceProductName: String,
        chains: [MultichainChain],
        navigationController: TKNavigationController? = nil
    ) {
        guard let peripheralID = UUID(uuidString: deviceId) else {
            return
        }
        let viewModel = LedgerAccountsViewModel(chains: chains, dependencies: LedgerAccountsViewModel.Dependencies(
            read: { [weak self] indices, apps, choosesApps in
                guard let self, pairingAnalytics.isActive else {
                    throw CancellationError()
                }
                let discovery: LedgerDiscovery
                do {
                    discovery = try await LedgerSteps.discovery(indices, apps: apps, choosesApps: choosesApps).perform(
                        peripheralID: peripheralID,
                        transport: coreAssembly.ledgerAssembly.transport,
                        from: router.rootViewController.topPresentedViewController()
                    )
                } catch {
                    if !(error is CancellationError) { pairingAnalytics.setBlocked(.connectionError) }
                    throw error
                }
                guard pairingAnalytics.isActive else { throw CancellationError() }
                pairingAnalytics.setBlocked(.connectionError, isBlocked: false)
                if choosesApps {
                    logTonAppOpened(deviceProductName: deviceProductName)
                }
                return discovery
            },
            loadBalances: { [weak self] accounts in
                await self?.loadBalances(accounts) ?? []
            },
            isAdded: { [weak self] account in
                self?.isLedgerAccountAdded(account, deviceId: deviceId) ?? false
            },
            askAccountNumber: { [weak self] in
                await self?.askAccountNumber()
            },
            amountFormatter: walletUpdateAssembly.formattersAssembly.amountFormatter
        ))
        viewModel.didShowAccounts = { [weak self] in
            self?.pairingAnalytics.advance(to: .accountsView)
        }
        openImportCoordinator(
            choice: .accounts(viewModel),
            deviceId: deviceId,
            deviceProductName: deviceProductName,
            navigationController: navigationController
        )
    }

    func openNetworkSelection(deviceId: String, deviceProductName: String) {
        guard pairingAnalytics.isActive else { return }
        let chains = MultichainChain.orderedByDisplayOrder([.ton] + multichainAssembly.supportedChains)
        let viewModel = LedgerNetworksViewModel(
            title: TKLocales.LedgerNetworks.title,
            description: TKLocales.LedgerNetworks.Pairing.description,
            chains: chains,
            preselectedChains: ledgerNetworkSelectionConfiguration.pairingSelection(among: chains),
            requiredChains: [.ton]
        )
        let viewController = LedgerNetworksViewController(viewModel: viewModel)
        let navigationController = TKNavigationController(rootViewController: viewController)
        navigationController.configureTransparentAppearance()
        navigationController.didDismiss = { [weak self] in
            guard self?.cancelPairing() == true else { return }
            self?.didCancel?()
        }
        viewController.setupHeaderLeftCloseButton { [weak self, weak navigationController] in
            self?.closeImport(navigationController, coordinator: nil)
        }
        viewModel.didContinue = { [weak self, weak navigationController] chains in
            guard let self, let navigationController else { return }
            // The selection is the root of this modal navigation stack. Remove it before the import coordinator
            // pushes its first screen, so that screen owns the close action rather than a back navigation to selection.
            navigationController.setViewControllers([], animated: false)
            self.openAccounts(
                deviceId: deviceId,
                deviceProductName: deviceProductName,
                chains: chains,
                navigationController: navigationController
            )
        }
        router.present(navigationController)
    }

    /// A multichain pairing opens the TON app at the end of the first accounts read rather than on the connect screen.
    func logTonAppOpened(deviceProductName: String?) {
        guard pairingAnalytics.isActive else { return }
        pairingAnalytics.advance(to: .appOpened)
        coreAssembly.analyticsProvider.log(WalletImportLedgerAppOpened(
            walletMode: self.pairingAnalytics.walletMode,
            walletSource: .ledger,
            from: analyticsContext.from,
            ledgerModel: deviceProductName.map(LedgerModel.init(deviceProductName:))
        ))
    }

    func loadBalances(_ accounts: [LedgerAccount]) async -> [ActiveWalletModel] {
        let contracts: [(String, Address, WalletContractVersion)] = accounts.compactMap { account in
            guard let version = WalletContractVersion(revision: account.revision),
                  let address = try? createContract(ledgerAccount: account).address()
            else {
                return nil
            }
            return (account.id, address, version)
        }
        do {
            return try await walletUpdateAssembly
                .walletImportController()
                .findActiveWallets(accounts: contracts, network: .mainnet, checkHistory: false)
        } catch {
            Log.w("pair ledger: balances not loaded", error: error)
            return []
        }
    }

    func isLedgerAccountAdded(_ account: LedgerAccount, deviceId: String) -> Bool {
        guard let address = try? createContract(ledgerAccount: account).address(),
              let wallets = try? walletUpdateAssembly.servicesAssembly.walletsService().getWallets()
        else {
            return false
        }
        return wallets.contains { wallet in
            guard case let .Ledger(_, _, device) = wallet.identity.kind, device.deviceId == deviceId else {
                return false
            }
            return (try? wallet.address) == address
        }
    }

    /// The account number the user types, from 1; `nil` when they cancel.
    func askAccountNumber() async -> Int? {
        let numbers = 1 ... LedgerAccountsViewModel.maxAccountIndex + 1
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: TKLocales.LedgerAccounts.Number.title,
                message: TKLocales.LedgerAccounts.Number.description(numbers.upperBound),
                preferredStyle: .alert
            )
            let add = UIAlertAction(title: TKLocales.LedgerAccounts.Number.action, style: .default) { [weak alert] _ in
                continuation.resume(returning: alert?.textFields?.first?.text.flatMap { Int($0) })
            }
            add.isEnabled = false
            alert.addTextField { field in
                field.keyboardType = .numberPad
                field.addAction(UIAction { [weak field] _ in
                    add.isEnabled = field?.text.flatMap { Int($0) }.map(numbers.contains) ?? false
                }, for: .editingChanged)
            }
            alert.addAction(UIAlertAction(title: TKLocales.Actions.cancel, style: .cancel) { _ in
                continuation.resume(returning: nil)
            })
            alert.addAction(add)
            router.rootViewController.topPresentedViewController().present(alert, animated: true)
        }
    }

    private func handleActiveWallets(
        activeWalletModels: [ActiveWalletModel],
        ledgerAccounts: [LedgerAccount],
        deviceId: String
    ) -> [ActiveWalletModel] {
        let sorted = activeWalletModels.sorted { lModel, rModel in
            guard let lLedgerAccount = ledgerAccounts.first(where: { $0.id == lModel.id }),
                  let rLedgetAcccount = ledgerAccounts.first(where: { $0.id == rModel.id })
            else {
                return true
            }
            return lLedgerAccount.path.index < rLedgetAcccount.path.index
        }
        do {
            let wallets = try walletUpdateAssembly.servicesAssembly
                .walletsService()
                .getWallets()
            return sorted.map { model in
                let isAdded = isLedgerWalletAdded(walletModel: model, wallets: wallets, deviceId: deviceId)
                return ActiveWalletModel(
                    id: model.id,
                    revision: model.revision,
                    address: model.address,
                    isActive: model.isActive,
                    balance: model.balance,
                    nfts: model.nfts,
                    isAdded: isAdded,
                    history: .unknown
                )
            }
        } catch {
            return sorted
        }
    }

    private func createContract(ledgerAccount: LedgerAccount) throws -> WalletContract {
        switch ledgerAccount.revision {
        case .v4R2:
            return WalletV4R2(publicKey: ledgerAccount.publicKey.data)
        }
    }

    private func isLedgerWalletAdded(
        walletModel: ActiveWalletModel,
        wallets: [Wallet],
        deviceId: String
    ) -> Bool {
        for wallet in wallets {
            do {
                guard case let .Ledger(_, _, device) = wallet.identity.kind,
                      device.deviceId == deviceId,
                      try walletModel.address == wallet.address else { continue }
                return true
            } catch {
                return false
            }
        }
        return false
    }
}

extension WalletContractVersion {
    init?(revision: LedgerWalletRevision) {
        switch revision {
        case .v4R2:
            self = .v4R2
        }
    }
}
