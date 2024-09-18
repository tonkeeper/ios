import UIKit
import TKUIKit
import TKCore
import KeeperCore

protocol BuySellListModuleOutput: AnyObject {
  var didSelectURL: ((URL) -> Void)? { get set }
  var didSelectItem: ((BuySellItem) -> Void)? { get set }
  var didSelectCountryPicker: ((SelectedCountry) -> Void)? { get set }
}

protocol BuySellListModuleInput: AnyObject {
  func setSelectedCountry(_ selectedCountry: SelectedCountry)
}

protocol BuySellListViewModel: AnyObject {
  var didUpdateSegmentedControl: ((BuySellListSegmentedControl.Model?) -> Void)? { get set }
  var didUpdateState: ((BuySellListViewController.State) -> Void)? { get set }
  var didUpdateSnapshot: ((BuySellListViewController.Snapshot) -> Void)? { get set }
  var didUpdateHeaderLeftButton: ((TKPullCardHeaderItem.LeftButton) -> Void)? { get set }
  
  func viewDidLoad()
  func getCellConfiguration(identifier: String) -> AnyHashable
  func selectTab(index: Int)
  func selecteItem(_ item: BuySellListItem)
}

final class BuySellListViewModelImplementation: BuySellListViewModel, BuySellListModuleOutput, BuySellListModuleInput {
  
  enum Tab: CaseIterable {
    case buy
    case sell
  }
  
  enum SectionExpandState {
    case collapsed
    case expanded
  }
  
  var didSelectURL: ((URL) -> Void)?
  var didSelectItem: ((BuySellItem) -> Void)?
  var didSelectCountryPicker: ((SelectedCountry) -> Void)?
  
  func setSelectedCountry(_ selectedCountry: SelectedCountry) {
    self.selectedCountry = selectedCountry
    if case let .country(countryCode) = selectedCountry {
      appSettings.selectedCountryCode = countryCode
    } else {
      appSettings.selectedCountryCode = nil
    }
    updateCountryPickerButton()
    categoryExpandStates = [:]
    switch fiatMethodsState {
    case .loading:
      break
    case .none:
      updateList(fiatMethods: nil)
    case .fiatMethods(let fiatMethods):
      updateList(fiatMethods: fiatMethods)
    }
  }
  
  // MARK: - BuySellListViewModel
  
  var didUpdateSegmentedControl: ((BuySellListSegmentedControl.Model?) -> Void)?
  var didUpdateState: ((BuySellListViewController.State) -> Void)?
  var didUpdateSnapshot: ((BuySellListViewController.Snapshot) -> Void)?
  var didUpdateHeaderLeftButton: ((TKPullCardHeaderItem.LeftButton) -> Void)?
  
  func viewDidLoad() {
    if let selectedCountryCode = appSettings.selectedCountryCode {
      self.selectedCountry = .country(countryCode: selectedCountryCode)
    }
    
    fiatMethodsStore.addObserver(self) { observer, event in
      DispatchQueue.main.async {
        switch event {
        case .didUpdateState(let state):
          observer.fiatMethodsState = state
        }
      }
    }
    
    fiatMethodsState = fiatMethodsStore.getState()
    
    updateCountryPickerButton()
  }
  
  func getCellConfiguration(identifier: String) -> AnyHashable {
    cellModels[identifier]
  }
  
  func selectTab(index: Int) {
    let allTabs = Tab.allCases
    guard index < allTabs.count else { return }
    activeTab = allTabs[index]
  }
  
  func selecteItem(_ item: BuySellListItem) {
    switch item {
    case .item(let identifier):
      cellModels[identifier]?.selectionClosure?()
    default:
      break
    }
  }
  
  // MARK: - State
  
  private var snapshot = BuySellListViewController.Snapshot() {
    didSet {
      self.didUpdateSnapshot?(snapshot)
    }
  }
  private var cellModels = [String: TKUIListItemCell.Configuration]()
  private var fiatMethodsState: FiatMethodsStore.State = .none {
    didSet {
      didUpdateFiatMethodsStoreState(fiatMethodsState)
    }
  }
  private var fiatMethods: FiatMethods?
  private var activeTab: Tab = .buy {
    didSet {
      didChangeTab()
    }
  }
  private var categoryExpandStates = [FiatMethodCategory: SectionExpandState]()
  private var selectedCountry: SelectedCountry = .auto

  // MARK: - Image Loader
  
  private let imageLoader = ImageLoader()
  
  // MARK: - Dependencies
  
