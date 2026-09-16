import BigInt
import Foundation

public enum BatteryState: Equatable {
    case fill(percents: CGFloat)
    case empty
    case negative

    public var percents: CGFloat {
        switch self {
        case let .fill(percents):
            return percents
        case .empty, .negative:
            return 0
        }
    }
}

public extension BatteryBalance {
    var batteryState: BatteryState {
        let numberFormatter = NumberFormatter()
        numberFormatter.decimalSeparator = "."
        guard let balanceNumber = numberFormatter.number(from: balance) else {
            return .empty
        }
        let balance = CGFloat(truncating: balanceNumber)
        // battery full charged for approxiamately 2000 charges
        let max = 4.0
        let empty = 0.0

        if balance > empty {
            return .fill(percents: balance / max)
        }

        if balance < empty {
            return .negative
        }

        return .empty
    }
}
