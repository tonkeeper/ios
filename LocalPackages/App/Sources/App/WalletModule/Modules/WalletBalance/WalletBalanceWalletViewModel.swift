import Foundation
import KeeperCore
import TKCore
import TKUIKit

@MainActor
final class WalletBalanceWalletViewModel {
    struct Content {
        let balanceListItems: WalletBalanceBalanceModel.BalanceListItems
        let setupState: WalletBalanceSetupModel.State?
        let isMoreAssetsExpanded: Bool
        let showsBannersSection: Bool
    }

    let headerViewModel: WalletBalanceHeaderViewModel
    let homeBannersViewModel: WalletBalanceHomeBannersViewModel
    let collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel

    var didUpdateContent: ((Content) -> Void)?

    var content: Content {
        Content(
            balanceListItems: balanceListItems,
            setupState: setupState,
            isMoreAssetsExpanded: isMoreAssetsExpanded,
            showsBannersSection: homeBannersViewModel.isSectionVisible
        )
    }

    var wallet: Wallet {
        balanceListModel.wallet
    }

    private let balanceListModel: WalletBalanceBalanceModel
    private let setupModel: WalletBalanceSetupModel
    private var balanceListItems: WalletBalanceBalanceModel.BalanceListItems
    private var setupState: WalletBalanceSetupModel.State?
    private var isMoreAssetsExpanded = false

    init(
        balanceListModel: WalletBalanceBalanceModel,
        setupModel: WalletBalanceSetupModel,
        headerViewModel: WalletBalanceHeaderViewModel,
        homeBannersViewModel: WalletBalanceHomeBannersViewModel,
        collectiblesViewModel: WalletBalanceMultichainCollectiblesViewModel
    ) {
        self.balanceListModel = balanceListModel
        self.setupModel = setupModel
        self.headerViewModel = headerViewModel
        self.homeBannersViewModel = homeBannersViewModel
        self.collectiblesViewModel = collectiblesViewModel
        balanceListItems = balanceListModel.getItems()
        setupState = setupModel.getState()

        balanceListModel.didUpdateItems = { [weak self] items in
            guard let self else { return }
            balanceListItems = items
            republishContent()
        }

        setupModel.didUpdateState = { [weak self] state in
            guard let self else { return }
            setupState = state
            republishContent()
        }

        homeBannersViewModel.onSectionVisibilityChanged = { [weak self] _ in
            self?.republishContent()
        }
    }

    func didAppear() {
        headerViewModel.didAppear()
    }

    func didDisappear() {
        headerViewModel.didDisappear()
    }

    func resignActive() {
        headerViewModel.didDisappear()
    }

    func load() async {
        async let banners: Void = homeBannersViewModel.loadIfNeeded()
        async let collectibles: Void = collectiblesViewModel.load()
        _ = await(banners, collectibles)
    }

    func reload() async {
        async let header: Void = headerViewModel.reload()
        async let collectibles: Void = collectiblesViewModel.load()
        _ = await(header, collectibles)
    }

    func expandMoreAssets() {
        guard !isMoreAssetsExpanded else { return }
        isMoreAssetsExpanded = true
        republishContent()
    }

    func turnOnNotifications() async {
        await setupModel.turnOnNotifications()
    }

    func turnOnBiometry(passcode: String) async throws {
        try await setupModel.turnOnBiometry(passcode: passcode)
    }

    func turnOffBiometry() async throws {
        try await setupModel.turnOffBiometry()
    }

    func finishSetup() {
        setupModel.finishSetup()
    }

    func republishContent() {
        didUpdateContent?(content)
    }
}
