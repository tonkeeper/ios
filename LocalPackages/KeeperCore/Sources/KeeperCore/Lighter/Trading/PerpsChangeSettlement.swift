import Foundation
import PerpsModels

enum PerpsChangeSettlement {
    static func sizeMoved(current: Double, before: Double, direction: PerpsSizeChangeDirection) -> Bool {
        switch direction {
        case .add: current > before
        case .reduce: current < before
        }
    }

    static func sizeMoved(
        current: Double,
        before: Double,
        direction: PerpsSizeChangeDirection,
        expectedDelta: Double?
    ) -> Bool {
        let observed = direction == .add ? current - before : before - current
        guard observed > 0 else { return false }
        guard let expectedDelta else { return true }
        let tolerance = max(0.000000001, abs(expectedDelta) * 1e-9)
        return observed + tolerance >= expectedDelta
    }

    static func closeMoved(current: Double, before: Double) -> Bool {
        current < before
    }

    static func marginMoved(current: Double, before: Double, amountUsd: Double, direction: PerpsMarginChangeDirection) -> Bool {
        let observedDelta = current - before
        // UpdateMargin is scaled to 1e-6 USDC. Allow only wire-rounding noise;
        // a half-amount threshold can turn unrelated funding/margin drift into success.
        let tolerance = max(0.000001, abs(amountUsd) * 1e-9)
        let requiredDelta = max(0, amountUsd - tolerance)
        switch direction {
        case .add: return observedDelta >= requiredDelta
        case .reduce: return -observedDelta >= requiredDelta
        }
    }
}
