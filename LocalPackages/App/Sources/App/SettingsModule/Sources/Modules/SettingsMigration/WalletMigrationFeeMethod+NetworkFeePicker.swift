import KeeperCore
import TKUIKit
import TronSwift
import UIKit

extension WalletMigrationPrepareResult.FeeMethod {
    var networkFeePickerTitle: String {
        switch self {
        case .ton:
            TransactionConfirmationModel.ExtraType.default.networkFeePickerTitle
        case .battery:
            TransactionConfirmationModel.ExtraType.battery.networkFeePickerTitle
        }
    }

    var feeRowMethodTitle: String {
        switch self {
        case .ton:
            TransactionConfirmationModel.ExtraType.default.feeRowMethodTitle
        case .battery:
            TransactionConfirmationModel.ExtraType.battery.feeRowMethodTitle
        }
    }

    var networkFeePickerLeading: NetworkFeePickerItem.Leading {
        switch self {
        case .ton:
            return TransactionConfirmationModel.ExtraType.default.networkFeePickerLeading
        case .battery:
            return TransactionConfirmationModel.ExtraType.battery.networkFeePickerLeading
        }
    }
}

extension WalletMigrationTronPrepareResult.FeeMethod {
    var networkFeePickerTitle: String {
        switch self {
        case .battery:
            TransactionConfirmationModel.ExtraType.battery.networkFeePickerTitle
        case .trx:
            TRX.symbol
        }
    }

    var feeRowMethodTitle: String {
        switch self {
        case .battery:
            TransactionConfirmationModel.ExtraType.battery.feeRowMethodTitle
        case .trx:
            TRX.symbol
        }
    }

    var networkFeePickerLeading: NetworkFeePickerItem.Leading {
        switch self {
        case .battery:
            return TransactionConfirmationModel.ExtraType.battery.networkFeePickerLeading
        case .trx:
            return .assetAvatar(
                imageSource: .image(
                    UIImage.TKUIKit.Icons.Size44.currencyTrc20.withRenderingMode(.alwaysOriginal)
                )
            )
        }
    }
}
