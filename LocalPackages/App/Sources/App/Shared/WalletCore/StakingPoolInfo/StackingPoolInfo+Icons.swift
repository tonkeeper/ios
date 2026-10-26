import KeeperCore
import TKUIKit
import UIKit

extension StackingPoolInfo {
    var icon: UIImage {
        switch implementation.type {
        case .liquidTF: .TKUIKit.Icons.Size44.tonStakersLogo
        case .tf: .TKUIKit.Icons.Size44.tonNominatorsLogo
        case .whales:
            if name.lowercased().contains("keeper") {
                BrandMarks.stakingPoolBadge
            } else {
                .TKUIKit.Icons.Size44.tonWhalesLogo
            }
        }
    }

    var bigIcon: UIImage {
        switch implementation.type {
        case .liquidTF: .TKUIKit.Shared.stakingTonstakers
        case .tf: .TKUIKit.Shared.stakingTonNominators
        case .whales:
            if name.lowercased().contains("keeper") {
                BrandMarks.stakingPoolBadge
            } else {
                .TKUIKit.Shared.stakingWhales
            }
        }
    }
}

extension StackingPoolInfo.Implementation {
    var icon: UIImage {
        switch type {
        case .liquidTF: .TKUIKit.Icons.Size44.tonStakersLogo
        case .tf: .TKUIKit.Icons.Size44.tonNominatorsLogo
        case .whales: .TKUIKit.Icons.Size44.tonWhalesLogo
        }
    }

    var bigIcon: UIImage {
        switch type {
        case .liquidTF: .TKUIKit.Shared.stakingTonstakers
        case .tf: .TKUIKit.Shared.stakingTonNominators
        case .whales: .TKUIKit.Shared.stakingWhales
        }
    }
}
