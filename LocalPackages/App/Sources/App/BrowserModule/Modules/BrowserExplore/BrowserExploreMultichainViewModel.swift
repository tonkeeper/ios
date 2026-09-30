import Combine
import KeeperCore
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import UIKit

enum BrowserExploreNetworkFilter: Hashable {
    case all
    case chain(MultichainChain)
}

struct BrowserExploreContent {
    var featuredApps: [PopularApp]
    var ads: [BrowserExploreAdItem]
    var sections: [BrowserExploreAppsSection]
}

struct BrowserExploreAppsSection: Identifiable {
    enum Placement {
        case beforeNetworkTabs
        case afterNetworkTabs
    }

    var id: String
    var category: PopularAppsCategory
    var placement: Placement
    var title: String?
    var hasAll: Bool
    var apps: [BrowserExploreAppItem]
}

struct BrowserExploreAppItem: Identifiable {
    var id: String
    var app: PopularApp
    var isTwoLinesTitle: Bool
    var chains: [MultichainChain]
}

struct BrowserExploreAdItem: Identifiable {
    var id: String
    var app: PopularApp
}

@MainActor
final class BrowserExploreMultichainViewModelImplementation: ObservableObject, BrowserExploreModuleInput, BrowserExploreModuleOutput {
    enum ViewState {
        case empty
        case loading
        case content(BrowserExploreContent)
    }

    // MARK: - BrowserExploreModuleInput

    var isExploreTabVisible: Bool {
        if isDappsDisabled {
            return false
        }
        if case .empty = state {
            return false
        }
        return true
    }

    var canShowExploreTab: Bool {
        !isDappsDisabled
    }

    var showsNetworkBadges: Bool {
        (try? walletStore.activeWallet)?.isMultichain ?? false
    }

    func selectNetworkFilter(_ chain: MultichainChain) {
        pendingNetworkChain = chain
        applyPendingNetworkFilter()
    }

    func selectNetworkFilter(_ filter: BrowserExploreNetworkFilter) {
        pendingNetworkChain = nil
        selectedNetworkFilter = filter
    }

    // MARK: - BrowserExploreModuleOutput

    var didSelectCategory: ((PopularAppsCategory, MultichainChain?) -> Void)?
    var didSelectDapp: ((DappOpenIntent) -> Void)?
    var didOpenDeeplink: ((_ deeplink: Deeplink, _ utm: UtmParameters) -> Void)?
    var didUpdateExploreTabVisible: ((Bool) -> Void)?

    // MARK: - State

    @Published private(set) var viewState: ViewState = .empty
    @Published private(set) var isRefreshEnabled = false
    @Published private(set) var supportedChains = [MultichainChain]()
    @Published private(set) var selectedNetworkFilter: BrowserExploreNetworkFilter = .all

    private enum State {
        case empty
        case loading
        case content(popularAppsData: PopularAppsResponseData)
    }

    private var state: State = .empty {
        didSet {
            didUpdateState()
        }
    }

    private var selectedCountry: SelectedCountry = .auto
    private var loadingTask: Task<Void, Never>?
    private var didStart = false
    private var pendingNetworkChain: MultichainChain?

    // MARK: - Dependencies

    private let browserExploreController: BrowserExploreController
    private let walletStore: WalletsStore
    private let regionStore: RegionStore
    private let configuration: Configuration
    private let deeplinkParser: DeeplinkParser
    private let supportedChainsOrder: [MultichainChain]

    // MARK: - Init

    init(
        browserExploreController: BrowserExploreController,
        walletStore: WalletsStore,
        regionStore: RegionStore,
        configuration: Configuration,
        deeplinkParser: DeeplinkParser,
        supportedChains: [MultichainChain]
    ) {
        self.browserExploreController = browserExploreController
        self.walletStore = walletStore
        self.regionStore = regionStore
        self.configuration = configuration
        self.deeplinkParser = deeplinkParser
        self.supportedChainsOrder = supportedChains
    }

    deinit {
        loadingTask?.cancel()
    }

    func viewDidLoad() {
        guard !didStart else { return }
        didStart = true

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

        walletStore.addObserver(self) { observer, event in
            switch event {
            case .didChangeActiveWallet:
                DispatchQueue.main.async {
                    observer.loadContentForActiveWallet()
                }
            case let .didUpdateWalletMultichain(wallet):
                DispatchQueue.main.async {
                    guard (try? observer.walletStore.activeWallet) == wallet else { return }
                    observer.didUpdateState()
                }
            default:
                break
            }
        }

        selectedCountry = regionStore.getState()

        loadContentForActiveWallet()
    }

    func reloadAsync() async {
        await loadPopularAppsFromNetwork()
    }

    func selectFeaturedApp(_ app: PopularApp) {
        didSelectDapp?(.popularApp(source: .banner, app: app, catalogMode: .multichain))
    }

    func selectApp(_ app: PopularApp) {
        didSelectDapp?(.popularApp(source: .browser, app: app, catalogMode: .multichain))
    }

    func selectCategory(_ category: PopularAppsCategory) {
        let chain: MultichainChain? = switch selectedNetworkFilter {
        case .all: nil
        case let .chain(chain): chain
        }
        didSelectCategory?(category, chain)
    }

