import PerpsModels
import TKLocalize

enum PerpsWithdrawErrorText {
    /// `nil` where the user already knows: a cancelled passcode needs no message.
    static func text(for message: PerpsWithdrawMessage) -> String? {
        switch message {
        case let .belowMinimum(usdc):
            TKLocales.Perps.WithdrawForm.minimum(usdc)
        case .quoteExpired:
            TKLocales.Perps.DepositForm.quoteExpired
        case .withdrawalRateLimited:
            TKLocales.Perps.WithdrawForm.rateLimited
        case .canceled:
            nil
        case .serviceUnavailable:
            TKLocales.Perps.Error.serverUnavailable
        case .notSent:
            TKLocales.Perps.WithdrawForm.notSent
        case .inFlight:
            TKLocales.Perps.WithdrawForm.inFlight
        case .failed:
            TKLocales.Perps.WithdrawForm.failed
        }
    }
}
