import Foundation
import KeeperCore
import TKUIKit
import UIKit
import TKCore

protocol StakingOptionsListModuleOutput: AnyObject {
    var didSelectStaking: ((PoolImplementation) -> Void)? { get set }
    var didSelectOther: ((PoolImplementation) -> Void)? { get set }
}

protocol StakingOptionsListViewModel: AnyObject {
    var didUpdateModel: (([StakingOptionsSection]) -> Void)? { get set }
    func viewDidLoad()
}

enum StakingOptionsSection: Hashable, CustomStringConvertible {
    case staking(items: [StakingOptionsCell.Model])
    case other(items: [StakingOptionsOtherCell.Model])
    
    var description: String {
        switch self {
        case .staking:
            return "Liquid Staking"
        case .other:
            return "Other"
        }
    }
}

final class StakingOptionsListViewModelImplementation: StakingOptionsListViewModel, StakingOptionsListModuleOutput {
    
    // MARK: - StakingOptionsModuleOutput
    
    var didSelectStaking: ((PoolImplementation) -> Void)?
    var didSelectOther: ((PoolImplementation) -> Void)?
    
    // MARK: - StakingOptionsViewModel
    
    var didUpdateModel: (([StakingOptionsSection]) -> Void)?
    
    func viewDidLoad() {
        stakingOptionsController.didUpdateModel = { [weak self] pools in
            guard let self else { return }
            DispatchQueue.main.async {
                self.didUpdateModel?(self.mapPools(pools))
            }
        }
        
        stakingOptionsController.start()
    }
    
    // MARK: - Dependencies
    
    private let stakingOptionsController: StakingOptionsController
    private let selectedPool: PoolImplementation
    private let imageLoader = ImageLoader()
    
    init(stakingOptionsController: StakingOptionsController, selectedPool: PoolImplementation) {
        self.stakingOptionsController = stakingOptionsController
        self.selectedPool = selectedPool
    }
}

private extension StakingOptionsListViewModelImplementation {
    func mapPools(_ pools: [PoolImplementation]) -> [StakingOptionsSection] {
        
        let stakingPools = pools.filter { $0.implementationType == .liquidTF }
        let otherPools = pools.filter { $0.implementationType != .liquidTF }
        
        let stakingItems = stakingPools.compactMap { pool in
            let iconModel = TKListItemIconImageView.Model(
                image: .image(pool.image),
                tintColor: .clear,
                backgroundColor: .clear,
                size: .init(width: 44, height: 44)
            )
            
            let apyFormatted = String(format: "%.2f", pool.maxPoolApy)
            let description = "APY ≈ \(apyFormatted)%"
            
            let isSelected = pool.pools.contains(where: { self.selectedPool.pools.first?.address == $0.address })
            
            var tagModel: TKUITagView.Configuration?
            if pool.pools.contains(where: { $0.isMax }) {
                tagModel = .init(text: "MAX APY", textColor: .Accent.green, backgroundColor: .Accent.green.withAlphaComponent(0.16))
            }
            
            let contentModel = StakingOptionsCellContentView.Model(
                iconModel: iconModel,
                title: pool.name,
                subtitle: pool.description,
                description: description,
                tagModel: tagModel,
                isSelected: isSelected
            )
            
            let cellModel = StakingOptionsCell.Model(
                identifier: pool.name,
                selectionHandler: { [weak self] in
                    var pool = pool
                    let poolsInfo = [pool.pools.first].compactMap { $0 }
                    pool.pools = poolsInfo
                    self?.didSelectStaking?(pool)
                },
                cellContentModel: contentModel
            )
            return cellModel
        }
        
        let otherItems = otherPools.compactMap { pool in
            let apyFormatted = String(format: "%.2f", pool.maxPoolApy)
            let description = "Earn up to \(apyFormatted)%"
            
            var tagModel: TKUITagView.Configuration?
            if pool.pools.contains(where: { $0.isMax }) {
                tagModel = .init(text: "MAX APY", textColor: .Accent.green, backgroundColor: .Accent.green.withAlphaComponent(0.16))
            }
            
            let contentModel = StakingOptionsOtherCellContentView.Model(
                image: pool.image,
                title: pool.name,
                subtitle: pool.description,
                description: description,
                tagModel: tagModel
            )
            
            let cellModel = StakingOptionsOtherCell.Model(
                identifier: pool.name,
                accessoryType: .disclosureIndicator,
                selectionHandler: { [weak self] in
                    self?.didSelectOther?(pool)
                },
                cellContentModel: contentModel
            )
            return cellModel
        }
        
        return [.staking(items: stakingItems), .other(items: otherItems)]
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
