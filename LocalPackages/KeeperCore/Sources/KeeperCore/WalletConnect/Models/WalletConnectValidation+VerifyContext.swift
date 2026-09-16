import ReownWalletKit

extension WalletConnectValidation {
    init(context: VerifyContext?) {
        switch context?.validation {
        case .valid:
            self = .valid
        case .invalid:
            self = .invalid
        case .scam:
            self = .scam
        case .unknown, .none:
            self = .unknown
        }
    }
}
