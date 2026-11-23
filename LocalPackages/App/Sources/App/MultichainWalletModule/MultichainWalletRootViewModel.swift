import AppUI
import Combine
import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

@MainActor
final class MultichainWalletRootViewModel: ObservableObject {
    @Published private(set) var walletViewModel: MultichainWalletViewModel
    @Published private(set) var raffleEntries = [MysteryRafflePresentation]()
    @Published private(set) var earnCards = [EarnCardViewData]()
    @Published private(set) var loyaltyRow: LoyaltyRow?

    struct LoyaltyRow: Equatable {
        let isJoined: Bool
        let ohmsText: String?
    }

    var onOpenRaffle: ((String) -> Void)?
    var onOpenEarn: ((URL) -> Void)?
    var onOpenLoyalty: (() -> Void)?

    var didChangeWallet: (() -> Void)?

    private let walletsStore: WalletsStore
    private let configuration: Configuration
    private let loyaltyStore: LoyaltyStore
    private let appSettingsStore: AppSettingsStore
    private let earnVaultsRepository: EarnVaultsRepository
    private let earnCardMapper: ([EarnVault]) -> [EarnCardViewData]
    private let analyticsProvider: AnalyticsProvider
    private let tooltipsService: TooltipsService
    private var raffleObserver: MysteryRafflePresentationObserver?
    private var earnLoadTask: Task<Void, Never>?
    /// Configuration is loaded once a session, so a failed load is retried as the screen comes back.
    private var hasEarnVaults = false
    private var shownEarnFeaturedWalletIds = Set<String>()

    private let makeWalletViewModel: (Wallet) -> MultichainWalletViewModel
    private var walletViewModels = [String: MultichainWalletViewModel]()

