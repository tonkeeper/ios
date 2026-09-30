import Foundation
@preconcurrency import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

@MainActor
protocol WalletsListModuleOutput: AnyObject {
    var addButtonEvent: (() -> Void)? { get set }
    var didSelectWallet: (() -> Void)? { get set }
    var didTapEditWallet: ((Wallet) -> Void)? { get set }
    var onOpenRaffle: (() -> Void)? { get set }
    var onOpenRaffleBanner: ((URL) -> Void)? { get set }
}

struct WalletsListRaffleBanner {
    enum Source {
        case raffle(MysteryRafflePresentation)
        case home(HomeBanner)
    }

    let source: Source
    let id: String
    let title: String
    let description: String
    let actionTitle: String
    let imageURL: URL?

    init?(presentation: MysteryRafflePresentation) {
        guard let banner = presentation.raffle.banner else { return nil }
        source = .raffle(presentation)
        id = presentation.raffle.id
        title = banner.title
        description = banner.button.title.isEmpty ? (banner.description ?? "") : banner.button.title
        actionTitle = banner.button.title
        imageURL = URL(string: banner.imageURL)
    }

    init(homeBanner: HomeBanner) {
        source = .home(homeBanner)
        id = homeBanner.id
        title = homeBanner.title
        description = homeBanner.description
        actionTitle = homeBanner.button?.title ?? ""
        imageURL = homeBanner.image
    }
}

@MainActor
protocol WalletsListViewModel: AnyObject {
    var didUpdateSnapshot: ((_ snapshot: WalletsListViewController.Snapshot) -> Void)? { get set }
    var didUpdateWaletCellConfiguration: ((_ item: WalletsListViewController.Item, _ configuration: TKListItemCell.Configuration) -> Void)? { get set }
    var selectedWalletIdentifier: String? { get }
    var didUpdateIsEditing: ((Bool) -> Void)? { get set }
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration) -> Void)? { get set }

    func viewDidLoad()
    func getWalletCellConfiguration(identifier: String) -> TKListItemCell.Configuration?
    func moveWallet(fromIndex: Int, toIndex: Int)
    func getRaffleBanner() -> WalletsListRaffleBanner?
    func raffleBannerDidAppear()
    func tapRaffleBanner()
    func dismissRaffleBanner()
    func didTapAddWallet()
}

@MainActor
final class WalletsListViewModelImplementation: WalletsListViewModel, WalletsListModuleOutput {
    // MARK: - WalletsListModuleOutput

    var addButtonEvent: (() -> Void)?
    var didSelectWallet: (() -> Void)?
    var didTapEditWallet: ((Wallet) -> Void)?
    var onOpenRaffle: (() -> Void)?
    var onOpenRaffleBanner: ((URL) -> Void)?

    // MARK: - WalletsListViewModel

    var didUpdateSnapshot: ((_ snapshot: WalletsListViewController.Snapshot) -> Void)?
    var didUpdateWaletCellConfiguration: ((WalletsListViewController.Item, TKListItemCell.Configuration) -> Void)?
    var didUpdateIsEditing: ((Bool) -> Void)?
    var didUpdateHeaderConfiguration: ((TKBottomSheetHeaderConfiguration) -> Void)?

    func viewDidLoad() {
        // The heaviest target there is — every wallet's full fan-out — behind a screen that renders
        // from the store and filters each wallet on its own freshness. It waits its turn.
        reloadAllWalletsBalance()
        didUpdateHeaderConfiguration?(createHeaderConfiguration())
        setupInitialState()
        startObservations()
    }

    func getWalletCellConfiguration(identifier: String) -> TKListItemCell.Configuration? {
        walletCellsConfigurations[identifier]
    }

    func moveWallet(fromIndex: Int, toIndex: Int) {
        self.model.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
    }

    func didTapAddWallet() {
        addButtonEvent?()
    }

    func getRaffleBanner() -> WalletsListRaffleBanner? {
        raffleBanner
    }

    func tapRaffleBanner() {
        guard let raffleBanner else { return }
        analyticsProvider?.log(RaffleBannerClick(source: .walletsList))
        switch raffleBanner.source {
        case .raffle:
            onOpenRaffle?()
        case let .home(banner):
            guard let button = banner.button else { return }
            switch button.type {
            case let .deeplink(url), let .link(url):
                onOpenRaffleBanner?(url)
            case .unknown:
                return
            }
        }
    }

    func dismissRaffleBanner() {
        guard let raffleBanner else { return }
        analyticsProvider?.log(RaffleBannerDismiss(source: .walletsList))
        switch raffleBanner.source {
        case let .raffle(presentation):
            presentation.walletsListBannerDismissed()
            refreshSnapshot()
        case let .home(banner):
            guard let walletId = try? walletsStore.activeWallet.id else { return }
            homeBannersStore.dismissBanner(id: banner.id, walletId: walletId)
        }
    }

