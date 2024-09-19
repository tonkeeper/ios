import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BrowserConnectedModuleOutput: AnyObject {
  var didSelectDapp: ((Dapp) -> Void)? { get set }
}

protocol BrowserConnectedViewModel: AnyObject {

  var didUpdateViewState: ((BrowserConnectedView.State) -> Void)? { get set }
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserConnectedSection, AnyHashable>) -> Void)? { get set }
  var didUpdateFeaturedItems: (([Dapp]) -> Void)? { get set }
  
  func viewDidLoad()
  func selectApp(index: Int)
}

final class BrowserConnectedViewModelImplementation: BrowserConnectedViewModel, BrowserConnectedModuleOutput {
  
  // MARK: - BrowserConnectedModuleOutput
  
  var didSelectDapp: ((Dapp) -> Void)?
  
  // MARK: - BrowserConnectedViewModel
  
  var didUpdateViewState: ((BrowserConnectedView.State) -> Void)?
  var didUpdateSnapshot: ((NSDiffableDataSourceSnapshot<BrowserConnectedSection, AnyHashable>) -> Void)?
  var didUpdateFeaturedItems: (([Dapp]) -> Void)?
  
  func viewDidLoad() {
    browserConnectedController.didUpdateApps = { [weak self] in
      self?.syncQueue.async {
        self?.reloadContent()
      }
    }
    browserConnectedController.start()
    syncQueue.sync {
      reloadContent()
    }
  }
  
  func selectApp(index: Int) {
    guard connectedApps.count > index else { return }
    let connectedApp = connectedApps[index]
    let dapp = Dapp(
      name: connectedApp.name,
      description: nil,
      icon: connectedApp.iconURL,
      poster: nil,
      url: connectedApp.url,
      textColor: nil
    )
    didSelectDapp?(dapp)
  }
  
  // MARK: - State
  
  private var connectedApps = [BrowserConnectedController.ConnectedApp]() {
    didSet {
      DispatchQueue.main.async {
        self.didUpdateConnectedApps()
      }
    }
  }
  private let syncQueue = DispatchQueue(label: "BrowserConnectedViewModelImplementationQueue")
  
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
    
    self.connectedApps = browserConnectedController.getConnectedApps()
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
  
  func didUpdateConnectedApps() {
    let state: BrowserConnectedView.State
    let sections: [BrowserConnectedSection]
    if connectedApps.isEmpty {
      sections = [.apps(items: [])]
      state = .empty(
        TKEmptyStateView.Model(
          title: "Connected apps will be shown here",
          caption: "Explore apps and services in Tonkeeper browser.",
          leftButton: nil,
          rightButton: nil
        )
      )
    } else {
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
     
      sections = [.apps(items: items)]
      state = .data
    }
  
    DispatchQueue.main.async {
      self.updateSnapshot(sections: sections)
      self.didUpdateViewState?(state)
    }
  }
}
