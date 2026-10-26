import AppUI
import Combine
import Foundation
import KeeperCore
import TKCore
import TKLogging

@MainActor
final class MultichainWalletRootViewModel: ObservableObject {
    @Published private(set) var walletViewModel: MultichainWalletViewModel
    @Published private(set) var rafflePresentation: MysteryRafflePresentation?
    @Published private(set) var earnCards = [EarnCardViewData]()

    var onOpenRaffle: (() -> Void)?
    var onOpenEarn: ((URL) -> Void)?

    var didChangeWallet: (() -> Void)?

    private let walletsStore: WalletsStore
    private let configuration: Configuration
    private let earnFeaturedVaultsRepository: EarnFeaturedVaultsRepository
    private let earnVaultsRepository: EarnVaultsRepository
    private let earnCardMapper: ([EarnVault]) -> [EarnCardViewData]
    private let analyticsProvider: AnalyticsProvider
    private var raffleObserver: MysteryRafflePresentationObserver?
    private var earnLoadTask: Task<Void, Never>?
    private var shownEarnFeaturedWalletIds = Set<String>()

    private let makeWalletViewModel: (Wallet) -> MultichainWalletViewModel
    private var walletViewModels = [String: MultichainWalletViewModel]()

    private var isOnScreen = false
    private var loggedRaffleBannerViewId: String?

    init(
        wallet: Wallet,
        walletsStore: WalletsStore,
        configuration: Configuration,
        raffleStore: RaffleStore,
        analyticsProvider: AnalyticsProvider,
        earnFeaturedVaultsRepository: EarnFeaturedVaultsRepository,
        earnVaultsRepository: EarnVaultsRepository,
        earnCardMapper: @escaping ([EarnVault]) -> [EarnCardViewData],
        makeWalletViewModel: @escaping (Wallet) -> MultichainWalletViewModel
    ) {
        self.earnFeaturedVaultsRepository = earnFeaturedVaultsRepository
        self.earnVaultsRepository = earnVaultsRepository
        self.earnCardMapper = earnCardMapper
        self.walletsStore = walletsStore
        self.configuration = configuration
        self.analyticsProvider = analyticsProvider
        self.makeWalletViewModel = makeWalletViewModel
        let walletViewModel = makeWalletViewModel(wallet)
        walletViewModels = [wallet.id: walletViewModel]
        self.walletViewModel = walletViewModel

        raffleObserver = MysteryRafflePresentationObserver(
            raffleStore: raffleStore
        ) { [weak self] presentation in
            self?.rafflePresentation = presentation
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

    func loadEarnVaults() {
        let featuredVaults = earnFeaturedVaultsRepository.featuredVaults()
        earnLoadTask?.cancel()
        earnLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let vaults = try await earnVaultsRepository.vaults(for: featuredVaults)
                guard !Task.isCancelled else { return }
                earnCards = earnCardMapper(vaults)
            } catch {
                guard !Task.isCancelled else { return }
                Log.w("failed to load earn vaults", extraInfo: ["error": "\(error)"])
            }
        }
    }

    func viewWillAppear() {
        isOnScreen = true
        activate(wallet: try? walletsStore.activeWallet)
        walletViewModel.didAppear()
    }

    func viewDidDisappear() {
        isOnScreen = false
        walletViewModel.didDisappear()
    }

    func refresh() async {
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

    func tapRaffle() {
        analyticsProvider.log(RaffleBannerClick(source: .walletMain))
        onOpenRaffle?()
    }

    func raffleBannerDidAppear() {
        guard let presentation = rafflePresentation, presentation.shouldShowMainScreenEntry else { return }
        guard loggedRaffleBannerViewId != presentation.raffle.id else { return }
        loggedRaffleBannerViewId = presentation.raffle.id
        analyticsProvider.log(RaffleBannerView(source: .walletMain))
    }

    private func activate(wallet: Wallet?) {
        guard let wallet else { return }
        let viewModel = walletViewModel(for: wallet)
        guard viewModel !== walletViewModel else { return }

        walletViewModel.resignActive()
        walletViewModel = viewModel
        viewModel.becomeActive(isVisible: isOnScreen)
        didChangeWallet?()
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