    func raffleBannerDidAppear() {
        guard raffleBanner != nil else { return }
        analyticsProvider?.log(RaffleBannerView(source: .walletsList))
    }

    // MARK: - State

    private var walletCellsConfigurations = [String: TKListItemCell.Configuration]()
    private var isEditing = false {
        didSet {
            didUpdateIsEditing?(isEditing)
            didUpdateHeaderConfiguration?(createHeaderConfiguration())
        }
    }

    private var homeRaffleBanner: HomeBanner?
    private var rafflePresentation: MysteryRafflePresentation?
    private var raffleObserver: MysteryRafflePresentationObserver?

    private var raffleBanner: WalletsListRaffleBanner? {
        if let rafflePresentation, rafflePresentation.raffle.banner != nil {
            guard rafflePresentation.shouldShowWalletsListBanner else { return nil }
            return WalletsListRaffleBanner(presentation: rafflePresentation)
        }
        return homeRaffleBanner.map(WalletsListRaffleBanner.init(homeBanner:))
    }

    var selectedWalletIdentifier: String?

    // MARK: - Dependencies

    private let model: WalletsListModel
    private let balanceLoader: BalanceLoader
    private let totalBalancesStore: TotalBalanceStore
    private let multichainPortfolioStore: MultichainPortfolioStore
    private let currencyStore: CurrencyStore
    private let appSettingsStore: AppSettingsStore
    private let amountFormatter: AmountFormatter
    private let homeBannersStore: HomeBannersStore
    private let walletsStore: WalletsStore
    private let multichainFormatter = MultichainPortfolioAmountFormatting()
    private let analyticsProvider: AnalyticsProvider?

    // MARK: - Init

    init(
        model: WalletsListModel,
        balanceLoader: BalanceLoader,
        totalBalancesStore: TotalBalanceStore,
        multichainPortfolioStore: MultichainPortfolioStore,
        currencyStore: CurrencyStore,
        appSettingsStore: AppSettingsStore,
        amountFormatter: AmountFormatter,
        homeBannersStore: HomeBannersStore,
        walletsStore: WalletsStore,
        raffleStore: RaffleStore? = nil,
        analyticsProvider: AnalyticsProvider? = nil
    ) {
        self.model = model
        self.balanceLoader = balanceLoader
        self.totalBalancesStore = totalBalancesStore
        self.multichainPortfolioStore = multichainPortfolioStore
        self.currencyStore = currencyStore
        self.appSettingsStore = appSettingsStore
        self.amountFormatter = amountFormatter
        self.homeBannersStore = homeBannersStore
        self.walletsStore = walletsStore
        self.analyticsProvider = analyticsProvider

        raffleObserver = MysteryRafflePresentationObserver(
            raffleStore: raffleStore
        ) { [weak self] presentation in
            self?.rafflePresentation = presentation
            self?.refreshSnapshot()
        }

        homeBannersStore.addObserver(self) { [weak self] _, _ in
            self?.refreshRaffleBanner()
        } onRegistered: { [weak self] in
            self?.refreshRaffleBanner()
        }

        // The deck is answered per wallet, so the banner this list shows belongs to whichever
        // wallet is active — and that can change while the list is open.
        walletsStore.addObserver(self) { observer, event in
            switch event {
            case .didChangeActiveWallet, .didUpdateWalletMultichain:
                observer.refreshRaffleBanner()
            default:
                break
            }
        }
    }

    /// The heaviest request there is — every wallet at once — behind a screen that renders from the
    /// stores and filters each wallet on its own freshness. It waits its turn.
    private func reloadAllWalletsBalance() {
        Task { [balanceLoader] in
            await balanceLoader.reloadAllWalletsBalance(priority: .background)
        }
    }

    private func refreshRaffleBanner() {
        let banners = activeWalletBanners()
        Task { @MainActor in
            self.applyRaffleBanner(from: banners)
        }
    }

    private func activeWalletBanners() -> [HomeBanner] {
        guard let wallet = try? walletsStore.activeWallet else { return [] }
        return homeBannersStore.visibleBanners(for: wallet)
    }
}

extension HomeBanner {
    var isMysteryRaffleBanner: Bool {
        id.hasPrefix("mystery_raffle")
    }
}

private extension WalletsListViewModelImplementation {
    func setupInitialState() {
        refreshSnapshot()
    }

