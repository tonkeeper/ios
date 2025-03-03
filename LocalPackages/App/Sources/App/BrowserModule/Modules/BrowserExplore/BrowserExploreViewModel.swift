import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize
import TKFeatureFlags

@MainActor
protocol BrowserExploreModuleOutput: AnyObject {
  var didSelectCategory: ((PopularAppsCategory) -> Void)? { get set }
  var didSelectDapp: ((Dapp) -> Void)? { get set }
}

@MainActor
protocol BrowserExploreViewModel: AnyObject {
  var didUpdateSnapshot: ((BrowserExplore.Snapshot) -> Void)? { get set }
  var didUpdateFeaturedItems: (([PopularApp]) -> Void)? { get set }
  var didUpdateEmptyView: ((BrowserExploreEmptyView.Model) -> Void)? { get set }
  var didUpdateIsRefreshEnable: ((_ isEnable: Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectCategoryAll(index: Int)
  func selectFeaturedApp(dapp: Dapp)
  func reload()
}

@MainActor
final class BrowserExploreViewModelImplementation: BrowserExploreViewModel, BrowserExploreModuleOutput {
  
  // MARK: - BrowserExploreModuleOutput
  
  var didSelectCategory: ((PopularAppsCategory) -> Void)?
  var didSelectDapp: ((Dapp) -> Void)?

  private var selectedCountry: SelectedCountry = .auto

  // MARK: - BrowserExploreViewModel
  
  var didUpdateSnapshot: ((BrowserExplore.Snapshot) -> Void)?
  var didUpdateFeaturedItems: (([PopularApp]) -> Void)?
  var didUpdateEmptyView: ((BrowserExploreEmptyView.Model) -> Void)?
  var didUpdateIsRefreshEnable: ((_ isEnable: Bool) -> Void)?
  
  func didSelectCategoryAll(index: Int) {
    let categoryIndex = max(index - 1, 0)
    guard categoryIndex < categories.count else { return }
    didSelectCategory?(categories[categoryIndex])
  }
  
  func selectFeaturedApp(dapp: Dapp) {
    didSelectDapp?(dapp)
    analyticsProvider.logEvent(eventKey: .clickDapp,
                               args: ["name": dapp.name,
                                      "url": dapp.url.absoluteString,
                                      "from": "banner"])
  }
  
  // MARK: - State
  
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
  
  private var loadingTask: Task<Void, Never>?
  
  private var categories = [PopularAppsCategory]()
  private var featuredCategory: PopularAppsCategory?

  // MARK: - Dependencies

  private let browserExploreController: BrowserExploreController
  private let walletStore: WalletsStore
  private let regionStore: RegionStore
  private let analyticsProvider: AnalyticsProvider

  // MARK: - Init
  
  init(browserExploreController: BrowserExploreController,
       walletStore: WalletsStore,
       regionStore: RegionStore,
       analyticsProvider: AnalyticsProvider) {
    self.browserExploreController = browserExploreController
    self.walletStore = walletStore
    self.regionStore = regionStore
    self.analyticsProvider = analyticsProvider
  }
  
  func viewDidLoad() {
    regionStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateRegion(let country):
        DispatchQueue.main.async {
          guard observer.selectedCountry != country else {
            return
          }
          
          observer.selectedCountry = country
          observer.didUpdateRegion()
        }
      }
    }
    
    TKFeatureFlags.provider.addObserver(self, flags: [.isDappsDisable]) { observer, _ in
      DispatchQueue.main.async {
        observer.didUpdateDappFeatureFlag()
      }
    }
    
    if let hardcodedCountryCode = TKFeatureFlags.provider.hardcodedCountryCode, hardcodedCountryCode != "" {
      selectedCountry = .country(countryCode: hardcodedCountryCode)
    } else {
      selectedCountry = regionStore.getState()
    }
    
    let isDappDisable = TKFeatureFlags.provider.isDappsDisable
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
    switch state {
    case .content(let popularAppsData):
      showContent(content: popularAppsData)
    case .empty:
      showEmptyState()
    case .loading:
      break
    }
  }
  
