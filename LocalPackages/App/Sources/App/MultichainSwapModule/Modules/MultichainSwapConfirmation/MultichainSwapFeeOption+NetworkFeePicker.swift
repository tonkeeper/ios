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

    /// Battery holds charges for the whole message and gives the change back, so a swap costs what it
    /// holds less what comes back, and the change is held only for the time of the swap. A change that
    /// equals the hold says nothing about either, and the hold stands as the cost.
    var batteryCharges: (cost: Int, reserve: Int?)? {
        guard case let .batteryCharges(count, excess, _) = cost else {
            return nil
        }
        guard let excess, excess > 0, excess < count else {
            return (count, nil)
        }
        return (count - excess, excess)
    }

    /// What a coin or a token pays, summed per asset; `nil` for the battery.
    var feeAmounts: [MultichainSwapFeeSummary.Amount]? {
        switch cost {
        case let .native(fees, _):
            MultichainSwapFeeSummary.Amount.totals(fees.map { ($0.fee, $0.asset) })
        case let .gram(amountNano, _):
            [MultichainSwapFeeSummary.Amount(amount: amountNano, asset: .gram)]
        case let .token(asset, amount, _):
            [MultichainSwapFeeSummary.Amount(amount: amount, asset: asset)]
        case .batteryCharges, .batteryUnpriced:
            nil
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
