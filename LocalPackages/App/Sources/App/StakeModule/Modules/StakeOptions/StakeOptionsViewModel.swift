import UIKit
import TKUIKit
import KeeperCore

protocol StakeOptionsModuleOutput: AnyObject {
  var didTapOtherPoolCell: ((String, [SelectionCollectionViewCell.Configuration]) -> Void)? { get set }
  var onOpenPoolDetails: ((StakePool) -> Void)? { get set }
}

protocol StakeOptionsModuleInput: AnyObject {
  func didTapPoolCell(_ pool: StakePool)
}

protocol StakeOptionsViewModel: AnyObject {
  var didUpdateModel: ((StakeOptionsView.Model) -> Void)? { get set }
  var didUpdatePoolList: (([SelectionCollectionViewCell.Configuration], [TKUIListItemCell.Configuration]) -> Void)? { get set }
  
  func viewDidLoad()
}

final class StakeOptionsViewModelImplementation: StakeOptionsViewModel, StakeOptionsModuleOutput, StakeOptionsModuleInput {
  
  // MARK: - StakeOptionsModuleOutput
  
  var didTapOtherPoolCell: ((String, [SelectionCollectionViewCell.Configuration]) -> Void)?
  var onOpenPoolDetails: ((StakePool) -> Void)?
  
  // MARK: - StakeOptionsModuleInput
  
  func didTapPoolCell(_ pool: StakePool) {
    onOpenPoolDetails?(pool)
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
  private var selectedStakePool: StakePool
  
  // MARK: - Init
  
  init(stakeOptionsController: StakeOptionsController, selectedStakePool: StakePool) {
    self.stakeOptionsController = stakeOptionsController
    self.selectedStakePool = selectedStakePool
  }
  
  deinit {
    print("\(Self.self) deinit")
  }
}

// MARK: - Private

private extension StakeOptionsViewModelImplementation {
  func updateWithInitialData() {
    var liquidStakePools = StakePool.testData
    var otherPools = StakePoolList.testData
    
    liquidStakePools.updateSelected(selectPool: selectedStakePool)
    otherPools.updateSelected(selectPool: selectedStakePool)
    
    let liquidStakingPoolItemsModel = PoolItemsModel(items: liquidStakePools)
    let otherPoolItemsModel = PoolListItemsModel(items: otherPools)
    
    let liquidStakingListItems = liquidStakingPoolItemsModel.items.map { item in
      itemMapper.mapLiquidStakingPoolListItem(item) { [weak self] in
        self?.didTapPoolCell(item)
      }
    }
    
    let otherListItems = otherPoolItemsModel.items.map { item in
      itemMapper.mapOtherPoolListItem(item) { [weak self] in
        let poolsItems = item.pools.compactMap { pool in
          let poolForMap = pool.updatedMinimum("")
          return self?.itemMapper.mapLiquidStakingPoolListItem(poolForMap) { self?.didTapPoolCell(pool) }
        }
        let poolTitle = item.title
        self?.didTapOtherPoolCell?(poolTitle, poolsItems)
      }
    }
    
    didUpdatePoolList?(liquidStakingListItems, otherListItems)
    update()
  }
  
  func updatedSelectedItem(selectedPool: StakePool, in pools: [StakePool]) -> [StakePool] {
    return pools.map { stakePool in
      var updatedStakePool = stakePool
      updatedStakePool.isSelected = stakePool.id == selectedPool.id
      return updatedStakePool
    }
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

// MARK: - TestData

public extension StakePool {
  func updatedMinimum(_ minimumDeposit: String) -> StakePool {
    var updatedPool = self
    updatedPool.minimumDeposit = minimumDeposit
    return updatedPool
  }
  
  static let testData: [StakePool] = [
    .init(
      id: "poolTonstakers",
      image: .TKUIKit.Images.Pools.tonstakers,
      title: "Tonstakers",
      tag: "MAX APY",
      apy: "5.01",
      minimumDeposit: "1 TON",
      links: .testLinks
    ),
    .init(
      id: "poolBemo",
      image: .TKUIKit.Images.Pools.bemo,
      title: "Bemo",
      tag: nil,
      apy: "5.01",
      minimumDeposit: "1 TON",
      links: .testLinks
    ),
    .init(
      id: "poolTonWhales",
      image: .TKUIKit.Images.Pools.tonWhales,
      title: "Whales Liquid Pool",
      tag: nil,
      apy: "5.01",
      minimumDeposit: "1 TON",
      links: .testLinks
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
          minimumDeposit: "50 TON",
          links: .testLinks
        ),
        .init(
          id: "otherTonWhales_2",
          image: .TKUIKit.Images.Pools.tonkeeperPool1,
          title: "Tonkeeper Queue #2",
          tag: nil,
          apy: "3.01",
          minimumDeposit: "50 TON",
          links: .testLinks
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
          minimumDeposit: "10K TON",
          links: .testLinks
        ),
        .init(
          id: "otherTonNominators_2",
          image: .TKUIKit.Images.Pools.tonNominators,
          title: "Tonkeeper Queue #4",
          tag: nil,
          apy: "3.01",
          minimumDeposit: "10K TON",
          links: .testLinks
        )
      ]
    ),
  ]
}

public extension Array where Element == StakePool.Link {
  static let testLinks: [StakePool.Link] = [
    .init(
      icon: .TKUIKit.Icons.Size16.globe,
      titledUrl: TitledURL(
        title: "tonstakers.com",
        url: URL(string: "https://tonstakers.com")!
      )
    ),
    .init(
      icon: .TKUIKit.Icons.Size16.twitter,
      titledUrl: TitledURL(
        title: "Twitter",
        url: URL(string: "https://twitter.com/tonstakers")!
      )
    ),
    .init(
      icon: .TKUIKit.Icons.Size16.telegram,
      titledUrl: TitledURL(
        title: "Community",
        url: URL(string: "https://t.me/tonstakers_community")!
      )
    ),
    .init(
      icon: .TKUIKit.Icons.Size16.magnifyingGlass,
      titledUrl: TitledURL(
        title: "tonviewer.com",
        url: URL(string: "https://tonviewer.com")!
      )
    )
  ]
}

