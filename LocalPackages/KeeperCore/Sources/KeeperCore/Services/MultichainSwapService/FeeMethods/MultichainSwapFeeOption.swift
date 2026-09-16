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
    }

    public let cost: Cost

    public var isInsufficient: Bool {
        switch cost {
        case let .native(_, isInsufficient),
             let .batteryCharges(_, _, isInsufficient):
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
        }
    }

    var batteryCharges: Int? {
        switch cost {
        case .native, .batteryUnpriced:
            return nil
        case let .batteryCharges(count, _, _):
            return count
        }
    }

    var logValue: String {
        let detail = switch cost {
        case let .native(fees, _): fees.map(\.asset.symbol).joined(separator: "+")
        case let .batteryCharges(count, _, _): "\(count)charges"
        case .batteryUnpriced: "unpriced"
        }
        return "\(method)(\(detail)\(isInsufficient ? ",insufficient" : ""))"
    }

    public init(cost: Cost) {
        self.cost = cost
    }
}
