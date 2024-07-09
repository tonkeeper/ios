import Foundation
import TKUIKit
import UIKit
import KeeperCore
import TKLocalize
import TonSwift

protocol ManageTokensModuleOutput: AnyObject {

}

protocol ManageTokensViewModel: AnyObject {
  var didUpdateSnapshot: ((_ snapshot: NSDiffableDataSourceSnapshot<ManageTokensSection, ManageTokensItem>,
                           _ isAnimated: Bool) -> Void)? { get set }
  var didUpdateTitle: ((String) -> Void)? { get set }
  
  func viewDidLoad()
  func getItemModel(item: ManageTokensItem) -> ManagerTokensItemCellModel?
  func pinItem(item: ManageTokensItem)
  func unpinItem(item: ManageTokensItem)
  func hideItem(item: ManageTokensItem)
  func unhideItem(item: ManageTokensItem)
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
  
//  // MARK: - ManageTokensModuleOutput

//  // MARK: - ManageTokensViewModel
  
  var didUpdateTitle: ((String) -> Void)?
  var didUpdateSnapshot: ((_ snapshot: NSDiffableDataSourceSnapshot<ManageTokensSection, ManageTokensItem>,
                           _ isAnimated: Bool) -> Void)?

  func viewDidLoad() {
    didUpdateTitle?(TKLocales.HomeScreenConfiguration.title)
    
    model.didUpdateState = { [weak self] state in
      guard let self else { return }
      Task {
        await self.actor.addTask(block:{
          guard !self.isDragging else { return }
          await self.didUpdateState(state)
        })
      }
    }
    
    Task {
      await self.actor.addTask(block:{
        let state = self.model.getState()
        await self.handleState(state: state)
      })
    }
  }
  
  func getItemModel(item: ManageTokensItem) -> ManagerTokensItemCellModel? {
    itemModels[item]
  }
  
  func pinItem(item: ManageTokensItem) {
    Task {
      switch item {
      case .token(let identifier):
        await model.pinItem(identifier: identifier)
      }
    }
  }
  
  func unpinItem(item: ManageTokensItem) {
    Task {
      switch item {
      case .token(let identifier):
        await model.unpinItem(identifier: identifier)
      }
    }
  }
  
  func hideItem(item: ManageTokensItem) {
    Task {
      switch item {
      case .token(let identifier):
        await model.hideItem(identifier: identifier)
      }
    }
  }
  
  func unhideItem(item: ManageTokensItem) {
    Task {
      switch item {
      case .token(let identifier):
        await model.unhideItem(identifier: identifier)
      }
    }
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
    Task {
      await model.movePinnedItem(from: from, to: to)
    }
  }
  
  // MARK: - State
  
  private let actor = SerialActor<Void>()
  private var itemModels = [ManageTokensItem: ManagerTokensItemCellModel]()
  private var isDragging = false
  
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
  func didUpdateState(_ state: ManageTokensModel.State) async {
    await handleState(state: state)
  }
  
  func handleState(state: ManageTokensModel.State) async {
    var models = [ManageTokensItem: ManagerTokensItemCellModel]()
    state.pinnedItems.forEach { pinnedItem in
      switch pinnedItem {
      case .ton(let ton):
        let cellConfiguration = mapper.mapTonItem(ton)
        models[.token(ton.id)] = ManagerTokensItemCellModel(
          configuration: cellConfiguration,
          state: .pinned
        )
      case .jetton(let jetton):
        let cellConfiguration = mapper.mapJettonItem(jetton)
        models[.token(jetton.id)] = ManagerTokensItemCellModel(
          configuration: cellConfiguration,
          state: .pinned
        )
      case .staking(let staking):
        let cellConfiguration = mapper.mapStakingItem(staking)
        models[.token(staking.id)] = ManagerTokensItemCellModel(
          configuration: cellConfiguration,
          state: .pinned
        )
      }
    }
    state.unpinnedItems.forEach { unpinnedItem in
      switch unpinnedItem.item {
      case .ton(let ton):
        let cellConfiguration = mapper.mapTonItem(ton)
        models[.token(ton.id)] = ManagerTokensItemCellModel(
          configuration: cellConfiguration,
          state: .unpinned(isHidden: unpinnedItem.isHidden)
        )
      case .jetton(let jetton):
        let cellConfiguration = mapper.mapJettonItem(jetton)
        models[.token(jetton.id)] = ManagerTokensItemCellModel(
          configuration: cellConfiguration,
          state: .unpinned(isHidden: unpinnedItem.isHidden)
        )
      case .staking(let staking):
        let cellConfiguration = mapper.mapStakingItem(staking)
        models[.token(staking.id)] = ManagerTokensItemCellModel(
          configuration: cellConfiguration,
          state: .unpinned(isHidden: unpinnedItem.isHidden)
        )
      }
    }
    
    let snapshot = createSnapshot(state: state)
    
    await MainActor.run { [models, snapshot] in
      self.itemModels.merge(models) { $1 }
      self.didUpdateSnapshot?(snapshot, false)
    }
  }
  
  private func createSnapshot(state: ManageTokensModel.State) -> NSDiffableDataSourceSnapshot<ManageTokensSection, ManageTokensItem> {
    var snapshot = NSDiffableDataSourceSnapshot<ManageTokensSection, ManageTokensItem>()
    
    snapshot.appendSections([.pinned, .allAsstes])
    
    if !state.pinnedItems.isEmpty {
      snapshot.appendItems(state.pinnedItems.map { .token($0.identifier) }, toSection: .pinned)
    }
    if !state.unpinnedItems.isEmpty {
      snapshot.appendItems(state.unpinnedItems.map { .token($0.item.identifier) }, toSection: .allAsstes)
    }
    
    if #available(iOS 15.0, *) {
      snapshot.reconfigureItems(snapshot.itemIdentifiers)
    } else {
      snapshot.reloadItems(snapshot.itemIdentifiers)
    }
    
    return snapshot
  }
}