    func refreshSnapshot() {
        let state = model.getState()
        let totalBalanceState = totalBalancesStore.getState()
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let (snapshot, cellConfigurations) = updateList(wallets: state.wallets, totalBalanceState: totalBalanceState, isSecureMode: isSecureMode)
        self.walletCellsConfigurations = cellConfigurations
        self.selectedWalletIdentifier = state.selectedWalletIdentifier
        self.didUpdateSnapshot?(snapshot)
    }

    func startObservations() {
        model.didUpdateState = { [weak self] walletsState in
            self?.didUpdateWalletsState(walletsState: walletsState)
        }
        totalBalancesStore.addObserver(self) { observer, event in
            DispatchQueue.main.async {
                observer.didGetTotalBalanceStoreEvent(event)
            }
        }
        multichainPortfolioStore.addObserver(self) { observer, event in
            DispatchQueue.main.async {
                observer.didGetMultichainPortfolioStoreEvent(event)
            }
        }
        appSettingsStore.addObserver(self) { observer, event in
            guard case .didUpdateBalanceFilter = event else { return }
            Task { @MainActor in
                observer.reloadAllWalletsBalance()
            }
        }
    }

    private func updateList(
        wallets: [Wallet],
        totalBalanceState: TotalBalanceStore.State,
        isSecureMode: Bool
    ) -> (WalletsListViewController.Snapshot, [String: TKListItemCell.Configuration]) {
        var snapshot = WalletsListViewController.Snapshot()

        if let raffleBanner {
            let raffleSection = WalletsListSection.raffleBanner(raffleId: raffleBanner.id)
            snapshot.appendSections([raffleSection])
            snapshot.appendItems([.raffleBannerItem(raffleId: raffleBanner.id)], toSection: raffleSection)
        }

        var cellConfigurations = [String: TKListItemCell.Configuration]()
        var items = [WalletsListItem]()
        let portfolioState = multichainPortfolioStore.getState()
        for wallet in wallets {
            let cellConfiguration = createWalletCellConfiguration(
                wallet: wallet,
                totalBalanceState: totalBalanceState[wallet],
                portfolioTotal: portfolioState[wallet],
                isSecure: isSecureMode
            )
            cellConfigurations[wallet.id] = cellConfiguration
            items.append(createItem(wallet: wallet))
        }

        let footerConfiguration = TKListCollectionViewButtonFooterView.Configuration(
            identifier: .walletsFooterIdentifier,
            content: TKButton.Configuration.Content(title: .plainString(TKLocales.AddWallet.title)),
            action: { [weak self] in
                self?.addButtonEvent?()
            }
        )
        let section = WalletsListSection.wallets(footerConfiguration: footerConfiguration)
        snapshot.appendSections([section])
        snapshot.appendItems(items, toSection: section)

        if #available(iOS 15.0, *) {
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        } else {
            snapshot.reloadItems(snapshot.itemIdentifiers)
        }

