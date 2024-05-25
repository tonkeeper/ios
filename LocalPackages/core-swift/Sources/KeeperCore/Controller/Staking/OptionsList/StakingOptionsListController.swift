import UIKit
import Foundation
import TKUIKit
import BigInt
import TonSwift

public struct StakingOptionsListModel {
  public struct PoolImplementation {
    public let name: String
    public let image: StakingPoolImage
    public let apy: Decimal
    public let minDepositAmount: BigInt
    public let address: Address?
    public let kind: StakingPool.Implementation.Kind
  }
  
  public enum ListType {
    case nested([PoolImplementation])
    case plain([StakingPool])
  }
  
  public let listType: ListType
}

public struct StakingOptionGroup {
  public let id: String
  public let items: [StakingOptionItem]
}

public struct StakingOptionItem {
  public let id: String
  public let title: String
  public let image: StakingPoolImage
  public let apyPercents: String
  public let apyTokenAmount: String?
  public let isMaxAPY: Bool
  public let minDepositAmount: String
  public let canSelect: Bool
  public var isSelected: Bool
  public var kind: StakingPool.Implementation.Kind
}

public final class StakingOptionsListController {
  public var didUpdateItems: (([StakingOptionItem]) -> Void)?
  public var didUpdateItemGroups: (([StakingOptionGroup]) -> Void)?
  public var selectedPoolAddress: Address?
  
  private var listModel: StakingOptionsListModel
  private var stakingPools: [StakingPool] = []
  
  private let stakingPoolsService: StakingPoolsService
  private let walletStore: WalletsStore
  private let mapper: StakingOptionsListMapper
  
  public init(
    listModel: StakingOptionsListModel,
    selectedPoolAddress: Address?,
    mapper: StakingOptionsListMapper,
    stakingPoolsService: StakingPoolsService,
    walletStore: WalletsStore
  ) {
    self.listModel = listModel
    self.selectedPoolAddress = selectedPoolAddress
    self.stakingPoolsService = stakingPoolsService
    self.walletStore = walletStore
    self.mapper = mapper
  }
  
  public func start() {
    let wallet = walletStore.activeWallet
    stakingPools = (try? stakingPoolsService.getPools(
      address: wallet.address,
      isTestnet: wallet.isTestnet
    )) ?? []
    
    updateList()
  }
  
  public func didSelectExactPool(id: String) {
    var newSelectedAddress: Address?
    switch listModel.listType {
    case .nested(let poolImplementations):
      guard let poolImplementation = poolImplementations.first(where: { $0.name == id }) else {
        return
      }
      
      newSelectedAddress = poolImplementation.address
    case .plain(let pools):
      guard let pool = pools.first(where: { $0.address.toRaw() == id }) else {
          return
      }
      
      newSelectedAddress = pool.address
    }
    
    selectedPoolAddress = newSelectedAddress
    updateList()
  }
  
  public func createInputModel(id: String) -> StakingOptionsListModel {
    switch listModel.listType {
    case .nested(let poolImplementations):
      guard let pool = poolImplementations.first(where: { $0.name == id }) else {
        return .init(listType: .plain([]))
      }
      
      let pools = stakingPools.filterByPoolKind(pool.kind)
      return .init(listType: .plain(pools))
    case .plain:
      return .init(listType: .plain([]))
    }
  }
  
  public func getSelectedStakingPool() -> StakingPool? {
    return stakingPools.first(where: { $0.address == selectedPoolAddress })
  }
  
  public func getStakingPool(_ id: String) -> StakingPool? {
    var poolAddress: Address?
    switch listModel.listType {
    case .nested(let poolImplementations):
      guard let poolImplementation = poolImplementations.first(where: { $0.name == id }) else {
        return nil
      }
      
      poolAddress = poolImplementation.address
    case .plain(let pools):
      guard let pool = pools.first(where: { $0.address.toRaw() == id }) else {
          return nil
      }
      
      poolAddress = pool.address
    }
    
    return stakingPools.first(where: { $0.address == poolAddress })
  }
}

// MARK: - Private methods

private extension StakingOptionsListController {
  func updateList() {
    switch listModel.listType {
    case .nested(let poolImplentations):
      
      var mostProfitableId: String?
      if let mostProfitable = poolImplentations.max(by: { $0.apy < $1.apy }) {
        mostProfitableId = mostProfitable.name
      }
      
      let liquid = poolImplentations.filter { $0.kind == .liquidTF }
      let other = poolImplentations.filter { $0.kind != .liquidTF }
      
      let liquiditems = mapper.mapPoolImplementations(
        liquid,
        selectedPoolAddress: selectedPoolAddress,
        mostPofitableId: mostProfitableId
      )
      
      let otherItems = mapper.mapPoolImplementations(
        other,
        selectedPoolAddress: selectedPoolAddress,
        mostPofitableId: mostProfitableId
      )
      
      let liquidGroup = StakingOptionGroup(id: .liquidHeaderTitle, items: liquiditems)
      let otherGroup = StakingOptionGroup(id: .otherHeaderTitle, items: otherItems)
      
      didUpdateItemGroups?([liquidGroup, otherGroup])
    case .plain(let pools):
      guard let profitablePool = pools.mostProfitablePool else {
        return
      }
      
      let id = profitablePool.implementation.name
      let items = mapper.mapStakingPools(
        pools,
        profitablePool: profitablePool,
        selectedPoolAddress: selectedPoolAddress
      )
      
      didUpdateItemGroups?([StakingOptionGroup(id: id, items: items)])
    }
  }
}

private extension String {
  static let liquidHeaderTitle = "Liquid Staking"
  static let otherHeaderTitle = "Other"
}