    func performAdButtonAction(_ item: BrowserExploreAdItem) {
        guard let button = item.app.button else { return }
        switch button.type {
        case let .deeplink(url):
            do {
                let deeplink = try deeplinkParser.parse(
                    string: url.absoluteString,
                    source: .browser
                )
                didOpenDeeplink?(deeplink, UtmParameters(link: url.absoluteString))
            } catch where error.isSilent {
                break
            } catch {
                break
            }
        case .unknown:
            break
        }
    }
}

private extension BrowserExploreMultichainViewModelImplementation {
    var isDappsDisabled: Bool {
        let network: Network = (try? walletStore.activeWallet)?.network ?? .mainnet
        return configuration.flag(\.dappsDisabled, network: network)
    }

    func loadContentForActiveWallet() {
        loadingTask?.cancel()
        let network: Network = (try? walletStore.activeWallet)?.network ?? .mainnet
        let dappsDisabled = configuration.flag(\.dappsDisabled, network: network)
        isRefreshEnabled = !dappsDisabled
        if dappsDisabled {
            state = .empty
        } else if let cached = getCachedPopularApps() {
            state = .content(popularAppsData: cached)
        } else {
            state = .loading
        }

        guard !dappsDisabled else { return }
        loadPopularApps()
    }

    func loadPopularApps() {
        loadingTask?.cancel()
        loadingTask = Task { [weak self] in
            await self?.loadPopularAppsFromNetwork()
        }
    }

    func loadPopularAppsFromNetwork() async {
        let lang = Locale.current.languageCode ?? "en"
        do {
            let loaded = try await browserExploreController.loadPopularApps(lang: lang)
            try Task.checkCancellation()
            state = .content(popularAppsData: loaded)
        } catch {
            guard !error.isCancelledError else { return }
            state = .empty
        }
    }

    func getCachedPopularApps() -> PopularAppsResponseData? {
        let lang = Locale.current.languageCode ?? "en"
        return try? browserExploreController.getCachedPopularApps(lang: lang)
    }

    func didUpdateRegion() {
        didUpdateState()
    }

    func didUpdateDappFeatureFlag() {
        let network: Network = (try? walletStore.activeWallet)?.network ?? .mainnet
        isRefreshEnabled = !configuration.flag(\.dappsDisabled, network: network)
        didUpdateState()
    }

    func didUpdateState() {
        didUpdateExploreTabVisible?(isExploreTabVisible)
        switch state {
        case .empty:
            updateSupportedChains([])
            viewState = .empty
        case .loading:
            updateSupportedChains([])
            viewState = .loading
        case let .content(popularAppsData):
            showContent(content: popularAppsData)
        }
    }

    func showContent(content: PopularAppsResponseData) {
        guard !content.categories.isEmpty else {
            state = .empty
            return
        }

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

        let featuredApps = featuredCategory?.apps.filter {
            if let filter, isDappContainsCountriesFilter(filter, app: $0) {
                return false
            }
            return true
        } ?? []

        let ads = adsCategory?.apps.compactMap { app -> BrowserExploreAdItem? in
            if let filter, isDappContainsCountriesFilter(filter, app: app) {
                return nil
            }
            return BrowserExploreAdItem(id: app.id, app: app)
        } ?? []

        let sections = categories.map { category in
            mapCategory(category, filterValue: filter)
        }
        updateSupportedChains(sections)

        viewState = .content(BrowserExploreContent(
            featuredApps: featuredApps,
            ads: ads,
            sections: sections
        ))
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

    func mapCategory(_ category: PopularAppsCategory, filterValue: String?) -> BrowserExploreAppsSection {
        let isTwoLinesTitle = category.id == Constants.digitalNomadsCategoryId
        let apps = category.apps.enumerated().compactMap { appIndex, app -> BrowserExploreAppItem? in
            if let filterValue, isDappContainsCountriesFilter(filterValue, app: app) {
                return nil
            }
            return BrowserExploreAppItem(
                id: "\(category.id)-\(appIndex)-\(app.id)",
                app: app,
                isTwoLinesTitle: isTwoLinesTitle,
                chains: app.chains
            )
        }

        return BrowserExploreAppsSection(
            id: category.id,
            category: category,
            placement: isTwoLinesTitle ? .beforeNetworkTabs : .afterNetworkTabs,
            title: isTwoLinesTitle ? nil : category.title,
            hasAll: false,
            apps: apps
        )
    }

    var activeWalletChains: [MultichainChain] {
        guard let wallet = try? walletStore.activeWallet else { return [.ton] }
        return wallet.browserChains(order: supportedChainsOrder)
    }

    func updateSupportedChains(_ sections: [BrowserExploreAppsSection]) {
        let loadedChains = Set(sections.flatMap { section in
            section.apps.flatMap(\.chains)
        })

        supportedChains = activeWalletChains.filter {
            loadedChains.contains($0)
        }

        if case let .chain(chain) = selectedNetworkFilter,
           !(supportedChains.count > 1 && supportedChains.contains(chain))
        {
            selectedNetworkFilter = .all
        }

        applyPendingNetworkFilter()
    }

    /// Deeplink-requested filter may arrive before content loads; apply once its chain is available.
    func applyPendingNetworkFilter() {
        guard let chain = pendingNetworkChain,
              supportedChains.count > 1,
              supportedChains.contains(chain)
        else { return }
        selectedNetworkFilter = .chain(chain)
        pendingNetworkChain = nil
    }

    enum Constants {
        static let digitalNomadsCategoryId = "digital_nomads"
    }
}
