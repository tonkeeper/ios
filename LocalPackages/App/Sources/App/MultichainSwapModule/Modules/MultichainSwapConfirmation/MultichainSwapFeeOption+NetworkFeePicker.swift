import KeeperCore
import TKCore
import TKLocalize
import TKUIKit

extension MultichainSwapFeeOption {
    /// The picker and the fee row already know how to render a send's extra type, so a swap fee option
    /// only has to say which one it is.
    var extraType: TransactionConfirmationModel.ExtraType {
        switch cost {
        case .batteryCharges, .batteryUnpriced:
            return .battery
        case let .native(fees, _):
            guard let asset = fees.first?.asset else {
                return .default
            }
            return .multichain(token: asset)
        case .gram:
            return .default
        }
    }

    func feeValueText(amountFormatter: AmountFormatter) -> String {
        switch cost {
        case let .batteryCharges(count, _, _):
            return "\(count) \(TKLocales.Battery.Refill.chargesCount(count: count))"
        case .batteryUnpriced:
            return "—"
        case let .native(fees, _):
            return fees.map { fee in
                amountFormatter.format(
                    amount: fee.fee,
                    fractionDigits: fee.asset.decimals,
                    accessory: .tokenSymbol(fee.asset.symbol),
                    style: .compact
                )
            }.joined(separator: " · ")
        case let .gram(amountNano, _):
            return amountFormatter.format(
                amount: amountNano,
                fractionDigits: MultichainAssetDetails.gram.decimals,
                accessory: .tokenSymbol(MultichainAssetDetails.gram.symbol),
                style: .compact
            )
        }
    }
}
