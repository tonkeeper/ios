import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BrowserCategoryModuleOutput: AnyObject {
  var didSelectApp: ((PopularApp) -> Void)? { get set }
}

protocol BrowserCategoryViewModel: AnyObject {
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserCategorySection, AnyHashable>) -> Void)? { get set }
  var didUpdateTitle: ((String?) -> Void)? { get set }
  
  func viewDidLoad()
}

final class BrowserCategoryViewModelImplementation: BrowserCategoryViewModel, BrowserCategoryModuleOutput {
  
  // MARK: - BrowserCategoryModuleOutput
  
  var didSelectApp: ((PopularApp) -> Void)?
  
  // MARK: - BrowserCategoryViewModel
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserCategorySection, AnyHashable>) -> Void)?
  var didUpdateTitle: ((String?) -> Void)?
  
  func viewDidLoad() {
    configure()
    reloadContent()
  }
  
  // MARK: - State
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let category: PopularAppsCategory
  
  // MARK: - Init
  
  init(category: PopularAppsCategory) {
    self.category = category
  }
}

private extension BrowserCategoryViewModelImplementation {
  func configure() {
    didUpdateTitle?(category.title)
  }
  
  func reloadContent() {
    let mappedCategory = mapCategory(category)
    updateSnapshot(sections: [mappedCategory])
  }
  
  func mapCategory(_ category: PopularAppsCategory) -> BrowserCategorySection {
    let items = category.apps.map { mapPopularApp($0) }
    return BrowserCategorySection.regular(items: items)
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
          rightItemConfiguration: nil,
          isVerticalCenter: true
        ),
        accessoryConfiguration: .image(.init(image: .TKUIKit.Icons.Size16.chevronRight, tintColor: .Icon.tertiary, padding: .zero))
      ),
      selectionClosure: { [weak self] in
        self?.didSelectApp?(popularApp)
      }
    )
  }
  
  func updateSnapshot(sections: [BrowserCategorySection]) {
    var snapshot = NSDiffableDataSourceSnapshot<BrowserCategorySection, AnyHashable>()
    snapshot.appendSections(sections)
    for section in sections {
      switch section {
      case .regular(let items):
        snapshot.appendItems(items, toSection: section)
      }
    }
    didUpdateSnapshot?(snapshot)
  }
}
