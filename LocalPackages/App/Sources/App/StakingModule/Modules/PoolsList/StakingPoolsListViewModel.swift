import Foundation
import KeeperCore
import TKUIKit
import UIKit
import TKCore

protocol StakingPoolsListModuleOutput: AnyObject {
    var didSelectPool: ((PoolImplementation) -> Void)? { get set }
}

protocol StakingPoolsListModuleInput: AnyObject {
}

protocol StakingPoolsListViewModel: AnyObject {
    var didUpdateModel: ((StakingPoolsListSection) -> Void)? { get set }
    func viewDidLoad()
}

struct StakingPoolsListSection: Hashable {
    let items: [StakingPoolsCell.Model]
}

final class StakingPoolsListViewModelImplementation: StakingPoolsListViewModel, StakingPoolsListModuleOutput, StakingPoolsListModuleInput {
    
    // MARK: - StakingPoolsModuleOutput
    
    var didSelectPool: ((PoolImplementation) -> Void)?
    
    // MARK: - StakingPoolsModuleInput
    
    // MARK: - StakingPoolsViewModel
    
    var didUpdateModel: ((StakingPoolsListSection) -> Void)?
    
    func viewDidLoad() {
        didUpdateModel?(createModel(pool))
    }
    
    // MARK: - Dependencies
    
    private let selectedPool: PoolImplementation
    private let pool: PoolImplementation
    
    init(selectedPool: PoolImplementation, pool: PoolImplementation) {
        self.selectedPool = selectedPool
        self.pool = pool
    }
}

private extension StakingPoolsListViewModelImplementation {
    func createModel(_ pool: PoolImplementation) -> StakingPoolsListSection {
        let items = pool.pools.compactMap { poolInfo in
            let iconModel = TKListItemIconImageView.Model(
                image: .image(pool.image),
                tintColor: .clear,
                backgroundColor: .clear,
                size: .init(width: 44, height: 44)
            )
            
            let apyFormatted = String(format: "%.2f", poolInfo.apy)
            let description = "APY ≈ \(apyFormatted)%"
            
            let isSelected = self.selectedPool.pools.first?.address == poolInfo.address
            
            let contentModel = StakingPoolsCellContentView.Model(
                iconModel: iconModel,
                title: poolInfo.name,
                description: description,
                isSelected: isSelected
            )
            
            let cellModel = StakingPoolsCell.Model(
                identifier: pool.name,
                selectionHandler: { [weak self] in
                    guard let self else { return }
                    var poolImplementation = self.pool
                    poolImplementation.pools = [poolInfo]
                    poolImplementation.maxPoolApy = poolInfo.apy
                    self.didSelectPool?(poolImplementation)
                },
                cellContentModel: contentModel
            )
            return cellModel
        }
        
        return .init(items: items)
    }
}

private extension PoolImplementation {
    var image: UIImage {
        let lowercasedName = name.lowercased()
        
        switch lowercasedName {
        case "ton nominators":
            return .TKUIKit.Icons.Size44.tonNominators
        case "ton whales":
            return .TKUIKit.Icons.Size44.tonWhales
        case "bemo":
            return .TKUIKit.Icons.Size44.bemo
        case "tonstakers":
            return .TKUIKit.Icons.Size44.tonStakers
        default:
            return .TKUIKit.Icons.Size44.staking
        }
    }
}
