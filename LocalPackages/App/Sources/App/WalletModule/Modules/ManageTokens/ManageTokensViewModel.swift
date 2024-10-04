import Foundation
import TKUIKit
import UIKit
import KeeperCore
import TKLocalize
import TonSwift

protocol ManageTokensModuleOutput: AnyObject {
  
}

protocol ManageTokensViewModel: AnyObject {
  var didUpdateSnapshot: ((_ snapshot: ManageTokensViewController.Snapshot,
                           _ isAnimated: Bool) -> Void)? { get set }
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
  
  func viewDidLoad()
  func getItemCellConfiguration(item: ManageTokensListItem) -> TKListItemCell.Configuration?
  func didStartDragging()
  func didStopDragging()
  func movePinnedItem(from: Int, to: Int)
}

enum ManageTokensItemState {
  case pinned
  case unpinned(isHidden: Bool)
}

struct ManagerTokensItemCellModel {
  let configuration: TKUIListItemCell.Configuration
  let state: ManageTokensItemState
}

final class ManageTokensViewModelImplementation: ManageTokensViewModel, ManageTokensModuleOutput {
  
  struct ListModel {
    let snapshot: ManageTokensViewController.Snapshot
    let itemCellConfigurations: [ManageTokensListItem: TKListItemCell.Configuration]
  }
  
  //  // MARK: - ManageTokensModuleOutput
  
  //  // MARK: - ManageTokensViewModel
  
  var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
  var didUpdateSnapshot: ((ManageTokensViewController.Snapshot, Bool) -> Void)?
  
  func viewDidLoad() {
    didUpdateTitleView?(TKUINavigationBarTitleView.Model(
      title: TKLocales.HomeScreenConfiguration.title)
    )
    
    model.didUpdateState = { [weak self] state in
      guard let self else { return }
      Task {
        await self.actor.addTask(block:{
          guard !self.isDragging else { return }
          let listModel = self.handleState(state: state)
          await MainActor.run {
            self.listModel = listModel
            self.didUpdateSnapshot?(listModel.snapshot, false)
          }
        })
      }
    }
    
    let state = model.getState()
    let listModel = self.handleState(state: state)
    self.listModel = listModel
    self.didUpdateSnapshot?(listModel.snapshot, false)
  }
  
  func getItemCellConfiguration(item: ManageTokensListItem) -> TKListItemCell.Configuration? {
    listModel.itemCellConfigurations[item]
  }
  
  func didStartDragging() {
    Task {
      await actor.addTask {
        self.isDragging = true
      }
    }
  }
  
  func didStopDragging() {
    Task {
      await actor.addTask {
        self.isDragging = false
      }
    }
  }
  
  func movePinnedItem(from: Int, to: Int) {
    model.movePinnedItem(from: from, to: to)
  }
  
  // MARK: - State
  
  private var listModel = ListModel(snapshot: ManageTokensViewController.Snapshot(),
                                    itemCellConfigurations: [:])
  
  private let actor = SerialActor<Void>()
  private var isDragging = false {
    didSet {
      guard !isDragging else { return }
      Task {
        let state = await model.getState()
        let listModel = self.handleState(state: state)
        await MainActor.run {
          self.listModel = listModel
          self.didUpdateSnapshot?(listModel.snapshot, false)
        }
      }
    }
  }
  
  // MARK: - Dependencies
  
  private let model: ManageTokensModel
  private let mapper: ManageTokensListMapper
  
  // MARK: - Init
  
  init(model: ManageTokensModel,
       mapper: ManageTokensListMapper) {
    self.model = model
    self.mapper = mapper
  }
}