  func showEmptyState() {
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .small
    )
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Learn more"))
    let emptyViewModel = BrowserExploreEmptyView.Model(
      title: "Use Tonkeeper with all TON apps and services",
      caption: "Explore apps and services where you can use Tonkeeper for sign-in and payments.",
      button: buttonConfiguration
    )
    
    didUpdateEmptyView?(emptyViewModel)
    
    didUpdateFeaturedItems?([])
    
    var snapshot = BrowserExplore.Snapshot()
    snapshot.appendSections([.empty])
    snapshot.appendItems([.empty], toSection: .empty)
    didUpdateSnapshot?(snapshot)
  }
  
  func showContent(content: PopularAppsResponseData) {
    guard !content.apps.isEmpty else {
      showEmptyState()
      return
    }
    
    var snapshot = BrowserExplore.Snapshot()
    
    var featuredCategory: PopularAppsCategory?
    var categories = [PopularAppsCategory]()

    content.categories.forEach { category in
      if category.id == "featured" {
        featuredCategory = category
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
        }
        return true
      }
      featuredItems = filteredFeaturedItems
      if !featuredItems.isEmpty {
        snapshot.appendSections([.featured])
        snapshot.appendItems([.featured], toSection: .featured)
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
    let filter: String?
    switch selectedCountry {
    case .auto:
      filter = Locale.current.regionCode ?? ""
    case .all:
      filter = nil
    case let .country(countryCode):
      filter = countryCode
    }
    return filter
  }

  func isDappContainsCountriesFilter(_ filter: String, app: PopularApp) -> Bool {
    if let excludeCountries = app.excludeCountries,
       excludeCountries.contains(where: { $0 == filter }) {
      return true
    }

    if let includeCountries = app.includeCountries,
       !includeCountries.contains(where: { $0 == filter }) {
      return true
    }

    return false
  }

  func mapCategory(_ category: PopularAppsCategory, filterValue: String?) -> (section: BrowserExplore.Section, items: [BrowserExplore.Item]) {
    var items = [BrowserExplore.Item]()
    let chunks = category.apps.chunked(into: 4)
    for chunk in chunks {
      guard chunk.count > 2 else { continue }
      items.append(contentsOf: chunk.compactMap { app in
        if let filterValue, isDappContainsCountriesFilter(filterValue, app: app) {
          return nil
        }
        
        let configuration = mapApp(app)
        return .app(
          Browser.AppItem(
            id: UUID().uuidString,
            configuration: configuration,
            selectionHandler: { [weak self] in
              guard let dapp = Dapp(popularApp: app) else { return }
              self?.didSelectDapp?(dapp)
            },
            longPressHandler: {
              
            }
          )
        )
      })
    }

    let header: BrowserExplore.AppsSectionHeader? = {
      if category.id == "digital_nomads" {
        return nil
      } else {
        return BrowserExplore.AppsSectionHeader(
          title: category.title ?? "",
          hasAll: category.apps.count > 4,
          allTapHandler: { [weak self] in
            self?.didSelectCategory?(category)
          }
        )
      }
    }()
    let isMultilineAppsTitle = category.id == "digital_nomads"
    let section = BrowserExplore.Section.apps(
      id: category.id,
      header: header,
      isMultilineAppsTitle: isMultilineAppsTitle
    )
    
    return (section: section, items: items)
  }
  
  func mapApp(_ app: PopularApp) -> BrowserAppCollectionViewCell.Configuration {
    return BrowserAppCollectionViewCell.Configuration(
      id: app.id,
      title: app.name,
      iconModel: TKImageView.Model(
        image: .urlImage(app.icon),
        size: .size(CGSize(width: 64, height: 64)),
        corners: .cornerRadius(cornerRadius: 16)
      )
    )
  }
}
