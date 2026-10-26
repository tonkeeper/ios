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
        case let .token(asset, _, _):
            return .multichain(token: asset)
        }
    }

    var refundedChargesText: String? {
        guard case let .batteryCharges(count, excess, _) = cost,
              let excess, excess > 0, excess < count
        else {
            return nil
        }
        return "\(TKLocales.Common.Numbers.approximate) \(excess) \(TKLocales.Battery.Refill.refunded(count: excess))"
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
        case let .token(asset, amount, _):
            return amountFormatter.format(
                amount: amount,
                fractionDigits: asset.decimals,
                accessory: .tokenSymbol(asset.symbol),
                style: .compact
            )
        }
    }
}
