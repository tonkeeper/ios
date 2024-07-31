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
  var didUpdateSnapshot: ((_ snapshot: NSDiffableDataSourceSnapshot<WalletsListSection, WalletsListItem>,
                           _ completion: @escaping () -> Void) -> Void)? { get set }
  var didUpdateSelected: ((Int?) -> Void)? { get set }
  var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)? { get set }
  var didUpdateIsEditing: ((Bool) -> Void)? { get set }
  var didUpdateWalletItems: (([String: TKUIListItemCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
  func moveWallet(fromIndex: Int, toIndex: Int)
  func didTapEdit(item: WalletsListItem)
  func getItemModel(identifier: String) -> AnyHashable?
  func didSelectItem(_ item: WalletsListItem)
  func canReorderItem(_ item: WalletsListItem) -> Bool
  func didTapAddWalletButton()
}

final class WalletsListViewModelImplementation: WalletsListViewModel, WalletsListModuleOutput {
  
  // MARK: - WalletsListModuleOutput
  
  var addButtonEvent: (() -> Void)?
  var didSelectWallet: (() -> Void)?
  var didTapEditWallet: ((Wallet) -> Void)?
  
  // MARK: - WalletsListViewModel
  
  var didUpdateSnapshot: ((_ snapshot: NSDiffableDataSourceSnapshot<WalletsListSection, WalletsListItem>,
                           _ completion: @escaping () -> Void) -> Void)?
  var didUpdateSelected: ((Int?) -> Void)?
  var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var didUpdateIsEditing: ((Bool) -> Void)?
  var didUpdateWalletItems: (([String : TKUIListItemCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    setupInitialState()
    startObservations()
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) {
    self.model.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
  }
  
  func didTapEdit(item: WalletsListItem) {
    switch item {
    case .wallet(let identifier):
      guard let wallet = model.getWalletsState().wallets.first(where: { $0.id == identifier }) else { return }
      DispatchQueue.main.async {
        self.didTapEditWallet?(wallet)
      }
    default:
      return
    }
  }
  
  func getItemModel(identifier: String) -> AnyHashable? {
    switch identifier {
    case .addWalletButtonCellIdentifier:
      var configuration = TKButton.Configuration.actionButtonConfiguration(
        category: .secondary,
        size: .small
      )
      configuration.content = TKButton.Configuration.Content(
        title: .plainString(TKLocales.WalletsList.add_wallet)
      )
      configuration.action = { [weak self] in
        self?.addButtonEvent?()
      }
      return TKButtonCell.Model(
        id: "",
        configuration: configuration,
        padding: UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0),
        mode: .widthToFit
      )
    default:
      return cellModels[identifier]
    }
  }
  
  func didTapAddWalletButton() {
    addButtonEvent?()
  }
  
  func didSelectItem(_ item: WalletsListItem) {
    switch item {
    case .wallet(let identifier):
      guard let wallet = model.getWalletsState().wallets.first(where: { $0.id == identifier }) else {
        return
      }
      self.model.selectWallet(wallet: wallet)
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
      self.didSelectWallet?()
    case .addWalletButton:
      return
    }
  }
  
  func canReorderItem(_ item: WalletsListItem) -> Bool {
    switch item {
    case .wallet: return true && (walletsState?.wallets ?? []).count > 1
    default: return false
    }
  }
  
  // MARK: - State
  
  private let syncQueue = DispatchQueue(label: "WalletsListViewModelImplementationSyncQueue")
  private var cellModels = [String: AnyHashable]()
  private var walletsState: WalletsListModelState?
  private var isEditing = false {
    didSet {
      didUpdateIsEditing?(isEditing)
      didUpdateSelected?(isEditing ? nil : self.selectedIndex)
      updateHeaderItem()
    }
  }

  private var selectedIndex: Int? {
    didSet {
      didUpdateSelected?(selectedIndex)
    }
  }
  
  // MARK: - Dependencies
  
  private let model: WalletsListModel
  private let totalBalancesStore: TotalBalanceStore
  private let decimalAmountFormatter: DecimalAmountFormatter
  private let amountFormatter: AmountFormatter
  
  // MARK: - Init
  
  init(model: WalletsListModel,
       totalBalancesStore: TotalBalanceStore,
       decimalAmountFormatter: DecimalAmountFormatter,
       amountFormatter: AmountFormatter) {
    self.model = model
    self.totalBalancesStore = totalBalancesStore
    self.decimalAmountFormatter = decimalAmountFormatter
    self.amountFormatter = amountFormatter
  }
}

private extension WalletsListViewModelImplementation {
  func setupInitialState() {
    updateHeaderItem()
    
    let walletsState = model.getWalletsState()
    self.walletsState = walletsState
    updateList(walletsState: walletsState, totalBalancesState: [:]) { models, snapshot, selectedIndex in
      self.cellModels = models
      self.didUpdateSnapshot?(snapshot, {
        self.didUpdateSelected?(selectedIndex)
      })
    }
    syncQueue.async {
      let totalBalancesState = self.totalBalancesStore.getState()
      self.didUpdateTotalBalancesState(state: totalBalancesState, oldState: nil)
    }
  }
  
  func startObservations() {
    model.didUpdateWalletsState = { [weak self] walletsState in
      self?.syncQueue.async {
        self?.walletsState = walletsState
        self?.didUpdateWalletsState(walletsState: walletsState)
      }
    }
    
    totalBalancesStore.addObserver(self, notifyOnAdded: false) { observer, newState, oldState in
      observer.syncQueue.async {
        observer.didUpdateTotalBalancesState(state: newState, oldState: oldState)
      }
    }
  }
  
  func updateList(walletsState: WalletsListModelState,
                  totalBalancesState: [FriendlyAddress: TotalBalanceState],
                  completion: (_ models: [String: AnyHashable],
                               _ snapshot: NSDiffableDataSourceSnapshot<WalletsListSection, WalletsListItem>,
                               _ selectedIndex: Int?) -> Void) {
    var snapshot = NSDiffableDataSourceSnapshot<WalletsListSection, WalletsListItem>()
    snapshot.appendSections([.wallets, .addWallet])
    
    let isHighlightable = walletsState.wallets.count > 1
    var models = [String: AnyHashable]()
    walletsState.wallets.forEach { wallet in
      let totalBalance: TotalBalance? = {
        guard let address = try? wallet.friendlyAddress else {
          return nil
        }
        return totalBalancesState[address]?.totalBalance
      }()
      snapshot.appendItems([.wallet(wallet.id)], toSection: .wallets)
      models[wallet.id] = createWalletModel(
        wallet,
        totalBalance: totalBalance,
        isHighlightable: isHighlightable
      )
    }
    snapshot.appendItems([.addWalletButton(.addWalletButtonCellIdentifier)], toSection: .addWallet)
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    var selectedIndex: Int?
    if let selectedWallet = walletsState.selectedWallet,
       let index = walletsState.wallets.firstIndex(of: selectedWallet) {
      selectedIndex = index
    }

    completion(models, snapshot, selectedIndex)
  }
  
  func didUpdateWalletsState(walletsState: WalletsListModelState) {
    let totalBalancesState = self.totalBalancesStore.getState()
    self.updateList(walletsState: walletsState, totalBalancesState: totalBalancesState) { models, snapshot, selectedIndex in
      DispatchQueue.main.async {
        self.cellModels = models
        self.didUpdateSnapshot?(snapshot, {
          self.didUpdateSelected?(selectedIndex)
        })
      }
    }
  }
  
  func didUpdateTotalBalancesState(state: [FriendlyAddress: TotalBalanceState],
                                   oldState: [FriendlyAddress: TotalBalanceState]?) {
    guard let walletsState else { return }
    let isHighlightable = walletsState.wallets.count > 1
    var updatedModels = [String: TKUIListItemCell.Configuration]()
    for wallet in walletsState.wallets {
      guard let address = try? wallet.friendlyAddress,
            state[address]?.totalBalance != oldState?[address]?.totalBalance else {
        continue
      }
      
      let model = createWalletModel(
        wallet,
        totalBalance: state[address]?.totalBalance,
        isHighlightable: isHighlightable
      )
      updatedModels[wallet.id] = model
    }
    
    DispatchQueue.main.async {
      self.cellModels.merge(updatedModels) { $1 }
      self.didUpdateWalletItems?(updatedModels)
    }
  }
 
  func createWalletModel(_ wallet: Wallet,
                         totalBalance: TotalBalance?,
                         isHighlightable: Bool) -> TKUIListItemCell.Configuration {
    let subtitle: String
    if let totalBalance {
      subtitle = decimalAmountFormatter.format(
        amount: totalBalance.amount,
        maximumFractionDigits: 2,
        currency: totalBalance.currency
      )
    } else {
      subtitle = "-"
    }
    
    let contentConfiguration = TKUIListItemContentView.Configuration(
      leftItemConfiguration: TKUIListItemContentLeftItem.Configuration(
        title: wallet.label.withTextStyle(.label1, color: .Text.primary, alignment: .left),
        tagViewModel: wallet.listTagConfiguration(),
        subtitle: subtitle.withTextStyle(.body2, color: .Text.secondary, alignment: .left),
        description: nil
      ),
      rightItemConfiguration: nil
    )
    
    let iconConfiguration: TKUIListItemIconView.Configuration.IconConfiguration
    switch wallet.icon {
    case .emoji(let emoji):
      iconConfiguration = .emoji(TKUIListItemEmojiIconView.Configuration(
        emoji: emoji,
        backgroundColor: wallet.tintColor.uiColor
      ))
    case .icon(let image):
      iconConfiguration = .image(TKUIListItemImageIconView.Configuration(
        image: .image(image.image),
        tintColor: .white,
        backgroundColor: wallet.tintColor.uiColor,
        size: CGSize(width: 44, height: 44),
        cornerRadius: 22,
        contentMode: .scaleAspectFit,
        imageSize: CGSize(width: 22, height: 22)
      ))
    }
    
    let listItemConfiguration = TKUIListItemView.Configuration(
      iconConfiguration: TKUIListItemIconView.Configuration(
        iconConfiguration: iconConfiguration,
        alignment: .center
      ),
      contentConfiguration: contentConfiguration,
      accessoryConfiguration: TKUIListItemAccessoryView.Configuration.none
    )
    
    return TKUIListItemCell.Configuration(
      id: wallet.id,
      listItemConfiguration: listItemConfiguration,
      isHighlightable: isHighlightable,
      selectionClosure: nil
    )
  }
  
  func updateHeaderItem() {
    didUpdateHeaderItem?(createHeaderItem())
  }
  
  func createHeaderItem() -> TKPullCardHeaderItem {
    let leftButtonModel = TKUIHeaderTitleIconButton.Model(
      title: isEditing ? TKLocales.Actions.done: TKLocales.Actions.edit
    )
    let leftButton = TKPullCardHeaderItem.LeftButton(
      model: leftButtonModel) { [weak self] in
        self?.isEditing.toggle()
      }
    return TKPullCardHeaderItem(
      title: .title(title: TKLocales.WalletsList.title, subtitle: nil),
      leftButton: leftButton)
  }
}

private extension String {
  static let addWalletButtonCellIdentifier = "AddWalletButtonCellIdentifier"
}
