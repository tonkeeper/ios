import BigInt
import Foundation
import TonSwift

public struct StackingPoolInfo: Codable, Equatable, Hashable {
    public struct Implementation: Codable, Hashable {
        @frozen public enum Kind: String, CaseIterable, Codable {
            case liquidTF
            case whales
            case tf
        }

        public let type: Kind
        public let name: String
        public let description: String
        public let urlString: String
        public let socials: [String]
    }

    public let address: Address
    public let name: String
    public let totalAmount: Int64
    public let implementation: Implementation
    public let apy: Decimal
    public let minStake: Int64
    public let cycleStart: TimeInterval
    public let cycleEnd: TimeInterval
    public let isVerified: Bool
    public let currentNominators: Int64
    public let maxNominators: Int64
    public let liquidJettonMaster: Address?
    public let nominatorsStake: Int64
    public let validatorStake: Int64
    public let cycleLength: TimeInterval?
}

public extension Array where Element == StackingPoolInfo {
    var profitablePools: [Element] {
        guard !isEmpty else { return [] }
        var max = self[0]
        var result = [max]
        forEach { element in
            if element.apy == max.apy {
                result.append(element)
                return
            }
            if element.apy > max.apy {
                result = [element]
                max = element
            }
        }
        return result
    }

    func filterByPoolKind(_ kind: StackingPoolInfo.Implementation.Kind) -> [StackingPoolInfo] {
        filter { $0.implementation.type == kind }
    }
}

public extension StackingPoolInfo.Implementation {
    var withdrawalFee: BigUInt {
        switch self.type {
        case .liquidTF:
            return BigUInt(integerLiteral: 1_000_000_000)
        case .tf:
            return BigUInt(integerLiteral: 1_000_000_000)
        case .whales:
            return BigUInt(integerLiteral: 200_000_000)
        }
    }

    /// TON held back while a withdrawal runs and returned afterwards, except what Whales keeps as its fee.
    var temporaryReserve: BigUInt {
        withdrawalFee
    }

    /// Whales keeps its withdrawal fee out of the reserve and returns only the rest.
    var keepsWithdrawalFee: Bool {
        if case .whales = type {
            return true
        }
        return false
    }

    /// TON left in the wallet by a max deposit, so the user can pay for withdrawing it later.
    var depositMinRemaining: BigUInt {
        switch self.type {
        case .whales:
            // Requesting the withdrawal and collecting it: 0.2 TON each plus fees.
            return BigUInt(integerLiteral: 410_000_000)
        case .liquidTF, .tf:
            return temporaryReserve + Self.networkFeeMargin
        }
    }

    /// Minimum TON balance to start a withdrawal: the temporary reserve plus the emulated network fee,
    /// or an estimate of it while the emulation is missing.
    func withdrawalRequiredBalance(networkFee: BigUInt?) -> BigUInt {
        temporaryReserve + (networkFee ?? withdrawalNetworkFeeEstimate)
    }

    private var withdrawalNetworkFeeEstimate: BigUInt {
        switch self.type {
        case .whales:
            return 10_000_000
        case .liquidTF, .tf:
            return Self.networkFeeMargin
        }
    }

    static var networkFeeMargin: BigUInt {
        100_000_000
    }

    var extraFee: BigUInt {
        switch self.type {
        case .liquidTF:
            return 0
        case .tf:
            return BigUInt(integerLiteral: 1_000_000_000)
        case .whales:
            return BigUInt(integerLiteral: 200_000_000)
        }
    }

    var depositExtraFee: BigUInt {
        switch self.type {
        case .liquidTF:
            return BigUInt(integerLiteral: 1_000_000_000)
        case .tf:
            return 0
        case .whales:
            return 0
        }
    }
}

public extension StackingPoolInfo {
    /// Yearly reward for `amount` at this pool's APY, in the same fraction digits as `amount`.
    func annualProfit(for amount: BigUInt) -> BigUInt {
        let apyFractionLength = max(Int(-apy.exponent), 0)
        let apyPlain = NSDecimalNumber(decimal: apy).multiplying(byPowerOf10: Int16(apyFractionLength))
        guard let apyBigInt = BigUInt(apyPlain.stringValue) else { return 0 }
        let scalingFactor = BigUInt(100) * BigUInt(10).power(apyFractionLength)
        return amount * apyBigInt / scalingFactor
    }
}
