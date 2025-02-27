import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize
import TKFeatureFlags

protocol BrowserExploreModuleOutput: AnyObject {
  var didSelectCategory: ((PopularAppsCategory) -> Void)? { get set }
  var didSelectDapp: ((Dapp) -> Void)? { get set }
}

protocol BrowserExploreViewModel: AnyObject {
  var didUpdateViewState: ((BrowserExploreView.State) -> Void)? { get set }
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserExploreSection, AnyHashable>) -> Void)? { get set }
  var didUpdateFeaturedItems: (([Dapp]) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectCategoryAll(index: Int)
  func selectFeaturedApp(dapp: Dapp)
}

final class BrowserExploreViewModelImplementation: BrowserExploreViewModel, BrowserExploreModuleOutput {
  
  // MARK: - BrowserExploreModuleOutput
  
  var didUpdateViewState: ((BrowserExploreView.State) -> Void)?
  var didSelectCategory: ((PopularAppsCategory) -> Void)?
  var didSelectDapp: ((Dapp) -> Void)?

  private var selectedCountry: SelectedCountry = .auto

  // MARK: - BrowserExploreViewModel
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserExploreSection, AnyHashable>) -> Void)?
  var didUpdateFeaturedItems: (([Dapp]) -> Void)?
  
  func viewDidLoad() {
    walletStore.addObserver(self) { observer, event in
      switch event {
      case .didChangeActiveWallet(let wallet):
        Task {
          await observer.reloadContent()
        }
      default:
        break
      }
    }
    TKFeatureFlags.provider.addObserver(self, flags: [.isDappsDisable]) { observer, _ in
      Task {
        await observer.reloadContent()
      }
    }
    Task {
      bindRegion()
      await reloadContent()
    }
  }

  private func bindRegion() {
    if let hardcodedCountryCode = TKFeatureFlags.provider.hardcodedCountryCode, hardcodedCountryCode != "" {
      selectedCountry = .country(countryCode: hardcodedCountryCode)
    } else {
      selectedCountry = regionStore.getState()
    }

    regionStore.addObserver(self) { observer, event in
      switch event {
      case .didUpdateRegion(let country):
        guard observer.selectedCountry != country else {
          return
        }

        observer.selectedCountry = country
        Task {
          await observer.reloadContent()
        }
      }
    }
  }

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
  
  private var categories = [PopularAppsCategory]()
  private var featuredCategory: PopularAppsCategory?
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()

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
}

private extension BrowserExploreViewModelImplementation {

  func reloadContent() async {
    guard !TKFeatureFlags.provider.isDappsDisable else {
      await setEmptyState()
      return 
    }
    
    let lang = Locale.current.languageCode ?? "en"
    if let cached = try? browserExploreController.getCachedPopularApps(lang: lang) {
      await handle(popularAppsData: cached)
    }
    
    do {
      let loaded = try await browserExploreController.loadPopularApps(lang: lang)
      await handle(popularAppsData: loaded)
    } catch {
      await setEmptyState()
    }
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

  func isDappContainsCountriesFilter(_ filter: String, dapp: Dapp) -> Bool {
    if let excludeCountries = dapp.excludeCountries,
       excludeCountries.contains(where: { $0 == filter }) {
      return true
    }

    if let includeCountries = dapp.includeCountries,
       !includeCountries.contains(where: { $0 == filter }) {
      return true
    }

    return false
  }

  func handle(popularAppsData: PopularAppsResponseData) async {
    guard !popularAppsData.apps.isEmpty else {
      await setEmptyState()
      return
    }

    var featuredCategory: PopularAppsCategory?
    var categories = [PopularAppsCategory]()
    popularAppsData.categories.forEach { category in
      if category.id == "featured" {
        featuredCategory = category
      } else {
        categories.append(category)
      }
    }

    let filter = composeCountryFilter()

    var featuredItems = [Dapp]()
    var sections = [BrowserExploreSection]()
    if let featuredCategory {
      let filteredFeaturedItems = featuredCategory.apps.filter {
        if let filter, isDappContainsCountriesFilter(filter, dapp: $0) {
          return false
        }
        return true
      }
      featuredItems = filteredFeaturedItems
      if !featuredItems.isEmpty {
        sections.append(.featured(items: [.banner]))
      }
    }
    
    sections.append(contentsOf: mapCategories(categories))

    await MainActor.run { [categories, featuredCategory, sections, featuredItems] in
      self.categories = categories
      self.featuredCategory = featuredCategory
      updateSnapshot(sections: sections)
      didUpdateFeaturedItems?(featuredItems)
      didUpdateViewState?(BrowserExploreView.State.data)
    }
  }
  
  func setEmptyState() async {
    let featuredItems = [Dapp]()
    let sections = [BrowserExploreSection]()
    let categories = [PopularAppsCategory]()
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .small
    )
    buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Learn more"))
    let state: BrowserExploreView.State = .empty(
      BrowserExploreEmptyView.Model(
        title: "Use Tonkeeper with all TON apps and services",
        caption: "Explore apps and services where you can use Tonkeeper for sign-in and payments.",
        button: buttonConfiguration
      )
    )
    
    await MainActor.run {
      self.categories = categories
      self.featuredCategory = nil
      updateSnapshot(sections: sections)
      didUpdateFeaturedItems?(featuredItems)
      didUpdateViewState?(state)
    }
  }
  
  func mapCategories(_ categories: [PopularAppsCategory]) -> [BrowserExploreSection] {
    let filter = composeCountryFilter()

    return categories.compactMap { category in
      let items: [BrowserAppCollectionViewCell.Configuration?] = category.apps.compactMap {
        if let filter, isDappContainsCountriesFilter(filter, dapp: $0) {
          return nil
        }

        return mapDapp($0)
      }
      
      let categoryTitle = category.id == "digital_nomads" ? nil : category.title
      
      return BrowserExploreSection.regular(
        title: categoryTitle,
        hasAll: items.count > 3,
        items: items
      )
    }
  }
  
  func mapDapp(_ dapp: Dapp) -> BrowserAppCollectionViewCell.Configuration {
    return BrowserAppCollectionViewCell.Configuration(
      id: UUID(),
      title: dapp.name,
      iconModel: TKImageView.Model(
        image: .urlImage(dapp.icon),
        size: .size(CGSize(width: 64, height: 64)),
        corners: .cornerRadius(cornerRadius: 16)
      ),
      selectionClosure: { [weak self] in
        self?.didSelectDapp?(dapp)
      }
    )
  }
  
  func updateSnapshot(sections: [BrowserExploreSection]) {
    var snapshot = NSDiffableDataSourceSnapshot<BrowserExploreSection, AnyHashable>()
    snapshot.appendSections(sections)
    for section in sections {
      switch section {
      case .regular(_, _, let items):
        snapshot.appendItems(items, toSection: section)
      case .featured(let items):
        snapshot.appendItems(items, toSection: section)
      }
    }
    didUpdateSnapshot?(snapshot)
  }
}
