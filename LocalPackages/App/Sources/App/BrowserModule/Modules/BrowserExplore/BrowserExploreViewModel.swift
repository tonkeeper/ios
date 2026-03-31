import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

@MainActor
protocol BrowserExploreModuleInput: AnyObject {
    var isExploreTabVisible: Bool { get }
}

@MainActor
protocol BrowserExploreModuleOutput: AnyObject {
    var didSelectCategory: ((PopularAppsCategory) -> Void)? { get set }
    var didSelectDapp: ((Dapp) -> Void)? { get set }
    var didOpenDeeplink: ((Deeplink) -> Void)? { get set }
    var didUpdateExploreTabVisible: ((Bool) -> Void)? { get set }
}

@MainActor
protocol BrowserExploreViewModel: AnyObject {
    var didUpdateSnapshot: ((BrowserExplore.Snapshot) -> Void)? { get set }
    var didUpdateFeaturedItems: (([PopularApp]) -> Void)? { get set }
    var didUpdateIsRefreshEnable: ((_ isEnable: Bool) -> Void)? { get set }

    func viewDidLoad()
    func selectFeaturedApp(dapp: Dapp)
    func reload()
}

@MainActor
final class BrowserExploreViewModelImplementation: BrowserExploreViewModel, BrowserExploreModuleInput, BrowserExploreModuleOutput {
    // MARK: - State

    private enum State {
        case empty
        case loading
        case content(popularAppsData: PopularAppsResponseData)
    }

    // MARK: - BrowserExploreModuleInput

    var isExploreTabVisible: Bool {
        let network: Network = (try? walletStore.activeWallet)?.network ?? .mainnet
        let dappsDisabled = configuration.flag(\.dappsDisabled, network: network)
        if dappsDisabled { return false }
        if case .empty = state { return false }
        return true
    }

    // MARK: - BrowserExploreModuleOutput

    var didSelectCategory: ((PopularAppsCategory) -> Void)?
    var didSelectDapp: ((Dapp) -> Void)?
    var didOpenDeeplink: ((Deeplink) -> Void)?
    var didUpdateExploreTabVisible: ((Bool) -> Void)?

    // MARK: - BrowserExploreViewModel

    var didUpdateSnapshot: ((BrowserExplore.Snapshot) -> Void)?
    var didUpdateFeaturedItems: (([PopularApp]) -> Void)?
    var didUpdateIsRefreshEnable: ((_ isEnable: Bool) -> Void)?

    private var selectedCountry: SelectedCountry = .auto

    func selectFeaturedApp(dapp: Dapp) {
        didSelectDapp?(dapp)
        analyticsProvider.logClickDappEvent(
            name: dapp.name,
            url: dapp.url.absoluteString,
            from: .banner
        )
    }

    // MARK: - State

    private var state: State = .empty {
        didSet {
            didUpdateState()
        }
    }

    private var loadingTask: Task<Void, Never>?

    private var categories = [PopularAppsCategory]()
    private var featuredCategory: PopularAppsCategory?

    // MARK: - Dependencies

    private let browserExploreController: BrowserExploreController
    private let walletStore: WalletsStore
    private let regionStore: RegionStore
    private let analyticsProvider: AnalyticsProvider
    private let configuration: Configuration

    // MARK: - Init

    init(
        browserExploreController: BrowserExploreController,
        walletStore: WalletsStore,
        regionStore: RegionStore,
        analyticsProvider: AnalyticsProvider,
        configuration: Configuration
    ) {
        self.browserExploreController = browserExploreController
        self.walletStore = walletStore
        self.regionStore = regionStore
        self.analyticsProvider = analyticsProvider
        self.configuration = configuration
    }

