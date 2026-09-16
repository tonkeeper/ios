import KeeperCore
import TKUIKit
import UIKit

enum MultichainHistoryStakingProvider: String {
    case liquidTF
    case whales
    case tf

    init?(activity: MultichainActivity) {
        guard activity.activityType == .stake || activity.activityType == .unstake,
              let protocolName = activity.protocolName
        else {
            return nil
        }
        self.init(rawValue: protocolName)
    }

    var icon: UIImage {
        switch self {
        case .liquidTF:
            .TKUIKit.Icons.Size44.tonStakersLogo
        case .whales:
            .TKUIKit.Icons.Size44.tonWhalesLogo
        case .tf:
            .TKUIKit.Icons.Size44.tonNominatorsLogo
        }
    }

    var displayName: String {
        switch self {
        case .liquidTF:
            "Tonstakers"
        case .whales:
            "TON Whales"
        case .tf:
            "TON Nominators"
        }
    }
}
