import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

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
  func selectFeaturedApp(index: Int)
}

final class BrowserExploreViewModelImplementation: BrowserExploreViewModel, BrowserExploreModuleOutput {
  
  // MARK: - BrowserExploreModuleOutput
  
  var didUpdateViewState: ((BrowserExploreView.State) -> Void)?
  var didSelectCategory: ((PopularAppsCategory) -> Void)?
  var didSelectDapp: ((Dapp) -> Void)?
  
  // MARK: - BrowserExploreViewModel
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserExploreSection, AnyHashable>) -> Void)?
  var didUpdateFeaturedItems: (([Dapp]) -> Void)?
  
  func viewDidLoad() {
    Task {
      await reloadContent()
    }
  }
  
  func didSelectCategoryAll(index: Int) {
    let categoryIndex = max(index - 1, 0)
    guard categoryIndex < categories.count else { return }
    didSelectCategory?(categories[categoryIndex])
  }
  
  func selectFeaturedApp(index: Int) {
    guard let featuredCategory,
          index < (featuredCategory.apps.count - 1) else {
      return
    }
    let app = featuredCategory.apps[index]
    didSelectDapp?(app)
  }
  
  // MARK: - State
  
  private var categories = [PopularAppsCategory]()
  private var featuredCategory: PopularAppsCategory?
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let browserExploreController: BrowserExploreController
  
  // MARK: - Init
  
  init(browserExploreController: BrowserExploreController) {
    self.browserExploreController = browserExploreController
  }
}

private extension BrowserExploreViewModelImplementation {
  func reloadContent() async {
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
  
  func handle(popularAppsData: PopularAppsResponseData) async {

    if popularAppsData.apps.isEmpty {
      await setEmptyState()
    } else {
      let state: BrowserExploreView.State
      var featuredCategory: PopularAppsCategory?
      var categories = [PopularAppsCategory]()
      popularAppsData.categories.forEach { category in
        if category.id == "featured" {
          featuredCategory = category
        } else {
          categories.append(category)
        }
      }
      
      var featuredItems = [Dapp]()
      var sections = [BrowserExploreSection]()
      if let featuredCategory {
        featuredItems = featuredCategory.apps
        sections.append(.featured(items: [.banner]))
      }
      sections.append(contentsOf: mapCategories(categories))
      state = .data
      
      await MainActor.run { [categories, featuredCategory, sections, featuredItems] in
        self.categories = categories
        self.featuredCategory = featuredCategory
        updateSnapshot(sections: sections)
        didUpdateFeaturedItems?(featuredItems)
        didUpdateViewState?(state)
      }
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
    categories.map { category in
      let items = category.apps.map { mapDapp($0) }
      return BrowserExploreSection.regular(
        title: category.title ?? "",
        hasAll: items.count > 3,
        items: items
      )
    }
  }
  
  func mapDapp(_ dapp: Dapp) -> TKUIListItemCell.Configuration? {
    let id = UUID().uuidString
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: TKUIListItemView.Configuration(
        iconConfiguration: TKUIListItemIconView.Configuration(
          iconConfiguration: .image(
            TKUIListItemImageIconView.Configuration(
              image: .asyncImage(
                dapp.icon,
                TKCore.ImageDownloadTask(
                  closure: {
                    [imageLoader] imageView,
                    size,
                    cornerRadius in
                    return imageLoader.loadImage(
                      url: dapp.icon,
                      imageView: imageView,
                      size: size,
                      cornerRadius: cornerRadius
                    )
                  }
                )
              ),
              tintColor: .clear,
              backgroundColor: .clear,
              size: CGSize(width: 44, height: 44),
              cornerRadius: 16
            )
          ),
          alignment: .center
        ),
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: dapp.name.withTextStyle(.label2, color: .Text.primary),
            tagViewModel: nil,
            subtitle: nil,
            description: dapp.description?.withTextStyle(.body3Alternate, color: .Text.secondary),
            descriptionNumberOfLines: 2
          ),
          rightItemConfiguration: nil,
          isVerticalCenter: true
        ),
        accessoryConfiguration: .image(.init(image: .TKUIKit.Icons.Size16.chevronRight, tintColor: .Icon.tertiary, padding: .zero))
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
