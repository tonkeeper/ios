import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

extension TransactionConfirmationModel {
    /// The picker renders one row per available fee method, and that set is already resolved by the
    /// time the fee row offers to open it — so the placeholder matches the loaded list exactly rather
    /// than guessing from the asset. Floored at one row so an unresolved set still shows a placeholder.
    var networkFeePickerSkeletonItemCount: Int {
        max(availableExtraTypes.count, 1)
    }
}

extension TransactionConfirmationModel.ExtraType {
    var networkFeePickerTitle: String {
        switch self {
        case .default:
            TKLocales.ExtraType.ton
        case .battery:
            TKLocales.ExtraType.battery
        case let .gasless(token):
            token.symbol ?? token.name
        case let .multichain(token):
            token.symbol
        }
    }

    var feeRowMethodTitle: String {
        switch self {
        case .battery:
            TKLocales.Settings.Items.battery
        case .default, .gasless, .multichain:
            networkFeePickerTitle
        }
    }

    var networkFeePickerLeading: NetworkFeePickerItem.Leading {
        switch self {
        case .default:
            return .assetAvatar(
                imageSource: .image(UIImage.TKUIKit.Icons.Size44.tonLogo)
            )
        case .battery:
            return .icon(
                image: UIImage.TKUIKit.Icons.Size24.flash,
                tintColor: .accentGreen,
                backgroundColor: TKColor.accentGreen.opacity(0.12)
            )
        case let .gasless(token):
            if token.symbol?.uppercased() == TRX.symbol.uppercased() {
                return .assetAvatar(
                    imageSource: .image(
                        UIImage.TKUIKit.Icons.Size44.currencyTrc20.withRenderingMode(.alwaysOriginal)
                    )
                )
            }
            return .assetAvatar(
                imageSource: .url(token.imageURL)
            )
        case let .multichain(token):
            return .assetAvatar(
                imageSource: AssetIdResolver.imageSource(
                    for: token.assetId,
                    imageUrl: URL(string: token.image),
                    multichainEnabled: true
                )
            )
        }
    }
}
