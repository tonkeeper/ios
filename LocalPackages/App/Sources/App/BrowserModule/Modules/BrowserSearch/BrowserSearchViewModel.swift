import UIKit
import TKUIKit
import KeeperCore
import TKCore

typealias BrowserSearchSnapshot = NSDiffableDataSourceSnapshot<BrowserSearchSection, AnyHashable>

protocol BrowserSearchModuleOutput: AnyObject {
  var didSelectDapp: ((Dapp) -> Void)? { get set }
}

protocol BrowserSearchViewModel: AnyObject {
  var didUpdateEmptyText: ((NSAttributedString) -> Void)? { get set }
  var didUpdateSnapshot: ((BrowserSearchSnapshot) -> Void)? { get set }
  
  func viewDidLoad()
  func searchInput(_ input: String)
  func goButtonPressed()
}

final class BrowserSearchViewModelImplementation: BrowserSearchViewModel, BrowserSearchModuleOutput {
  
  var didSelectDapp: ((Dapp) -> Void)?
  
  var didUpdateEmptyText: ((NSAttributedString) -> Void)?
  var didUpdateSnapshot: ((BrowserSearchSnapshot) -> Void)?
  
  func viewDidLoad() {
    let emptyText = "Enter an address or search the web".withTextStyle(
      .body1,
      color: .Text.tertiary,
      alignment: .center,
      lineBreakMode: .byWordWrapping
    )
    didUpdateEmptyText?(emptyText)
    
    snapshot.appendSections([.apps, .newSearch])
  }
  
  func searchInput(_ input: String) {
    searchPopularApps(input: input)
  }
  
  func goButtonPressed() {
    guard !apps.isEmpty else {
      return
    }
    didSelectDapp?(apps[0])
  }
  
  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  // MARK: - State
  
  private var snapshot = NSDiffableDataSourceSnapshot<BrowserSearchSection, AnyHashable>()
  private var apps = [Dapp]() {
    didSet {
      let items = apps.map { mapDapp($0) }
      snapshot.appendItems(items, toSection: .apps)
    }
  }
  
  // MARK: - Dependencies
  
  private let popularAppsService: PopularAppsService
  
  // MARK: - Init
  
  init(popularAppsService: PopularAppsService) {
    self.popularAppsService = popularAppsService
  }
}

private extension BrowserSearchViewModelImplementation {
  func searchPopularApps(input: String) {
    defer {
      didUpdateSnapshot?(snapshot)
    }
    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .apps))
    guard !input.isEmpty else {
      return
    }
    let lang = Locale.current.languageCode ?? "en"
    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .apps))
    if let popularApps = try? popularAppsService.getPopularApps(lang: lang) {
      let filtered = popularApps.categories
        .flatMap { $0.apps }
        .filter { $0.name.contains(input) }
        .prefix(3)
      self.apps = Array(filtered)
    }
  }
  
  private func mapDapp(_ dapp: Dapp) -> TKUIListItemCell.Configuration {
    TKUIListItemCell.Configuration(
      id: UUID().uuidString,
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
            title: dapp.name.withTextStyle(.label1, color: .Text.primary),
            tagViewModel: nil,
            subtitle: dapp.url.absoluteString.withTextStyle(.body2, color: .Text.secondary),
            description: nil
          ),
          rightItemConfiguration: nil
        ),
        accessoryConfiguration: .none
      ),
      selectionClosure: { [weak self] in
        self?.didSelectDapp?(dapp)
      }
    )
  }
}
