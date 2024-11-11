import Foundation
import TKUIKit
import UIKit
import KeeperCore
import TKLocalize
import TonSwift

protocol WalletsListModuleOutput: AnyObject {
  var addButtonEvent: (() -> Void)? { get set }
  var didSelectWallet: (() -> Void)? { get set }
  var didTapEditWallet: ((Wallet) -> Void)? { get set }
}

protocol WalletsListViewModel: AnyObject {
  var didUpdateSnapshot: ((_ snapshot: WalletsListViewController.Snapshot) -> Void)? { get set }
  var didUpdateWaletCellConfiguration: ((_ item: WalletsListViewController.Item, _ configuration: TKListItemCell.Configuration) -> Void)? { get set }
  var selectedWalletIndex: Int? { get }
  var didUpdateIsEditing: ((Bool) -> Void)? { get set }
  var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)? { get set }
  
  func viewDidLoad()
  func getWalletCellConfiguration(identifier: String) -> TKListItemCell.Configuration?
  func moveWallet(fromIndex: Int, toIndex: Int)
}

final class WalletsListViewModelImplementation: WalletsListViewModel, WalletsListModuleOutput {
  
  // MARK: - WalletsListModuleOutput
  
  var addButtonEvent: (() -> Void)?
  var didSelectWallet: (() -> Void)?
  var didTapEditWallet: ((Wallet) -> Void)?
  
  // MARK: - WalletsListViewModel
  
  var didUpdateSnapshot: ((_ snapshot: WalletsListViewController.Snapshot) -> Void)?
  var didUpdateWaletCellConfiguration: ((WalletsListViewController.Item, TKListItemCell.Configuration) -> Void)?
  var didUpdateIsEditing: ((Bool) -> Void)?
  var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  
  func viewDidLoad() {
    balanceLoader.loadAllWalletsBalance()
    didUpdateHeaderItem?(createHeaderItem())
    setupInitialState()
    startObservations()
  }
  
  func getWalletCellConfiguration(identifier: String) -> TKListItemCell.Configuration? {
    walletCellsConfigurations[identifier]
  }
  

  func moveWallet(fromIndex: Int, toIndex: Int) {
    self.model.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
  }

  // MARK: - State

  private var walletCellsConfigurations = [String: TKListItemCell.Configuration]()
  private var isEditing = false {
    didSet {
      didUpdateIsEditing?(isEditing)
      didUpdateHeaderItem?(createHeaderItem())
    }
  }
  private let syncQueue = DispatchQueue(label: "WalletsListViewModelImplementationSyncQueue")
  var selectedWalletIndex: Int?

  // MARK: - Dependencies
  
  private let model: WalletsListModel
  private let balanceLoader: BalanceLoader
  private let totalBalancesStore: TotalBalanceStore
  private let appSettingsStore: AppSettingsStore
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(model: WalletsListModel,
       balanceLoader: BalanceLoader,
       totalBalancesStore: TotalBalanceStore,
       appSettingsStore: AppSettingsStore,
       decimalAmountFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter) {
    self.model = model
    self.balanceLoader = balanceLoader
    self.totalBalancesStore = totalBalancesStore
    self.appSettingsStore = appSettingsStore
    self.decimalAmountFormatter = decimalAmountFormatter
    self.amountFormatter = amountFormatter
  }
}

private extension WalletsListViewModelImplementation {
  func setupInitialState() {
    let state = model.getState()
    let totalBalanceState = totalBalancesStore.getState()
    let isSecureMode = appSettingsStore.getState().isSecureMode
    let (snapshot, cellConfigurations) = updateList(wallets: state.wallets, totalBalanceState: totalBalanceState, isSecureMode: isSecureMode)
    self.walletCellsConfigurations = cellConfigurations
    self.selectedWalletIndex = state.selectedWallet
    self.didUpdateSnapshot?(snapshot)
  }
  
  func startObservations() {
    model.didUpdateState = { [weak self] walletsState in
      self?.didUpdateWalletsState(walletsState: walletsState)
    }
    totalBalancesStore.addObserver(self) { observer, event in
      observer.didGetTotalBalanceStoreEvent(event)
    }
  }
  
  private func updateList(wallets: [Wallet],
                          totalBalanceState: TotalBalanceStore.State,
                          isSecureMode: Bool) -> (WalletsListViewController.Snapshot, [String: TKListItemCell.Configuration]) {
    var snapshot = WalletsListViewController.Snapshot()
    
    var cellConfigurations = [String: TKListItemCell.Configuration]()
    var items = [WalletsListItem]()
    for wallet in wallets {
      let cellConfiguration = createWalletCellConfiguration(wallet: wallet, totalBalanceState: totalBalanceState[wallet], isSecure: isSecureMode)
      cellConfigurations[wallet.id] = cellConfiguration
      items.append(createItem(wallet: wallet))
    }
    
    let footerConfiguration = TKListCollectionViewButtonFooterView.Configuration(
      identifier: .walletsFooterIdentifier,
      content: TKButton.Configuration.Content(title: .plainString(TKLocales.AddWallet.title)),
      action: { [weak self] in
        self?.addButtonEvent?()
      }
    )
    let section = WalletsListSection.wallets(footerConfiguration: footerConfiguration)
    snapshot.appendSections([section])
    snapshot.appendItems(items, toSection: section)
    
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    
    return (snapshot, cellConfigurations)
  }
  
