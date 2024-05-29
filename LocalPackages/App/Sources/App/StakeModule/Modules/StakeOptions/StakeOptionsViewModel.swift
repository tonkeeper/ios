import UIKit
import TKUIKit
import KeeperCore

protocol StakeOptionsModuleOutput: AnyObject {
  var didSelectOtherPool: ((String, String, [SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  var didSelectNewPool: ((StakePool) -> Void)? { get set }
}

protocol StakeOptionsModuleInput: AnyObject {
  func didSelectPool(_ pool: StakePool)
}

protocol StakeOptionsViewModel: AnyObject {
  var didUpdateModel: ((StakeOptionsView.Model) -> Void)? { get set }
  var didUpdatePoolList: (([SelectionCollectionViewCell.Configuration], [TKUIListItemCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
}

final class StakeOptionsViewModelImplementation: StakeOptionsViewModel, StakeOptionsModuleOutput, StakeOptionsModuleInput {
  
  // MARK: - StakeOptionsModuleOutput
  
  var didSelectOtherPool: ((String, String, [SelectionCollectionViewCell.Configuration]) -> Void)?
  var didSelectNewPool: ((StakePool) -> Void)?
  
  // MARK: - StakeOptionsModuleInput
  
  func didSelectPool(_ pool: StakePool) {
    didSelectNewPool?(pool)
  }
  
  // MARK: - StakeOptionsViewModel
  
  var didUpdateModel: ((StakeOptionsView.Model) -> Void)?
  var didUpdatePoolList: (([SelectionCollectionViewCell.Configuration], [TKUIListItemCell.Configuration]) -> Void)?
  
  func viewDidLoad() {
    updateWithInitialData()
    
    Task {
      await stakeOptionsController.start()
    }
  }
  
  // MARK: - Mapper
  
  let itemMapper = StakeOptionsListItemMapper()
  
  // MARK: - Dependencies
  
  private let stakeOptionsController: StakeOptionsController
  
  // MARK: - Init
  
  init(stakeOptionsController: StakeOptionsController) {
    self.stakeOptionsController = stakeOptionsController
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension StakeOptionsViewModelImplementation {
  func updateWithInitialData() {
    let liquidStakingPoolItemsModel = PoolItemsModel(items: StakePool.testData)
    let otherPoolItemsModel = PoolListItemsModel(items: StakePoolList.testData)
    
    let liquidStakingListItems = liquidStakingPoolItemsModel.items.map { item in
      itemMapper.mapLiquidStakingPoolListItem(item) { [weak self] in
        self?.didSelectPool(item)
      }
    }
    
    let otherListItems = otherPoolItemsModel.items.map { item in
      itemMapper.mapOtherPoolListItem(item) { [weak self] in
        let poolsItems = item.pools.compactMap { pool in
          self?.itemMapper.mapLiquidStakingPoolListItem(pool) { self?.didSelectPool(pool) }
        }
        let poolTitle = item.title
        let selectedId = poolsItems.first?.id ?? ""
        self?.didSelectOtherPool?(poolTitle, selectedId, poolsItems)
      }
    }
    
    let selectedItem = StakeOptionsSelectedItem(
      id: otherListItems[0].id,
      section: .liquidStaking
    )
    
    didUpdatePoolList?(liquidStakingListItems, otherListItems)
    update()
  }
  
  func update() {
    let model = createModel()
    didUpdateModel?(model)
  }
  
  func createModel() -> StakeOptionsView.Model {
    StakeOptionsView.Model(
      title: ModalTitleView.Model(title: "Options")
    )
  }
}

public extension StakePool {
  static let testData: [StakePool] = [
    .init(
      id: "poolTonstakers",
      image: .TKUIKit.Images.Pools.tonstakers,
      title: "Tonstakers",
      tag: "MAX APY",
      apy: "5.01",
      minimumDeposit: "1 TON"
    ),
    .init(
      id: "poolBemo",
      image: .TKUIKit.Images.Pools.bemo,
      title: "Bemo",
      tag: nil,
      apy: "5.01",
      minimumDeposit: "1 TON"
    ),
    .init(
      id: "poolTonWhales",
      image: .TKUIKit.Images.Pools.tonWhales,
      title: "Whales Liquid Pool",
      tag: nil,
      apy: "5.01",
      minimumDeposit: "1 TON"
    ),
  ]
}

public extension StakePoolList {
  static let testData: [StakePoolList] = [
    .init(
      id: "otherTonWhales",
      image: .TKUIKit.Images.Pools.tonWhales,
      title: "TON Whales",
      tag: nil,
      minimumDeposit: "50 TON",
      description: "Earn up to 3.01%",
      pools: [
        .init(
          id: "otherTonWhales_1",
          image: .TKUIKit.Images.Pools.tonkeeperPool1,
          title: "Tonkeeper Queue #1",
          tag: nil,
          apy: "3.01",
          minimumDeposit: nil
        ),
        .init(
          id: "otherTonWhales_2",
          image: .TKUIKit.Images.Pools.tonkeeperPool1,
          title: "Tonkeeper Queue #2",
          tag: nil,
          apy: "3.01",
          minimumDeposit: nil
        )
      ]
    ),
    .init(
      id: "otherTonNominators",
      image: .TKUIKit.Images.Pools.tonNominators,
      title: "TON Nominators",
      tag: nil,
      minimumDeposit: "10K TON",
      description: "Earn up to 3.01%",
      pools: [
        .init(
          id: "otherTonNominators_1",
          image: .TKUIKit.Images.Pools.tonNominators,
          title: "Tonkeeper Queue #3",
          tag: nil,
          apy: "3.01",
          minimumDeposit: nil
        ),
        .init(
          id: "otherTonNominators_2",
          image: .TKUIKit.Images.Pools.tonNominators,
          title: "Tonkeeper Queue #4",
          tag: nil,
          apy: "3.01",
          minimumDeposit: nil
        )
      ]
    ),
  ]
}