        return (snapshot, cellConfigurations)
    }

    func applyRaffleBanner(from banners: [HomeBanner]) {
        homeRaffleBanner = banners.first(where: \.isMysteryRaffleBanner)
        refreshSnapshot()
    }

    private func createItem(wallet: Wallet) -> WalletsListItem {
        WalletsListItem(
            identifier: wallet.id,
            accessories: [],
            selectAccessories: [
                TKListItemAccessory.icon(
                    TKListItemIconAccessoryView.Configuration(
                        icon: .TKUIKit.Icons.Size28.donemarkOutline,
                        tintColor: .Accent.blue
                    )
                ),
            ],
            editingAccessories: [
                TKListItemAccessory.icon(
                    TKListItemIconAccessoryView.Configuration(
                        icon: .TKUIKit.Icons.Size28.pencilOutline,
                        tintColor: .Icon.tertiary,
                        action: {
                            [weak self] in
                            self?.didTapEditWallet?(
                                wallet
                            )
                        }
                    )
                ),
            ]
        ) { [weak self] in
            self?.model.selectWallet(wallet: wallet)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            self?.didSelectWallet?()
        }
    }

    private func createWalletCellConfiguration(
        wallet: Wallet,
        totalBalanceState: TotalBalanceState?,
        portfolioTotal: MultichainPortfolio?,
        isSecure: Bool
    ) -> TKListItemCell.Configuration {
        let titleViewConfiguration = TKListItemTitleView.Configuration(
            title: wallet.label,
            tags: walletListTagConfigurations(wallet: wallet)
        )

        let caption: String
        if isSecure {
            caption = .secureModeValueShort
        } else if wallet.isMultichain {
            if let portfolioTotal,
               let total = multichainFormatter.portfolioFiatTotalAndCurrency(
                   from: portfolioTotal.fiatPrice,
                   displayCurrency: currencyStore.getState()
               )
            {
                caption = amountFormatter.format(
                    decimal: total.amount,
                    accessory: .fiat(total.currency),
                    style: .fiatBalance
                )
            } else {
                // Space keeps the caption line height while the total loads.
                caption = " "
            }
        } else if let totalBalance = totalBalanceState?.totalBalance {
            caption = amountFormatter.format(
                decimal: totalBalance.amount,
                accessory: .fiat(totalBalance.currency),
                style: .fiatBalance
            )
        } else {
            caption = "---"
        }

        var captionViewsConfigurations = [TKListItemTextView.Configuration]()
        captionViewsConfigurations.append(TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2))

        let iconContent: TKListItemIconView.Configuration.Content
        switch wallet.icon {
        case let .emoji(emoji):
            iconContent = .text(TKListItemIconView.Configuration.TextContent(text: emoji))
        case let .icon(image):
            iconContent = .image(TKImageView.Model(image: .image(image.image), tintColor: .white, size: .size(CGSize(width: 22, height: 22))))
        }

        return TKListItemCell.Configuration(
            listItemContentViewConfiguration: TKListItemContentView.Configuration(
                iconViewConfiguration: TKListItemIconView.Configuration(
                    content: iconContent,
                    alignment: .center,
                    cornerRadius: 22,
                    backgroundColor: wallet.tintColor.uiColor,
                    size: CGSize(width: 44, height: 44)
                ),
                textContentViewConfiguration: TKListItemTextContentView.Configuration(
                    titleViewConfiguration: titleViewConfiguration,
                    captionViewsConfigurations: captionViewsConfigurations
                )
            )
        )
    }

    func walletListTagConfigurations(wallet: Wallet) -> [TKTagView.Configuration] {
        guard wallet.isMultichain else {
            return wallet.listTagConfigurations()
        }

        var tags = [WalletMultichainPresentation.badgeTagConfiguration]
        if case .watchonly = wallet.kind,
           let watchOnlyTag = wallet.listTagConfiguration()
        {
            tags.append(watchOnlyTag)
        }
        return tags
    }

    func didUpdateWalletsState(walletsState: WalletsListModelState) {
        reloadAllWalletsBalance()
        let totalBalancesState = totalBalancesStore.getState()
        let isSecureMode = appSettingsStore.getState().isSecureMode
        let (snapshot, cellConfigurations) = updateList(wallets: walletsState.wallets, totalBalanceState: totalBalancesState, isSecureMode: isSecureMode)
        selectedWalletIdentifier = walletsState.selectedWalletIdentifier
        walletCellsConfigurations = cellConfigurations
        didUpdateSnapshot?(snapshot)
    }

    func didGetTotalBalanceStoreEvent(_ event: TotalBalanceStore.Event) {
        switch event {
        case let .didUpdateTotalBalance(wallet):
            guard let wallet = model.getWallet(id: wallet.id) else { return }
            refreshWalletCellConfiguration(wallet: wallet)
        }
    }

    func didGetMultichainPortfolioStoreEvent(_ event: MultichainPortfolioStore.Event) {
        switch event {
        case let .didUpdatePortfolio(wallet):
            let wallets = model.getState().wallets
            guard let wallet = wallets.first(where: { $0.id == wallet.id }) else { return }
            refreshWalletCellConfiguration(wallet: wallet)
        }
    }

    func refreshWalletCellConfiguration(wallet: Wallet) {
        let totalBalanceState = totalBalancesStore.getState()[wallet]
        let portfolioTotal = multichainPortfolioStore.getState()[wallet]
        let isSecure = appSettingsStore.getState().isSecureMode
        let cellConfiguration = createWalletCellConfiguration(
            wallet: wallet,
            totalBalanceState: totalBalanceState,
            portfolioTotal: portfolioTotal,
            isSecure: isSecure
        )
        let item = createItem(wallet: wallet)
        walletCellsConfigurations[wallet.id] = cellConfiguration
        didUpdateWaletCellConfiguration?(item, cellConfiguration)
    }

    func createHeaderConfiguration() -> TKBottomSheetHeaderConfiguration {
        var leftButton: TKBottomSheetHeaderConfiguration.Button?
        if model.isEditable {
            leftButton = .init(
                content: .titleIcon(
                    title: isEditing ? TKLocales.Actions.done : TKLocales.Actions.edit
                ),
                action: { [weak self] _ in
                    self?.isEditing.toggle()
                }
            )
        }

        return TKBottomSheetHeaderConfiguration(
            title: .title(
                title: TKLocales.WalletsList.title,
                alignment: .center
            ),
            leftButton: leftButton
        )
    }
}

private extension String {
    static let walletsFooterIdentifier = "WalletsFooterIdentifier"
}
