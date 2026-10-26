import KeeperCore
import TKLocalize

extension TonConnectSignMessageValidationError {
    var toastTitle: String {
        switch self {
        case .notSupported:
            return TKLocales.SignMessage.Error.notSupported
        case .invalidMessages:
            return TKLocales.SignMessage.Error.invalidRequest
        case .expired:
            return TKLocales.SignMessage.Error.expired
        case .networkMismatch:
            return TKLocales.SignMessage.Error.networkMismatch
        case .addressMismatch:
            return TKLocales.SignMessage.Error.addressMismatch
        }
    }
}
