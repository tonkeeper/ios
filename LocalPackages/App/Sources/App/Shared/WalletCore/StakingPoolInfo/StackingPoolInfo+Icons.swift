import UIKit
import TKUIKit
import KeeperCore

extension StackingPoolInfo {
  var icon: UIImage {
    switch implementation.type {
    case .liquidTF: .TKUIKit.Icons.Size44.tonStakersLogo
    case .tf: .TKUIKit.Icons.Size44.tonNominatorsLogo
    case .whales:
      if name.lowercased().contains("tonkeeper") {
        .TKUIKit.Icons.Size44.tonkeeperLogo
      } else {
        .TKUIKit.Icons.Size44.tonWhalesLogo
      }
    }
  }
  
  var bigIcon: UIImage {
    switch implementation.type {
    case .liquidTF: .App.Images.StakingImplementation.tonstakers
    case .tf: .App.Images.StakingImplementation.tonNominators
    case .whales:
      if name.lowercased().contains("tonkeeper") {
        .TKUIKit.Icons.Size44.tonkeeperLogo
      } else {
        .App.Images.StakingImplementation.whales
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
    case .liquidTF: .App.Images.StakingImplementation.tonstakers
    case .tf: .App.Images.StakingImplementation.tonNominators
    case .whales: .App.Images.StakingImplementation.whales
    }
  }
}

