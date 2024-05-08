import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BrowserExploreModuleOutput: AnyObject {
  var didSelectCategory: ((PopularAppsCategory) -> Void)? { get set }
  var didSelectApp: ((PopularApp) -> Void)? { get set }
}

protocol BrowserExploreViewModel: AnyObject {

  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserExploreSection, AnyHashable>) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectCategoryAll(index: Int)
}

final class BrowserExploreViewModelImplementation: BrowserExploreViewModel, BrowserExploreModuleOutput {
  
  // MARK: - BrowserExploreModuleOutput
  
  var didSelectCategory: ((PopularAppsCategory) -> Void)?
  var didSelectApp: ((PopularApp) -> Void)?
  
  // MARK: - BrowserExploreViewModel
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserExploreSection, AnyHashable>) -> Void)?
  
  func viewDidLoad() {
    reloadContent()
  }
  
  func didSelectCategoryAll(index: Int) {
    guard index < categories.count else { return }
    didSelectCategory?(categories[index])
  }
  
  // MARK: - State
  
  private var categories = [PopularAppsCategory]()
  
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
  func reloadContent() {
    if let cached = try? browserExploreController.getCachedPopularApps(lang: "en") {
      let mapped = mapPopularAppsData(cached)
      categories = cached.categories
      updateSnapshot(sections: mapped)
    }
    Task {
      do {
        let loaded = try await browserExploreController.loadPopularApps(lang: "en")
        let mapped = mapPopularAppsData(loaded)
        await MainActor.run {
          categories = loaded.categories
          updateSnapshot(sections: mapped)
        }
      } catch {
        print(error)
      }
    }
  }
  
  func mapPopularAppsData(_ popularAppsData: PopularAppsResponseData) -> [BrowserExploreSection] {
    popularAppsData.categories.map { category in
      let items = category.apps.map { mapPopularApp($0) }
      return BrowserExploreSection.regular(
        title: category.title ?? "",
        hasAll: items.count > 3,
        items: items
      )
    }
  }
  
  func mapPopularApp(_ popularApp: PopularApp) -> TKUIListItemCell.Configuration? {
    let id = UUID().uuidString
    return TKUIListItemCell.Configuration(
      id: id,
      listItemConfiguration: TKUIListItemView.Configuration(
        iconConfiguration: TKUIListItemIconView.Configuration(
          iconConfiguration: .image(
            TKUIListItemImageIconView.Configuration(
              image: .asyncImage(
                popularApp.icon,
                TKCore.ImageDownloadTask(
                  closure: {
                    [imageLoader] imageView,
                    size,
                    cornerRadius in
                    return imageLoader.loadImage(
                      url: popularApp.icon,
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
              cornerRadius: 12
            )
          ),
          alignment: .center
        ),
        contentConfiguration: TKUIListItemContentView.Configuration(
          leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
            title: popularApp.name?.withTextStyle(.label2, color: .Text.primary),
            tagViewModel: nil,
            subtitle: nil,
            description: popularApp.description?.withTextStyle(.body3Alternate, color: .Text.secondary),
            descriptionNumberOfLines: 2
          ),
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: .image(.init(image: .TKUIKit.Icons.Size16.chevronRight, tintColor: .Icon.tertiary, padding: .zero))
      ),
      selectionClosure: { [weak self] in
        self?.didSelectApp?(popularApp)
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
      }
    }
    didUpdateSnapshot?(snapshot)
  }
}
