import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

@MainActor
protocol BuySellListModuleOutput: AnyObject {
    var didSelectURL: ((URL) -> Void)? { get set }
    var didSelectItem: ((BuySellItem, _ openClosure: @escaping () -> Void) -> Void)? { get set }
}

@MainActor
protocol BuySellListModuleInput: AnyObject {}

@MainActor
protocol BuySellListViewModel: AnyObject {
    var didUpdateSegmentedControl: ((BuySellListSegmentedControl.Model?) -> Void)? { get set }
    var didUpdateState: ((BuySellListViewController.State) -> Void)? { get set }
    var didUpdateSnapshot: ((BuySellList.Snapshot) -> Void)? { get set }
    var didUpdateHeaderLeftButton: ((TKPullCardHeaderItem.LeftButton) -> Void)? { get set }

    func viewDidLoad()
    func selectTab(index: Int)
}

@MainActor
final class BuySellListViewModelImplementation: BuySellListViewModel, BuySellListModuleOutput, BuySellListModuleInput {
    enum Tab: CaseIterable {
        case buy
        case sell
    }

    enum SectionExpandState {
        case collapsed
        case expanded
    }

    var didSelectURL: ((URL) -> Void)?
    var didSelectItem: ((BuySellItem, _ openClosure: @escaping () -> Void) -> Void)?

    // MARK: - BuySellListViewModel

    var didUpdateSegmentedControl: ((BuySellListSegmentedControl.Model?) -> Void)?
    var didUpdateState: ((BuySellListViewController.State) -> Void)?
    var didUpdateSnapshot: ((BuySellList.Snapshot) -> Void)?
    var didUpdateHeaderLeftButton: ((TKPullCardHeaderItem.LeftButton) -> Void)?

    func viewDidLoad() {
        buySellProvider.addUpdateObserver(self) { observer in
            DispatchQueue.main.async {
                observer.buySellProviderState = observer.buySellProvider.state
            }
        }
        buySellProviderState = buySellProvider.state
        buySellProvider.load()
    }

    func selectTab(index: Int) {
        let allTabs = Tab.allCases
        guard index < allTabs.count else { return }
        activeTab = allTabs[index]
    }

    // MARK: - State

    private var snapshot = BuySellList.Snapshot() {
        didSet {
            self.didUpdateSnapshot?(snapshot)
        }
    }

    private var buySellProviderState: BuySellProvider.State = .none {
        didSet {
            if case .fiatMethods = oldValue,
               case .loading = buySellProviderState
            {
                return
            }
            didUpdateBuySellProviderState(buySellProviderState)
        }
    }

    private var fiatMethods: FiatMethods?
    private var activeTab: Tab = .buy {
        didSet {
            didChangeTab()
        }
    }

    private var categoryExpandStates = [FiatMethodCategory: SectionExpandState]()

    // MARK: - Image Loader

    private let imageLoader = ImageLoader()

    // MARK: - Dependencies

    private let wallet: Wallet
    private let buySellProvider: BuySellProvider
    private let walletsStore: WalletsStore
    private let currencyStore: CurrencyStore
    private let configuration: Configuration
    private let regionStore: RegionStore
    private let appSettings: AppSettings
    private let analyticsProvider: AnalyticsProvider
    private let tonkeeperAPI: TonkeeperAPI

    // MARK: - Init

    init(
        wallet: Wallet,
        buySellProvider: BuySellProvider,
        walletsStore: WalletsStore,
        currencyStore: CurrencyStore,
        regionStore: RegionStore,
        configuration: Configuration,
        appSettings: AppSettings,
        analyticsProvider: AnalyticsProvider,
        tonkeeperAPI: TonkeeperAPI
    ) {
        self.wallet = wallet
        self.buySellProvider = buySellProvider
        self.walletsStore = walletsStore
        self.currencyStore = currencyStore
        self.regionStore = regionStore
        self.configuration = configuration
        self.appSettings = appSettings
        self.analyticsProvider = analyticsProvider
        self.tonkeeperAPI = tonkeeperAPI
    }
}

private extension BuySellListViewModelImplementation {
    func didChangeTab() {
        switch buySellProviderState {
        case .loading:
            break
        case .none:
            updateList(fiatMethods: nil)
        case let .fiatMethods(fiatMethods):
            updateList(fiatMethods: fiatMethods)
        }
    }

    func didUpdateBuySellProviderState(_ state: BuySellProvider.State) {
        categoryExpandStates = [:]
        switch state {
        case .loading:
            didUpdateState?(.loading)
            didUpdateSegmentedControl?(nil)
            fiatMethods = nil
        case .none:
            didUpdateSegmentedControl?(
                BuySellListSegmentedControl.Model(
                    tabs: [TKLocales.BuySellList.buy, TKLocales.BuySellList.sell]
                )
            )
            fiatMethods = nil
            didUpdateState?(.list)
        case let .fiatMethods(fiatMethods):
            self.fiatMethods = fiatMethods
            didUpdateSegmentedControl?(
                BuySellListSegmentedControl.Model(
                    tabs: [TKLocales.BuySellList.buy, TKLocales.BuySellList.sell]
                )
            )
            didUpdateState?(.list)
        }
        updateList(fiatMethods: fiatMethods)
    }

    func updateList(fiatMethods: FiatMethods?) {
        updateSnapshot(fiatMethods: fiatMethods)
    }

