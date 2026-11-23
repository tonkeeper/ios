import BigInt
import KeeperCore

/// What the plan prepared for the route on screen says about its fee.
enum MultichainSwapFeePlan: Equatable {
    case preparing
    case ready(feeOptions: [MultichainSwapFeeOption], networkFees: [MultichainTransactionEmulationResult])
    /// The chain's coin cannot pay, and the route offers nothing else.
    case nativeFeeShortage(MultichainNativeFeeShortage)
    case failed
}

/// What pays the fee of the route on screen, as the row under the cards names it.
enum MultichainSwapFeeSummary: Equatable {
    struct Amount: Equatable {
        let amount: BigUInt
        let asset: MultichainAssetDetails

        /// A route that approves first pays its chain twice, and the fee is shown as the sum.
        static func totals(_ fees: [(amount: BigUInt, asset: MultichainAssetDetails)]) -> [Amount] {
            var amounts = [Amount]()
            for fee in fees {
                if let index = amounts.firstIndex(where: { $0.asset.assetId == fee.asset.assetId }) {
                    amounts[index] = Amount(amount: amounts[index].amount + fee.amount, asset: fee.asset)
                } else {
                    amounts.append(Amount(amount: fee.amount, asset: fee.asset))
                }
            }
            return amounts
        }
    }

    case charges(Int)
    case amounts([Amount])
    case batteryEmpty
    case lowBattery
    case noFunds(symbol: String)
    /// The route's fee is not known.
    case unknown

    /// Nothing the swap could use pays the fee.
    var isUnpaid: Bool {
        switch self {
        case .batteryEmpty, .lowBattery, .noFunds:
            return true
        case .charges, .amounts, .unknown:
            return false
        }
    }

    /// `nil` while the plan is on its way. With `amountBlockedAssetId`, the asset sold below the minimum,
    /// the methods paying in that asset are resolved as they pay once the amount fits.
    init?(plan: MultichainSwapFeePlan, picked: MultichainSwapFeeMethod?, amountBlockedAssetId: String? = nil) {
        func isAmountBlocked(_ asset: MultichainAssetDetails?) -> Bool {
            guard let asset, let amountBlockedAssetId else {
                return false
            }
            return AssetIdComponents.isSameAsset(asset.assetId, amountBlockedAssetId)
        }
        switch plan {
        case .preparing:
            return nil
        case .failed:
            self = .unknown
        case let .nativeFeeShortage(shortage) where isAmountBlocked(shortage.asset):
            self = .amounts([Amount(amount: shortage.requiredAmount, asset: shortage.asset)])
        case let .nativeFeeShortage(shortage):
            self = .noFunds(symbol: shortage.asset.symbol)
        case let .ready(feeOptions, networkFees):
            let options = feeOptions.map { isAmountBlocked($0.depositAsset) ? $0.payable : $0 }
            if let option = MultichainSwapFeeSelection.resolve(options: options, picked: picked) {
                self = Self.summary(of: option)
            } else {
                self = networkFees.isEmpty ? .unknown : .amounts(Amount.totals(networkFees.map { ($0.fee, $0.asset) }))
            }
        }
    }
}

private extension MultichainSwapFeeSummary {
    /// The selection lands on a method that cannot pay only when none can, and the row names that one's
    /// shortage: the battery when the user left the choice to it, the method they picked otherwise.
    static func summary(of option: MultichainSwapFeeOption) -> MultichainSwapFeeSummary {
        guard !option.isInsufficient else {
            if option.method.isBattery {
                return (option.availableCharges ?? 0) > 0 ? .lowBattery : .batteryEmpty
            }
            return option.depositAsset.map { .noFunds(symbol: $0.symbol) } ?? .unknown
        }
        if let charges = option.batteryCharges {
            return .charges(charges.cost)
        }
        guard let amounts = option.feeAmounts, !amounts.isEmpty else {
            return .unknown
        }
        return .amounts(amounts)
    }
}

private extension MultichainSwapFeeOption {
    var payable: MultichainSwapFeeOption {
        switch cost {
        case let .native(fees, _):
            return MultichainSwapFeeOption(cost: .native(fees, isInsufficient: false), availableCharges: availableCharges)
        case let .gram(amountNano, _):
            return MultichainSwapFeeOption(cost: .gram(amountNano: amountNano, isInsufficient: false), availableCharges: availableCharges)
        case let .token(asset, amount, _):
            return MultichainSwapFeeOption(cost: .token(asset, amount: amount, isInsufficient: false), availableCharges: availableCharges)
        case .batteryCharges, .batteryUnpriced:
            return self
        }
    }
}
