import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BrowserModuleOutput: AnyObject {
  var didTapSearch: (() -> Void)? { get set }
  var didSelectCategory: ((PopularAppsCategory) -> Void)? { get set }
  var didSelectApp: ((PopularApp) -> Void)? { get set }
}

protocol BrowserViewModel: AnyObject {
  var didUpdateSegmentedControl: ((BrowserSegmentedControl.Model) -> Void)? { get set }
  var didSelectExplore: (() -> Void)? { get set }
  var didSelectConnected: (() -> Void)? { get set }
  
  func viewDidLoad()
  func didTapSearchBar()
}

final class BrowserViewModelImplementation: BrowserViewModel, BrowserModuleOutput {
  
  // MARK: - BrowserModuleOutput
  
  var didTapSearch: (() -> Void)?
  var didSelectCategory: ((PopularAppsCategory) -> Void)?
  var didSelectApp: ((PopularApp) -> Void)?
  
  // MARK: - BrowserViewModel
  
  var didUpdateSegmentedControl: ((BrowserSegmentedControl.Model) -> Void)?
  var didSelectExplore: (() -> Void)?
  var didSelectConnected: (() -> Void)?
  
  func viewDidLoad() {
    configure()
    didSelectExplore?()
  }
  
  func didTapSearchBar() {
    didTapSearch?()
  }
  
  // MARK: - Dependencies
  
  private let exploreModuleOutput: BrowserExploreModuleOutput
  private let connectedModuleOutput: BrowserConnectedModuleOutput
  
  // MARK: - Init
  
  init(exploreModuleOutput: BrowserExploreModuleOutput,
       connectedModuleOutput: BrowserConnectedModuleOutput) {
    self.exploreModuleOutput = exploreModuleOutput
    self.connectedModuleOutput = connectedModuleOutput
  }
}

private extension BrowserViewModelImplementation {
  func configure() {
    
    exploreModuleOutput.didSelectCategory = { [weak self] category in
      self?.didSelectCategory?(category)
    }
    
    exploreModuleOutput.didSelectApp = { [weak self] app in
      self?.didSelectApp?(app)
    }
    
    let segmentedControlModel = BrowserSegmentedControl.Model(
      exploreButton: BrowserSegmentedControl.Model.Button(
        title: TKLocales.Browser.Tab.explore,
        tapAction: { [weak self] in
          self?.didSelectExplore?()
        }
      ),
      connectedButton: BrowserSegmentedControl.Model.Button(
        title: TKLocales.Browser.Tab.connected,
        tapAction: {[weak self] in
          self?.didSelectConnected?()
        }
      )
    )
    didUpdateSegmentedControl?(segmentedControlModel)
  }
}
