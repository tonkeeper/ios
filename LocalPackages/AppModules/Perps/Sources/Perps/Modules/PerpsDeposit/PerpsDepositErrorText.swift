import PerpsModels
import TKLocalize

enum PerpsDepositErrorText {
    /// `nil` where the user already knows: a cancelled passcode needs no message.
    static func text(for message: PerpsDepositMessage, format: PerpsFormatting) -> String? {
        switch message {
        case let .belowMinimum(usd):
            TKLocales.Perps.DepositForm.minimum(format.usd(usd))
        case .quoteExpired:
            TKLocales.Perps.DepositForm.quoteExpired
        case .insufficientBalance:
            TKLocales.Perps.Funding.insufficientBalance
        case let .insufficientNetworkFee(symbol, required):
            if let required {
                TKLocales.Perps.DepositForm.insufficientNetworkFee(symbol, format.plain(required))
            } else {
                TKLocales.MultichainSwap.Screen.Confirm.NetworkFee.insufficientNativeToken(symbol)
            }
        case .accountCreationPending:
            TKLocales.Perps.DepositForm.accountCreationPending
        case .canceled:
            nil
        case .failed:
            TKLocales.Perps.DepositForm.failed
        }
    }
}