    func viewDidLoad() {
        regionStore.addObserver(self) { observer, event in
            switch event {
            case let .didUpdateRegion(country):
                DispatchQueue.main.async {
                    guard observer.selectedCountry != country else { return }

                    observer.selectedCountry = country
                    observer.didUpdateRegion()
                }
            }
        }

        configuration.addUpdateObserver(self) { observer in
            DispatchQueue.main.async {
                observer.didUpdateDappFeatureFlag()
            }
        }

        selectedCountry = regionStore.getState()

        let network: Network = (try? self.walletStore.activeWallet)?.network ?? .mainnet
        let isDappDisable = configuration.flag(\.dappsDisabled, network: network)
        didUpdateIsRefreshEnable?(!isDappDisable)
        if isDappDisable {
            state = .empty
        } else {
            if let cached = getCachedPopularApps() {
                state = .content(popularAppsData: cached)
            } else {
                state = .loading
            }
        }

        if !isDappDisable {
            loadPopularApps()
        }
    }

    func reload() {
        loadPopularApps()
    }

    private func loadPopularApps() {
        if let loadingTask {
            loadingTask.cancel()
        }

        let loadingTask = Task { [weak self] in
            guard let self else { return }
            let lang = Locale.current.languageCode ?? "en"
            do {
                let loaded = try await browserExploreController.loadPopularApps(lang: lang)
                try Task.checkCancellation()
                self.state = .content(popularAppsData: loaded)
            } catch {
                guard !error.isCancelledError else { return }
                self.state = .empty
            }
        }
        self.loadingTask = loadingTask
    }

    private func getCachedPopularApps() -> PopularAppsResponseData? {
        let lang = Locale.current.languageCode ?? "en"
        return try? browserExploreController.getCachedPopularApps(lang: lang)
    }
}

private extension BrowserExploreViewModelImplementation {
    func didUpdateRegion() {
        didUpdateState()
    }

    func didUpdateDappFeatureFlag() {
        didUpdateState()
    }

    func didUpdateState() {
        didUpdateExploreTabVisible?(isExploreTabVisible)
        if case let .content(popularAppsData) = state {
            showContent(content: popularAppsData)
        }
    }

    func showContent(content: PopularAppsResponseData) {
        guard !content.categories.isEmpty else {
            state = .empty
            return
        }

        var snapshot = BrowserExplore.Snapshot()

        var featuredCategory: PopularAppsCategory?
        var adsCategory: PopularAppsCategory?
        var categories = [PopularAppsCategory]()

        for category in content.categories {
            if category.id == "featured" {
                featuredCategory = category
            } else if category.id == "ads" {
                adsCategory = category
            } else {
                categories.append(category)
            }
        }

        let filter = composeCountryFilter()

        var featuredItems = [PopularApp]()
        if let featuredCategory {
            let filteredFeaturedItems = featuredCategory.apps.filter {
                if let filter, isDappContainsCountriesFilter(filter, app: $0) {
                    return false
                } else {
                    return true
                }
            }
            featuredItems = filteredFeaturedItems
            if !featuredItems.isEmpty {
                snapshot.appendSections([.featured])
                snapshot.appendItems([.featured], toSection: .featured)
            }
        }

        if let adsCategory {
            let filteredItems = adsCategory.apps.filter {
                if let filter, isDappContainsCountriesFilter(filter, app: $0) {
                    return false
                }
                return true
            }
            if !filteredItems.isEmpty {
                let items: [BrowserExplore.Item] = filteredItems.map { item in
                    let configuration = TKListItemCell.Configuration(
                        listItemContentViewConfiguration: TKListItemContentView.Configuration(
                            iconViewConfiguration: TKListItemIconView.Configuration(
                                content: .image(
                                    TKImageView.Model(
                                        image: .urlImage(item.icon),
                                        size: .size(CGSize(width: 44, height: 44)),
                                        corners: .cornerRadius(cornerRadius: 12)
                                    )
                                ),
                                alignment: .center,
                                cornerRadius: 12,
                                backgroundColor: .clear,
                                size: CGSize(width: 44, height: 44)
                            ),
                            textContentViewConfiguration: TKListItemTextContentView.Configuration(
                                titleViewConfiguration: TKListItemTitleView.Configuration(title: item.name),
                                captionViewsConfigurations: [
                                    TKListItemTextView.Configuration(text: item.description, color: .Text.secondary, textStyle: .body2),
                                ]
                            )
                        )
                    )

                    let buttonAccessory: TKListItemButtonAccessoryView.Configuration? = {
                        guard let button = item.button else { return nil }
                        return TKListItemButtonAccessoryView.Configuration(
                            title: button.title,
                            category: .tertiary
                        ) { [weak self] in
                            switch button.type {
                            case let .deeplink(url):
                                do {
                                    let deeplink = try DeeplinkParser().parse(string: url.absoluteString)
                                    self?.didOpenDeeplink?(deeplink)
                                } catch {
                                    break
                                }
                            default: break
                            }
                        }
                    }()

                    return .ads(BrowserExplore.AdsItem(
                        identifier: UUID().uuidString,
                        configuration: configuration,
                        buttonAccessory: buttonAccessory
                    ))
                }
                snapshot.appendSections([.ads])
                snapshot.appendItems(items, toSection: .ads)
            }
        }

        let filterValue = composeCountryFilter()
        for category in categories {
            let (section, items) = mapCategory(category, filterValue: filterValue)
            snapshot.appendSections([section])
            snapshot.appendItems(items, toSection: section)
        }

        didUpdateFeaturedItems?(featuredItems)
        didUpdateSnapshot?(snapshot)
    }

