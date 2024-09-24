import UIKit
import TKUIKit
import KeeperCore
import TKCore
import TKLocalize

protocol BrowserModuleInput: AnyObject {
  func updateSelectedCountry(_ selectedCountry: SelectedCountry)
}

protocol BrowserModuleOutput: AnyObject {
  var didTapSearch: (() -> Void)? { get set }
  var didSelectCategory: ((PopularAppsCategory) -> Void)? { get set }
  var didSelectDapp: ((Dapp) -> Void)? { get set }
  var didSelectCountryPicker: ((SelectedCountry) -> Void)? { get set }
}

protocol BrowserViewModel: AnyObject {
  var didUpdateSegmentedControl: ((BrowserSegmentedControl.Model) -> Void)? { get set }
  var didSelectExplore: (() -> Void)? { get set }
  var didSelectConnected: (() -> Void)? { get set }
  var didUpdateRightHeaderButton: ((BrowserHeaderRightButtonModel) -> Void)? { get set }

  func viewDidLoad()
  func didTapSearchBar()
}

final class BrowserViewModelImplementation: BrowserViewModel, BrowserModuleOutput {

  // MARK: - BrowserModuleOutput

  var didTapSearch: (() -> Void)?
  var didSelectCategory: ((PopularAppsCategory) -> Void)?
  var didSelectDapp: ((Dapp) -> Void)?
  var didSelectCountryPicker: ((SelectedCountry) -> Void)?

  // MARK: - BrowserViewModel

  var didUpdateSegmentedControl: ((BrowserSegmentedControl.Model) -> Void)?
  var didSelectExplore: (() -> Void)?
  var didSelectConnected: (() -> Void)?
  var didUpdateRightHeaderButton: ((BrowserHeaderRightButtonModel) -> Void)?

  private var selectedCountry: SelectedCountry = .auto

  func viewDidLoad() {
    configure()
    didSelectExplore?()

    bindRegion()
    selectedCountry = regionStore.getState()
    updateCountryPickerButton()
  }

  func didTapSearchBar() {
    didTapSearch?()
  }
  
  // MARK: - Dependencies
  
  private let exploreModuleOutput: BrowserExploreModuleOutput
  private let connectedModuleOutput: BrowserConnectedModuleOutput
  private let regionStore: RegionStore

  // MARK: - Init
  
  init(exploreModuleOutput: BrowserExploreModuleOutput,
       connectedModuleOutput: BrowserConnectedModuleOutput,
       regionStore: RegionStore) {
    self.exploreModuleOutput = exploreModuleOutput
    self.connectedModuleOutput = connectedModuleOutput
    self.regionStore = regionStore
  }
}

private extension BrowserViewModelImplementation {

  func configure() {
    
    exploreModuleOutput.didSelectCategory = { [weak self] category in
      self?.didSelectCategory?(category)
    }
    
    exploreModuleOutput.didSelectDapp = { [weak self] dapp in
      self?.didSelectDapp?(dapp)
    }
    
    connectedModuleOutput.didSelectDapp = { [weak self] dapp in
      self?.didSelectDapp?(dapp)
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
        tapAction: { [weak self] in
          self?.didSelectConnected?()
        }
      )
    )
    didUpdateSegmentedControl?(segmentedControlModel)
  }

  private func bindRegion() {
    regionStore.addObserver(self) { observer, event in
      DispatchQueue.main.async {
        switch event {
        case .didUpdateRegion(let country):
          observer.updateSelectedCountry(country)
        }
      }
    }
  }

  func updateCountryPickerButton() {
    let title: String
    switch selectedCountry {
    case .all:
      title = "🌍"
    case .auto:
      title = Locale.current.regionCode ?? ""
    case .country(let countryCode):
      title = countryCode
    }

    let model = BrowserHeaderRightButtonModel(title: title) { [weak self] in
      guard let self = self else {
        return
      }

      self.didSelectCountryPicker?(self.selectedCountry)
    }

    didUpdateRightHeaderButton?(model)
  }
}

// MARK: -  BrowserModuleInput

extension BrowserViewModelImplementation: BrowserModuleInput {

  func updateSelectedCountry(_ selectedCountry: SelectedCountry) {
    guard self.selectedCountry != selectedCountry else {
      return
    }

    Task {
      await regionStore.updateRegion(selectedCountry)

      await MainActor.run {
        self.selectedCountry = selectedCountry
        updateCountryPickerButton()
      }
    }
  }
}
