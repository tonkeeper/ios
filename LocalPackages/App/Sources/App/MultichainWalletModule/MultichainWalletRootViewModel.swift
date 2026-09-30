import Combine
import Foundation
import KeeperCore
import TKCore

@MainActor
final class MultichainWalletRootViewModel: ObservableObject {
    @Published private(set) var walletViewModel: MultichainWalletViewModel
    @Published private(set) var rafflePresentation: MysteryRafflePresentation?

    var onOpenRaffle: (() -> Void)?

    var didChangeWallet: (() -> Void)?

    private let walletsStore: WalletsStore
    private let analyticsProvider: AnalyticsProvider
    private var raffleObserver: MysteryRafflePresentationObserver?

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
        makeWalletViewModel: @escaping (Wallet) -> MultichainWalletViewModel
    ) {
        self.walletsStore = walletsStore
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