    func composeCountryFilter() -> String? {
        switch selectedCountry {
        case .auto: Locale.current.regionCode ?? ""
        case .all: nil
        case let .country(countryCode): countryCode
        }
    }

    func isDappContainsCountriesFilter(_ filter: String, app: PopularApp) -> Bool {
        if let excludeCountries = app.excludeCountries,
           excludeCountries.contains(where: { $0 == filter })
        {
            return true
        }

        if let includeCountries = app.includeCountries,
           !includeCountries.contains(where: { $0 == filter })
        {
            return true
        }

        return false
    }

    func mapCategory(_ category: PopularAppsCategory, filterValue: String?) -> (section: BrowserExplore.Section, items: [BrowserExplore.Item]) {
        let isTwoLinesTitle = category.id == Constants.digitalNomadsCategoryId
        var items: [BrowserExplore.Item] = []
        let chunks = category.apps.chunked(into: Constants.chunkSize).prefix(Constants.maxRows)
        for (index, chunk) in chunks.enumerated() where index == 0 || chunk.count > Constants.minAppsInSecondChunk {
            items.append(contentsOf: chunk.compactMap { app in
                if let filterValue, isDappContainsCountriesFilter(filterValue, app: app) {
                    return nil
                }

                return .app(.init(
                    id: UUID().uuidString,
                    configuration: mapApp(app, isTwoLinesTitle: isTwoLinesTitle),
                    selectionHandler: { [weak self] in
                        guard let dapp = Dapp(popularApp: app) else { return }

                        self?.analyticsProvider.logClickDappEvent(
                            name: dapp.name,
                            url: dapp.url.absoluteString,
                            from: .browser
                        )
                        self?.didSelectDapp?(dapp)
                    },
                    longPressHandler: {}
                ))
            })
        }

        let header: BrowserExplore.AppsSectionHeader? = {
            if isTwoLinesTitle {
                return nil
            } else {
                return BrowserExplore.AppsSectionHeader(
                    title: category.title ?? "",
                    hasAll: category.apps.count > Constants.chunkSize,
                    allTapHandler: { [weak self] in
                        self?.didSelectCategory?(category)
                    }
                )
            }
        }()

        let section = BrowserExplore.Section.apps(
            id: category.id,
            header: header,
            twoLinesAppsTitle: isTwoLinesTitle
        )

        return (section: section, items: items)
    }

    func mapApp(_ app: PopularApp, isTwoLinesTitle: Bool) -> BrowserAppCollectionViewCell.Configuration {
        BrowserAppCollectionViewCell.Configuration(
            id: app.id,
            title: app.name,
            isTwoLinesTitle: isTwoLinesTitle,
            iconModel: TKImageView.Model(
                image: .urlImage(app.icon),
                size: .size(CGSize(width: 64, height: 64)),
                corners: .cornerRadius(cornerRadius: 16)
            )
        )
    }

    // MARK: - Constants

    private enum Constants {
        static let digitalNomadsCategoryId = "digital_nomads"
        static let chunkSize = 4
        static let minAppsInSecondChunk = 2
        static let maxRows = 2
    }
}