  private func createItem(wallet: Wallet) -> WalletsListItem {
    WalletsListItem(
      identifier: wallet.id,
      accessories: [],
      selectAccessories: [
        TKListItemAccessory.icon(
          TKListItemIconAccessoryView.Configuration(
            icon: .TKUIKit.Icons.Size28.donemarkOutline,
            tintColor: .Accent.blue
          )
        )
      ],
      editingAccessories: [
        TKListItemAccessory.icon(
          TKListItemIconAccessoryView.Configuration(
            icon: .TKUIKit.Icons.Size28.pencilOutline,
            tintColor: .Icon.tertiary,
            action: {
              [weak self] in
              self?.didTapEditWallet?(
                wallet
              )
            })
        ),
        TKListItemAccessory.icon(
          TKListItemIconAccessoryView.Configuration(
            icon: .TKUIKit.Icons.Size28.reorder,
            tintColor: .Icon.secondary
          )
        )
      ]
    ) { [weak self] in
        self?.model.selectWallet(wallet: wallet)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        self?.didSelectWallet?()
      }
  }
  
  private func createWalletCellConfiguration(wallet: Wallet, totalBalanceState: TotalBalanceState?, isSecure: Bool) -> TKListItemCell.Configuration {
    let titleViewConfiguration = TKListItemTitleView.Configuration(
      title: wallet.label,
      tags: wallet.listTagConfigurations()
    )
    
    let caption: String
    if isSecure {
      caption = .secureModeValueShort
    } else if let totalBalance = totalBalanceState?.totalBalance {
     caption = decimalAmountFormatter.format(
        amount: totalBalance.amount,
        maximumFractionDigits: 2,
        currency: totalBalance.currency
      )
    } else {
      caption = "---"
    }
    
    var captionViewsConfigurations = [TKListItemTextView.Configuration]()
    captionViewsConfigurations.append(TKListItemTextView.Configuration(text: caption, color: .Text.secondary, textStyle: .body2))

    let iconContent: TKListItemIconView.Configuration.Content
    switch wallet.icon {
    case .emoji(let emoji):
      iconContent = .text(TKListItemIconView.Configuration.TextContent(text: emoji))
    case .icon(let image):
      iconContent = .image(TKImageView.Model(image: .image(image.image), tintColor: .white, size: .size(CGSize(width: 22, height: 22))))
    }
    
    return TKListItemCell.Configuration(
      listItemContentViewConfiguration: TKListItemContentView.Configuration(
        iconViewConfiguration: TKListItemIconView.Configuration(
          content: iconContent,
          alignment: .center,
          cornerRadius: 22,
          backgroundColor: wallet.tintColor.uiColor,
          size: CGSize(width: 44, height: 44)
        ),
        textContentViewConfiguration: TKListItemTextContentView.Configuration(
          titleViewConfiguration: titleViewConfiguration,
          captionViewsConfigurations: captionViewsConfigurations
        )
      )
    )
  }
  
  func didUpdateWalletsState(walletsState: WalletsListModelState) {
    syncQueue.async {
      let totalBalancesState = self.totalBalancesStore.getState()
      let isSecureMode = self.appSettingsStore.getState().isSecureMode
      let (snapshot, cellConfigurations) = self.updateList(wallets: walletsState.wallets, totalBalanceState: totalBalancesState, isSecureMode: isSecureMode)
      DispatchQueue.main.async {
        self.selectedWalletIndex = walletsState.selectedWallet
        self.walletCellsConfigurations = cellConfigurations
        self.didUpdateSnapshot?(snapshot)
      }
    }
  }
  
  func didGetTotalBalanceStoreEvent(_ event: TotalBalanceStore.Event) {
    switch event {
    case .didUpdateTotalBalance(let wallet):
      syncQueue.async { [weak self] in
        guard let self else { return }
        guard let wallet = model.getWallet(id: wallet.id) else { return }
        let totalBalanceState = self.totalBalancesStore.getState()[wallet]
        let isSecure = self.appSettingsStore.getState().isSecureMode
        self.didUpdateTotalBalancesState(state: totalBalanceState, wallet: wallet, isSecure: isSecure)
      }
    }
  }
  
  func didAppSettingsStoreEvent(_ event: AppSettingsStore.Event) {
    switch event {
    case .didUpdateIsSecureMode:
      syncQueue.async {
        let wallets = self.model.getState().wallets
        let totalBalanceState = self.totalBalancesStore.getState()
        let isSecure = self.appSettingsStore.getState().isSecureMode
        for wallet in wallets {
          self.didUpdateTotalBalancesState(state: totalBalanceState[wallet], wallet: wallet, isSecure: isSecure)
        }
      }
    default: break
    }
  }
  
  func didUpdateTotalBalancesState(state: TotalBalanceState?, wallet: Wallet, isSecure: Bool) {
    let cellConfiguration = createWalletCellConfiguration(wallet: wallet, totalBalanceState: state, isSecure: isSecure)
    let item = createItem(wallet: wallet)
    DispatchQueue.main.async {
      self.walletCellsConfigurations[wallet.id] = cellConfiguration
      self.didUpdateWaletCellConfiguration?(item, cellConfiguration) 
    }
  }
  
  func createHeaderItem() -> TKPullCardHeaderItem {
    let leftButtonModel = TKUIHeaderTitleIconButton.Model(
      title: isEditing ? TKLocales.Actions.done: TKLocales.Actions.edit
    )
    var leftButton: TKPullCardHeaderItem.LeftButton?
    if model.isEditable {
      leftButton = TKPullCardHeaderItem.LeftButton(
        model: leftButtonModel) { [weak self] in
          self?.isEditing.toggle()
        }
    }
    
    return TKPullCardHeaderItem(
      title: .title(title: TKLocales.WalletsList.title, subtitle: nil),
      leftButton: leftButton)
  }
}

private extension String {
  static let walletsFooterIdentifier = "WalletsFooterIdentifier"
}