    private var isOnScreen = false
    private var loggedRaffleBannerViewIds = Set<String>()
    private weak var earnTooltipSourceView: UIView?
    private weak var earnSectionView: UIView?
    private weak var perpsTooltipSourceView: UIView?
    private var perpsTooltipObservations = [NSKeyValueObservation]()
    private var perpsTooltipCheck: Task<Void, Never>?

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
        configuration: Configuration,
        raffleStore: RaffleStore,
        loyaltyStore: LoyaltyStore,
        appSettingsStore: AppSettingsStore,
        analyticsProvider: AnalyticsProvider,
        tooltipsService: TooltipsService,
        earnVaultsRepository: EarnVaultsRepository,
        earnCardMapper: @escaping ([EarnVault]) -> [EarnCardViewData],
        makeWalletViewModel: @escaping (Wallet) -> MultichainWalletViewModel
    ) {
        self.earnVaultsRepository = earnVaultsRepository
        self.earnCardMapper = earnCardMapper
        self.walletsStore = walletsStore
        self.configuration = configuration
        self.loyaltyStore = loyaltyStore
        self.appSettingsStore = appSettingsStore
        self.analyticsProvider = analyticsProvider
        self.tooltipsService = tooltipsService
        self.makeWalletViewModel = makeWalletViewModel
        let walletViewModel = makeWalletViewModel(wallet)
        walletViewModels = [wallet.id: walletViewModel]
        self.walletViewModel = walletViewModel

        raffleObserver = MysteryRafflePresentationObserver(
            raffleStore: raffleStore
        ) { [weak self] raffles in
            let entries = MysteryRafflePresentation.all(from: raffles).filter(\.shouldShowWalletEntry)
            // The observer re-emits on every raffle reload and timer tick; an equal value would re-render all of home.
            guard let self, raffleEntries != entries else { return }
            raffleEntries = entries
        }

        loyaltyStore.addObserver(self) { observer, _ in
            Task { @MainActor in
                observer.refreshLoyaltyEntry()
            }
        }

        appSettingsStore.addObserver(self) { observer, event in
            guard case .didUpdateIsSecureMode = event else { return }
            Task { @MainActor in
                observer.refreshLoyaltyEntry()
            }
        }

        configuration.addUpdateObserver(self) { observer in
            Task { @MainActor in
                observer.loadEarnVaults()
            }
        }

        walletsStore.addObserver(self) { [weak self] _, event in
            guard let self else { return }
            Task { @MainActor in
                switch event {
                case let .didChangeActiveWallet(_, wallet):
                    self.activate(wallet: wallet)
                    self.discardOrphanedWalletViewModels()
                case .didAddWallets:
                    self.discardOrphanedWalletViewModels()
                case let .didUpdateWalletMultichain(wallet):
                    guard wallet == self.walletViewModel.wallet else { return }
                    self.refreshLoyaltyEntry(wallet: wallet)
                    self.reloadLoyalty(wallet: wallet)
                case let .didDeleteWallet(wallet):
                    self.discardWalletViewModel(id: wallet.id)
                case .didDeleteAll:
                    self.discardWalletViewModels()
                default:
                    break
                }
            }
        }
    }

    private func loadEarnVaults() {
        earnLoadTask?.cancel()
        earnLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let vaults = try await earnVaultsRepository.loadFeaturedVaults()
                guard !Task.isCancelled else { return }
                earnCards = earnCardMapper(vaults)
                hasEarnVaults = true
            } catch {
                guard !Task.isCancelled else { return }
                Log.w("failed to load earn vaults", extraInfo: ["error": "\(error)"])
            }
        }
    }

    func viewWillAppear() {
        isOnScreen = true
        activate(wallet: try? walletsStore.activeWallet)
        refreshLoyaltyEntry()
        reloadLoyalty()
        walletViewModel.didAppear()
        if !hasEarnVaults {
            loadEarnVaults()
        }
        showEarnTooltipIfNeeded()
        showPerpsTooltipIfNeeded()
    }

    func viewDidDisappear() {
        isOnScreen = false
        stopWatchingPerpsTooltipSource()
        walletViewModel.didDisappear()
    }

    func refresh() async {
        loadEarnVaults()
        reloadLoyalty()
        await walletViewModel.refresh()
    }

    func earnFeaturedDidAppear(walletId: String) {
        guard !earnCards.isEmpty, shownEarnFeaturedWalletIds.insert(walletId).inserted else { return }
        analyticsProvider.log(EarnEntryView(from: .earnFeatured, vaultsCount: earnCards.count))
    }

    func earnFeaturedDidDisappear(walletId: String) {
        shownEarnFeaturedWalletIds.remove(walletId)
    }

    func tapEarnCatalog() {
        onOpenEarn?(configuration.earnUrl)
    }

    func tapEarnCard(_ card: EarnCardViewData) {
        onOpenEarn?(configuration.earnUrl.appendingEarnVaultPath(network: card.network, vaultId: card.vaultId))
    }

    /// Only the vaults carousel, shown to a wallet without Earn positions, gives the tooltip its anchor.
    func setEarnTooltipAnchor(_ view: UIView) {
        guard earnTooltipSourceView !== view else { return }
        earnTooltipSourceView = view
        showEarnTooltipIfNeeded()
    }

    func setEarnSectionAnchor(_ view: UIView) {
        earnSectionView = view
    }

    func setPerpsTooltipAnchor(_ view: UIView) {
        if perpsTooltipSourceView !== view {
            perpsTooltipSourceView = view
            stopWatchingPerpsTooltipSource()
        } else if !perpsTooltipObservations.isEmpty {
            return
        }
        showPerpsTooltipIfNeeded()
    }

    func tapRaffle(id: String) {
        analyticsProvider.log(RaffleBannerClick(source: .walletMain))
        onOpenRaffle?(id)
    }

    func tapLoyalty() {
        onOpenLoyalty?()
    }

    func raffleBannerDidAppear(id: String) {
        guard loggedRaffleBannerViewIds.insert(id).inserted else { return }
        analyticsProvider.log(RaffleBannerView(source: .walletMain))
    }

    private func showEarnTooltipIfNeeded() {
        guard isOnScreen, let earnTooltipSourceView else { return }
        tooltipsService.showTooltipIfNeeded(
            id: .earnSection,
            sourceView: earnTooltipSourceView,
            targetActionViews: [earnTooltipSourceView],
            configuration: Self.sectionTooltipConfiguration,
            onTargetAction: { [weak self] in
                self?.tapEarnCatalog()
            },
            onTooltipTap: { [weak self] in
                self?.earnSectionView?.scrollToTopOfVisibleArea(animated: true)
            }
        )
    }

    private func showPerpsTooltipIfNeeded() {
        guard isOnScreen, let perpsTooltipSourceView, tooltipsService.canShowTooltip(id: .perpsSection) else {
            stopWatchingPerpsTooltipSource()
            return
        }
        if perpsTooltipObservations.isEmpty, let scrollView = perpsTooltipSourceView.nearestEnclosingScrollView {
            perpsTooltipObservations = [
                scrollView.observe(\.contentOffset) { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.schedulePerpsTooltipCheck() }
                },
                scrollView.observe(\.contentSize) { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.schedulePerpsTooltipCheck() }
                },
            ]
        }
        schedulePerpsTooltipCheck()
    }

    private func schedulePerpsTooltipCheck() {
        perpsTooltipCheck?.cancel()
        perpsTooltipCheck = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Layout.perpsTooltipSettleDelay)
            guard !Task.isCancelled else { return }
            self?.requestPerpsTooltipIfSettled()
        }
    }

    private func requestPerpsTooltipIfSettled() {
        guard isOnScreen,
              let perpsTooltipSourceView,
              perpsTooltipSourceView.isWithinVisibleScrollArea,
              let scrollView = perpsTooltipSourceView.nearestEnclosingScrollView,
              !scrollView.isDragging,
              !scrollView.isDecelerating
        else { return }
        guard tooltipsService.canShowTooltip(id: .perpsSection) else {
            stopWatchingPerpsTooltipSource()
            return
        }
        var configuration = Self.sectionTooltipConfiguration
        configuration.requiresVisibleSource = true
        tooltipsService.showTooltipIfNeeded(
            id: .perpsSection,
            sourceView: perpsTooltipSourceView,
            targetActionViews: [perpsTooltipSourceView],
            configuration: configuration,
            onTargetAction: { [weak self] in
                self?.walletViewModel.perpsSectionViewModel?.openPerps()
            },
            onTooltipTap: nil
        )
    }

    private func stopWatchingPerpsTooltipSource() {
        perpsTooltipObservations = []
        perpsTooltipCheck?.cancel()
        perpsTooltipCheck = nil
    }

    private static let sectionTooltipConfiguration = HintConfiguration(
        position: HintPosition(
            tailParameters: TKTooltipView.tailParameters,
            horizontal: .default,
            vertical: .init(absolute: 0),
            direction: .topRight
        ),
        maximumWidth: Layout.sectionTooltipMaximumWidth,
        animationStyle: .bouncing
    )

    private func activate(wallet: Wallet?) {
        guard let wallet else { return }
        let viewModel = walletViewModel(for: wallet)
        guard viewModel !== walletViewModel else { return }

        walletViewModel.resignActive()
        walletViewModel = viewModel
        viewModel.becomeActive(isVisible: isOnScreen)
        refreshLoyaltyEntry()
        reloadLoyalty()
        didChangeWallet?()
    }

    private func refreshLoyaltyEntry() {
        refreshLoyaltyEntry(wallet: walletViewModel.wallet)
    }

    private func refreshLoyaltyEntry(wallet: Wallet) {
        let entry = loyaltyStore.entry(for: wallet)
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let row = entry.showsSection
            ? LoyaltyRow(
                isJoined: entry.isJoined,
                ohmsText: entry.ohms.map { isSecureMode ? .secureModeValueShort : TKLocales.Loyalty.ohms($0) }
            )
            : nil
        guard loyaltyRow != row else { return }
        loyaltyRow = row
    }

    private func reloadLoyalty() {
        reloadLoyalty(wallet: walletViewModel.wallet)
    }

    private func reloadLoyalty(wallet: Wallet) {
        Task { [loyaltyStore] in
            await loyaltyStore.reload(wallet: wallet)
        }
    }

    private func walletViewModel(for wallet: Wallet) -> MultichainWalletViewModel {
        if let viewModel = walletViewModels[wallet.id] {
            return viewModel
        }

        let viewModel = makeWalletViewModel(wallet)
        walletViewModels[wallet.id] = viewModel
        return viewModel
    }

    private func discardWalletViewModel(id: String) {
        guard let viewModel = walletViewModels.removeValue(forKey: id) else { return }
        guard viewModel !== walletViewModel else { return }
        viewModel.resignActive()
    }

    private func discardOrphanedWalletViewModels() {
        let walletIds = Set(walletsStore.wallets.map(\.id))
        for (id, viewModel) in walletViewModels where !walletIds.contains(id) {
            guard viewModel !== walletViewModel else { continue }
            walletViewModels[id] = nil
            viewModel.resignActive()
        }
    }

    private func discardWalletViewModels() {
        for viewModel in walletViewModels.values {
            viewModel.resignActive()
        }
        walletViewModels = [walletViewModel.wallet.id: walletViewModel]
    }
}

private extension MultichainWalletRootViewModel {
    enum Layout {
        static let sectionTooltipMaximumWidth: CGFloat = 280
        static let perpsTooltipSettleDelay: UInt64 = 300_000_000
    }
}
