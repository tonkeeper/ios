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
  var didUpdateSnapshot: ((BrowserConnected.Snapshot) -> Void)? { get set }
  var didUpdateFeaturedItems: (([Dapp]) -> Void)? { get set }
  
  func viewDidLoad()
  func selectApp(index: Int)
}

final class BrowserConnectedViewModelImplementation: BrowserConnectedViewModel, BrowserConnectedModuleOutput {
  
  // MARK: - BrowserConnectedModuleOutput
  
  var didSelectDapp: ((Dapp) -> Void)?
  
  // MARK: - BrowserConnectedViewModel
  
  var didUpdateViewState: ((BrowserConnectedView.State) -> Void)?
  var didUpdateSnapshot: ((BrowserConnected.Snapshot) -> Void)?
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
      textColor: nil,
      excludeCountries: nil,
      includeCountries: nil
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
    connectedApps = browserConnectedController.getConnectedApps()
  }
  
  func updateSnapshot(sections: [BrowserConnected.Section]) {
    var snapshot = BrowserConnected.Snapshot()
    sections.forEach { section in
      switch section {
      case .apps:
        let items = connectedApps.compactMap { app in
          let downloadTask = TKCore.ImageDownloadTask() { [imageLoader] imageView, size, cornerRadius in
            imageLoader.loadImage(
              url: app.iconURL,
              imageView: imageView,
              size: size,
              cornerRadius: cornerRadius
            )
          }

          let configuration = BrowserConnectedAppCell.Configuration(
            title: app.name,
            iconUrl: app.iconURL,
            iconDownloadTask: downloadTask
          )

          return BrowserConnected.Item(
            identifier: UUID().uuidString,
            configuration: configuration
          )
        }

        snapshot.appendSections([.apps])
        snapshot.appendItems(items, toSection: .apps)
      }
    }

    didUpdateSnapshot?(snapshot)
  }
  
  func didUpdateConnectedApps() {
    let state: BrowserConnectedView.State
    let sections: [BrowserConnected.Section]

    defer {
      DispatchQueue.main.async {
        self.updateSnapshot(sections: sections)
        self.didUpdateViewState?(state)
      }
    }

    guard !connectedApps.isEmpty else {
      sections = []
      state = .empty(
        TKEmptyStateView.Model(
          title: TKLocales.Browser.ConnectedApps.emptyTitle,
          caption: TKLocales.Browser.ConnectedApps.emptyDescription,
          leftButton: nil,
          rightButton: nil
        )
      )

      return
    }

    sections = [.apps]
    state = .data
  }
}