    func updateSnapshot(fiatMethods: FiatMethods?) {
        var snapshot = BuySellList.Snapshot()

        defer {
            self.snapshot = snapshot
        }

        guard let fiatMethods else {
            return
        }

        let categories: [FiatMethodCategory]
        let sectionType: Section
        switch activeTab {
        case .buy:
            categories = fiatMethods.buy
            sectionType = .buy
        case .sell:
            categories = fiatMethods.sell
            sectionType = .sell
        }

        for category in categories {
            let assets = category.assets.map { UIImage(named: "Images/CryptoAssets/\($0)") }
            let section = BuySellList.SnapshotSection.items(
                id: category.hashValue,
                title: category.title,
                assets: assets
            )

            let expandedState: SectionExpandState? = categoryExpandStates[category] ?? (category.items.count > 4 ? .collapsed : nil)
            categoryExpandStates[category] = expandedState

            let resultItems: [FiatMethodItem]
            switch expandedState {
            case .expanded, .none:
                resultItems = category.items
            case .collapsed:
                resultItems = Array(category.items.prefix(4))
            }

            guard !resultItems.isEmpty else { continue }
            snapshot.appendSections([section])
            snapshot.appendItems(
                resultItems.map { .item(mapBuySellItem(
                    $0,
                    category: category,
                    section: sectionType
                )) },
                toSection: section
            )

            switch expandedState {
            case .collapsed:
                var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
                    category: .secondary,
                    size: .small
                )
                buttonConfiguration.action = { [weak self] in
                    self?.expandCategory(category)
                }
                buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.List.showAll))
                let buttonItem = BuySellList.SnapshotItem.button(
                    TKButtonCell.Model(
                        id: UUID().uuidString,
                        configuration: buttonConfiguration,
                        padding: UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0),
                        mode: .widthToFit
                    )
                )
                buttonConfiguration.isEnabled = true
                snapshot.appendSections([.button(id: category.hashValue)])
                snapshot.appendItems([buttonItem], toSection: .button(id: category.hashValue))

            case .expanded:
                var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
                    category: .secondary,
                    size: .small
                )
                buttonConfiguration.action = { [weak self] in
                    self?.collapseCategory(category)
                }
                buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString(TKLocales.List.hide))
                let buttonItem = BuySellList.SnapshotItem.button(
                    TKButtonCell.Model(
                        id: UUID().uuidString,
                        configuration: buttonConfiguration,
                        padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 0),
                        mode: .widthToFit
                    )
                )
                snapshot.appendSections([.button(id: category.hashValue)])
                snapshot.appendItems([buttonItem], toSection: .button(id: category.hashValue))

            case .none:
                break
            }
        }

        snapshot.reloadItems(snapshot.itemIdentifiers)
    }

    func expandCategory(_ category: FiatMethodCategory) {
        categoryExpandStates[category] = .expanded
        updateSnapshot(fiatMethods: fiatMethods)
    }

    func collapseCategory(_ category: FiatMethodCategory) {
        categoryExpandStates[category] = .collapsed
        updateSnapshot(fiatMethods: fiatMethods)
    }

    enum Section: String {
        case buy
        case sell
    }

    func mapBuySellItem(
        _ item: FiatMethodItem,
        category: FiatMethodCategory,
        section: Section
    ) -> BuySellList.Item {
        let configuration = BuySellList.mapListItemConfiguration(item: item)

        return BuySellList.Item(
            identifier: item.id,
            configuration: configuration,
            selectionHandler: {
                [weak self] in
                guard let self else { return }

                Task {
                    do {
                        let currency = self.currencyStore.state
                        let walletAddress = try self.wallet.friendlyAddress
                        let mercuryoSecret = await self.configuration.mercuryoSecret
                        guard let url = await item.actionURL(
                            walletAddress: walletAddress,
                            tronAddress: self.wallet.tron?.address,
                            currency: currency,
                            mercuryoParameters: FiatMethodItem.MercuryoParameters(
                                secret: mercuryoSecret,
                                ipProvider: { [weak self] in try? await self?.tonkeeperAPI.getIP() }
                            )
                        ) else { return }
                        await MainActor.run {
                            if self.appSettings.isBuySellItemMarkedDoNotShowWarning(item.id) {
                                self.didSelectURL?(url)
                                self.logOnrampSelectAnalyticsEvent(
                                    item: item,
                                    category: category,
                                    section: section,
                                    url: url
                                )
                            } else {
                                let buySellItem = BuySellItem(fiatItem: item, actionUrl: url)
                                self.didSelectItem?(
                                    buySellItem
                                ) { [weak self] in
                                    self?.logOnrampSelectAnalyticsEvent(
                                        item: item,
                                        category: category,
                                        section: section,
                                        url: url
                                    )
                                }
                            }
                        }
                    } catch {
                        return
                    }
                }
            }
        )
    }

    func logOnrampSelectAnalyticsEvent(
        item: FiatMethodItem,
        category: FiatMethodCategory,
        section: Section,
        url: URL
    ) {
        let placement = {
            if category.type != "swap", !category.type.contains("_") {
                category.type + "_ton"
            } else {
                category.type
            }
        }()

        let location = {
            switch regionStore.getState() {
            case let .country(countryCode):
                return countryCode.lowercased()
            case .all:
                return "null"
            case .auto:
                return Locale.current.regionCode?.lowercased() ?? "null"
            }
        }()

        analyticsProvider.log(
            eventKey: .onrampClick,
            args: [
                "type": section.rawValue,
                "placement": placement,
                "location": location,
                "name": item.title,
                "url": url.absoluteString,
            ]
        )
    }
}
