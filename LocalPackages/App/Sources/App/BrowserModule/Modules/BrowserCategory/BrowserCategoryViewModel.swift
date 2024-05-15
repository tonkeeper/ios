import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BrowserCategoryModuleOutput: AnyObject {
  var didSelectDapp: ((Dapp) -> Void)? { get set }
}

protocol BrowserCategoryViewModel: AnyObject {
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserCategorySection, AnyHashable>) -> Void)? { get set }
  var didUpdateTitle: ((String?) -> Void)? { get set }
  
  func viewDidLoad()
}

final class BrowserCategoryViewModelImplementation: BrowserCategoryViewModel, BrowserCategoryModuleOutput {
  
  // MARK: - BrowserCategoryModuleOutput
  
  var didSelectDapp: ((Dapp) -> Void)?
  
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
    let items = category.apps.map { mapDapp($0) }
    return BrowserCategorySection.regular(items: items)
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
              cornerRadius: 12
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
