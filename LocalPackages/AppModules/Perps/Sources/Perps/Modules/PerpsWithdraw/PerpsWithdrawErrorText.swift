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
        case .canceled:
            nil
        case .failed:
            TKLocales.Perps.WithdrawForm.failed
        }
    }
}
