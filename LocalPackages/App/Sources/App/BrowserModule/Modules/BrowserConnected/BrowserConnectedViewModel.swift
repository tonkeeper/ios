import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BrowserConnectedModuleOutput: AnyObject {
  var didSelectCategory: ((PopularAppsCategory) -> Void)? { get set }
  var didSelectApp: ((PopularApp) -> Void)? { get set }
}

protocol BrowserConnectedViewModel: AnyObject {

  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserConnectedSection, AnyHashable>) -> Void)? { get set }
  var didUpdateFeaturedItems: (([PopularApp]) -> Void)? { get set }
  
  func viewDidLoad()
  func didSelectCategoryAll(index: Int)
}

final class BrowserConnectedViewModelImplementation: BrowserConnectedViewModel, BrowserConnectedModuleOutput {
  
  // MARK: - BrowserConnectedModuleOutput
  
  var didSelectCategory: ((PopularAppsCategory) -> Void)?
  var didSelectApp: ((PopularApp) -> Void)?
  
  // MARK: - BrowserConnectedViewModel
  
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserConnectedSection, AnyHashable>) -> Void)?
  var didUpdateFeaturedItems: (([PopularApp]) -> Void)?
  
  func viewDidLoad() {
    browserConnectedController.didUpdateApps = { [weak self] in
      self?.reloadContent()
    }
    browserConnectedController.start()
    reloadContent()
  }
  
  func didSelectCategoryAll(index: Int) {
    guard index < categories.count else { return }
    didSelectCategory?(categories[index])
  }
  
  // MARK: - State
  
  private var categories = [PopularAppsCategory]()
  private var featuredCategory: PopularAppsCategory?
  
  // MARK: - Image Loading
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let browserConnectedController: BrowserConnectedController
  
  // MARK: - Init
  
  init(browserConnectedController: BrowserConnectedController) {
    self.browserConnectedController = browserConnectedController
  }
}

private extension BrowserConnectedViewModelImplementation {
  func reloadContent() {
    
    let connectedApps = browserConnectedController.getConnectedApps()
    let items = connectedApps.map { app in
      BrowserConnectedAppCell.Configuration(
        title: app.name,
        iconUrl: app.iconURL,
        iconDownloadTask: TKCore.ImageDownloadTask(
          closure: {
            [imageLoader] imageView,
            size,
            cornerRadius in
            return imageLoader.loadImage(
              url: app.iconURL,
              imageView: imageView,
              size: size,
              cornerRadius: cornerRadius
            )
          }
        )
      )
    }
   
    updateSnapshot(sections: [.apps(items: items)])
  }
  
  func updateSnapshot(sections: [BrowserConnectedSection]) {
    var snapshot = NSDiffableDataSourceSnapshot<BrowserConnectedSection, AnyHashable>()
    snapshot.appendSections(sections)
    for section in sections {
      switch section {
      case .apps(let items):
        snapshot.appendItems(items, toSection: section)
      }
    }
    didUpdateSnapshot?(snapshot)
  }
}
