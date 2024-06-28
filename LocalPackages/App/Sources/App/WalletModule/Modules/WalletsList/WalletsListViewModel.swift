import Foundation
import TKUIKit
import UIKit
import KeeperCore
import TKLocalize

protocol WalletsListModuleOutput: AnyObject {
  var didTapAddWalletButton: (() -> Void)? { get set }
  var didSelectWallet: (() -> Void)? { get set }
  var didTapEditWallet: ((Wallet) -> Void)? { get set }
}

protocol WalletsListViewModel: AnyObject {
  var didUpdateItems: (([TKUIListItemCell.Configuration]) -> Void)? { get set }
  var didUpdateSelected: ((Int?) -> Void)? { get set }
  var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)? { get set }
  var didUpdateIsEditing: ((Bool) -> Void)? { get set }
  var didUpdateFooterModel: ((WalletsListFooterView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func moveWallet(fromIndex: Int, toIndex: Int)
  func didTapEdit(index: Int)
}

final class WalletsListViewModelImplementation: WalletsListViewModel, WalletsListModuleOutput {
  
  // MARK: - WalletsListModuleOutput
  
  var didTapAddWalletButton: (() -> Void)?
  var didSelectWallet: (() -> Void)?
  var didTapEditWallet: ((Wallet) -> Void)?
    
  // MARK: - WalletsListViewModel
  
  var didUpdateItems: (([TKUIListItemCell.Configuration]) -> Void)?
  var didUpdateSelected: ((Int?) -> Void)?
  var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var didUpdateIsEditing: ((Bool) -> Void)?
  var didUpdateFooterModel: ((WalletsListFooterView.Model) -> Void)?
  
  func viewDidLoad() {
    walletListController.didUpdateState = { [weak self] model in
      guard let self else { return }
      Task { @MainActor in
        self.model = model
      }
    }
    Task {
      await walletListController.start()
    }
    
    didUpdateFooterModel?(createFooterModel())
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) {
    Task {
      await walletListController.moveWallet(from: fromIndex, to: toIndex)
    }
  }
  
  func didTapEdit(index: Int) {
    Task {
      guard let wallet = await walletListController.getWallet(at: index) else { return }
      await MainActor.run {
        didTapEditWallet?(wallet)
      }
    }
  }
  
  // MARK: - State
  
  private var model = WalletListController.Model(items: [],
                                                 selectedIndex: nil,
                                                 isEditable: false) {
    didSet {
      didUpdateModel(model)
    }
  }

  private var isEditing = false {
    didSet {
      updateHeaderItem()
      didUpdateIsEditing?(isEditing)
      didUpdateSelected?(selectedIndex)
    }
  }
  
  private var selectedIndex: Int?

  // MARK: - Dependencies
  
  private let walletListController: WalletListController
  
  init(walletListController: WalletListController) {
    self.walletListController = walletListController
  }
}

private extension WalletsListViewModelImplementation {
  func didUpdateModel(_ model: WalletListController.Model) {
    let cellItems = createListItems(items: model.items)
    selectedIndex = model.selectedIndex
    updateHeaderItem()
    didUpdateItems?(cellItems)
    didUpdateSelected?(model.selectedIndex)
  }
  
  func didSelectAt(index: Int?) {
    Task { @MainActor in
      didUpdateSelected?(index)
    }
  }
  
  func updateHeaderItem() {
    didUpdateHeaderItem?(createHeaderItem())
  }
  
  func createListItems(items: [WalletListController.ItemModel]) -> [TKUIListItemCell.Configuration] {
    let isHighligtable = items.count > 1
    return items.map { createListItem(item: $0, isHighlightable: isHighligtable) }
  }
  
  func createListItem(item: WalletListController.ItemModel,
                      isHighlightable: Bool) -> TKUIListItemCell.Configuration {
    let listItemConfiguration = TKUIListItemView.Configuration.configuration(
      wallet: item.wallet,
      subtitle: item.totalBalance,
      accessoryConfiguration: .none
    )
    
    return TKUIListItemCell.Configuration(
      id: item.id,
      listItemConfiguration: listItemConfiguration,
      isHighlightable: isHighlightable,
      selectionClosure: { [weak self] in
        guard let self = self else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        self.didSelectWallet?()
        Task { await self.walletListController.selectWallet(identifier: item.id) }
      }
    )
  }
  
  func createHeaderItem() -> TKPullCardHeaderItem {
    var leftButton: TKPullCardHeaderItem.LeftButton?
    if model.isEditable {
      let leftButtonModel = TKUIHeaderTitleIconButton.Model(
        title: isEditing ? TKLocales.Actions.done: TKLocales.Actions.edit
      )
      leftButton = TKPullCardHeaderItem.LeftButton(
        model: leftButtonModel) { [weak self] in
          self?.isEditing.toggle()
        }
    }
    return TKPullCardHeaderItem(
      title: TKLocales.WalletsList.title,
      leftButton: leftButton)
  }
  
  func createFooterModel() -> WalletsListFooterView.Model {
    WalletsListFooterView.Model(
      content: TKButton.Configuration.Content(title: .plainString(TKLocales.WalletsList.add_wallet))) { [weak self] in
        self?.didTapAddWalletButton?()
      }
  }
}