  private let wallet: Wallet
  private let fiatMethodsStore: FiatMethodsStore
  private let walletsStore: WalletsStore
  private let currencyStore: CurrencyStore
  private let configurationStore: ConfigurationStore
  private let appSettings: AppSettings
  
  // MARK: - Init
  
  init(wallet: Wallet,
       fiatMethodsStore: FiatMethodsStore,
       walletsStore: WalletsStore,
       currencyStore: CurrencyStore,
       configurationStore: ConfigurationStore,
       appSettings: AppSettings) {
    self.wallet = wallet
    self.fiatMethodsStore = fiatMethodsStore
    self.walletsStore = walletsStore
    self.currencyStore = currencyStore
    self.configurationStore = configurationStore
    self.appSettings = appSettings
  }
}

private extension BuySellListViewModelImplementation {
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
  
    didUpdateHeaderLeftButton?(
      TKPullCardHeaderItem.LeftButton(
        model: TKUIHeaderTitleIconButton.Model(title: title),
        action: { [weak self] in
          guard let self else { return }
          self.didSelectCountryPicker?(selectedCountry)
        }
      )
    )
  }
  
  func didChangeTab() {
    switch fiatMethodsState {
    case .loading:
      break
    case .none:
      updateList(fiatMethods: nil)
    case .fiatMethods(let fiatMethods):
      updateList(fiatMethods: fiatMethods)
    }
  }
  
  func didUpdateFiatMethodsStoreState(_ state: FiatMethodsStore.State) {
    categoryExpandStates = [:]
    switch state {
    case .loading:
      didUpdateState?(.loading)
      didUpdateSegmentedControl?(nil)
      fiatMethods = nil
    case .none:
      didUpdateSegmentedControl?(
        BuySellListSegmentedControl.Model(
          tabs: ["Buy", "Sell"]
        )
      )
      fiatMethods = nil
      didUpdateState?(.list)
    case .fiatMethods(let fiatMethods):
      self.fiatMethods = fiatMethods
      didUpdateSegmentedControl?(
        BuySellListSegmentedControl.Model(
          tabs: ["Buy", "Sell"]
        )
      )
      didUpdateState?(.list)
    }
    updateList(fiatMethods: fiatMethods)
  }

  func updateList(fiatMethods: FiatMethods?) {
    var cellModels = [String: TKUIListItemCell.Configuration]()
    
    for category in (fiatMethods?.buy ?? []) {
      for item in category.items {
        cellModels[item.id] = mapBuySellItem(item)
      }
    }
    for category in (fiatMethods?.sell ?? []) {
      for item in category.items {
        cellModels[item.id] = mapBuySellItem(item)
      }
    }
    self.cellModels = cellModels
    
    updateSnapshot(fiatMethods: fiatMethods)
  }
  
  func updateSnapshot(fiatMethods: FiatMethods?) {
    var snapshot = BuySellListViewController.Snapshot()
    
    defer {
      self.snapshot = snapshot
    }
    
    guard let fiatMethods else {
      return
    }
    
    let categories: [FiatMethodCategory]
    switch activeTab {
    case .buy:
      categories = fiatMethods.buy
    case .sell:
      categories = fiatMethods.sell
    }
    
    for category in categories {
      let assets = category.assets.map { UIImage(named: "Images/CryptoAssets/\($0)") }
      let section = BuySellListSection.items(
        id: category.hashValue,
        title: category.title,
        assets: assets
      )
      
      let filteredItems: [FiatMethodItem] = {
        switch selectedCountry {
        case .all:
          return category.items
        case .auto:
          let region = Locale.current.regionCode
          if let methods = fiatMethods.layoutByCountry
            .first(where: { $0.countryCode == region })?.methods {
            return category.items.filter { methods.contains($0.id) }
          } else {
            return category.items
          }
        case .country(let countryCode):
          if let methods = fiatMethods.layoutByCountry
            .first(where: { $0.countryCode == countryCode })?.methods {
            return category.items.filter { methods.contains($0.id) }
          } else {
            return category.items
          }
        }
      }()
      
      let expandedState: SectionExpandState? = categoryExpandStates[category] ?? (filteredItems.count > 4 ? .collapsed : nil)
      categoryExpandStates[category] = expandedState
      
      let resultItems: [FiatMethodItem]
      switch expandedState {
      case .expanded, .none:
        resultItems = filteredItems
      case .collapsed:
        resultItems = Array(filteredItems.prefix(4))
      }
      
      guard !resultItems.isEmpty else { continue }
      snapshot.appendSections([section])
      snapshot.appendItems(resultItems.map { .item(identifier: $0.id) }, toSection: section)
      
      switch expandedState {
      case .collapsed:
        var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
          category: .secondary,
          size: .small
        )
        buttonConfiguration.action = { [weak self] in
          self?.expandCategory(category)
        }
        buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Show all"))
        let buttonItem = BuySellListItem.button(
          TKButtonCell.Model(
            id: UUID().uuidString,
            configuration: buttonConfiguration,
            padding: UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0),
            mode: .widthToFit
          )
        )
        snapshot.appendSections([.button(id: category.hashValue)])
        snapshot.appendItems([buttonItem], toSection: .button(id: category.hashValue))
        
      case .expanded:
        var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
          category: .secondary,
          size: .small
        )
        buttonConfiguration.action = { [weak self] in
          self?.collapseCategory(category)
        }
        buttonConfiguration.content = TKButton.Configuration.Content(title: .plainString("Hide"))
        let buttonItem = BuySellListItem.button(
          TKButtonCell.Model(
            id: UUID().uuidString,
            configuration: buttonConfiguration,
            padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 0),
            mode: .widthToFit
          )
        )
        snapshot.appendSections([.button(id: category.hashValue)])
        snapshot.appendItems([buttonItem], toSection: .button(id: category.hashValue))
        
      case .none:
        break
      }
    }
    
    snapshot.reloadItems(snapshot.itemIdentifiers)
  }
  
  func expandCategory(_ category: FiatMethodCategory) {
    categoryExpandStates[category] = .expanded
    updateSnapshot(fiatMethods: fiatMethods)
  }
  
  func collapseCategory(_ category: FiatMethodCategory) {
    categoryExpandStates[category] = .collapsed
    updateSnapshot(fiatMethods: fiatMethods)
  }
  
  func mapBuySellItem(_ item: FiatMethodItem) -> TKUIListItemCell.Configuration {
    let iconConfigurationImage: TKUIListItemImageIconView.Configuration.Image = .asyncImage(item.iconURL, TKCore.ImageDownloadTask(
      closure: {
        [imageLoader] imageView,
        size,
        cornerRadius in
        return imageLoader.loadImage(
          url: item.iconURL,
          imageView: imageView,
          size: size,
          cornerRadius: cornerRadius
        )
      }
    ))
    
    let iconConfiguration = TKUIListItemIconView.Configuration(
      iconConfiguration: .image(
        .init(
          image: iconConfigurationImage,
          tintColor: .clear,
          backgroundColor: .clear,
          size: CGSize(width: 44, height: 44),
          cornerRadius: 12
        )
      ),
      alignment: .center
    )
    
    let title = item.title.withTextStyle(
      .label1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byTruncatingTail
    )
    let description = item.description?.withTextStyle(
      .body2,
      color: .Text.secondary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    
    let leftItemConfiguration = TKUIListItemContentLeftItem.Configuration(
      title: title,
      tagViewModel: nil,
      subtitle: nil,
      description: description,
      descriptionNumberOfLines: 0
    )
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: iconConfiguration,
      contentConfiguration: TKUIListItemContentView.Configuration(
        leftItemConfiguration: leftItemConfiguration,
        rightItemConfiguration: nil
      ),
      accessoryConfiguration: .image(
        .init(
          image: .TKUIKit.Icons.Size16.chevronRight,
          tintColor: .Text.tertiary,
          padding: .zero
        )
      )
    )
    
    return TKUIListItemCell.Configuration(
      id: item.id,
      listItemConfiguration: listItemConfiguration,
      selectionClosure: {
        [weak self] in
        guard let self else { return }
        Task {
          do {
            let currency = await self.currencyStore.getState()
            let walletAddress = try self.wallet.friendlyAddress
            let mercuryoSecret = try? await self.configurationStore.getConfiguration().mercuryoSecret
            guard let url = item.actionURL(
              walletAddress: walletAddress,
              currency: currency,
              mercuryoSecret: mercuryoSecret
            ) else { return }
            await MainActor.run {
              if self.appSettings.isBuySellItemMarkedDoNotShowWarning(item.id) {
                self.didSelectURL?(url)
              } else {
                let buySellItem = BuySellItem(fiatItem: item, actionUrl: url)
                self.didSelectItem?(buySellItem)
              }
            }
          } catch {
            return
          }
        }
      }
    )
  }
}

