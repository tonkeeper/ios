import KeeperCore
import TKCore

extension FeeAsset {
    /// The existing analytics shape can report only one fee asset, so TRON takes precedence.
    init(
        tonFeeMethod: WalletMigrationPrepareResult.FeeMethod?,
        tronFeeMethod: WalletMigrationTronPrepareResult.FeeMethod?
    ) {
        if let tronFeeMethod {
            switch tronFeeMethod {
            case .battery:
                self = .batteryCharges
            case .trx:
                self = .coin
            }
            return
        }

        switch tonFeeMethod {
        case .battery:
            self = .batteryCharges
        case .ton, nil:
            self = .coin
        }
    }
}
