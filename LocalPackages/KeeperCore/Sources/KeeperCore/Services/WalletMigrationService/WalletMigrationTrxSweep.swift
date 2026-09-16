import BigInt
import Foundation
import TronSwiftAPI

/// Live leftover-TRX sweep helpers shared by migration execution.
enum WalletMigrationTrxSweep {
    /// `createtransaction` is stricter than burn-price estimates — keep a buffer when a burn is due.
    static func bufferedFeeSun(_ feeSun: BigUInt) -> BigUInt {
        guard feeSun > 0 else { return 0 }
        let half = feeSun / 2
        let plusFloor = feeSun + 100_000
        return max(feeSun + half, plusFloor)
    }

    static func transferAmount(balanceSun: BigUInt, feeSun: BigUInt) -> BigUInt {
        let reserved = bufferedFeeSun(feeSun)
        guard balanceSun > reserved else { return 0 }
        return balanceSun - reserved
    }

    static func reducedAmountSun(_ amountSun: BigUInt) -> BigUInt {
        (amountSun * 4) / 5
    }

    static func isInsufficientTrxBalance(_ error: Error) -> Bool {
        if let tronError = error as? TronApi.Error {
            if tronError.isInsufficientTronResources {
                return true
            }
            if case let .apiError(message) = tronError {
                return messageIndicatesInsufficientBalance(message)
            }
        }
        return false
    }

    private static func messageIndicatesInsufficientBalance(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("balance is not sufficient")
            || lowered.contains("insufficient balance")
            || lowered.contains("account resource insufficient")
            || lowered.contains("not enough bandwidth")
    }
}
