import Foundation
import TKUIKit
import UIKit
import KeeperCore

protocol WalletsListModuleOutput: AnyObject {
  var didTapAddWalletButton: (() -> Void)? { get set }
  var didSelectWallet: (() -> Void)? { get set }
}

protocol WalletsListViewModel: AnyObject {
  var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)? { get set }
  var didUpdateItems: (([TKCollectionItemIdentifier]) -> Void)? { get set }
  var didUpdateSelectedItem: ((Int?, Bool) -> Void)? { get set }
  var didUpdateFooterModel: ((WalletsListFooterView.Model) -> Void)? { get set }
  var didUpdateIsEditing: ((Bool) -> Void)? { get set }
  
  func viewDidLoad()
  func moveWallet(fromIndex: Int, toIndex: Int)
}

final class WalletsListViewModelImplementation: WalletsListViewModel, WalletsListModuleOutput {
  
  // MARK: - WalletsListModuleOutput
  
  var didTapAddWalletButton: (() -> Void)?
  var didSelectWallet: (() -> Void)?
    
  // MARK: - WalletsListViewModel
  
  var didUpdateHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var didUpdateItems: (([TKCollectionItemIdentifier]) -> Void)?
  var didUpdateSelectedItem: ((Int?, Bool) -> Void)?
  var didUpdateFooterModel: ((WalletsListFooterView.Model) -> Void)?
  var didUpdateIsEditing: ((Bool) -> Void)?
  
  func viewDidLoad() {
    setupWalletListControllerBindings()
    didUpdateFooterModel?(createFooterModel())
    didUpdateHeaderItem?(createHeaderItem())
    didUpdateItems?(createListItems())
    didUpdateSelectedItem?(getSelectedItemIndex(), false)
  }
  
  func moveWallet(fromIndex: Int, toIndex: Int) {
    walletListController.moveWallet(fromIndex: fromIndex, toIndex: toIndex)
  }
  
  // MARK: - State
  
  private var isEditing = false {
    didSet {
      didUpdateIsEditing?(isEditing)
      didUpdateHeaderItem?(createHeaderItem())
      if !isEditing {
        didUpdateSelectedItem?(getSelectedItemIndex(), true)
      }
    }
  }

  // MARK: - Dependencies
  
  private let walletListController: WalletListController
  
  init(walletListController: WalletListController) {
    self.walletListController = walletListController
  }
}

private extension WalletsListViewModelImplementation {
  func setupWalletListControllerBindings() {
    walletListController.didUpdateWallets = { [weak self] in
      guard let self = self else { return }
      self.didUpdateItems?(self.createListItems())
      self.didUpdateHeaderItem?(self.createHeaderItem())
    }
    
    walletListController.didUpdateActiveWallet = { [weak self] in
      guard let self = self else { return }
      self.didUpdateSelectedItem?(self.getSelectedItemIndex(), false)
      self.didSelectWallet?()
    }
  }
  
  func createHeaderItem() -> TKPullCardHeaderItem {
    var leftButton: TKPullCardHeaderItem.LeftButton?
    if walletListController.walletsModels.count > 1 {
      let leftButtonModel = TKUIHeaderTitleIconButton.Model(title: isEditing ? "Done": "Edit")
      leftButton = TKPullCardHeaderItem.LeftButton(
        model: leftButtonModel) { [weak self] in
          self?.isEditing.toggle()
        }
    }
    return TKPullCardHeaderItem(
      title: "Wallets",
      leftButton: leftButton)
  }
  
  func createListItems() -> [TKCollectionItemIdentifier] {
    let models = walletListController.walletsModels
    let isSelectable = models.count > 1
    let items = models
      .enumerated()
      .map { index, walletModel in
        var tagModel: TKTagView.Model?
        if let tag = walletModel.tag {
          tagModel = TKTagView.Model(title: tag)
        }
        
        let listItemModel = TKListItemView.Model(
          iconModel: TKListItemIconView.Model(
            type: .emoji(
              model: TKListItemIconEmojiContentView.Model(
                emoji: walletModel.emoji,
                backgroundColor: .Tint.color(with: walletModel.colorIdentifier)
              )
            ),
            alignment: .top),
          textContentModel: TKListItemTextContentView.Model(
            textWithTagModel: TKTextWithTagView.Model(title: walletModel.name, tagViewModel: tagModel),
            subtitle: walletModel.balance
          )
        )
        
        let cellModel = TKCollectionItemIdentifier(
          identifier: walletModel.identifier,
          isSelectable: isSelectable,
          isReorderable: true,
          model: listItemModel) { [weak self] in
            guard isSelectable else { return }
            self?.walletListController.setWalletActive(with: walletModel.identifier)
          }
        return cellModel
      }
    return items
  }
  
  func getSelectedItemIndex() -> Int? {
    guard walletListController.walletsModels.count > 1 else { return nil }
    return walletListController.activeWalletIndex
  }
  
  func createFooterModel() -> WalletsListFooterView.Model {
    WalletsListFooterView.Model(
      addWalletButtonModel: TKUIHeaderTitleIconButton.Model(title: "Add Wallet"),
      addWalletButtonAction: { [weak self] in
        self?.didTapAddWalletButton?()
      }
    )
  }
}