private extension ManageTokensViewModelImplementation {
  func handleState(state: ManageTokensModel.State) -> ListModel {
    var snapshot = ManageTokensViewController.Snapshot()
    var itemCellConfigurations = [ManageTokensListItem: TKListItemCell.Configuration]()
    
    snapshot.appendSections([.pinned, .allAssets])
    
    state.pinnedItems.forEach { pinnedItem in
      switch pinnedItem {
      case .ton(let ton):
        let cellConfiguration = mapper.mapTonItem(ton)
        let item = ManageTokensListItem(
          identifier: ton.id,
          canReorder: true,
          accessories: createPinnedItemAccessories(identifier: ton.id)
        )
        itemCellConfigurations[item] = cellConfiguration
        snapshot.appendItems([item], toSection: .pinned)
      case .jetton(let jetton):
        let cellConfiguration = mapper.mapJettonItem(jetton)
        let item = ManageTokensListItem(
          identifier: jetton.id,
          canReorder: true,
          accessories: createPinnedItemAccessories(identifier: jetton.id)
        )
        itemCellConfigurations[item] = cellConfiguration
        snapshot.appendItems([item], toSection: .pinned)
      case .staking(let staking):
        let cellConfiguration = mapper.mapStakingItem(staking)
        let item = ManageTokensListItem(
          identifier: staking.id,
          canReorder: true,
          accessories: createPinnedItemAccessories(identifier: staking.id)
        )
        itemCellConfigurations[item] = cellConfiguration
        snapshot.appendItems([item], toSection: .pinned)
      }
    }
    state.unpinnedItems.forEach { unpinnedItem in
      switch unpinnedItem.item {
      case .ton(let ton):
        let cellConfiguration = mapper.mapTonItem(ton)
        let item = ManageTokensListItem(
          identifier: ton.id,
          canReorder: false,
          accessories: createUnpinnedItemAccessories(identifier: ton.id, isHidden: unpinnedItem.isHidden)
        )
        itemCellConfigurations[item] = cellConfiguration
        snapshot.appendItems([item], toSection: .allAssets)
      case .jetton(let jetton):
        let cellConfiguration = mapper.mapJettonItem(jetton)
        let item = ManageTokensListItem(
          identifier: jetton.id,
          canReorder: false,
          accessories: createUnpinnedItemAccessories(identifier: jetton.id, isHidden: unpinnedItem.isHidden)
        )
        itemCellConfigurations[item] = cellConfiguration
        snapshot.appendItems([item], toSection: .allAssets)
      case .staking(let staking):
        let cellConfiguration = mapper.mapStakingItem(staking)
        let item = ManageTokensListItem(
          identifier: staking.id,
          canReorder: false,
          accessories: createUnpinnedItemAccessories(identifier: staking.id, isHidden: unpinnedItem.isHidden)
        )
        itemCellConfigurations[item] = cellConfiguration
        snapshot.appendItems([item], toSection: .allAssets)
      }
    }
    
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    
    let listModel = ListModel(
      snapshot: snapshot,
      itemCellConfigurations: itemCellConfigurations
    )
    return listModel
  }
  
  private func createPinnedItemAccessories(identifier: String) -> [TKListItemAccessory] {
    return [
      TKListItemAccessory.icon(
        TKListItemIconAccessoryView.Configuration(
          icon: .TKUIKit.Icons.Size28.pin,
          tintColor: .Accent.blue,
          action: { [weak self] in
            self?.model.unpinItem(identifier: identifier)
          }
        )
      ),
      TKListItemAccessory.icon(
        TKListItemIconAccessoryView.Configuration(
          icon: .TKUIKit.Icons.Size28.reorder,
          tintColor: .Icon.secondary
        )
      )
    ]
  }
  
  private func createUnpinnedItemAccessories(identifier: String, isHidden: Bool) -> [TKListItemAccessory] {
    if isHidden {
      return [.icon(
        TKListItemIconAccessoryView.Configuration(
          icon: .TKUIKit.Icons.Size28.eyeClosedOutline,
          tintColor: .Icon.tertiary,
          action: { [weak self] in
            self?.model.unhideItem(identifier: identifier)
          }
        )
      )]
    } else {
      return [
        .icon(
          TKListItemIconAccessoryView.Configuration(
            icon: .TKUIKit.Icons.Size28.pin,
            tintColor: .Icon.tertiary,
            action: { [weak self] in
              self?.model.pinItem(identifier: identifier)
            }
          )
        ),
        .icon(
          TKListItemIconAccessoryView.Configuration(
            icon: .TKUIKit.Icons.Size28.eyeOutline,
            tintColor: .Accent.blue,
            action: { [weak self] in
              self?.model.hideItem(identifier: identifier)
            }
          )
        )
      ]
    }
  }
}

extension TKUIListItemAccessoryView.Configuration {
  static var chevron: TKUIListItemAccessoryView.Configuration {
    .image(
      TKUIListItemImageAccessoryView.Configuration(
        image: .TKUIKit.Icons.Size16.chevronRight,
        tintColor: .Text.tertiary,
        padding: .zero
      )
    )
  }
}
