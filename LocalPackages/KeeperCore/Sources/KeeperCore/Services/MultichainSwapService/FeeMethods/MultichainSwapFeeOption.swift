@preconcurrency import BigInt

/// One priced way a prepared swap can pay its fee.
public struct MultichainSwapFeeOption: Sendable, Hashable {
    /// What the fee is denominated in, and whether the wallet can cover it. Payability lives here
    /// rather than beside it, so the one method that can never pay cannot be built as if it could.
    public enum Cost: Sendable, Hashable {
        /// The whole per-asset breakdown, because a route with an approval is charged more than once
        /// on the same chain.
        case native([MultichainTransactionEmulationResult], isInsufficient: Bool)
        case batteryCharges(count: Int, excess: Int?, isInsufficient: Bool)
        /// Battery may pay for this swap but the estimate came back without a price. The option is
        /// still listed — a refill is the way out and the picker is the only place to reach it — and
        /// is insufficient by construction, so it can never be sent.
        case batteryUnpriced
        /// The same relayer, billed in the wallet's GRAM instead of in charges.
        case gram(amountNano: BigUInt, isInsufficient: Bool)
    }

    public let cost: Cost

    public var isInsufficient: Bool {
        switch cost {
        case let .native(_, isInsufficient),
             let .batteryCharges(_, _, isInsufficient),
             let .gram(_, isInsufficient):
            return isInsufficient
        case .batteryUnpriced:
            return true
        }
    }

    public var method: MultichainSwapFeeMethod {
        switch cost {
        case .native:
            return .native
        case .batteryCharges, .batteryUnpriced:
            return .battery
        case .gram:
            return .gram
        }
    }

    /// The asset a wallet has to top up when this method cannot pay, or `nil` when the way out is a
    /// battery refill rather than a deposit.
    public var depositAsset: MultichainAssetDetails? {
        switch cost {
        case let .native(fees, _):
            return fees.first?.asset
        case .batteryCharges, .batteryUnpriced:
            return nil
        case .gram:
            return .gram
        }
    }

    /// What the relayer has to honour once this option is confirmed, or `nil` for a method it does
    /// not send at all.
    var relayedFee: MultichainSwapRelayedFee? {
        switch cost {
        case .native, .batteryUnpriced:
            return nil
        case let .batteryCharges(count, _, _):
            return .batteryCharges(count)
        case let .gram(amountNano, _):
            return .gram(amountNano: amountNano)
        }
    }

    var logValue: String {
        let detail = switch cost {
        case let .native(fees, _): fees.map(\.asset.symbol).joined(separator: "+")
        case let .batteryCharges(count, _, _): "\(count)charges"
        case .batteryUnpriced: "unpriced"
        case let .gram(amountNano, _): "\(amountNano)nano"
        }
        return "\(method)(\(detail)\(isInsufficient ? ",insufficient" : ""))"
    }

    public init(cost: Cost) {
        self.cost = cost
    }
}

public extension MultichainAssetDetails {
    /// The relayer's instant fee is settled in the TON coin, which the fee option names without a
    /// catalog lookup — the relayed methods are mainnet-only, so the id is fixed.
    static let gram = MultichainAssetDetails(
        assetId: "\(MultichainChain.ton.rawValue)/mainnet/coin",
        name: TonInfo.name,
        symbol: TonInfo.symbol,
        decimals: TonInfo.fractionDigits,
        image: ""
    )
}
