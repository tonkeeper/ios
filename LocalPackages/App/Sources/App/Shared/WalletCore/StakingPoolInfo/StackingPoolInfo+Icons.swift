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
        case .liquidTF: .TKUIKit.Icons.Size96.stakingTonstakers
        case .tf: .TKUIKit.Icons.Size96.stakingTonNominators
        case .whales:
            if name.lowercased().contains("keeper") {
                BrandMarks.stakingPoolBadge
            } else {
                .TKUIKit.Icons.Size96.stakingWhales
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
        case .liquidTF: .TKUIKit.Icons.Size96.stakingTonstakers
        case .tf: .TKUIKit.Icons.Size96.stakingTonNominators
        case .whales: .TKUIKit.Icons.Size96.stakingWhales
        }
    }
}
